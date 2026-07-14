# Chapter 13 — Multi-Agent：协作、隔离与成本现实

> Multi-Agent 只有在任务可分解、角色边界清晰、通信协议可控、失败可隔离时才有价值。

---

## Problem

Multi-Agent 的生产问题不是模型是否“会”，而是系统能否在权限、成本、延迟、质量和审计约束下稳定交付。

面向资深后端工程师，重点是边界、状态、数据流、失败路径和可观测性，而不是 toy prompt。

你需要把不确定的模型调用拆成可测的阶段：输入治理、上下文构造、模型决策、外部动作、验证、降级。

相关章节应串起来理解：Ch01 解释无状态与 token 成本，Ch10/Ch11 处理上下文来源，Ch15/Ch16/Ch20 处理评测、guardrail 与观测。

## Architecture

```mermaid
flowchart LR
    UserGoal-->Orchestrator
    Orchestrator-->Planner
    Orchestrator-->Researcher
    Orchestrator-->Coder
    Orchestrator-->Reviewer
    Orchestrator-->Synthesizer
```

| 层 | 职责 | 生产关注点 |
|----|------|------------|
| 入口 | 鉴权、限流、trace | 租户隔离、quota |
| 上下文 | 组装事实/记忆/状态 | token budget、版本 |
| 模型 | 推理或决策 | temperature、max_tokens、版本 |
| 工具/存储 | 外部副作用 | 权限、幂等、超时 |
| 验证 | grounding/安全/格式 | 拒答、回滚、审计 |

## Design

### 1. When multi-agent helps

- **When multi-agent helps**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **When multi-agent helps**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **When multi-agent helps**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **When multi-agent helps**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **When multi-agent helps**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **When multi-agent helps**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **When multi-agent helps**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 2. When multi-agent hurts

- **When multi-agent hurts**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **When multi-agent hurts**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **When multi-agent hurts**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **When multi-agent hurts**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **When multi-agent hurts**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **When multi-agent hurts**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **When multi-agent hurts**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 3. Orchestrator/worker

- **Orchestrator/worker**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Orchestrator/worker**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Orchestrator/worker**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Orchestrator/worker**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Orchestrator/worker**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Orchestrator/worker**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Orchestrator/worker**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 4. Supervisor pattern

- **Supervisor pattern**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Supervisor pattern**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Supervisor pattern**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Supervisor pattern**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Supervisor pattern**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Supervisor pattern**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Supervisor pattern**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 5. Agent-to-agent handoff

- **Agent-to-agent handoff**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Agent-to-agent handoff**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Agent-to-agent handoff**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Agent-to-agent handoff**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Agent-to-agent handoff**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Agent-to-agent handoff**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Agent-to-agent handoff**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 6. Role specialization

- **Role specialization**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Role specialization**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Role specialization**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Role specialization**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Role specialization**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Role specialization**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Role specialization**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 7. Shared vs isolated context/memory

- **Shared vs isolated context/memory**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Shared vs isolated context/memory**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Shared vs isolated context/memory**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Shared vs isolated context/memory**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Shared vs isolated context/memory**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Shared vs isolated context/memory**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Shared vs isolated context/memory**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 8. Failure isolation

- **Failure isolation**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Failure isolation**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Failure isolation**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Failure isolation**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Failure isolation**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Failure isolation**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Failure isolation**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 9. Debugging trace tree

- **Debugging trace tree**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Debugging trace tree**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Debugging trace tree**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Debugging trace tree**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Debugging trace tree**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Debugging trace tree**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Debugging trace tree**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 10. Cost/latency reality

- **Cost/latency reality**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Cost/latency reality**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Cost/latency reality**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Cost/latency reality**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Cost/latency reality**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Cost/latency reality**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Cost/latency reality**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 11. Part4 patterns

- **Part4 patterns**：输入契约要明确：谁产生、何时产生、是否可信、是否可缓存；没有契约的阶段无法定位事故。
- **Part4 patterns**：输出 schema 要机器可校验；自由文本只能用于展示，不能作为状态转移或权限判断的依据。
- **Part4 patterns**：失败分类要区分用户输入、权限、数据缺失、模型错误、工具超时和系统异常。
- **Part4 patterns**：指标至少包含 latency、token、cost、quality、error rate 和拒答率，并按租户/模型/版本切分。
- **Part4 patterns**：回滚路径要提前设计：索引版本、prompt 版本、模型版本、工具版本都应能独立回退。
- **Part4 patterns**：安全边界不能交给模型自觉；权限、PII、secret、destructive action 必须在代码层拦截。
- **Part4 patterns**：评测样本要覆盖 happy path、空结果、旧版本、冲突信息、恶意输入和不可回答问题。

