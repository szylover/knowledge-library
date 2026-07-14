# Part 1 — 现代系统设计

> 从 **AI 工程师视角**重建系统设计知识。AI 系统本质仍是分布式后端系统，只是多了 LLM 这个"高延迟、高成本、非确定性"的特殊依赖。本部分帮你把已有的系统设计能力重新映射到 AI 场景。

## 每章结构

- **What problem does it solve** — 解决什么问题
- **Core idea** — 核心思想
- **Design choices** — 设计选择
- **Trade-offs** — 权衡
- **Common mistakes** — 常见错误
- **Production best practices** — 生产最佳实践
- **How AI systems use this concept** — AI 系统如何使用
- **Example Architecture** — 示例架构（Mermaid）
- **Interview Questions** — 面试题
- **Summary** — 小结

## 章节

| # | 章节 | 文件 |
|---|------|------|
| 01 | API 设计 | [chapter-01-api-design.md](chapter-01-api-design.md) |
| 02 | Gateway · Reverse Proxy · Load Balancer | [chapter-02-gateway-proxy-lb.md](chapter-02-gateway-proxy-lb.md) |
| 03 | Cache 与 Redis | [chapter-03-cache-redis.md](chapter-03-cache-redis.md) |
| 04 | Database：SQL vs NoSQL | [chapter-04-database.md](chapter-04-database.md) |
| 05 | Object Storage 与 CDN | [chapter-05-object-storage-cdn.md](chapter-05-object-storage-cdn.md) |
| 06 | Message Queue · Kafka · Event-Driven | [chapter-06-mq-kafka-event-driven.md](chapter-06-mq-kafka-event-driven.md) |
| 07 | 分布式事务 | [chapter-07-distributed-transactions.md](chapter-07-distributed-transactions.md) |
| 08 | Scheduler / 任务调度 | [chapter-08-scheduler.md](chapter-08-scheduler.md) |
| 09 | Authentication 与 Authorization | [chapter-09-auth.md](chapter-09-auth.md) |
| 10 | Observability | [chapter-10-observability.md](chapter-10-observability.md) |
| 11 | Cost Optimization | [chapter-11-cost-optimization.md](chapter-11-cost-optimization.md) |
