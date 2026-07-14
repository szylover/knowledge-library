# Interview 10 — Behavior 面试

> Behavior 面试不是讲漂亮故事，而是判断你能否在高不确定性、高成本、高风险的 AI 工程环境中做成熟决策。Senior/Staff 回答应体现 ownership、系统思维、跨团队影响力和对非确定性系统的敬畏。

### Q1: 讲一次你在需求高度模糊时推动 AI 项目落地的经历

**Question**

Tell me about a time you had to deliver an AI feature when requirements were ambiguous.

**Model Answer**

**Situation**：业务希望“做一个智能助手提升客服效率”，但没有明确任务边界、成功指标和风险定义。

**Task**：我需要把模糊愿景转成可交付 MVP，并避免团队陷入 demo-driven development。

**Action**：我先组织 discovery，把需求拆成高频、低风险、可验证的用例：订单状态解释、政策问答、工单摘要。然后定义成功指标：人工处理时长下降、引用准确率、升级人工率、p95 延迟、拒答正确率。

我们没有一开始做全能 Agent，而是做 RAG + citation + human handoff。并建立 eval set：历史工单 200 条、专家边界样本 50 条、安全样本 30 条。上线采用 5% 灰度，只对低风险问题启用，所有回答带引用和“转人工”入口。

**Result**：MVP 六周上线，目标场景平均处理时间下降 28%，错误升级率可控。更重要的是，团队有了可迭代的指标体系，而不是继续争论“模型聪不聪明”。

**Follow-up Questions**

- 你如何说服业务缩小 MVP 范围？
- 如果老板坚持做全能 Agent，你怎么办？
- 你如何定义“足够好”？
- 项目最大风险是什么？

**Deep Dive**

强答案体现 ambiguity reduction：场景切分、指标定义、风险分级、迭代路径。弱答案只说“我快速写了 prompt 做 demo”。Staff 候选人要展示从不确定性中建立工程控制面的能力。

---

### Q2: 讲一次生产环境中 LLM 幻觉造成事故，你如何处理

**Question**

Describe an incident where an AI system gave a hallucinated or misleading answer in production.

**Model Answer**

**Situation**：内部知识助手回答了过期合规政策，并给出看似正确的引用。用户据此准备客户回复，幸好发送前被人工发现。

**Task**：我作为 on-call owner，需要止血、定位、修复，并建立防复发机制。

**Action**：我先关闭高风险 policy 问答的自动回答，改为检索结果展示 + 人工确认。随后用 trace 复盘：retriever 找到旧版本文档，reranker 把新文档排在后面；prompt 没要求检查 effective date；citation 只引用标题，没有验证具体段落。

修复分三层：

- 索引层加入文档版本和生效日期过滤。
- 生成层要求回答显式检查 effective date。
- Eval 层新增 40 条“新旧政策冲突”样本，把 citation correctness 作为 gate。

我们还更新 UI，对高风险政策显示“最后更新日期”。

**Result**：两天内恢复灰度，一周后全量。后三个月没有同类事故。团队也把“过期知识”列为 RAG 标准风险。

**Follow-up Questions**

- 如何向非技术 stakeholder 解释幻觉？
- 为什么不是简单换更强模型？
- 事故期间如何沟通？
- 哪些指标会提前暴露问题？

**Deep Dive**

强答案展示 incident management：止血、定位、修复、防复发。弱答案把责任推给模型。AI 事故要当系统性风险管理。

---

### Q3: 讲一次你处理 AI 成本失控的经历

**Question**

Tell me about a time AI cost exceeded expectations. What did you do?

**Model Answer**

**Situation**：新功能上线后，LLM 账单一周内增长 4 倍，但用户增长只有 30%。

**Task**：我需要快速归因成本，降低浪费，同时不牺牲核心质量。

**Action**：第一步不是砍模型，而是补齐 cost attribution。我们按 tenant、endpoint、prompt version、model、prompt/completion tokens 建 dashboard。发现 60% 成本来自自动摘要任务：它把完整历史和全部 RAG chunks 都塞进 prompt，且 `max_tokens` 设得过高。

优化措施：

- 上下文预算器。
- RAG top-k 从 12 降到 5，并加 rerank。
- 摘要任务改异步批处理。
- 低风险摘要路由到小模型。
- FAQ response cache。
- 租户 budget alert。

我和产品定义成本 SLO：每成功任务成本上限，而不是只看总账单。

**Result**：两周内单位任务成本下降 63%，质量 eval 下降不到 1%，p95 延迟也下降。之后每个 AI feature 上线前都必须给 token/cost 预估。

**Follow-up Questions**

- 如何判断降成本没有伤害质量？
- 如果业务方不接受降级怎么办？
- 成本归因需要哪些日志字段？
- 什么时候应该自托管？

**Deep Dive**

Staff 答案体现经济性思维：token 是资源，成本是产品约束。弱答案只说“换便宜模型”。有效优化通常先来自上下文和路由。

