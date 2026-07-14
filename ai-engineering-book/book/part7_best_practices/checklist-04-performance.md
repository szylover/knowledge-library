# Checklist 04 — Performance Checklist

> 用于两类场景：一是上线前评审所有 latency-sensitive 的 AI 功能；二是线上出现 TTFT 变慢、吞吐下降、尾延迟抬升时，快速定位瓶颈。不要只看一个“总延迟”数字，要拆阶段、看分布、看负载条件。

---

## 使用方式

| 标记 | 含义 | 处理原则 |
|------|------|----------|
| **P0** | 上线阻断项 | 未满足不要发布；先补硬限制、观测和回退。 |
| **P1** | 高风险项 | 可以灰度，但必须带 dashboard、告警和回滚手段。 |
| **P2** | 优化项 | 不阻断发布，但应进入 backlog，并在下轮压测前复查。 |

性能评审不要接受“感觉还行”。每一项都应落到证据：trace、token 分布、phase breakdown、压测报告、provider 限流数据、GPU 指标、queue depth、缓存命中率、agent step trace。

## TTFT / TPOT 与延迟分解

- [ ] **[P0] 为 TTFT 和 TPOT 分别定义 SLO**：TTFT 主要受 prefill 影响，TPOT 主要受 decode 影响；把它们混成一个“响应时间”会掩盖真正瓶颈。
  - 怎么验证：在 dashboard 中单独展示 `ttft_ms`、`tpot_ms`、`output_tokens_per_sec`，并为至少 p50 / p95 设置阈值；确认告警不是只绑总延迟。

- [ ] **[P0] 在 trace 中拆出 queueing、retrieval、prefill、decode 四段时间**：用户感知的是端到端，但工程优化必须知道时间到底耗在排队、检索还是生成。
  - 怎么验证：抽样 20 条 trace，确认至少包含 `queue_ms`、`rag_ms`、`prefill_ms`、`decode_ms`、`network_ms` 字段，且总和近似端到端延迟。

- [ ] **[P0] 为长输入和长输出分别建尾延迟视图**：长 prompt 往往拉高 TTFT，长 completion 往往拉高总时长；只看全量平均值会把两类问题抵消掉。
  - 怎么验证：按 `input_tokens` 和 `output_tokens` 分桶看 p95 / p99，至少有 `<1k`、`1k-8k`、`8k+` 三档输入和 `<256`、`256-1k`、`1k+` 三档输出。

- [ ] **[P1] 区分 provider latency 与应用侧附加延迟**：模型 API 本身可能快，但 gateway、JSON 序列化、审核、日志同步写入也会显著推高尾延迟。
  - 怎么验证：比较 provider SDK 返回时间与 API handler 总时长；确认二者差值被进一步拆到 auth、policy、serialization、post-processing 等阶段。

- [ ] **[P1] 用 decode 吞吐而不是“每请求平均耗时”观察生成性能**：decode 更接近 memory-bandwidth-bound；模型升级或显卡切换时，tokens/sec 往往比总耗时更稳定地暴露问题。
  - 怎么验证：为每个 model deployment 展示 `decode_tokens_per_sec` 和 `tpot_ms`；对比同一输入长度下不同机型或不同 provider 的差异。

- [ ] **[P2] 为客户端取消、超时、provider stop 分别记录结束原因**：很多“高延迟”其实是用户中途放弃，或服务端在长尾时被客户端断开。
  - 怎么验证：检查 `finish_reason`、`client_cancelled`、`timeout_source`、`stream_closed_by` 统计；确认这些事件不会被误算成纯模型性能回归。

## Token 预算与分布

- [ ] **[P0] 持续观测输入和输出 token 的 p50 / p95 / p99 分布**：性能容量不是只由请求数决定，而是由 token 体积决定；固定 RPS 下，长度分布漂移会直接改写延迟与成本。
  - 怎么验证：dashboard 中同时展示 `input_tokens` 与 `output_tokens` 的 p50 / p95 / p99，按 endpoint、tenant、model 三个维度都能下钻。

