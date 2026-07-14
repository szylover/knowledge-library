# Checklist 05 — Cost Checklist

> 用于三类场景：**上线前**确认成本不会失控；**成本 review / FinOps audit** 时核对计费路径；**成本尖峰排查**时定位是 token、模型、缓存、检索、agent 还是租户行为出了问题。不要只看 provider 总账单，要把成本拆到 request、session、feature、tenant 与 model 版本。

---

## Token 预算与计费机制

- [ ] **[P0] 为 input tokens 与 output tokens 分开建预算**: 多数供应商的 output token 单价通常是 input token 的 2–4 倍，而且 decode 还是更慢的阶段；只盯总 token 会掩盖真正的成本杠杆。
  - 怎么验证：在计费日志或 trace 中分别记录 `prompt_tokens`、`completion_tokens`、
    `estimated_input_cost`、`estimated_output_cost`，并能按接口查看两者占比。

- [ ] **[P0] 为每个 request 和 session 设置硬性 token ceiling**: 没有硬上限时，长历史、长 RAG 片段和长输出会叠加，把单次成本从“可接受”推到“失控”。
  - 怎么验证：检查服务端配置而不是 prompt 文案；确认 `max_input_tokens`、`max_output_tokens`、
    `max_session_tokens` 超限时会截断、摘要或拒绝，而不是继续请求更贵模型。

- [ ] **[P0] 按任务类型收紧 `max_tokens`，不要用一个宽松默认值覆盖所有场景**: 摘要、分类、抽取、SQL 生成、客服回复的最优输出长度完全不同；统一放大只会稳定放大账单。
  - 怎么验证：导出各 feature 的 `max_tokens` 配置与真实 completion P50/P95；
    如果真实输出长期低于上限很多，说明上限设置过宽。

- [ ] **[P1] 把历史对话预算化，优先摘要旧轮次，而不是每轮全量回放**: 模型无状态，历史越长，每轮都要重新付 prefill 成本；“记忆”做得不好，本质上是重复买 token。
  - 怎么验证：抽样长会话，确认存在 history summarization 或 windowing 策略；
    查看 10+ 轮会话的 prompt token 曲线，不能随轮次近似线性无界增长。

- [ ] **[P1] 把 system prompt、tool schema、JSON schema、RAG chunk 统统计入预算**: 很多团队只算用户输入，结果真正昂贵的是稳定前缀和工具定义，尤其在 function calling / structured output 场景。
  - 怎么验证：打印请求拼装后的分项 token 明细，至少包含 system、history、retrieval、
    tool definitions、response format schema 五类，并能定位最大头部。

## 模型路由与降级

- [ ] **[P0] 默认路由到“最便宜且足够好”的模型，而不是“最强模型”**: 成本优化的第一原则不是压榨 prompt，而是先纠正默认模型选择；很多 feature 根本不需要最强推理模型。
  - 怎么验证：查看离线 eval 或 A/B 报告，确认每个 feature 都有“便宜模型 vs 贵模型”的质量-成本对比，
    且默认选择是满足 SLA / quality bar 的最低成本方案。

- [ ] **[P0] 为 router 设定可解释的置信度阈值，并量化阈值对成本的影响**: 路由阈值太保守，流量会过度打到贵模型；太激进，又会把质量损失转化为人工兜底成本。
  - 怎么验证：回放一批真实请求，输出不同 threshold 下的 cheap-model 命中率、
    escalation rate、每千请求成本和质量指标，阈值选择必须有数据依据。

- [ ] **[P1] 只把贵模型用于第二跳或困难样本，不要“一上来就上最强”**: 先用小模型完成分类、路由、抽取、约束化，再把少量困难请求升级，通常比全量直打大模型便宜得多。
  - 怎么验证：检查链路设计，确认存在 cheap-first / escalate-later 路径；
    在 trace 中能看到第一次判定模型与升级模型分别是谁，以及升级原因码。

- [ ] **[P1] 设计预算触发的降级路径，而不是只在 provider 5xx 时降级**: 真正常见的故障是“还能调用，但已经不值得调用”；预算耗尽时也要安全降级到小模型、模板回复或异步处理。
  - 怎么验证：人工演练 spend cap、provider tier 降级、rate limit 收紧三种场景；
    确认系统会切到 fallback model / cached answer / queue later，而不是继续透支预算。

- [ ] **[P2] 维护版本化价格表与 provider 映射，不要把单价写死在代码里**: 同一模型在不同 region、不同 provider、不同承诺量 tier 下价格可能不同；价格漂移会让旧假设失效。
  - 怎么验证：检查是否有配置化 price catalog，包含 `provider`、`region`、`model_version`、
    `input_price`、`output_price`、`cached_input_price` 等字段，并可热更新。

