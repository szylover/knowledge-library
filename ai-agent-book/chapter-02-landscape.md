# 第二章：AI Agent 行业全景

AI Agent 的生态在 2026 年已经不再是“几个框架 + 一个模型”的简单组合，而是一套分层技术栈。本章给你一张清晰的行业地图：**11 类核心工具、主要玩家与企业采用现状。**

---

## 2.1 先看总图：Agent 生态是分层的

站在工程角度，一个完整 Agent 系统通常由六层构成：

```text
+-----------------------------------------------------------+
| 应用层：客服 / 编码 / 金融分析 / 医疗 / 零售 / 法律 / 教育 |
+-----------------------------------------------------------+
| 执行层：Agent Runtime / Browser Agent / IDE Agent / Memory |
+-----------------------------------------------------------+
| 编排层：Workflow / Scheduling / Tool Routing / A2A / MCP  |
+-----------------------------------------------------------+
| 数据层：RAG / Vector DB / Cache / Session State           |
+-----------------------------------------------------------+
| 运维层：Tracing / Evaluation / Guardrails / Policy        |
+-----------------------------------------------------------+
| 模型层：GPT / Claude / Gemini / Llama / Qwen / ERNIE      |
+-----------------------------------------------------------+
```

不同公司、不同岗位关注的层次并不一样：模型公司占模型层，框架公司占执行与编排层，企业平台团队关注治理，应用团队关心业务 ROI。

---

## 2.2 2026 年 11 类 Agentic AI 工具版图

根据 StackOne 在 2026 年对 **120+ Agentic AI 工具**的映射，主流生态大致可分成 11 类。

### 1）基础模型（Foundation Models）

代表选手包括 GPT-4o / GPT-4.1、Claude 4.x、Gemini 2.x / 3.x、Llama、Qwen、文心（ERNIE）。这一层决定推理、工具选择、长上下文和多模态能力。工程选型时重点看工具调用稳定性、结构化输出、长上下文成本、延迟和合规部署。

### 2）Agent 框架（Agent Frameworks）

代表选手包括 LangChain / LangGraph、CrewAI、AutoGen、Dify、Coze。它们解决的是“Agent 怎么组织起来”，包括状态管理、工具接口、多步流程、多 Agent 协作和人工审批。

### 3）编排平台（Orchestration Platforms）

这一层比框架更偏生产环境，关注任务调度、重试超时、审批、工作流版本化和成本控制。很多企业会叠加自己的编排平台。

### 4）向量数据库（Vector Databases）

代表选手包括 Pinecone、Weaviate、Milvus、FAISS、Chroma。它们是 RAG 的底层基础设施，但别把向量数据库误解成“自动记忆”。真正决定效果的还有 chunking、embedding、元数据过滤、混合检索和 reranking。

```python
def retrieve(query: str, top_k: int = 3):
    return ["doc-1", "doc-2", "doc-3"][:top_k]


context = retrieve("退款多久到账")
print(context)
```

### 5）可观测性与评估（Observability & Evaluation）

代表选手是 LangSmith、Weights & Biases、Arize。重点不是“让日志更好看”，而是回答：哪一步失败、哪类任务成功率最低、新版本是否退化、成本和延迟是否可控。

### 6）Agent 协议（Agent Protocols）

最关键的是 MCP（Model Context Protocol）和 A2A（Agent-to-Agent）。MCP 解决“模型或 Agent 如何接工具和资源”，A2A 解决“不同 Agent 如何协作和传递任务”。协议成熟意味着生态从点对点适配走向标准化接入。

### 7）记忆系统（Memory Systems）

记忆通常分三层：短期记忆、长期记忆、工作记忆。真正的难点是“什么时候存、什么时候取、什么时候忘”，而不是简单存文本。

### 8）代码/IDE Agent（Code/IDE Agents）

代表产品包括 Claude Code、Cursor、GitHub Copilot、Windsurf。它们的核心能力是读仓库、搜代码、改文件、跑测试。这是转行者最容易做作品集的一类方向。

### 9）浏览器 Agent（Browser Agents）

这类 Agent 通过网页环境感知和操作 UI，适合表单填写、运营后台自动化、网页调研和数据抓取。难点在于网页变化频繁，因此依赖重试、回退和审批。

### 10）企业集成平台（Enterprise Integration Platforms）

企业是否愿意采购 Agent，很大程度上取决于它能不能接进现有系统，如 CRM、ERP、工单系统、邮件系统、数据仓库和 IAM。没有连接器（connectors），Agent 再聪明也只能“会说不会做”。

### 11）安全与护栏（Security & Guardrails）

随着 Agent 获得更多操作权限，安全层的重要性快速上升，重点包括 prompt injection 防护、越权控制、敏感操作审批、secret 扫描、审计日志和输出过滤。

一句话总结：**模型提供智能，框架负责执行，平台负责治理，数据负责知识，观测与安全保证可上线。**

---

## 2.3 一张更完整的 ASCII 生态地图

