# 第三章：转行路径与岗位分析

理解行业和技术版图之后，真正决定你能不能顺利转行的，不是“AI 很热”这个事实，而是：**你应该投什么岗位、补什么能力、用多长时间补、做什么作品集最有效。**

很多转行失败，并不是因为不够努力，而是因为目标岗位选错了。前端去冲模型训练岗，后端只刷 Prompt，QA 忽略评估体系，DevOps 完全不碰 LLM API——这些都很常见。

这一章的目标，就是把 AI Agent 相关岗位拆清楚，并给出从不同背景切入的可执行路线。

---

## 3.1 六类最常见岗位：先把坐标系立住

### AI Agent Engineer

这是本书最核心的目标岗位，职责是构建能够完成任务的 Agent 系统，通常涉及：

- 工具调用；
- 工作流编排；
- RAG；
- memory；
- 安全与权限；
- 评估与上线。

一句话：**让模型真正干活的人。**

### ML Engineer

更偏模型训练、部署与推理优化，常见工作有：

- 训练或微调模型；
- serving 与推理优化；
- GPU 资源管理；
- 数据流水线。

一句话：**让模型更强、更稳的人。**

### LLM Application Engineer

这类岗位介于传统应用工程师和 Agent 工程师之间，主要做：

- LLM API 接入；
- Prompt、摘要、分类、问答；
- RAG 驱动的产品功能。

它是很多工程师进入 Agent 方向的过渡台阶。

### AI Infrastructure Engineer

非常适合 DevOps / SRE 切入。重点包括：

- 推理集群；
- 模型部署平台；
- 监控与成本优化；
- GPU 调度；
- LLMOps / MLOps。

### Data Scientist

重点在分析、实验和指标，而不是搭完整 Agent 系统。常做：

- 数据分析；
- A/B 测试；
- 实验设计；
- 业务建模。

### Prompt Engineer

到了 2026 年，纯 Prompt Engineer 正在被并入其他岗位。Prompt 仍然重要，但它越来越像一项基础技能，而不是单独职业。

---

## 3.2 一张最重要的岗位对比表

| 岗位 | 主要职责 | 必备技能 | 美国年薪区间 | 中国年薪区间 | 典型雇主 | 日常工作 |
|---|---|---|---|---|---|---|
| AI Agent Engineer | 做 Agent 系统、工具链、RAG、评估、上线 | Python、API、RAG、框架、系统设计、观测 | 15万-32万美元，高级可到45万+ | 32万-100万人民币，头部可到200万+ | AI 创业公司、SaaS、金融科技、企业数字化团队 | 设计流程、接工具、做评估、上线 |
| ML Engineer | 训练/部署模型、推理优化 | Python、PyTorch、Serving、GPU、数据流水线 | 16万-30万美元 | 40万-120万人民币 | 大模型公司、自动驾驶、研究团队 | 训练、部署、调优 |
| LLM Application Engineer | 构建 LLM 应用功能 | Python/TS、LLM API、Prompt、RAG | 14万-24万美元 | 30万-80万人民币 | SaaS、知识管理、内容平台 | 接 API、做实验、上线功能 |
| AI Infrastructure Engineer | 平台、推理、稳定性、成本 | Kubernetes、Docker、GPU、云平台、监控 | 16万-28万美元 | 35万-100万人民币 | 云厂商、大型企业平台团队 | 部署、容量规划、可靠性建设 |
| Data Scientist | 分析与实验 | SQL、Python、统计、实验设计 | 12万-22万美元 | 25万-70万人民币 | 互联网、零售、金融 | 分析数据、跑实验 |
| Prompt Engineer* | 提示词与对话质量优化 | Prompt、评估、业务理解 | 多已并入其他岗 | 多已并入其他岗 | 少量咨询/内容团队 | 优化提示词、做标注 |

\* 提示：Prompt Engineer 作为纯独立岗位正在减少，更常见的是并入 AI Agent、LLM 应用或产品岗位。

从这张表你应该得到一个结论：**对多数软件工程师而言，AI Agent Engineer 和 LLM Application Engineer 是最现实的切入点；对 DevOps/SRE 而言，AI Infrastructure Engineer 是黄金路径。**

---

## 3.3 不同背景的最佳转行路径

### 前端 -> AI

前端最大的优势不是“会做页面”，而是会做**Agent UI 和人机协作界面**。2026 年很多 Agent 产品都需要：

- React / TypeScript；
- 流式输出（streaming UI）；
- 复杂状态管理；
- 任务轨迹可视化；
- 审批流和工作台交互。

推荐补课顺序：

1. Python 基础；
2. LLM API；
3. RAG；
4. 一个 Agent 框架；
5. 做 Agent 控制台项目。

