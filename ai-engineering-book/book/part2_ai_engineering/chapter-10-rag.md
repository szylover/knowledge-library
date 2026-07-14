# Chapter 10 — RAG：Retrieval-Augmented Generation

> RAG 不是“给模型接一个向量库”。它是 ingest、chunk、embed、index、retrieve、rerank、augment、generate、verify 的证据流水线。

---

## Problem

RAG 的生产问题不是模型是否“会”，而是系统能否在权限、成本、延迟、质量和审计约束下稳定交付。

面向资深后端工程师，重点是边界、状态、数据流、失败路径和可观测性，而不是 toy prompt。

你需要把不确定的模型调用拆成可测的阶段：输入治理、上下文构造、模型决策、外部动作、验证、降级。

相关章节应串起来理解：Ch01 解释无状态与 token 成本，Ch10/Ch11 处理上下文来源，Ch15/Ch16/Ch20 处理评测、guardrail 与观测。

## Architecture

```mermaid
flowchart LR
    Sources-->Parse-->Chunk-->Embed-->Index
    Query-->Rewrite/HyDE-->Retrieve-->Rerank-->Assemble-->Generate-->Verify
```

| 层 | 职责 | 生产关注点 |
|----|------|------------|
| 入口 | 鉴权、限流、trace | 租户隔离、quota |
| 上下文 | 组装事实/记忆/状态 | token budget、版本 |
| 模型 | 推理或决策 | temperature、max_tokens、版本 |
| 工具/存储 | 外部副作用 | 权限、幂等、超时 |
| 验证 | grounding/安全/格式 | 拒答、回滚、审计 |

## Design

### 1. 数据源与权限先行

- **数据源与权限先行**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **数据源与权限先行**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **数据源与权限先行**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **数据源与权限先行**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **数据源与权限先行**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **数据源与权限先行**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **数据源与权限先行**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 2. Chunking 是质量地基

- **Chunking 是质量地基**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Chunking 是质量地基**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Chunking 是质量地基**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Chunking 是质量地基**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Chunking 是质量地基**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Chunking 是质量地基**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Chunking 是质量地基**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 3. Embedding/index version

- **Embedding/index version**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Embedding/index version**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Embedding/index version**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Embedding/index version**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Embedding/index version**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Embedding/index version**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Embedding/index version**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 4. Query rewriting 与 expansion

- **Query rewriting 与 expansion**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Query rewriting 与 expansion**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Query rewriting 与 expansion**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Query rewriting 与 expansion**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Query rewriting 与 expansion**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Query rewriting 与 expansion**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Query rewriting 与 expansion**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 5. HyDE

- **HyDE**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **HyDE**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **HyDE**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **HyDE**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **HyDE**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **HyDE**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **HyDE**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 6. Context assembly 与 token budgeting

- **Context assembly 与 token budgeting**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Context assembly 与 token budgeting**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Context assembly 与 token budgeting**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Context assembly 与 token budgeting**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Context assembly 与 token budgeting**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Context assembly 与 token budgeting**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Context assembly 与 token budgeting**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 7. Citation/grounding

- **Citation/grounding**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Citation/grounding**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Citation/grounding**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Citation/grounding**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Citation/grounding**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Citation/grounding**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Citation/grounding**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 8. Agentic RAG

- **Agentic RAG**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Agentic RAG**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Agentic RAG**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Agentic RAG**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Agentic RAG**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Agentic RAG**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Agentic RAG**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 9. GraphRAG overview

- **GraphRAG overview**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **GraphRAG overview**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **GraphRAG overview**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **GraphRAG overview**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **GraphRAG overview**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **GraphRAG overview**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **GraphRAG overview**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 10. When NOT to use RAG

- **When NOT to use RAG**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **When NOT to use RAG**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **When NOT to use RAG**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **When NOT to use RAG**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **When NOT to use RAG**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **When NOT to use RAG**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **When NOT to use RAG**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 深入：RAG 质量分层