```text
                              +----------------------+
                              |  Industry Use Cases  |
                              | CS / Coding / Fin /  |
                              | Healthcare / Legal   |
                              +----------+-----------+
                                         |
        +--------------------+-----------+-----------+--------------------+
        |                    |                       |                    |
        v                    v                       v                    v
 +--------------+   +---------------+     +----------------+   +----------------+
 | IDE Agents   |   | BrowserAgent  |     | Enterprise App |   | Memory Systems |
 | Copilot etc. |   | UI Automation |     | Support/Sales  |   | Session/Long   |
 +------+-------+   +-------+-------+     +--------+-------+   +--------+-------+
        \                   |                      /                    /
         \                  |                     /                    /
          v                 v                    v                    v
      +--------------------------------------------------------------------+
      | Agent Frameworks / Runtime / Orchestration                         |
      | LangChain | CrewAI | AutoGen | Dify | Coze | Workflow | Scheduling |
      +------------------------------+-------------------------------------+
                                     |
                                     v
      +--------------------------------------------------------------------+
      | Protocols & Enterprise Integration                                 |
      | MCP | A2A | Tool Registry | Connectors | IAM | Approval            |
      +------------------------------+-------------------------------------+
                                     |
                                     v
      +--------------------------------------------------------------------+
      | Retrieval / Vector / Knowledge                                     |
      | Pinecone | Weaviate | Milvus | FAISS | Chroma | Cache | RAG        |
      +------------------------------+-------------------------------------+
                                     |
                                     v
      +--------------------------------------------------------------------+
      | Observability / Evaluation / Security                              |
      | LangSmith | W&B | Arize | Tracing | Guardrails | Red Teaming       |
      +------------------------------+-------------------------------------+
                                     |
                                     v
      +--------------------------------------------------------------------+
      | Foundation Models                                                  |
      | GPT | Claude | Gemini | Llama | Qwen | ERNIE                       |
      +--------------------------------------------------------------------+
```

---

## 2.4 主要玩家深度观察

### OpenAI

OpenAI 的强项在于模型能力、API 完整度和开发者心智。

### Anthropic

Anthropic 在 2025-2026 年最强的心智是安全、推理质量、coding 场景。Claude 系列在代码理解、仓库导航、工具调用稳定性方面很突出。

### Google

Google 的优势是“模型 + 云 + 多模态”。

### Meta

Meta 的核心影响力来自 Llama 开源生态。它带来私有化部署、低成本试验和二次微调空间，对强调数据主权的企业有吸引力。

### Microsoft

Microsoft 的优势是企业入口：GitHub、Office、Azure、Copilot 家族，再加上成熟的安全与治理能力。很多企业内部 Agent 项目都会优先考虑微软生态。

### 中国玩家：百度、阿里、字节跳动

中国市场的重要特点是本地模型、云和企业协作工具耦合更紧：**百度**偏搜索与企业服务，**阿里巴巴**依托 Qwen 与阿里云，**字节跳动**产品化速度快。对中文场景求职者来说，本地部署、中文效果、飞书/钉钉/企业微信集成往往更重要。

---

## 2.5 企业采用现状：哪些行业已经跑起来了

### 金融

典型场景包括财报与研究摘要、合规检索、客服辅助、风险初筛。金融行业愿意投入，因为文档密集、人工分析昂贵。

### 医疗

典型场景包括分诊、病历摘要、患者沟通辅助、保险理赔文档整理。医疗行业上 Agent 的前提不是“更聪明”，而是“可追踪、可审核、人类最终责任人”。

### 零售与电商

典型场景包括智能客服、商品描述生成、商家运营助手、库存与补货建议、营销分析。零售之所以是高 ROI 行业，是因为订单量大、重复任务多。

### 法律

典型场景包括合同条款提取、版本对比、案例检索、初稿生成。法律 Agent 最适合压缩前置机械劳动，而不是替代律师判断。

### 教育

典型场景包括作业讲解、个性化辅导、备课辅助、学习路径推荐。教育适合长期记忆与多模态能力落地。

---

## 2.6 作为转行者，如何看待这个生态

不要试图把所有工具都学一遍。更有效的方法是问自己五个问题：

1. **它解决的是哪一层的问题？** 模型、检索、框架、编排、评估还是安全？  
2. **它有没有明确业务闭环？** 是能提高工单处理率，还是只会做演示？  
3. **它是否需要工程深度？** 权限、重试、日志、回归测试越多，岗位壁垒通常越强。  
4. **它能否与你原有技能叠加？** 后端适合工具与平台，前端适合 Agent UI，DevOps 适合推理与部署，QA 适合评估与红队测试。  
5. **它能不能做成作品集？** 客服 Agent、编码 Agent、评估平台，都比“会聊天的小机器人”更有说服力。  

读完这一章，你至少要形成一个结构：**Foundation Model 并不等于 Agent；价值主要在模型之上的执行、编排、知识、评估和治理。**

## 本章要点

- 2026 年 Agentic AI 已形成**分层明确的生态系统**，不是单一模型或单一框架能解释的。
- StackOne 的 2026 版图显示，市场上已有 **11 类、120+ 工具**，说明行业进入快速分工期。
- 11 类核心类别包括：**基础模型、Agent 框架、编排平台、向量数据库、可观测性与评估、协议、记忆系统、代码/IDE Agent、浏览器 Agent、企业集成平台、安全与护栏**。
- OpenAI、Anthropic、Google、Meta、Microsoft 与中国玩家（百度、阿里、字节等）分别在模型、平台、企业入口、开源和本地化部署上形成不同优势。
- 金融、医疗、零售、法律、教育都已出现较清晰的 Agent 落地场景。
- 对转行者最重要的，不是记住所有产品名，而是理解每一层解决什么问题，并押注**有业务闭环、工程深度高**的方向。

## 延伸阅读

- StackOne：2026 Agentic AI Tools Landscape
- LangChain / LangGraph、CrewAI、AutoGen、Dify、Coze 官方文档
- Pinecone、Milvus、Weaviate、Chroma 官方文档
- LangSmith、Weights & Biases、Arize 关于 LLM 评估的资料
- MCP 与 A2A 协议规范
- OpenAI、Anthropic、Google Cloud、Microsoft Azure 的企业 Agent 文档