### 深入：Multi-Agent 协作协议

- Multi-agent 只有在任务可分解、可并行、可验证时才有收益；否则只是多次调用模型。
- Orchestrator 负责全局目标、依赖、预算、取消、冲突解决和最终合成；worker 只负责局部任务。
- Handoff 必须结构化：task_id、objective、context_refs、constraints、schema、deadline、success_criteria。
- 默认 isolated context + shared structured state；不要共享完整聊天历史和未验证推理。
- Role specialization 必须体现在工具、权限、memory、模型、预算和评测标准上。
- Shared memory 只存 verified artifacts；写入需要 owner、version 和 confidence。
- Supervisor pattern 灵活但容易路由循环；要有 max_handoffs 和 repeated-state detection。
- Blackboard 适合异步协作，但需要锁、版本、冲突策略和垃圾回收。
- Reviewer agent 必须检查具体标准：证据、边界条件、安全、回归风险，而不是泛泛评价。
- Final synthesizer 只能使用 worker evidence/artifacts，并显式展示冲突和不确定性。
- 成本通常是 N×M：多个 agent、多轮 loop、handoff 摘要、review 和 final synthesis。
- 稳定协作流程应沉淀到 Part4 patterns 或 Ch18 workflow，而不是永远保持自由 agent 群聊。

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

- **Coordination overhead**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Context divergence**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Shared memory pollution**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Responsibility gap**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Supervisor loop**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Duplicate work**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Privilege escalation**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
- **Synthesis hallucination**：必须能在 trace 中定位到阶段、输入、版本、权限条件和降级结果；否则线上只能靠猜。
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
- **现场经验 1**：为 Multi-Agent 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **现场经验 2**：为 Multi-Agent 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **现场经验 3**：为 Multi-Agent 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **现场经验 4**：为 Multi-Agent 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **现场经验 5**：为 Multi-Agent 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **现场经验 6**：为 Multi-Agent 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **现场经验 7**：为 Multi-Agent 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **现场经验 8**：为 Multi-Agent 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **现场经验 9**：为 Multi-Agent 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **现场经验 10**：为 Multi-Agent 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **现场经验 11**：为 Multi-Agent 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **现场经验 12**：为 Multi-Agent 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **现场经验 13**：为 Multi-Agent 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **现场经验 14**：为 Multi-Agent 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **现场经验 15**：为 Multi-Agent 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **现场经验 16**：为 Multi-Agent 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **现场经验 17**：为 Multi-Agent 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **现场经验 18**：为 Multi-Agent 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **现场经验 19**：为 Multi-Agent 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **现场经验 20**：为 Multi-Agent 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **现场经验 21**：为 Multi-Agent 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **现场经验 22**：为 Multi-Agent 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **现场经验 23**：为 Multi-Agent 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **现场经验 24**：为 Multi-Agent 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **现场经验 25**：为 Multi-Agent 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **现场经验 26**：为 Multi-Agent 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **现场经验 27**：为 Multi-Agent 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **现场经验 28**：为 Multi-Agent 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **现场经验 29**：为 Multi-Agent 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **现场经验 30**：为 Multi-Agent 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **现场经验 31**：为 Multi-Agent 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **现场经验 32**：为 Multi-Agent 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **现场经验 33**：为 Multi-Agent 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **现场经验 34**：为 Multi-Agent 做 tenant quota：防止单租户复杂请求拖垮共享容量。

### 生产检查清单