- [ ] **[P0] 记录 prompt 各组成部分的 token 占比**：system prompt、history、retrieved chunks、tool schema、user input 都在抢 context window；不拆开就不知道该削哪里。
  - 怎么验证：trace 中输出 `system_tokens`、`history_tokens`、`retrieved_tokens`、`tool_tokens`、`user_tokens`，并能在一次请求上加总对齐 `input_tokens`。

- [ ] **[P0] 对每条请求执行硬性的 token budget**：没有 budget，长历史、过多 chunk 或过大的 tool schema 会把 TTFT 和失败率一起推高。
  - 怎么验证：检查代码里的 hard limit，而不是只靠提示词约束；确认超预算时会裁剪、摘要或拒绝，而不是把超长上下文直接发给模型。

- [ ] **[P1] 监控 token 分布漂移而不是只监控延迟漂移**：很多 latency regression 根因是输入变长，不是模型变慢；先发现 token 漂移，定位更快。
  - 怎么验证：对版本发布前后比较 `input_tokens_p95`、`retrieved_tokens_p95`、`tool_tokens_p95`；确认告警策略里有 token 分布漂移规则。

- [ ] **[P1] 为不同任务定义不同输出上限**：抽取、分类、路由通常不该拿和长文写作一样的 `max_tokens`；过大的上限会放大尾延迟和显存预留。
  - 怎么验证：检查配置中心或代码映射，确认每个 task type 有独立 `max_output_tokens`，并在 trace 中能看到生效值。

- [ ] **[P2] 将 token 分布纳入容量规划模型**：同样是“100 并发”，`200 in / 50 out` 与 `8k in / 1k out` 对系统的压力完全不是一个数量级。
  - 怎么验证：压测报告中包含长度分布假设，而不是只写 QPS；容量表格至少区分 short / medium / long 三种请求画像。

## 上下文长度与 Prefill 成本

- [ ] **[P0] 明确长上下文主要伤害 TTFT，而不是用模糊的“模型慢了”描述问题**：prefill 要一次处理全部输入 token，长度上去后首 token 时间会先抬升。
  - 怎么验证：选同一模型、近似相同输出长度，对比不同输入长度的 TTFT 曲线；确认 TTFT 随 `input_tokens` 增长而不是无关波动。

- [ ] **[P0] 在长上下文场景下评估 attention 成本，而不是只看 context window 能不能塞下**：能塞下不等于值得塞；attention 及 KV cache 会显著放大延迟与资源占用。
  - 怎么验证：在 8k、32k、64k、128k 四档输入上做基准，对比 TTFT、显存占用和失败率；把“可用上限”和“推荐工作区间”分开记录。

- [ ] **[P1] 避免把低价值内容放进长上下文中段**：长上下文不仅贵，还容易出现 lost-in-the-middle，结果是又慢又不准。
  - 怎么验证：抽查 prompt 组装逻辑，确认重要 instruction、query 和高置信证据优先放前后；对长上下文样本做 A/B 比较看质量与 TTFT。

- [ ] **[P1] 为 history、RAG、tool schema 分别设置裁剪顺序**：上下文超限时，如果所有内容一刀切，很容易误删真正重要的部分。
  - 怎么验证：检查裁剪策略是否定义优先级，例如先减历史、再减低分 chunk、最后才压系统提示；用超长样本验证裁剪结果可解释。

- [ ] **[P1] 对长上下文请求单独看 admission control**：少量超长请求会拖垮 shared worker，影响大量短请求。
  - 怎么验证：确认长上下文请求能走单独队列、单独并发上限或单独 deployment；观察长短请求混跑与隔离时的 p95 差异。

- [ ] **[P2] 不把“更长 context window”当成默认优化方向**：很多场景更有效的是更准的 retrieval、更短的 prompt、或更强的 cache 命中率。
  - 怎么验证：在设计评审中要求提供替代方案对比：长上下文直塞 vs RAG vs 摘要压缩，并比较质量、TTFT 和成本。

## Prompt Cache 与前缀复用

