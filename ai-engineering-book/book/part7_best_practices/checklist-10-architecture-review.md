# Checklist 10 — Architecture Review Checklist

> 用于**新 AI 系统立项**或**重大架构变更**开始编码前的设计评审。它回答的不是“现在能不能上线”，而是“这个方向是否值得做、边界是否清楚、失败时会不会拖垮主系统”。这是一份 design-time review，和 checklist-01 的 pre-launch review 不是一回事。

架构评审不要停留在“模型效果看起来不错”。Staff+/Principal 级评审要把问题拆成机制：哪里必须 deterministic，哪里允许 probabilistic；哪些能力应该做成 shared platform，哪些必须由业务团队自担；哪些风险要在设计期消化，而不是在上线周临时补洞。

评审通过的最低输出，不是“可以继续做”，而是一组可执行的设计决策：

- 已记录的 baseline comparison，而不是一句“规则做不了”。
- 已画清楚的系统边界，而不是让 prompt 隐式决定业务状态。
- 已写明的 fallback / kill switch，而不是故障时再临时讨论。
- 已批准的成本预算，而不是“先做出来再看账单”。
- 已明确的 ownership，而不是把 eval、prompt、on-call 留给上线周。
- 已记录的 rejected alternatives，而不是只展示单一路线。

如果证据只来自 demo，而没有 design doc、ADR、cost projection、threat model 或 eval plan，这次评审就还没有完成。

## 问题是否真的适合 LLM

- [ ] **[P0] 先写清楚不用 LLM 的 baseline**: 如果设计文档里没有同时比较 rule engine、search、workflow automation 或 classic ML，这个方案很容易沦为 resume-driven development。
  - 怎么验证：在 ADR 或设计文档中看到至少一个 deterministic / classic-ML baseline，包含质量、延迟、成本、可维护性对比，而不是一句“规则做不了”。

- [ ] **[P0] 把“需要生成”与“需要判断”分开**: 很多需求本质是 classification、ranking、parsing 或 retrieval，未必需要 open-ended generation；误判这一点会把简单系统做成高成本黑盒。
  - 怎么验证：需求分解图明确区分 generation、extraction、routing、decision 四类任务，并为每类任务指定候选技术路径。

- [ ] **[P0] 明确成功指标不是“回答像人”**: 架构评审关心的是 task success rate、deflection rate、resolution time、agent completion rate，而不是 demo 的主观流畅度。
  - 怎么验证：设计文档有 north-star metric、guardrail metric 和 offline eval 指标，并说明它们如何映射到真实业务价值。

- [ ] **[P1] 识别“高错误成本”步骤是否应去 AI 化**: 价格审批、付款执行、权限变更、合规结论等高代价动作，不应仅凭模型输出直接决策。
  - 怎么验证：关键流程图中标出 irreversible action，确认这些步骤后面有 deterministic policy、人审或双通道校验。

- [ ] **[P1] 识别问题的稳定性与可枚举性**: 如果输入空间相对稳定、边界可枚举、规则频繁复用，优先考虑 workflow + rules，而不是引入 prompt 变体管理成本。
  - 怎么验证：文档中记录需求波动频率、规则变更频率、异常类别数，并解释为何这些特征仍然支持采用 LLM。

- [ ] **[P2] 评估是否只是把组织问题技术化**: 很多“需要 agent”的场景，真正缺的是知识整理、权限打通、流程 owner，而不是更复杂的推理层。
  - 怎么验证：评审记录中有非技术阻塞项列表，例如文档质量、接口 ownership、审批链条；若这些问题未解，必须说明为什么仍值得先建 AI 层。

## 系统边界与确定性 / 概率性接口

- [ ] **[P0] 画出 deterministic 与 probabilistic 的责任边界**: 模型负责生成候选、解释或提取；规则系统负责状态迁移、权限校验、金额计算、审计落库。边界模糊时，事故会直接落到主业务。
  - 怎么验证：架构图中每个组件标注 deterministic / probabilistic 属性，以及失败后由谁兜底。