---

### Q4: 讲一次 build vs buy 模型策略分歧

**Question**

Tell me about a disagreement on whether to use a managed model provider, fine-tune, or self-host.

**Model Answer**

**Situation**：平台团队想自托管开源模型降低长期成本，产品团队希望继续用 managed API 保持质量和速度。

**Task**：我需要推动基于数据的决策，而不是立场之争。

**Action**：我设计评估矩阵：质量、延迟、单位成本、数据合规、运维复杂度、峰值弹性、模型升级速度。用真实流量 replay 三类任务：分类、RAG 问答、复杂推理。

结果显示：

- 分类任务开源小模型质量足够且便宜。
- 复杂推理 managed frontier model 明显更好。
- RAG 问答中模型差距小于检索质量差距。

最终方案是 hybrid：简单任务自托管，复杂任务走 provider，gateway 统一路由和观测。我们设置季度复评机制，而不是一次性决定。

**Result**：团队避免了全量迁移风险，同时一年成本预计下降 35%。双方都接受，因为决策依据是 workload 数据。

**Follow-up Questions**

- 如果评估结果不符合你的直觉怎么办？
- 如何计算自托管真实 TCO？
- 数据合规如何影响选择？
- 如何避免 provider lock-in？

**Deep Dive**

强答案展示 disagree and commit：先定义标准，再实验，再分层决策。弱答案站队某个技术路线。Staff 候选人能把技术争论转成可测量 trade-off。

---

### Q5: 讲一次你 mentoring 工程师掌握 AI Engineering 的经历

**Question**

How have you mentored backend engineers transitioning into AI engineering?

**Model Answer**

**Situation**：团队多数工程师后端能力强，但把 LLM 当黑盒 API，用 prompt 调参替代系统设计。

**Task**：我希望团队形成共同的 AI engineering mental model。

**Action**：我设计 4 周 enablement：

1. token、context、prefill/decode、成本。
2. RAG pipeline 和 eval。
3. agent tools、幂等和安全。
4. 每人负责一个真实改进：citation eval、token budget、streaming trace 或 model routing。

我避免只做讲座，而是用 production incidents 做 case study。每次 code review 我会问：这个 prompt version 怎么回滚？工具调用是否幂等？eval 如何覆盖？成本变化是多少？

**Result**：两个月后，团队 PR 开始自然包含 eval 结果和成本影响。一个 mid-level 工程师独立完成 model routing，把延迟降低 20%。

**Follow-up Questions**

- 如何评价 mentoring 是否有效？
- 面对抗拒 AI 的资深工程师怎么办？
- 如何平衡交付和培养？
- 你自己如何保持学习？

**Deep Dive**

强答案体现 leverage：不是自己做所有 AI 工作，而是提升团队判断力。Staff 影响力来自机制、review 标准和共同语言。

---

### Q6: 讲一次你推动安全或合规要求

**Question**

Tell me about a time you pushed back on shipping because of safety, privacy, or compliance risks.

**Model Answer**

**Situation**：销售助手准备上线，能总结客户邮件并生成回复。产品希望快速发布，但系统会把客户 PII 发给外部 provider，且没有明确保留策略。

**Task**：我需要降低合规风险，同时不让项目无限期停滞。

**Action**：我列出具体风险：PII 出境、prompt 日志保留、越权访问 CRM 数据、生成不合规承诺。然后提出可执行替代方案：

- 先只对内部测试租户开放。
- PII redaction。
- 配置 provider 不用于训练。
- prompt 加密存储并设置保留期。
- CRM 权限下推。
- 高风险承诺类回复必须人工确认。

我和 legal/security/product 一起定义 launch checklist，而不是用“安全”一票否决所有进展。

**Result**：上线推迟两周，但通过安全评审。后续采用率高，且没有 PII 事故。这个 checklist 后来成为 LLM feature 标准模板。

**Follow-up Questions**

- 哪些风险必须阻止上线？
- 如何与 product 沟通延期？
- PII redaction 伤害质量怎么办？
- 如何审计模型供应商？

**Deep Dive**

强答案体现 pragmatic safety：坚持底线，同时给路径。弱答案要么盲目阻止，要么忽视风险。AI 工程成熟度体现在可执行 guardrail。

---

### Q7: 讲一次你在非确定性系统中建立质量信心

**Question**

LLM outputs are non-deterministic. How do you build confidence before launch?

**Model Answer**

**Situation**：我们要上线代码 review assistant。单次 demo 表现很好，但团队担心输出不稳定、误报和漏报。

**Task**：我需要建立可量化的 launch confidence。

**Action**：我把质量拆成可测维度：bug finding precision、critical issue recall、false positive rate、review latency、developer acceptance。我们构造带 known defects 的 repo 集合，并用历史 PR replay。每个样本跑多次，估计方差，而不是只看一次输出。