- [ ] **[P0] 把稳定前缀固定在 prompt 最前面**：system prompt、tool definitions、few-shot example 先放，变化大的 user input 和 retrieval 后放，才能最大化 prompt cache / prefix cache 命中率。
  - 怎么验证：检查 prompt builder 的拼接顺序；确认相同任务的稳定前缀在多次请求间字节级一致或 token 级一致。

- [ ] **[P0] 将 cache hit rate 作为一等性能指标**：没有命中率指标，团队通常直到账单上涨或 TTFT 抬升才发现缓存失效。
  - 怎么验证：dashboard 至少展示 `prompt_cache_hit_rate`、`cached_input_tokens`、`cache_saved_ms`、`cache_saved_cost`，并支持按 model / endpoint 下钻。

- [ ] **[P1] 避免把 request_id、timestamp、随机 salt 等高熵字段塞进前缀**：这些微小变化会让理论上可缓存的前缀完全失去复用价值。
  - 怎么验证：抽查实际发送给模型的 prompt，确认动态字段位于后缀或 metadata，而不是位于系统提示或 few-shot 前部。

- [ ] **[P1] 为 prompt version、tool schema version 建立稳定发布机制**：频繁无意义改动前缀会打穿 cache，导致灰度期间 TTFT 明显抖动。
  - 怎么验证：查看 prompt/template 的版本 diff；确认小改动不会在所有请求路径上同步失效，且版本变更有回滚方案。

- [ ] **[P1] 用真实流量测量 cache 对 TTFT 的收益，而不是只看 provider 文档**：不同 workload 的收益差异很大，尤其取决于前缀稳定度和请求重用模式。
  - 怎么验证：对命中与未命中请求分别统计 TTFT 分布，确认存在可观的 p50 / p95 改善，而不是只有理论节省。

- [ ] **[P2] 为缓存失效高峰准备预热或渐进发布策略**：大规模切 prompt version、region 迁移或 deployment 切换时，prefill 成本会瞬间回到满额。
  - 怎么验证：发布计划中包含 cache cold-start 预估；灰度期间观察 `prompt_cache_hit_rate` 和 `ttft_ms` 是否出现预期内的短时波动。

## 模型路由与降级

- [ ] **[P0] 先定义 router 的优化目标，再决定用什么规则**：路由不是“尽量便宜”这么简单，目标通常是质量下限约束下的最低延迟或最低成本。
  - 怎么验证：查看路由设计文档，确认明确写出目标函数、可接受误路由率、升级条件和业务失败定义，而不是口头约定。

- [ ] **[P0] 为 router 设置 confidence threshold 和 fallback**：小模型应处理简单请求，但低置信或结构化失败时必须升级到更大模型，而不是硬扛到底。
  - 怎么验证：检查 router 代码或策略配置，确认存在阈值、最大重试次数、升级模型列表和 fallback trace；用边界样例验证升级路径。

- [ ] **[P1] 把延迟预算纳入路由决策**：有些任务虽然“理论上更适合大模型”，但在交互场景下如果超出预算，应该优先更快路径或分阶段返回。
  - 怎么验证：查看 router feature，确认包含请求复杂度、当前队列、模型可用性或历史 latency；A/B 看相同质量下的 TTFT 改善。

- [ ] **[P1] 防止多跳升级造成串行延迟叠加**：先小模型、再中模型、再大模型的逐级试探，很容易把一次请求变成三次串行调用。
  - 怎么验证：检查 router 是否限制最大 hop 数；统计每请求的 `route_hops` 分布，确认 p95 不会出现两次以上升级。

- [ ] **[P1] 为每个模型部署独立监控错误率、TTFT 和 TPOT**：路由层会掩盖单个模型的退化；如果只看全局平均，问题会被分流掩盖。
  - 怎么验证：dashboard 可按 `routed_model` 分组查看成功率、TTFT、TPOT、tokens/sec 和 429/5xx；告警支持按模型维度触发。

- [ ] **[P2] 在灰度中同时评估质量、延迟、成本三轴，而不是只看某一个最优**：最便宜的路由不一定稳，最快的路由也可能质量不达标。
  - 怎么验证：灰度报告至少包含任务成功率、人工抽检或 eval 分数、TTFT / TPOT、单位请求成本，并给出最终 cutover 原因。