## Prompt Cache 与响应缓存

- [ ] **[P0] 把稳定不变的前缀前置，以最大化 prompt cache 命中率**: prompt cache 省掉的是重复 prefill 成本，不是“缓存整次回答”；前缀结构不稳定，命中率就会直接塌掉。
  - 怎么验证：检查 prompt 拼装顺序；system prompt、few-shot、tool schema 应位于前部且版本稳定，
    变化频繁的 user context / retrieval context 应位于后部。

- [ ] **[P0] 监控 prompt cache hit rate 与 billed prefill token 节省量**: 只知道“开了 cache”没有意义；真正要看的是命中率、命中后节省了多少输入成本，以及命中率为何下降。
  - 怎么验证：dashboard 至少展示 `cacheable_prefix_tokens`、`cached_tokens`、`cache_hit_rate`、
    `cache_savings_usd`，并能按 feature / prompt_version 过滤。

- [ ] **[P1] 为确定性、重复性高的请求建立 exact response cache**: FAQ、固定模板摘要、相同参数报表说明等场景，不需要每次都重新生成一遍。
  - 怎么验证：检查 cache key 是否包含 tenant、locale、prompt_version、model、
    normalized user input；抽样相同请求，命中后应直接返回缓存而不是再次触发模型调用。

- [ ] **[P1] 使用 semantic cache 时同时处理陈旧性与跨租户泄漏风险**: semantic cache 可以显著降成本，但近似匹配会带来答非所问、过期答案和安全隔离问题，必须和安全策略联动。
  - 怎么验证：确认 cache key 或检索 filter 至少绑定 tenant / ACL scope；
    设有 TTL、文档版本戳和人工抽检，且在安全评审中覆盖 cross-tenant leakage 风险。

- [ ] **[P2] 对 cache 失效条件做版本化管理**: prompt 变了、模型变了、tool schema 变了、知识库变了，如果缓存仍继续复用，省下的是成本，丢掉的是正确性。
  - 怎么验证：检查缓存层是否把 `prompt_version`、`model_version`、`tool_schema_hash`、
    `knowledge_snapshot_id` 纳入 key 或 invalidation 规则，并有回填/清理策略。

## Embedding 与 Rerank 成本

- [ ] **[P0] 单独预算索引期 embedding 成本，而不是只盯查询期**: 大语料库的 embedding 成本主要发生在建库和重建索引时；如果 corpus 规模和 chunk 策略设计错了，账单会在离线作业里爆炸。
  - 怎么验证：为 ingest pipeline 记录文档数、chunk 数、平均 chunk token、
    总 embedding token 和重建频率，能估算一次全量重建的美元成本。

- [ ] **[P1] 优先使用 batch embedding，而不是按文档逐条调用**: 单条调用会放大请求开销、吞吐抖动和限流影响；batch 往往同时改善单价和吞吐。
  - 怎么验证：查看 embedding worker 配置，确认存在 `batch_size`、`max_batch_tokens`、
    retry/backoff，并比较 batch 与单条模式的 docs/sec 与 usd / million tokens。

- [ ] **[P1] 选择 embedding model 时同时看 recall、单价、向量维度和存储成本**: 向量数据库成本不只在模型调用；维度越高，索引体积、内存占用和 ANN 查询成本也会上升。
  - 怎么验证：在同一评测集上比较候选 embedding 模型的 recall@k、index size、
    query latency 与总持有成本，而不是只看 provider 的每百万 token 报价。

- [ ] **[P1] 只在 rerank 能明显改变 top-k 质量时才启用，并限制候选集大小**: rerank 往往按 query 额外付费或额外调用模型；如果它很少改变排序，成本就是纯浪费。
  - 怎么验证：对比“仅向量检索”与“向量检索 + rerank”的 NDCG / MRR / answer accuracy；
    同时记录每次 rerank 的候选数 N，避免默认对 50 或 100 个 chunk 全量重排。

- [ ] **[P2] 采用增量 re-embed、去重与变更检测，避免无意义全量重建**: 每次小文档改动都重算全库，是最常见也最隐蔽的离线成本浪费。
  - 怎么验证：检查索引 pipeline 是否基于内容 hash、last_modified、chunk diff 做增量更新；
    抽查一次小批量文档更新，不应触发全库 re-embed。

## Agent 与工具调用成本

- [ ] **[P0] 把每个 agent step、tool call、sub-agent spawn 都视为显式成本事件**: Agent 账单不是“一次请求多少钱”，而是“每走一步都在花钱”；不做 step 级归因就无法解释 runaway bill。
  - 怎么验证：trace 中至少有 `step_index`、`tool_name`、`tool_latency_ms`、
    `model_tokens`、`step_cost_usd`、`cumulative_session_cost_usd` 字段。