- Ingest 质量决定上限：解析失败、表格丢列、代码符号切断，后续 rerank 无法补救。
- Chunk 要保存 breadcrumb、source URI、version、page/line range 和 ACL；没有 provenance 的 chunk 不应进入生产索引。
- Query rewrite 只改变检索，不改变用户问题；生成阶段必须看到 original query，避免 rewrite 漂移。
- HyDE 适合抽象概念，不适合 error code、ticket id、函数名；精确查询优先 BM25。
- Hybrid search 是默认基线：dense 负责语义，BM25 负责精确词，metadata 负责权限和版本。
- Rerank 之前追求 recall，rerank 之后追求 precision；不要把 top-k 调大当作质量优化。
- Context assembly 要做去重、多样性、token 预算、证据排序和引用映射。
- Citation 必须能点击、能授权、能定位到版本；格式化引用不等于 grounding。
- Faithfulness 与 answer relevance 要分开评测；一个答案可能相关但不忠实。
- Agentic RAG 只路由复杂多跳问题；简单问答进入 agent loop 只会增加成本和尾延迟。
- GraphRAG 适合实体关系密集的跨文档问题；构图、消歧和增量更新是主要成本。
- Long context 适合小规模全文分析；大规模多租户知识库仍需要 RAG 做权限、审计和成本控制。

## Trade-offs

| 决策 | 收益 | 代价 |
|------|------|------|
| 更强模型 | 质量上限更高 | 延迟和成本上升 |
| 更长上下文 | 减少外部步骤 | TTFT、token 成本、中段遗忘 |
| 结构化状态 | 可恢复可审计 | schema 演进成本 |
| 自动化程度更高 | 用户体验好 | 安全边界扩大 |
| 缓存 | 降低成本延迟 | 版本、权限、失效复杂 |
| HITL | 降低风险 | 增加等待和产品摩擦 |
| 多阶段评测 | 定位清楚 | 建设成本高 |
| 降级策略 | 稳定性强 | 答案可能保守 |

核心张力是质量、灵活性、延迟、成本和可解释性不可同时最大化。不要追求“最智能”，要追求“在业务约束下最稳定”。

## Failure Cases

- **Retrieval miss**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Wrong context**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Hallucination despite context**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Citation laundering**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **ACL leakage**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Stale index**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Context stuffing**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Embedding drift**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **预算耗尽**：这是 AI 系统的常见生产事故源，设计时就要有检测、报警和恢复策略。
- **上下文污染**：这是 AI 系统的常见生产事故源，设计时就要有检测、报警和恢复策略。
- **评测盲区**：这是 AI 系统的常见生产事故源，设计时就要有检测、报警和恢复策略。
- **缓存脏读**：这是 AI 系统的常见生产事故源，设计时就要有检测、报警和恢复策略。
- **模型版本漂移**：这是 AI 系统的常见生产事故源，设计时就要有检测、报警和恢复策略。
- **人工接管缺失**：这是 AI 系统的常见生产事故源，设计时就要有检测、报警和恢复策略。

## Best Practices

- **把边界写进代码而不是 prompt**。
- **所有外部输入都视为不可信数据**。
- **为 token、time、cost、steps 设置硬预算**。
- **记录 trace_id、版本、输入摘要、输出、错误和 stop_reason**。
- **把权限过滤下推到存储或工具层**。
- **保留 provenance，支持回放与删除**。
- **先离线 golden set，再线上 shadow/AB**。
- **默认可拒答、可降级、可人工接管**。
- **缓存 key 必须包含租户、权限、版本和模型**。
- **用评测集驱动调参，避免凭感觉调 prompt**。

## Production Experience

- **质量问题先分层定位，不要第一反应换模型**。
- **上线初期保留全链路 trace sample，后续按风险采样**。
- **成本账单必须按租户、接口、模型、阶段归因**。
- **大结果不要直接塞 prompt，存储引用并摘要进入上下文**。
- **评测集必须包含不可回答、权限拒绝、旧版本和对抗样本**。
- **模型供应商版本漂移会改变行为，固定版本并做回归**。
- **任何自动写操作先 read-only、再建议、再审批执行**。
- **复杂系统要有 kill switch、rate limit、tenant quota**。
- **稳定高频路径最终应沉淀为 workflow 或确定性服务**。
- **工程成熟度体现在失败路径，而不是 happy path demo**。
- **现场经验 1**：为 RAG 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **现场经验 2**：为 RAG 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **现场经验 3**：为 RAG 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **现场经验 4**：为 RAG 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **现场经验 5**：为 RAG 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **现场经验 6**：为 RAG 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **现场经验 7**：为 RAG 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **现场经验 8**：为 RAG 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **现场经验 9**：为 RAG 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **现场经验 10**：为 RAG 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **现场经验 11**：为 RAG 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **现场经验 12**：为 RAG 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **现场经验 13**：为 RAG 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **现场经验 14**：为 RAG 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **现场经验 15**：为 RAG 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **现场经验 16**：为 RAG 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **现场经验 17**：为 RAG 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **现场经验 18**：为 RAG 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **现场经验 19**：为 RAG 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **现场经验 20**：为 RAG 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **现场经验 21**：为 RAG 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **现场经验 22**：为 RAG 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **现场经验 23**：为 RAG 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **现场经验 24**：为 RAG 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **现场经验 25**：为 RAG 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **现场经验 26**：为 RAG 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **现场经验 27**：为 RAG 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **现场经验 28**：为 RAG 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **现场经验 29**：为 RAG 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **现场经验 30**：为 RAG 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **现场经验 31**：为 RAG 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **现场经验 32**：为 RAG 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **现场经验 33**：为 RAG 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **现场经验 34**：为 RAG 做 tenant quota：防止单租户复杂请求拖垮共享容量。

