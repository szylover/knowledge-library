# 工具链 Toolchain

> 本书代码示例采用的技术栈与推荐工具。

| 类别 | 选型 | 说明 |
|------|------|------|
| 语言 | Python 3.11+ | 类型注解 + async |
| Web 框架 | FastAPI | 异步、OpenAPI、依赖注入 |
| 数据校验 | Pydantic v2 | 结构化输入/输出、Settings |
| Agent 编排 | LangGraph | 有状态图、可中断、HITL |
| LLM SDK | OpenAI SDK / Anthropic SDK | 官方客户端 |
| 工具协议 | MCP | 标准化工具/数据源接入 |
| 容器 | Docker / Compose | 本地与部署一致 |
| 关系库 | Postgres | 事务、JSONB、pgvector 可选 |
| 缓存 | Redis | 缓存、限流、队列、语义缓存 |
| 向量库 | Qdrant | 过滤 + 混合检索 |
| 可观测 | OpenTelemetry + Langfuse | trace / metrics / LLM 观测 |