- [ ] **[P0] 为 agent 设置 `max_steps`、`max_tool_calls` 与 per-session spend cap**: 真正的高风险不是单次回答长，而是代理循环和工具重试无限扩散，把一条用户请求变成几十次模型调用。
  - 怎么验证：检查 orchestrator 代码，确认 hard stop 在服务端生效；
    人工构造循环样例，验证达到上限后会中断并返回可解释错误，而不是继续自旋。

- [ ] **[P1] 限制 sub-agent fan-out，禁止无预算的并发探索**: 每派生一个子代理，都是新的一段上下文、新的 prompt、新的工具调用面；“多开几个 agent 试试”本质上是在并行烧钱。
  - 怎么验证：查看 planner 或 agent policy，确认存在并发上限、
    子代理白名单和审批条件，并能在日志中看到谁触发了 fan-out。

- [ ] **[P1] 检测“无进展循环”，及时 early stop**: 很多 agent 失败不是模型不会做，而是重复读同一批文档、重复调用同一个工具、重复生成相似计划。
  - 怎么验证：实现 no-progress heuristic，例如连续 N 步相同 tool / 相似 action / 相同错误码；
    回放失败 session，确认能在低成本处终止，而不是拖到硬上限。

- [ ] **[P2] 为昂贵工具与外部 API 建立重试预算与幂等策略**: 一个工具调用的成本常常高于一次小模型推理；盲目重试会把“偶发失败”放大成“稳定亏损”。
  - 怎么验证：检查 tool runner 是否区分可重试 / 不可重试错误，
    是否有最大重试次数、退避和幂等 key，并在账单中分离“首次调用成本”与“重试成本”。

## 租户级配额与归因

- [ ] **[P0] 所有 AI 成本都必须可归因到 tenant / customer / workspace / feature**: 只看全局账单无法回答“是谁在烧钱”，也就无法做配额、showback、合同谈判或异常追责。
  - 怎么验证：抽样任意一条 provider 调用日志，确认能回查到 tenant_id、
    customer_id、feature_name、request_id 与 session_id，而不是只剩模型名和 token 数。

- [ ] **[P0] 在服务端执行 per-tenant spend cap 与 hard cutoff**: 预算约束不能靠前端提示或人工巡检；真正防止单个租户打爆预算的只有服务端强制执行。
  - 怎么验证：在测试环境为某租户设置极低月度/日度上限，
    连续发送请求直到触发阈值，确认返回的是受控错误和告警，而不是继续放行。

- [ ] **[P1] 按套餐、环境与身份分层配额**: free、trial、paid、internal admin、batch job 的预算模型不该相同；否则不是挡住付费客户，就是被内部脚本偷偷吃掉预算。
  - 怎么验证：检查 quota policy 是否至少区分 tenant plan、environment、
    actor type 和 sync/async workload，并有独立阈值与超额处理策略。

- [ ] **[P1] 对外做 showback / chargeback，对内做 owner 账本**: 成本一旦不可见，所有优化都缺乏组织动力；能看到账的人，才会主动减少无意义 token。
  - 怎么验证：确认存在 tenant 月报、feature owner 月报或内部 dashboard；
    报表至少展示请求量、token 量、缓存节省、模型分布和超额原因。

- [ ] **[P2] 把承诺量、预付金和合同条款纳入容量规划**: FinOps 不是只做“技术省钱”，还包括把真实流量形状映射到 provider tier，避免一边超买、一边按高价溢出。
  - 怎么验证：核对近 30/60/90 天实际消耗与合同承诺量、burst 条款、
    overage 单价，确认存在季度性重谈或迁移预案。

## 成本可观测性

- [ ] **[P0] 在 request、session、feature 三个粒度同时计算成本**: 只看单次请求会漏掉长会话；只看 session 会漏掉高频小请求；只看 feature 会掩盖个别异常请求模式。
  - 怎么验证：dashboard 中至少能按 request_id、session_id、feature_name 三个维度切片，
    并能 drill down 到单次调用的 token、缓存、工具与 rerank 构成。

- [ ] **[P0] 成本指标必须按 model、prompt_version、provider、tool、cache 状态拆分**: 聚合美元曲线没有诊断价值；你需要知道是哪个版本、哪个模型、哪个工具路径把成本推高了。
  - 怎么验证：检查指标标签或日志字段，至少包含 `model`、`model_version`、
    `prompt_version`、`provider`、`cache_hit`、`tool_name`、`route_reason`。

- [ ] **[P1] 每日对账：内部估算成本要能与 provider 发票近似对齐**: 如果内部 meter 与供应商账单长期对不上，所有优化都可能建立在错误数据上。
  - 怎么验证：跑 daily reconciliation job，比对 request-level meter 汇总与 provider usage export；
    差异超阈值时能列出是价格表错误、漏记 cached token，还是工具成本未纳入。

