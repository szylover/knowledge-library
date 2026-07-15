# 《中国大事编年》系列 Agent 规范

先阅读 `SERIES_SPEC.md`，再进入目标卷阅读 `volumes/<volume>/AGENTS.md`。

## 必须遵守

1. 不直接写 `main`；先运行 `scripts/new-agent-worktree.ps1 -TaskId <id>` 创建 worktree。
2. 在卷的 `WORK_QUEUE.yaml` 中认领状态为 `ready` 的任务；任务必须锁定文件范围。
3. Chronology 先写账本，Narrative 只写账本已有事件，Map 只写独立图文件。
4. 不跨任务范围修改文件。需要改 wrapper、索引、PDF 时交给 Integrator。
5. 交接时报告文件、事件 ID、来源、争议、构建结果。
6. 发布 PDF 只能写在仓库根 `pdf/china-chronicle/`，文件名为 `volXX-<slug>.pdf`；不得与其他书系的 PDF 平铺混放。每次合并并更新书系 PDF 后，Integrator 必须将该目录同步到 Azure Blob Storage 账户 `szydownloads` 的 `downloads/books/china-chronicle/` 路径，再报告发布结果。

## 共享资源

- `shared/styles/`：跨卷 LaTeX 样式。
- `shared/source-corpus/`：多卷来源矩阵和引用方法。
- `tasks/`：任务卡模板。