### 生产检查清单

- **RAG checklist 1 — 检索**：为 RAG 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **RAG checklist 2 — 重排**：为 RAG 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **RAG checklist 3 — 证据装配**：为 RAG 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **RAG checklist 4 — 引用验证**：为 RAG 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **RAG checklist 5 — faithfulness**：为 RAG 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **RAG checklist 6 — relevance**：为 RAG 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **RAG checklist 7 — ACL**：为 RAG 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **RAG checklist 8 — 索引版本**：为 RAG 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **RAG checklist 9 — GraphRAG**：为 RAG 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **RAG checklist 10 — agentic RAG**：为 RAG 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **RAG checklist 11 — 检索**：为 RAG 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **RAG checklist 12 — 重排**：为 RAG 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **RAG checklist 13 — 证据装配**：为 RAG 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **RAG checklist 14 — 引用验证**：为 RAG 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **RAG checklist 15 — faithfulness**：为 RAG 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **RAG checklist 16 — relevance**：为 RAG 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **RAG checklist 17 — ACL**：为 RAG 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **RAG checklist 18 — 索引版本**：为 RAG 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **RAG checklist 19 — GraphRAG**：为 RAG 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **RAG checklist 20 — agentic RAG**：为 RAG 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **RAG checklist 21 — 检索**：为 RAG 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **RAG checklist 22 — 重排**：为 RAG 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **RAG checklist 23 — 证据装配**：为 RAG 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **RAG checklist 24 — 引用验证**：为 RAG 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **RAG checklist 25 — faithfulness**：为 RAG 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **RAG checklist 26 — relevance**：为 RAG 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **RAG checklist 27 — ACL**：为 RAG 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **RAG checklist 28 — 索引版本**：为 RAG 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **RAG checklist 29 — GraphRAG**：为 RAG 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **RAG checklist 30 — agentic RAG**：为 RAG 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **RAG checklist 31 — 检索**：为 RAG 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **RAG checklist 32 — 重排**：为 RAG 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **RAG checklist 33 — 证据装配**：为 RAG 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **RAG checklist 34 — 引用验证**：为 RAG 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **RAG checklist 35 — faithfulness**：为 RAG 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **RAG checklist 36 — relevance**：为 RAG 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **RAG checklist 37 — ACL**：为 RAG 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **RAG checklist 38 — 索引版本**：为 RAG 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **RAG checklist 39 — GraphRAG**：为 RAG 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **RAG checklist 40 — agentic RAG**：为 RAG 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **RAG checklist 41 — 检索**：为 RAG 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **RAG checklist 42 — 重排**：为 RAG 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **RAG checklist 43 — 证据装配**：为 RAG 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **RAG checklist 44 — 引用验证**：为 RAG 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **RAG checklist 45 — faithfulness**：为 RAG 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。

## Code Example

OpenAI embedding、Qdrant 检索、Anthropic 生成的 RAG service。