- [ ] **[P0] LLM 输出进入下游前必须有结构化 contract**: 下游逻辑不能靠 string parsing 猜语义，必须用 JSON Schema、protobuf、typed DTO 或 function/tool schema 做约束。
  - 怎么验证：接口定义中存在 schema、字段必填性、枚举范围和版本号；评审时拒绝“后端正则解析回答文本”。

- [ ] **[P0] 设计 schema validation 与 repair 策略**: 结构化输出也会失败，必须先定义 parse failure、missing field、invalid enum、confidence too low 时的处理路径。
  - 怎么验证：状态机或 sequence diagram 展示 validate -> retry/repair -> safe fallback 的流程，并有重试上限。

- [ ] **[P1] 明确上下文构建器与业务逻辑的接口**: prompt assembly、retrieval、policy injection 不应散落在 controller 里，否则后续无法定位到底是数据、提示还是业务规则的问题。
  - 怎么验证：设计中有独立的 context builder / orchestration 层，输入输出字段清楚，且能单独测试。

- [ ] **[P1] 规定模型不拥有系统真实状态**: 会话摘要、memory、scratchpad 只能是派生状态，source of truth 仍应在业务数据库或 workflow engine。
  - 怎么验证：架构文档明确哪些状态可由模型读写，哪些状态只能通过 deterministic service 变更。

- [ ] **[P2] 为接口变化设计兼容策略**: prompt schema、tool schema、retrieved document format 都会演进；没有版本化，多个客户端会在灰度期互相踩踏。
  - 怎么验证：文档中有 schema version、deprecation policy 和旧版本兼容窗口。

## 平台化与复用

- [ ] **[P0] 先判断是否应该接入 shared model client**: 每个团队各自封装重试、限流、观测、鉴权，会制造重复 bug 和不可比较的成本结构。
  - 怎么验证：方案评审时对比现有 shared model-client 能力；若要自建，必须说明平台能力缺口和退出计划。

- [ ] **[P0] prompt 必须被视为受管资产**: prompt 不应埋在应用代码和 YAML 角落里；它需要 registry、版本、owner、review 和回滚能力。
  - 怎么验证：设计中存在 prompt registry 或等价资产库，且定义发布方式、命名规范、审批人和灰度策略。

- [ ] **[P1] 评估是否复用统一 eval harness**: 如果每队自写 eval runner，就无法横向比较模型、prompt、RAG 改动，也无法沉淀共享数据集。
  - 怎么验证：文档说明接入现有 eval 平台的方式；如未接入，必须列出缺失能力与补齐时间。

- [ ] **[P1] 统一 tracing / token accounting / cache 接口**: 这些能力如果不在平台层收口，成本归因、P95 分析和 prompt cache 命中率都无法做跨团队治理。
  - 怎么验证：架构中能指出统一 trace schema、token usage event、cache key 规范和租户隔离规则。

- [ ] **[P1] 明确哪些能力适合平台沉淀，哪些保留业务定制**: model invocation、observability、safety middleware 通常应平台化；领域 policy、domain rubric、action policy 往往由业务持有。
  - 怎么验证：设计文档有 platform responsibility matrix，列出 central team 与 product team 的边界。

- [ ] **[P2] 预留跨团队共享资产的演化路径**: 第一版可能只是两个团队复用，但没有 namespace、权限模型和版本策略，后面很难演进成真正的平台。
  - 怎么验证：评审记录中能看到多租户隔离、asset naming 和 backward compatibility 的考虑。

## 知识架构选型

- [ ] **[P0] 显式写出 RAG vs fine-tuning vs long-context vs hybrid 决策矩阵**: 不同路径解决的问题不同；如果不把 freshness、latency、cost、governance 放在同一张表里，团队通常会凭直觉选长上下文。
  - 怎么验证：设计文档包含决策矩阵，至少比较知识更新频率、领域私有性、可解释性、训练成本、推理成本和上线复杂度。