- **Multi-Agent checklist 1 — orchestrator**：为 Multi-Agent 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **Multi-Agent checklist 2 — worker**：为 Multi-Agent 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **Multi-Agent checklist 3 — supervisor**：为 Multi-Agent 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **Multi-Agent checklist 4 — handoff**：为 Multi-Agent 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **Multi-Agent checklist 5 — shared state**：为 Multi-Agent 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **Multi-Agent checklist 6 — isolated context**：为 Multi-Agent 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **Multi-Agent checklist 7 — critic**：为 Multi-Agent 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **Multi-Agent checklist 8 — blackboard**：为 Multi-Agent 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **Multi-Agent checklist 9 — 成本**：为 Multi-Agent 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **Multi-Agent checklist 10 — critical path**：为 Multi-Agent 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **Multi-Agent checklist 11 — orchestrator**：为 Multi-Agent 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **Multi-Agent checklist 12 — worker**：为 Multi-Agent 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **Multi-Agent checklist 13 — supervisor**：为 Multi-Agent 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **Multi-Agent checklist 14 — handoff**：为 Multi-Agent 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **Multi-Agent checklist 15 — shared state**：为 Multi-Agent 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **Multi-Agent checklist 16 — isolated context**：为 Multi-Agent 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **Multi-Agent checklist 17 — critic**：为 Multi-Agent 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **Multi-Agent checklist 18 — blackboard**：为 Multi-Agent 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **Multi-Agent checklist 19 — 成本**：为 Multi-Agent 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **Multi-Agent checklist 20 — critical path**：为 Multi-Agent 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **Multi-Agent checklist 21 — orchestrator**：为 Multi-Agent 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **Multi-Agent checklist 22 — worker**：为 Multi-Agent 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **Multi-Agent checklist 23 — supervisor**：为 Multi-Agent 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **Multi-Agent checklist 24 — handoff**：为 Multi-Agent 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **Multi-Agent checklist 25 — shared state**：为 Multi-Agent 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **Multi-Agent checklist 26 — isolated context**：为 Multi-Agent 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **Multi-Agent checklist 27 — critic**：为 Multi-Agent 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **Multi-Agent checklist 28 — blackboard**：为 Multi-Agent 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **Multi-Agent checklist 29 — 成本**：为 Multi-Agent 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **Multi-Agent checklist 30 — critical path**：为 Multi-Agent 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **Multi-Agent checklist 31 — orchestrator**：为 Multi-Agent 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **Multi-Agent checklist 32 — worker**：为 Multi-Agent 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **Multi-Agent checklist 33 — supervisor**：为 Multi-Agent 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **Multi-Agent checklist 34 — handoff**：为 Multi-Agent 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **Multi-Agent checklist 35 — shared state**：为 Multi-Agent 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。
- **Multi-Agent checklist 36 — isolated context**：为 Multi-Agent 建立 shadow mode：新策略先旁路运行并比较输出，不直接影响用户。
- **Multi-Agent checklist 37 — critic**：为 Multi-Agent 做 cache invalidation：cache key 包含权限、版本、模型和关键配置。
- **Multi-Agent checklist 38 — blackboard**：为 Multi-Agent 保留不可回答样本：系统必须学会拒答，而不是永远生成流畅文本。
- **Multi-Agent checklist 39 — 成本**：为 Multi-Agent 设计人工接管：低置信度、高风险、重复失败时进入 HITL 状态。
- **Multi-Agent checklist 40 — critical path**：为 Multi-Agent 做成本归因：按阶段看钱花在哪里，而不是只看模型总账单。
- **Multi-Agent checklist 41 — orchestrator**：为 Multi-Agent 建立 replay corpus：保存输入摘要、版本、检索/工具结果和最终输出，支持回归。
- **Multi-Agent checklist 42 — worker**：为 Multi-Agent 定义 SLO：p50/p95/p99 latency、错误率、拒答率、单位请求成本。
- **Multi-Agent checklist 43 — supervisor**：为 Multi-Agent 设置 kill switch：模型异常、成本异常、下游故障时能降级到安全路径。
- **Multi-Agent checklist 44 — handoff**：为 Multi-Agent 做 tenant quota：防止单租户复杂请求拖垮共享容量。
- **Multi-Agent checklist 45 — shared state**：为 Multi-Agent 记录 owner：线上质量问题必须能找到负责数据、模型、工具和产品决策的人。

## Code Example

LangGraph orchestrator/worker：结构化 handoff、隔离上下文、预算与失败隔离。

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

- Multi-Agent 的工程价值来自受控上下文、结构化状态、明确边界和可观测闭环。
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