## RAG 延迟链路

- [ ] **[P0] 把“生成前”的 RAG 延迟完整拆开**：embedding、query rewrite、vector search、metadata fetch、rerank、chunk hydration 都发生在模型开始生成之前，它们直接抬高 TTFT。
  - 怎么验证：trace 中至少有 `rewrite_ms`、`embed_ms`、`vector_search_ms`、`rerank_ms`、`hydrate_ms`、`generation_ms`，并能看见哪一段占比最大。

- [ ] **[P0] 为 RAG 设定 generation 前预算**：如果 retrieval 链路已经吃掉 1.5 秒，那么再快的模型也救不了交互体验。
  - 怎么验证：为 `rag_pre_generation_ms` 设置 p95 预算，例如 300ms / 500ms；超预算时触发降级，例如跳过 rerank、减少 top_k 或使用 cached answer path。

- [ ] **[P1] 调优 query embedding 的 batch size 与并发**：自建 embedding 服务常见问题不是模型精度，而是小 batch 低利用率或大 batch 排队过久。
  - 怎么验证：在不同 batch size 下测吞吐、p95 延迟和 GPU 利用率；选择而不是猜测最优点，并记录 query 峰值时的排队变化。

- [ ] **[P1] 对 ANN 参数做 latency / recall trade-off，而不是使用默认值**：`ef_search`、`nprobe`、`num_candidates` 等参数会直接影响搜索时延与召回率。
  - 怎么验证：准备带标注的 retrieval benchmark，对不同参数组合同时记录 recall@k、MRR 和 `vector_search_ms`，选业务可接受的折中点。

- [ ] **[P1] 控制 top-k 与 chunk hydration 的字节预算**：vector search 本身也许只要几毫秒，但把 20 个大 chunk 回源、拼接、清洗后，TTFT 很快就被拖垮。
  - 怎么验证：记录 `candidate_k`、`hydrated_chunks`、`hydrated_bytes`、`retrieved_tokens`；用实验比较 `top_k=5/10/20` 对质量和延迟的边际收益。

- [ ] **[P1] 为 rerank 明确延迟上限和收益下限**：rerank 不是默认必开；如果多花 120ms 只换来极小质量提升，在强交互场景可能不值。
  - 怎么验证：A/B 比较“无 rerank / 轻量 rerank / 大 rerank”的 answer quality 与 `rerank_ms`；为不同场景定义是否启用的门槛。

- [ ] **[P2] 并行化独立的 retrieval 子步骤**：能并行的不要串行，比如 metadata fetch、ACL filter、document hydration 常可与后续准备步骤并发。
  - 怎么验证：查看执行图，确认不存在无必要的串行等待；对并行前后 trace 的 critical path 做对比，验证总时长确实缩短。

## Agent 与工具调用延迟

- [ ] **[P0] 为 agent 设置 max_steps、max_tool_calls 和总 deadline**：agent 的延迟爆炸通常不是单次模型慢，而是多轮推理和工具调用串起来失控。
  - 怎么验证：检查 runtime 配置，确认存在硬上限；构造坏例子验证 agent 会在达到步数、时间或工具次数上限后安全停止。

- [ ] **[P0] 区分必须串行与可并行的工具调用**：很多 agent trace 慢，不是因为工具本身慢，而是本可并发的独立查询被顺序执行。
  - 怎么验证：抽样 agent trace，把每个 tool call 标注依赖关系；确认无依赖的查询、检索、状态读取可在同一轮并行发出。

- [ ] **[P1] 为每个工具设置单独 timeout，而不是继承一个模糊的大超时**：数据库查找、HTTP 搜索、文件读取的正常时延不同，统一超时会让某些工具过慢却迟迟不失败。
  - 怎么验证：检查 tool registry，确认每个工具有独立 timeout、重试策略和可观察的 `tool_latency_ms`；用故障注入验证超时生效。

