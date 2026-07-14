# AI Engineering Living Book

> 面向资深后端工程师的 **AI Application Engineering** 转型手册。
> 以 Senior / Staff Engineer 的视角，讲 **WHY、trade-offs、生产实践、失败案例、扩展性、成本、安全、可观测性**。
> 不讲基础编程，不吹捧，不营销 —— 只讲能真实落地的工程。

## 读者画像

假设你有：

- 10 年软件工程经验
- 扎实的 C++
- 系统设计能力
- 后端经验
- 分布式系统基础

本书的目的**不是**记忆概念，而是建立**足够的工程能力**，让你能独立构建**生产级 AI 系统**，成长为专业的 AI Application Engineer。

## 技术栈

Python · FastAPI · Pydantic · LangGraph · OpenAI SDK · Anthropic SDK · MCP · Docker · Postgres · Redis · Qdrant。
所有代码均为**生产级**示例（含错误处理、超时/重试、配置、类型与可观测性），非玩具代码。

## 约定

- 正文中文，英文术语保留（Kafka / RAG / Function Calling …）。
- 每章独立可读；多用**表格**与 **Mermaid** 图。
- 每章结尾统一含：**Key Takeaways · Interview Questions · Further Reading**。

---

## 目录

### [Part 1 — 现代系统设计](book/part1_system_design/README.md)

从 AI 工程师视角重建系统设计知识。

| # | 章节 |
|---|------|
| 01 | API 设计 |
| 02 | Gateway · Reverse Proxy · Load Balancer |
| 03 | Cache 与 Redis |
| 04 | Database：SQL vs NoSQL |
| 05 | Object Storage 与 CDN |
| 06 | Message Queue · Kafka · Event-Driven |
| 07 | 分布式事务 |
| 08 | Scheduler / 任务调度 |
| 09 | Authentication 与 Authorization |
| 10 | Observability：Monitoring · Logging · Metrics · Tracing |
| 11 | Cost Optimization |

### [Part 2 — AI 工程（核心）](book/part2_ai_engineering/README.md)

| # | 章节 | # | 章节 |
|---|------|---|------|
| 01 | LLM 基础与 Transformer 概览 | 12 | Agent |
| 02 | Token 与 Context Window | 13 | Multi-Agent |
| 03 | Prompt Engineering | 14 | Planning 与 Reflection |
| 04 | Structured Output | 15 | Evaluation |
| 05 | Function / Tool Calling | 16 | Guardrails 与 Hallucination |
| 06 | MCP | 17 | Streaming 与 Long Context |
| 07 | Embedding 与 Vector Database | 18 | Workflow Engine 与 Human-in-the-Loop |
| 08 | Chunking 与 Retrieval | 19 | AI Security |
| 09 | Hybrid Search 与 Re-ranking | 20 | AI Observability |
| 10 | RAG | 21 | Cost Optimization（LLM 成本）|
| 11 | Memory | 22 | Deployment |

### [Part 3 — 实战项目](book/part3_projects/README.md)

AI Chat · AI Knowledge Base · AI Coding Assistant · AI Meeting Assistant · AI Browser Agent · AI Research Agent · AI CRM · AI Email Assistant · AI Customer Support · AI Comic Generator · AI Resume Assistant · AI Document QA

### [Part 4 — 工程模式](book/part4_patterns/README.md)

Planner · Reflection · Critic · Router · Tool Selection · Retry · Memory · Workflow · Multi-Agent · Evaluation

### [Part 5 — Prompt 库](book/part5_prompts/README.md)

System · Planner · Reviewer · Architect · Critic · Memory · Summarizer · Code Reviewer · RAG Rewrite · Tool Selection · Evaluation

### [Part 6 — 面试](book/part6_interview/README.md)

System Design · LLM · RAG · Agent · MCP · Evaluation · Infrastructure · Backend · Coding · Behavior

### [Part 7 — 最佳实践](book/part7_best_practices/README.md)

Production · Deployment · Security · Performance · Cost · Prompt · RAG · Agent · Code Review · Architecture Review

### [Resources](book/resources/README.md)

术语表 · 参考书目 · 工具链。

---

## 阅读路线

- **快速转型**：Part 2（核心）→ Part 3（挑 2-3 个项目）→ Part 4 → Part 7。
- **系统重建**：Part 1 → Part 2 → Part 4 → Part 3 → Part 5/6/7。
- **面试冲刺**：Part 6 主线，回填 Part 1/2 对应章节。

> 这是一本 **living book**，持续累加与迭代。
