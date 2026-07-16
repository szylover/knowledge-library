# 《中国大事编年·第二卷甲：汉帝国》Agent 指令

本卷是独立的汉帝国卷，范围为前206年至220年。开始工作前阅读 `../../SERIES_SPEC.md` 与系列 `AGENTS.md`。

## 卷内约定

- 正文由事件簇和四个综合专题组成；不得把账本锚点逐条搬进阅读主线。
- `data/event-ledger/han.csv` 是从第二卷母账本筛出的本卷记录。正文只扩写其中已有的内部 ID；全量导航留在 `chapters/appendices/appendix-ledger-navigation.tex`。
- 图件必须是 `figures/` 下可版本化的 TikZ 示意图。不得将示意性的节点、路线或色块误作精确疆界。
- `main.tex` 只负责卷面、目录、分部及 wrappers；正文分别写入 `western-han/`、`eastern-han/` 和 `synthesis/`。
- 事件名称面向读者使用中文；内部 ID 只出现在链接锚点、账本和维护文件中。
- 先在 `WORK_QUEUE.yaml` 锁定范围，再开始写入。完成时更新 `PROGRESS.md`，报告账本 ID、来源、争议和构建结果。

## 构建与交付

运行 `scripts/build-volume.ps1`。它会以 Tectonic 编译至临时 `.build/`，短暂复制到仓库根 `pdf/china-chronicle/vol02a-han.pdf` 后默认删除；不要提交任何 PDF 或构建产物。若确有人工发布需要，可显式传入 `-KeepPublishedPdf`，并由 Integrator 依照系列发布契约处理。