- [ ] **[P0] 先回答“知识为什么不直接放系统记录里”**: 很多问答系统本质是现有数据库或搜索能力的包装；没有先定义 source of truth，就会出现知识副本漂移。
  - 怎么验证：文档标明 authoritative source、索引更新链路、失效策略和数据延迟容忍度。

- [ ] **[P1] 需要新鲜知识时优先验证 retrieval 架构**: 对高时效内容，fine-tuning 不是解决 freshness 的工具；设计阶段就该论证 chunking、metadata filter、ACL filtering、reranking 是否可行。
  - 怎么验证：RAG 方案里能看到索引粒度、召回策略、过滤条件、引用返回格式与 access control 方案。

- [ ] **[P1] 长上下文只能在 token 预算内证明成立**: “模型能塞 200K”不等于产品应该塞 200K；prefill 成本、TTFT、lost-in-the-middle 都是架构约束。
  - 怎么验证：文档中有代表性请求的 token budget，分别估算 system prompt、history、retrieved docs、tool schema、expected output 的占比。

- [ ] **[P1] fine-tuning 必须有不可替代理由**: 如果问题是格式不稳、领域词汇、语气风格，往往可以先用 prompt、RAG、structured output 解决；fine-tuning 会引入数据治理与回训流水线成本。
  - 怎么验证：方案中写明训练数据来源、标签质量、漂移检测、回训频率，以及为何这些投入优于 RAG / prompt 优化。

- [ ] **[P2] hybrid 架构要说明复杂度上限**: RAG + long-context + fine-tuning + agent 不是“更先进”，而是更多故障面；只有在各层收益可量化时才值得叠加。
  - 怎么验证：架构评审记录中有 rejected complexity，明确哪些能力本期不做，以及不做的理由。

## 模型策略与供应商风险

- [ ] **[P0] 定义 single-model 还是 routed multi-model 策略**: 并非所有请求都需要最强模型；如果不在架构层做路由设计，成本会被默认路径锁死。
  - 怎么验证：文档中给出请求分类、路由条件、默认模型、升级条件和降级条件，而不是“先统一用最强模型”。

- [ ] **[P0] 明确供应商锁定风险与退出路径**: prompt format、tool calling、embedding、safety API、batch API 都可能形成隐性 lock-in，越晚处理迁移成本越高。
  - 怎么验证：评审材料中列出 provider-specific surface area，并说明哪些通过 adapter 层抽象，哪些接受锁定且有商业理由。

- [ ] **[P0] 设计 multi-provider fallback，不要等故障后再补**: 备用 provider 不是把 API key 放进配置；要提前解决 schema 差异、tokenizer 差异、rate limit、observability 和 eval 基线差异。
  - 怎么验证：架构图里有 primary / secondary provider 切换策略，且说明切换后哪些能力降级、哪些测试必须重跑。

- [ ] **[P1] 区分 chat model、reasoning model、embedding model 的生命周期**: 它们更新节奏、评估指标和故障影响面不同，混成“一个模型栈”会掩盖问题。
  - 怎么验证：设计中对 generation、routing、retrieval 分别定义 model id、版本策略与回归集。

- [ ] **[P1] 明确模型版本 pinning 与升级节奏**: 直接依赖别名会让输出分布漂移进入生产；架构层应决定谁批准升级、谁跑回归。
  - 怎么验证：文档中存在 version pinning 策略、升级窗口、回滚条件和 owner。

- [ ] **[P2] 评估 self-hosted 或 private deployment 的触发条件**: 不是所有团队都该自托管，但在数据驻留、吞吐规模或单价压力下，必须提前设定切换阈值。
  - 怎么验证：评审记录中有触发条件，例如月 token 规模、合规要求、P95 延迟目标或单位成本阈值。

## 可靠性架构

- [ ] **[P0] 明确 AI 依赖失败时产品如何 graceful degradation**: 用户不该因为 summarization、copilot、semantic parse 失败而失去核心交易、查询或编辑能力。
  - 怎么验证：用户旅程图中标出 AI-enhanced path 与 core path，确认 AI 故障后核心 path 仍可完成关键任务。