对高风险建议，要求引用具体代码行和可执行解释；没有足够证据时不评论。上线时先 shadow mode，只记录建议不展示给用户，再与人工 review 对比。

**Result**：我们发现模型在安全漏洞 recall 上不稳定，于是先只上线 correctness review，不上线 security claims。一个月后基于 hard set 改进再扩展范围。

**Follow-up Questions**

- 如何向领导解释“不能保证 100%”？
- 多次采样如何用于评估？
- False positive 和 false negative 哪个更重要？
- Shadow mode 有什么局限？

**Deep Dive**

强答案接受非确定性，但不放弃工程控制：重复采样、置信区间、shadow、灰度、范围控制。弱答案会说 temperature=0 就确定。

---

### Q8: 讲一次你处理跨团队冲突的经历

**Question**

Tell me about a cross-functional conflict in an AI project.

**Model Answer**

**Situation**：Data team 认为问题在模型，需要 fine-tune；Search team 认为问题在文档质量；Product 只想快速改善用户体验。

**Task**：我需要让团队停止互相归因，找到最高杠杆改进。

**Action**：我组织 failure review，把 100 个失败样本按原因标注：检索漏召、证据冲突、生成幻觉、权限过滤、问题歧义。结果显示 45% 是检索和文档元数据问题，20% 是 prompt/grounding，只有少数需要 fine-tune。

据此分工：

- Search 修 metadata 和 hybrid retrieval。
- Product 改澄清问题 UX。
- AI team 改 citation prompt 和 eval。
- Backend team 补 trace 字段。

每周用同一 failure set 复盘进展。

**Result**：四周内 answer acceptance 提升 18%，没有做昂贵 fine-tune。冲突变成了共同 dashboard 上的待办。

**Follow-up Questions**

- 如果团队不认可标注结果怎么办？
- 如何避免 blame culture？
- 哪些决策需要你拍板？
- 如何持续保持 alignment？

**Deep Dive**

Staff 答案体现 system diagnosis 和 facilitation。跨团队影响力不是声音大，而是建立共同事实和可执行 owner。

---

### Q9: 讲一次你为了长期质量牺牲短期速度

**Question**

Tell me about a time you slowed down delivery to improve long-term quality.

**Model Answer**

**Situation**：团队频繁改 prompt，每次 demo 都更好，但线上偶尔退化。没有 prompt review、eval gate 或版本记录。

**Task**：我决定暂停新 prompt 上线一周，建立最小治理流程。

**Action**：我没有引入重流程，而是加三件事：

1. Prompt 存代码库并 code review。
2. 每个 prompt PR 跑 smoke eval。
3. 线上请求记录 prompt version。

对于紧急修复保留 break-glass 流程，但必须事后补评测。我向 product 解释：这一周不是“慢下来”，而是避免以后每次事故花三天复盘却无法复现。

**Result**：短期少上线两个小优化，但之后 prompt regression 明显减少。一次 provider 模型漂移时，我们能快速定位受影响 prompt 并回滚。

**Follow-up Questions**

- 如何避免治理变成官僚流程？
- 如何衡量长期质量收益？
- 如果有人绕过流程怎么办？
- Prompt 是否应该由 PM 修改？

**Deep Dive**

强答案展示适度流程：最小但关键的控制点。Staff 不是永远加流程，而是在复杂度上升前建立护栏。

---

### Q10: 你如何描述自己的 AI Engineering 原则？

**Question**

What principles guide your work as a senior AI engineer?

**Model Answer**

我的原则有五条：

1. **模型不是产品，系统才是产品**。用户体验来自模型、检索、工具、UI、延迟和安全的组合。
2. **先评测，再优化**。没有 eval 的 prompt 改动只是主观调参。
3. **把 token 当资源**。上下文、输出、重试、缓存都要有预算。
4. **不信任模型输出**。结构化校验、权限、幂等、审批和审计必须在后端实现。
5. **渐进式交付**。从低风险场景、shadow、灰度、回滚开始，而不是一次性全自动。

一个 Senior AI Engineer 的价值不是知道最多模型名字，而是能在非确定性能力之上构建确定性的工程边界。

**Follow-up Questions**

- 哪条原则最常被团队忽视？
- 如何在速度和安全之间取舍？
- 未来一年 AI engineering 最大变化是什么？
- 你如何培养产品直觉？

**Deep Dive**

强答案具体、可执行，并能连接到过往经历。弱答案停留在“持续学习、用户第一”这类泛泛表述。Staff 面试中，原则要能解释你的技术决策。

---

## Further Reading

- Part 1：系统设计、平台治理、可靠性、成本和工程组织章节。
- Part 2 Chapter 01：LLM 基础与 Transformer 概览，帮助向非 AI 背景团队解释机制。
- Part 2 Chapter 15：Evaluation 与实验体系，用于建立质量信心。
- Part 2 Chapter 16/19：Guardrails、安全、提示注入和生产风险控制。