### 后端 -> AI

这是最强通用路径。因为 Agent 的大多数生产难点，本质上都是后端问题：

- API 编排；
- 权限控制；
- 状态管理；
- 队列与重试；
- 日志与可观测性；
- 成本优化。

后端要补的主要是：Python、LLM 基础、RAG、Agent 框架、Evaluation。

### 全栈 -> AI

全栈最适合做端到端 Agent 产品，也是最容易做出“有 ownership 的作品集”的人群。你可以：

- 用 React/Next.js 做前端；
- 用 Python/FastAPI 做后端；
- 接模型、向量数据库、日志平台；
- 做一个完整可演示的业务场景。

这条路线也很适合独立开发者（indie hacker）。

### DevOps / SRE -> AI Infra

这是很多人低估的机会。你已有的能力——Kubernetes、CI/CD、监控、容量规划、安全、故障处理——在 AI 系统里全部有用。

重点补：

- 推理服务；
- GPU 基础；
- 吞吐/延迟优化；
- LLMOps / MLOps；
- 模型网关与成本核算。

### QA -> AI Evaluation

QA 是被低估的转行路径。传统测试方法论在 Agent 时代非常值钱：

- 用例设计；
- 回归测试；
- 边界情况；
- 缺陷分类；
- 自动化测试。

迁移到 AI 方向后，就变成：

- prompt regression；
- RAG benchmark；
- 红队测试（red teaming）；
- hallucination 测试；
- 多轮任务成功率评估。

---

## 3.4 你已有的技能，如何映射到 Agent 岗位

| 你已有的能力 | 在 Agent 岗位中的价值 | 还要补什么 |
|---|---|---|
| Web/API 开发 | 工具接入、服务编排 | LLM API、tool calling、streaming |
| 数据库设计 | memory、日志、知识库元数据 | 向量检索、embedding、RAG |
| 分布式系统 | 队列、重试、扩缩容 | Agent runtime、workflow |
| 前端交互 | Agent 控制台、审批流、可视化 | AI UX、对话状态设计 |
| 测试自动化 | 回归与质量保障 | LLM evaluation、红队测试 |
| DevOps/CI/CD | 部署、监控、可靠性 | GPU、推理服务、LLMOps |

你可以把学习目标分成三层：

### 第一层：必须会

- Python
- LLM API
- Prompt 基础
- RAG 基础
- 一个 Agent 框架
- Docker / Git / 基础部署

### 第二层：拉开差距

- Evaluation
- Tracing / observability
- Memory 系统
- Guardrails
- 成本优化
- 多 Agent 编排

### 第三层：冲高薪

- 私有化部署
- 模型路由
- 推理服务优化
- 企业 IAM 集成
- MCP / A2A
- 大规模生产经验

---

## 3.5 一个现实的 3-6 个月转行计划

假设你在职，每周能投入 12 到 18 小时，下面的节奏对大多数人比较现实。

### 第 1 个月：补基础

目标：

- 学 Python；
- 理解 token、context window、embedding；
- 接至少 2 家模型 API；
- 做 2 到 3 个小 demo。

建议产出：

- 问答 demo；
- 摘要或分类 demo；
- 一个简单工具型 Agent。

### 第 2 个月：掌握 RAG 和 Agent 结构

目标：

- 学文档切分、embedding、召回、重排；
- 选一个框架做完整流程；
- 理解 tool use 和状态机。

建议产出：

- 一个带知识库的问答系统；
- 一个能调 2 到 3 个工具的单 Agent。

### 第 3 个月：做出作品集项目

目标：

- 选真实业务场景；
- 做前后端完整链路；
- 接日志、评估、权限控制；
- 能讲清楚架构取舍。

推荐方向：

- 客服 Agent；
- 财报分析 Agent；
- 编码 Agent；
- 浏览器任务 Agent。

### 第 4-6 个月：冲面试

重点：

- 补系统设计；
- 做回归测试；
- 录项目演示；
- 按岗位 JD 补短板；
- 开始投递和模拟面试。

这里特别重要的一点是：**把项目做稳，比再开一个新项目更有价值。**

---

## 3.6 转行最常犯的错误

1. **把“会用 ChatGPT”当成职业技能**：用户能力不等于工程能力。  
2. **疯狂追框架，不做项目**：框架会变，项目交付能力才会留下。  
3. **只学 Prompt，不学工程**：上线后决定质量的往往是权限、缓存、日志、评估。  
4. **只会 demo，不会量化结果**：要能说清楚成功率、延迟、成本、召回率。  
5. **作品过于玩具化**：比起“会讲笑话的机器人”，企业更爱客服、分析、编码、评估系统。  
6. **忽略评估与安全**：prompt injection、防越权、人工审批、回归测试，都是高频面试题。  
7. **不看岗位 JD 就学习**：AI Infra、LLM App、Agent Platform、Evaluation 关注点完全不同。  
8. **低估原有背景价值**：你不是从零开始，而是在已有工程栈上加一层智能系统能力。  