- [ ] **[P0] 用 circuit breaker 和 bulkhead 隔离 AI 依赖**: provider 超时、限流或高错误率不应把线程池、连接池或队列全部拖死。
  - 怎么验证：设计文档说明 breaker 触发条件、半开恢复策略、独立资源池和隔离范围。

- [ ] **[P0] 限制 blast radius 到租户、功能或流量分层**: 全站统一 agent orchestration 一旦退化，不能影响所有租户和页面。
  - 怎么验证：架构中有 tenant-level feature flag、route-level kill switch、per-feature budget 或 region-level isolation。

- [ ] **[P1] 定义 timeout、retry、idempotency 的组合策略**: LLM 与 tool call 链路长，盲目 retry 会把尾延迟和成本同步放大。
  - 怎么验证：sequence diagram 中明确 client timeout、upstream timeout、max retry、jitter、idempotency key 和不可重试错误类型。

- [ ] **[P1] 把 AI 失败分类成“不可用”和“不可置信”**: 5xx 只是不可用；引用缺失、schema 失败、低信心回答属于不可置信，处理方式应不同。
  - 怎么验证：错误分类文档中区分 unavailable / untrusted / unsafe / over-budget，并为每类定义用户体验。

- [ ] **[P1] 为异步与人工兜底预留架构位**: 长耗时生成、复杂分析或高风险审批不必都走同步请求；提前设计 async job、人审队列能显著降低主链路风险。
  - 怎么验证：设计中说明哪些场景转为 async、如何通知用户、人工接管入口在哪里、SLA 如何变化。

## 安全威胁建模

- [ ] **[P0] 在写代码前完成 prompt injection threat model**: 只要系统会读取用户内容、网页、工单、邮件、文档，就存在 untrusted instruction 被拼进上下文的风险。
  - 怎么验证：威胁模型列出所有 untrusted input source、拼接位置、受影响工具和潜在后果，而不是只写“注意 prompt injection”。

- [ ] **[P0] 明确数据外发边界与 data exfiltration 路径**: 模型调用、embedding、日志、trace、cache、eval dataset 都可能把敏感数据送出原边界。
  - 怎么验证：数据流图标明每条出站路径的字段级分类、脱敏规则、保留期限和第三方处理方。

- [ ] **[P0] 对工具调用建立最小权限设计**: agent 能访问什么 API、文件、数据库、工单系统，必须在架构阶段锁清楚；“让模型自己判断何时调用”不是权限策略。
  - 怎么验证：tool policy 文档列出 allowlist、参数校验、租户边界、只读/读写区别和人工确认点。

- [ ] **[P1] 将 retrieval 结果视为不可信输入**: RAG 命中的文档不自动可信，它可能包含恶意指令、过期信息或越权内容。
  - 怎么验证：设计中有 ACL filter、citation binding、source freshness 标记，以及“文档内容不能直接提升权限”的约束。

- [ ] **[P1] 评估跨租户缓存、共享索引与 shared prompt 的泄漏面**: 多租户 AI 系统最常见的不是模型越狱，而是 cache key、index filter、trace sample 搞错。
  - 怎么验证：评审材料说明 cache key 组成、tenant isolation、index partitioning 和日志抽样脱敏方案。

- [ ] **[P1] 设计安全拒绝与审计证据链**: 当系统拒绝回答、拒绝执行工具或触发合规策略时，要能解释是哪个 policy 生效，而不是只返回“失败”。
  - 怎么验证：安全架构中定义 policy id、decision log、review queue 和事后审计查询方式。

## 成本治理与组织归属

- [ ] **[P0] 在架构阶段做 projected cost at scale**: “现在每天 500 次请求不贵”没有意义；很多系统在 10x 流量、长上下文和二次重试下成本曲线会拐头。
  - 怎么验证：文档里有按 1x / 3x / 10x 流量估算的 token、tool call、embedding、storage、cache 与人工复核成本。