```python
from __future__ import annotations
import os,time,asyncio,logging
from dataclasses import dataclass
from typing import Literal,Sequence
from pydantic import BaseModel,Field
from tenacity import retry,stop_after_attempt,wait_exponential
logger=logging.getLogger(__name__)

class Request(BaseModel):
    tenant_id:str; user_id:str; trace_id:str; question:str
    acl_tags:list[str]=Field(default_factory=list); max_steps:int=8

class Result(BaseModel):
    answer:str; sources:list[str]=Field(default_factory=list)
    stop_reason:str; latency_ms:int; cost_cents:int=0

@dataclass(frozen=True)
class Config:
    model:str="claude-3-5-sonnet-latest"
    embedding_model:str="text-embedding-3-large"
    timeout_s:int=30; token_budget:int=9000

class ProductionService:
    def __init__(self,cfg:Config)->None:
        self.cfg=cfg
        # Real deployment wires Anthropic/OpenAI SDK, Qdrant, Redis and Postgres here.
        # Keep clients injectable so tests can replay tool/model responses.

    async def run(self,req:Request)->Result:
        start=time.perf_counter(); state={"steps":0,"sources":[],"errors":[]}
        try:
            await self.authorize(req)
            ctx=await self.build_context(req,state)
            answer=await self.generate(req,ctx,state)
            reason="final" if answer else "insufficient_evidence"
            return Result(answer=answer or "证据不足，拒绝编造。",sources=state["sources"],stop_reason=reason,latency_ms=int((time.perf_counter()-start)*1000))
        except PermissionError:
            logger.warning("permission_denied",extra={"trace_id":req.trace_id,"tenant":req.tenant_id})
            return Result(answer="没有权限访问相关信息。",stop_reason="permission_denied",latency_ms=int((time.perf_counter()-start)*1000))
        except Exception as exc:
            logger.exception("service_failed",extra={"trace_id":req.trace_id})
            return Result(answer="系统暂时无法完成请求。",stop_reason=type(exc).__name__,latency_ms=int((time.perf_counter()-start)*1000))

    async def authorize(self,req:Request)->None:
        if not req.tenant_id or not req.user_id: raise PermissionError("missing identity")

    async def build_context(self,req:Request,state:dict)->str:
        state["steps"]+=1
        if state["steps"]>req.max_steps: return ""
        return f"KIND={kind}; tenant={req.tenant_id}; question={req.question}; budget={self.cfg.token_budget}"

    @retry(wait=wait_exponential(min=.2,max=3),stop=stop_after_attempt(3))
    async def generate(self,req:Request,ctx:str,state:dict)->str:
        if not ctx: return ""
        state["sources"].append(f"trace:{req.trace_id}")
        # Replace by SDK call with temperature=0, max_tokens, tool schemas and telemetry.
        await asyncio.sleep(0.01)
        return f"基于受控上下文回答：{req.question}"

    def observe(self,req:Request,result:Result)->None:
        logger.info("ai_pipeline_done",extra={"trace_id":req.trace_id,"stop":result.stop_reason,"latency_ms":result.latency_ms,"sources":len(result.sources)})
```

示例强调工程边界：鉴权、预算、重试、错误分类、trace 和可注入依赖。真实实现应接入 LangGraph、OpenAI/Anthropic SDK、Qdrant、Redis/Postgres 与 OpenTelemetry。

## Diagram

```mermaid
sequenceDiagram
participant U as User
participant API as API
participant C as Context/State
participant M as Model
participant T as Tools/Stores
participant O as Observability
U->>API: request + identity
API->>C: build bounded context
C->>T: retrieve/read authorized data
API->>M: model call with budget
M-->>API: decision/answer
API->>T: validated action if needed
API->>O: trace tokens latency cost errors
API-->>U: answer / stop_reason / sources
```

## Interview Questions

1. 什么时候不用这个架构？
2. 如何设计状态 schema 与 token budget？
3. 如何分层定位质量问题？
4. 如何处理权限、PII 和 prompt injection？
5. 如何做离线评测和线上回放？
6. 如何控制成本和 tail latency？
7. 如何设计拒答、降级和 HITL？
8. 如何把高频路径固化为 workflow？

## Summary

- RAG 的工程价值来自受控上下文、结构化状态、明确边界和可观测闭环。
- 生产系统要优先设计失败路径、权限、预算、版本和回放。
- 不要把 prompt 当架构；prompt 只是策略的一部分，外部控制面才是可靠性来源。

## Key Takeaways

- 上下文是预算，不是垃圾桶。
- 状态必须结构化、持久化、可恢复。
- 引用、trace、评测和拒答是基本设施。
- 复杂能力应逐步产品化为 workflow 与 guardrail。

## Interview Questions

见上文「Interview Questions」小节。

## Further Reading

- 相关章节：Ch01, Ch05, Ch07-Ch12, Ch15-Ch21
- LangGraph documentation
- OpenAI and Anthropic SDK documentation
- Qdrant, Redis, PostgreSQL/pgvector documentation
- Papers and production postmortems on RAG, agents, and evaluation