---

## 3.7 什么样的作品集最打动招聘方

如果只能做 3 个项目，我建议优先做下面三类。

### 项目 1：生产感强的客服 Agent

至少包含：

- RAG 知识库；
- 订单/工单工具调用；
- 升级人工；
- 审计日志；
- 延迟与成本统计。

### 项目 2：编码 Agent 或文档分析 Agent

重点体现：

- 多步任务；
- 工具链；
- 回归测试；
- 失败处理。

### 项目 3：评估平台或 Guardrails 项目

这类项目很能拉开差距，例如：

- Agent trace viewer；
- 回归评估脚本；
- prompt injection 测试套件；
- 敏感操作审批流。

下面给一个简单的 Python 评估示例：

```python
test_cases = [
    {"question": "退款多久到账？", "expected": "3 个工作日"},
    {"question": "订单未支付能退款吗？", "expected": "未支付"},
]


def evaluate(agent_fn):
    passed = 0
    for case in test_cases:
        answer = agent_fn(case["question"])
        if case["expected"] in answer:
            passed += 1
    return {"score": passed / len(test_cases), "passed": passed}
```

这个例子很简单，但代表了一个关键思维：**不要只问“能不能跑”，要问“能不能稳定通过一组任务”。**

---

## 3.8 社区、证书和资源怎么选

### 社区

优先加入三类社区：

- 开源社区：GitHub、Hugging Face、LangChain/Dify 等项目讨论区；
- 中文实践社区：微信群、飞书群、线下 Meetup；
- 招聘信息密集社区：LinkedIn、X、国内招聘平台专题圈子。

目的不是看热闹，而是：

- 看真实案例；
- 跟进岗位需求；
- 找项目合作和内推。

### 证书

证书不能替代项目，但对某些方向有辅助价值：

- 云厂商 AI/ML 认证：适合 AI Infra；
- Kubernetes / 云原生认证：适合部署与平台岗位；
- 安全认证：适合 Guardrails 和企业平台。

更实用的策略通常是：**先做强项目，再补证书。**

### 学习资源优先级

建议顺序：

1. 官方文档；
2. 生产级开源项目；
3. 有完整架构说明的技术博客；
4. 面试复盘与岗位 JD；
5. 论文和 benchmark 报告。

对转行者而言，先打通工程闭环，收益通常高于一开始就扎进论文细节。

---

## 3.9 最后给不同背景读者的一句话建议

- 前端：重点押注 Agent UI、工作台、流式交互。  
- 后端：重点押注工具编排、RAG、评估和平台能力。  
- 全栈：尽快做端到端项目，展示 ownership。  
- DevOps/SRE：补 GPU 和推理服务，走 AI Infra 路线。  
- QA：把测试方法论迁移到 Evaluation 和红队测试。  

转行 AI Agent，不是推倒重来，而是把你已有的软件工程能力，升级成“智能系统工程能力”。

## 本章要点

- 2026 年最常见的 AI 相关岗位包括：**AI Agent Engineer、ML Engineer、LLM Application Engineer、AI Infrastructure Engineer、Data Scientist、Prompt Engineer（逐步并入其他岗位）**。
- 对大多数软件工程师来说，**AI Agent Engineer 和 LLM Application Engineer** 是最现实的切入口；对 DevOps/SRE，**AI Infrastructure Engineer** 是高匹配路径；对 QA，**AI Evaluation** 是被低估的机会。
- 岗位选择必须结合原背景做映射，而不是盲目追最热名词。
- 一个现实的转行周期通常是 **3 到 6 个月**，关键是做出有业务价值、工程深度、评估意识的作品集。
- 最常见的错误包括：只会用模型、不做项目、只学 Prompt、忽视评估与安全、作品过于玩具化。
- 最能打动招聘方的项目，往往具备：**真实业务场景、多工具调用、RAG、日志、评估、审批或安全设计**。

## 延伸阅读

- OpenAI、Anthropic、Google、Microsoft 的开发者与 Agent 文档
- LangChain / LangGraph、CrewAI、Dify、AutoGen 官方教程
- LangSmith、Arize、Weights & Biases 关于 LLM evaluation 的资料
- vLLM、TGI、KServe、Ray Serve 等推理与部署工具文档
- 2025-2026 年 AI/LLM/Agent 岗位 JD 与薪酬报告