- [ ] **[P0] 明确预算 owner 与超支决策机制**: 没有 budget owner 的 AI 架构通常会在灰度期默默扩容，最后由别的团队埋单。
  - 怎么验证：评审记录中能看到 budget approver、月度阈值、超支报警和触发降级的财务规则。

- [ ] **[P0] 上线前先定义 eval owner**: 评测集不是一次性文档，而是长期资产；如果没有 owner，模型升级和 prompt 变更都会失去回归基线。
  - 怎么验证：组织设计里明确谁维护 golden set、谁加 hard negatives、谁批准指标变更、多久复查一次。

- [ ] **[P0] 上线前先定义 prompt change owner**: prompt 改动本质是行为变更；若没有 code-review、灰度和回滚 owner，生产行为会被运营式修改悄悄改变。
  - 怎么验证：文档说明 prompt 谁可改、如何 review、如何发布、如何回滚，以及是否要求关联 eval 报告。

- [ ] **[P1] 明确 on-call model 和 incident taxonomy**: AI 事故往往横跨模型、检索、平台、业务规则；如果只写“由应用团队负责”，故障会在交接中放大。
  - 怎么验证：runbook 或 ownership matrix 中列出一线 on-call、二线平台、供应商升级联系人，以及常见故障分类。

- [ ] **[P1] 设计成本优化旋钮而非一次性拍脑袋**: max_tokens、routing threshold、retrieval top-k、cache TTL、human-review sampling rate 都应是可治理参数。
  - 怎么验证：架构中有可配置参数列表、默认值、owner、变更审计和生效范围。

- [ ] **[P2] 预留“停止做”的退出条件**: 并非所有 AI 功能都值得长期维护；如果没有 sunset criteria，团队会持续背着低 ROI 系统前进。
  - 怎么验证：设计文档写明 kill criteria，例如 adoption 太低、单位收益过低、误报成本过高或合规不可接受。

## 常见反例

| 反例 | 为什么危险 | 更好的做法 |
|---|---|---|
| 为了用大模型而用大模型，没有和规则系统 / 传统模型做对比 | 会把本可 deterministic 解决的问题变成高成本黑盒 | 在 ADR 中强制写 baseline comparison，并要求业务指标对齐 |
| 默认把 LLM 输出当字符串交给下游解析 | 一次格式漂移就可能击穿主流程 | 用 schema-first contract、严格校验和 repair / fallback |
| 设计阶段完全没考虑供应商中断的降级方案 | provider 故障会直接变成产品故障 | 预先设计 kill switch、fallback provider、core path 降级 |
| 看到知识型需求就直接上 fine-tuning | 忽略 freshness、引用、ACL 与训练治理成本 | 先用决策矩阵比较 RAG、long-context、fine-tuning |
| 每个团队各自写 model client 和 prompt loader | 重复造轮子，监控口径和成本口径不一致 | 优先接 shared model client、prompt registry、eval harness |
| 只做安全过滤，不做威胁建模 | 很容易漏掉 retrieval 注入、tool 滥用、数据外发路径 | 在设计期画出 untrusted input、data flow 和 tool policy |
| 把“谁维护 eval / prompt / on-call”留到上线前再定 | 组织边界不清，事故时无人闭环 | 在架构评审通过前把 ownership matrix 定下来 |

## 关联章节

- [Chapter 01 — LLM 基础与 Transformer 概览](../part2_ai_engineering/chapter-01-llm-fundamentals.md)
- [Chapter 10 — RAG](../part2_ai_engineering/chapter-10-rag.md)
- [Chapter 12 — Agent](../part2_ai_engineering/chapter-12-agent.md)
- [Chapter 19 — AI Security](../part2_ai_engineering/chapter-19-ai-security.md)
- [Chapter 20 — AI Observability](../part2_ai_engineering/chapter-20-ai-observability.md)
- [Chapter 11 — Cost Optimization](../part1_system_design/chapter-11-cost-optimization.md)
