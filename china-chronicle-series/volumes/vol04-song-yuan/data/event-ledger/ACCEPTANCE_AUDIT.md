# 宋辽夏金元严格复验记录

日期：2026-07-17（`acceptance-song-yuan-strict-rewrite`）

## 可机械核验的结果

| 检查 | 结果 | 证据 |
|---|---|---|
| 账本格式与证据护照 | 通过 | `validate-event-ledger.ps1`：`song-yuan.csv` 2,200 条，`evidence-passport-13`。 |
| 首次呈现覆盖 | 通过 | 2,200 个账本 ID、2,200 个正文锚点、2,200 个唯一锚点；缺失与未知 ID 均为 0。 |
| 模板语句回归 | 通过 | 旧的八个桥接／账本模板短语均为 0；每项改写为含出处、行动者、空间线索、前因和可追踪后果的段落。 |
| 信息框 | 通过 | 六个首次呈现文件各有一个 `textwindow`，含短引文、出处、材料立场与可说范围。 |
| 缺口矩阵 | 通过 | `coverage-gap-matrix.md` 提供 7 个时间带 × 6 个政权／地区格的现有数、目标／桥接、密度、限度、空白与补证路径；`actioner-gap-matrix.md` 汇总行动者空白。 |
| 非发布构建 | 通过 | Tectonic 编译 `main.tex` 成功；构建目录已清理，未生成根目录 PDF、未同步下载目录。 |

## 仍须由 Integrator 处理

本任务不修改 wrapper、`main.tex`、`PROGRESS.md`、根目录 PDF 或发布资产。合并时应按书系流程复核链接、抽读事件簇的开头／转折／结尾，并由 Integrator 决定是否发布。