- [ ] **[P1] 监控“成本结构变化”，不只监控总额**: 总成本不变并不代表健康；可能是缓存命中率掉了，但被流量下降掩盖，或者贵模型占比升了但请求量降了。
  - 怎么验证：为 input/output token ratio、cache hit rate、
    expensive-model share、rerank adoption、tool cost share 建独立趋势图和异常检测。

- [ ] **[P2] 把成本观测接入 trace / span，而不是孤立在财务报表里**: 成本问题最终要落回工程链路；没有 trace，工程师只能看到钱花多了，却不知道是哪一步花多了。
  - 怎么验证：抽样一条高成本 trace，确认能沿调用链看到检索、模型、
    工具、缓存命中与重试事件，而不是只能在月报里看到一个汇总数字。

## 成本回归与预算告警

- [ ] **[P0] 在 CI / eval 中比较 prompt 变更前后的 token 使用量**: prompt 看起来只是多加一段说明，但可能把每次请求稳定增加几百 token；这类回归如果不自动化，几周后才会在账单上出现。
  - 怎么验证：为代表性样本集保存 baseline token 统计；
    PR 中自动输出 before/after 的 prompt tokens、completion tokens 和估算美元差异。

- [ ] **[P0] 为重要 feature 设“成本不退化”发布闸门**: 只看质量通过不够；如果同等质量下成本上涨 30%，这也是 release blocker，尤其在高 QPS 功能上。
  - 怎么验证：在评测流水线里定义可接受阈值，例如质量不降且成本涨幅 < 10%；
    超阈值的 PR 需要显式批准或回退。

- [ ] **[P1] 建立 burn-rate 与 forecast 告警，而不是月底对账才发现超支**: AI 成本的危险在于增长速度快；月底看总额时，往往已经来不及处理。
  - 怎么验证：按日/小时计算预算消耗速率与月底预测值；
    当预测超预算、单租户突增、单 feature 占比异常时，自动发告警给 owner。

- [ ] **[P1] 监控 provider 的 rate tier、pricing tier 与折扣失效**: 成本问题不只有“我们多用了”，也可能是“同样用量变贵了”——配额下调、折扣过期、区域切换都可能触发。
  - 怎么验证：维护供应商价格与配额基线，
    每日检查是否发生 tier 变化、discount expiry 或区域路由漂移，并产出差异报告。

- [ ] **[P2] 为成本尖峰准备 kill switch、feature flag 与排查 runbook**: 真正出事时，团队需要的是 10 分钟内可执行的止血动作，而不是事后分析文章。
  - 怎么验证：runbook 中至少写清关闭哪些 feature、切回哪些模型、
    如何禁用 rerank / agent / semantic cache，以及谁有权限执行这些开关。

## 常见反例

| 反例 | 典型后果 | 更好的做法 |
|------|----------|------------|
| 所有请求都路由到最强模型 | 质量提升不明显，但成本和延迟稳定偏高 | 先用 eval 找到 cheapest sufficient model，再只把困难样本升级 |
| 只看总 token，不拆 input / output | 找不到真正的成本杠杆，长输出问题长期被忽略 | 分别统计 input/output token 与各自美元占比，优先压 completion |
| 开了 prompt cache，但前缀顺序每次都变 | 命中率极低，账单几乎没有改善 | 稳定前缀前置，变化内容后置，并持续监控 hit rate |
| semantic cache 没有 tenant 隔离 | 可能出现跨租户内容泄漏，属于安全事故 | cache key / filter 绑定 tenant 与 ACL scope，并做 TTL 与版本失效 |
| rerank 默认对 100 个 chunk 全量执行 | 每次查询都额外付费，但 top-k 改善有限 | 先用第一阶段检索收窄候选，再证明 rerank 确实带来质量提升 |
| agent 没有 `max_steps` 和 spend cap | 一次循环就可能烧掉整天预算 | 服务端强制执行步数、工具次数和会话花费上限 |
| 没有 per-tenant 成本上限 | 单个客户或脚本异常即可打爆月度预算 | 服务端执行 tenant cap，并在接近上限时提前告警 |

## 关联章节

- [Chapter 21 — Cost Optimization](../part2_ai_engineering/chapter-21-cost-optimization.md)
- [Chapter 11 — Memory](../part2_ai_engineering/chapter-11-memory.md)
- [Chapter 07 — Embedding & Vector DB](../part2_ai_engineering/chapter-07-embedding-vector-db.md)
- [Chapter 09 — Hybrid Search & Reranking](../part2_ai_engineering/chapter-09-hybrid-search-reranking.md)
- [Part 1 / Chapter 11 — Cost Optimization](../part1_system_design/chapter-11-cost-optimization.md)