- [ ] **[P1] 对确定性工具结果做缓存或 shortcut**：例如配置查询、特征开关、静态元数据，不应在每步 agent 推理中重复请求。
  - 怎么验证：查看高频工具的调用分布，确认重复 read-only 调用有 cache 命中率指标，且命中后不会重新进入完整工具链。

- [ ] **[P1] 同时记录 token 消耗与工具时延**：agent 可能“看起来慢”，但瓶颈也许是每轮 prompt 变长、TTFT 越来越高，而非工具调用慢。
  - 怎么验证：trace 中每轮都有 `step_input_tokens`、`step_output_tokens`、`step_ttft_ms`、`tool_latency_ms`；能看出是思考变长还是工具变慢。

- [ ] **[P2] 对固定流程优先使用 workflow，而不是开放式 agent loop**：如果步骤本来就是“检索 -> 调 API -> 总结”，开放式 agent 只会引入额外轮次和不确定延迟。
  - 怎么验证：比较 workflow 版与 agent 版在同一任务上的 step 数、总时长和成功率；确认 agent 只用于确实需要动态决策的场景。

## 流式输出与感知延迟

- [ ] **[P0] 交互式场景默认启用 streaming**：用户通常更在意“多久看到第一个字”，而不是完整响应晚 200ms；流式能显著改善主观等待感。
  - 怎么验证：在 Web / App 端确认采用 SSE、WebSocket 或等价流式协议，并能在收到首 token 后立即渲染，而不是攒满再一次性显示。

- [ ] **[P0] 把 first rendered token time 作为 UX 指标，而不是只看服务端 TTFT**：服务端已生成首 token，不代表用户界面已经看到首 token；中间层 buffering 会吞掉收益。
  - 怎么验证：同时记录 server `ttft_ms` 与 client `first_rendered_token_ms`；抽样确认两者差值稳定且可解释。

- [ ] **[P1] 清理反向代理、CDN、应用框架的流缓冲**：默认 buffering 常让“流式”退化成伪流式，直到积累到一定字节数才吐给前端。
  - 怎么验证：在真实部署环境抓包或用浏览器 devtools 观察 chunk 到达时间，确认不是每隔几百毫秒或几 KB 才批量到达。

- [ ] **[P1] 为 streaming 设计渐进式 UI，而不是只把完整答案拆成字符雨**：如果引用、结构化字段、工具结果必须等全部完成才出现，用户感知未必更好。
  - 怎么验证：检查产品交互，确认可先显示摘要、思考中状态、局部段落或占位，再补 citation、table 或 tool result。

- [ ] **[P1] 用户取消时要把中断传播到模型和下游工具**：如果前端关闭连接但服务端仍继续 decode 或跑工具，容量会被静默浪费。
  - 怎么验证：在取消请求时观察 provider 调用、tool call 和 worker 生命周期，确认能尽快停止而不是继续跑完整条链路。

- [ ] **[P2] 非交互式任务不要为了“统一架构”强行流式**：批处理、后台报告生成更关心总吞吐和资源利用率，流式可能只增加复杂度。
  - 怎么验证：区分同步交互接口与后台异步任务；确认 streaming 的接入只出现在真正需要缩短感知延迟的路径上。

## 容量规划、压测与批处理

- [ ] **[P0] 容量规划按 token throughput、并发和长度分布建模，而不是只按 RPS**：LLM 系统的核心资源消耗来自 token 处理量与排队，不是传统 Web 的纯请求数。
  - 怎么验证：容量模型至少包含 `requests/sec`、`input_tokens/sec`、`output_tokens/sec`、并发请求数和队列上限，而不是只有单一 QPS。

- [ ] **[P0] autoscaling 依据 queue depth、GPU utilization、tokens/sec 或 provider rate-limit headroom，而不是只看 CPU**：CPU 经常很闲，但 GPU、provider quota 或内部队列已经成为硬瓶颈。
  - 怎么验证：检查 HPA / KEDA / 自定义扩缩容规则，确认触发指标包含 queue、GPU 或 quota；回看一次扩容事件验证触发合理。

- [ ] **[P0] 对 provider API 的 RPM / TPM / 并发限制做显式预算**：外部模型服务最常见的性能事故不是“变慢”，而是 429、排队和级联重试。
  - 怎么验证：查看各模型的 rate-limit 配额、客户端 limiter 配置和 burst 策略；在压测下确认不会因为重试放大拥塞。

- [ ] **[P1] 压测必须使用真实 token-length 分布，而不是固定短 prompt**：固定 200 token 的 synthetic prompt 几乎无法预测真实线上尾延迟。
  - 怎么验证：压测输入采样自真实流量或其匿名分布，至少覆盖短、中、长和极端长尾；报告中明确列出分布来源与百分位。

- [ ] **[P1] 自托管推理要调 batching 策略，而不是默认值上线**：continuous batching、max batch size、max batched tokens、batch timeout 会同时影响吞吐与 TTFT。
  - 怎么验证：在 self-hosted inference 上对不同 batching 参数做基准，记录 TTFT、TPOT、GPU 利用率和尾延迟；选择适合交互或离线任务的配置。

- [ ] **[P1] 为长短请求建立隔离或优先级队列**：一个超长请求占住 worker，会让大量短请求一起排队，表现为全局 p95 抬升。
  - 怎么验证：检查调度策略是否按预估 token 数、endpoint 或租户做分层；比较隔离前后的短请求 TTFT 和 queue time。

- [ ] **[P2] 预留 cold start、模型加载和索引预热预算**：很多系统平时快，扩容或故障切换时才暴露模型加载、ANN 索引 mmap、JIT 编译的额外开销。
  - 怎么验证：演练 scale-out、pod restart、region failover；记录第一次请求与稳态请求的 TTFT 差异，并决定是否需要 warm pool。

## 常见反例

| 反例 | 为什么错 | 应做什么 |
|------|----------|----------|
| 只监控 HTTP 总延迟，不拆 TTFT / TPOT | 无法区分是 prefill 慢、decode 慢，还是前置 RAG / queueing 慢 | 至少拆成 queue、RAG、prefill、decode 四段，并分别设 SLO |
| 压测只用固定短 prompt | 无法覆盖真实线上输入长度长尾，p95 / p99 会被严重低估 | 用真实 token-length 分布压测，并单独看长请求 |
| 只看平均 token 数 | 平均值会掩盖少量超长请求对尾延迟和容量的破坏 | 看输入、输出 token 的 p50 / p95 / p99 和分桶分布 |
| Prompt 前缀里带 timestamp / request_id | 高熵字段会打穿 prompt cache，TTFT 和成本一起上升 | 稳定前缀前置，动态字段放后缀或 metadata |
| 所有请求都上最大模型 | 质量未必显著更好，但延迟、成本和限流压力都会上升 | 用 router 把简单任务交给便宜/快模型，低置信再升级 |
| RAG 只看召回，不看链路时延 | embedding、向量检索、rerank 可能在生成前就耗掉大半预算 | 为 RAG 前置链路设独立 latency budget 和降级策略 |
| Agent 工具调用默认串行 | 多个独立 read-only 工具顺序执行会把总时长成倍放大 | 标注依赖关系，对无依赖调用并行化 |
| 扩缩容只盯 CPU | LLM 服务瓶颈常在 GPU、队列或 provider quota，CPU 常不敏感 | 用 queue depth、GPU utilization、tokens/sec、rate-limit headroom 驱动扩缩容 |

## 关联章节

- [Chapter 02 — Token 与 Context Window](../part2_ai_engineering/chapter-02-token-context-window.md)
- [Chapter 17 — Streaming 与 Long Context](../part2_ai_engineering/chapter-17-streaming-long-context.md)
- [Chapter 08 — Chunking 与 Retrieval](../part2_ai_engineering/chapter-08-chunking-retrieval.md)
- [Chapter 09 — Hybrid Search 与 Reranking](../part2_ai_engineering/chapter-09-hybrid-search-reranking.md)
- [Chapter 03 — Cache 与 Redis](../part1_system_design/chapter-03-cache-redis.md)
- [Chapter 02 — Gateway / Proxy / Load Balancer](../part1_system_design/chapter-02-gateway-proxy-lb.md)
