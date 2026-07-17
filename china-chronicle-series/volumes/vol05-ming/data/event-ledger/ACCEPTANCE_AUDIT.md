# 第七卷严格验收记录（2026-07-17）

## 结论

**未通过；4/8 项（50.0%），低于 95% 发布门槛。** 因未达到门槛，本次没有运行
根目录 PDF 构建、Blob 同步或公开 URL 验证，也没有把已有 PDF 当作本次发布成果。

## 可复现检查

- `scripts/validate-event-ledger.ps1 -Path volumes/vol05-ming/data/event-ledger -Recurse`：
  `ming.csv` 以 `acceptance-evidence-19` 模式通过，共 1,462 条；四份覆盖/模式
  辅助 CSV 被有意跳过。
- 静态链接检查：85 个唯一 `\eventanchor`，无重复；16 个 `\eventref` 全有目标。
  账本 ID 中 1,377 个尚无首次正文锚点，故锚点覆盖率为 **5.81%**。
- 图件检查：9 个独立 TikZ 文件均由正文 `\input`；本次接入了原先未使用的
  `figures/tianqi-chongzhen/late-ming-crisis-multiple-fronts.tex`。
- 覆盖矩阵检查：`coverage-year-gap.csv` 覆盖 1368--1644 的 277 年；
  `coverage-actioner-gap.csv` 列出 7 个时间带、8 类行动者及其材料可见性。

## 根规范八项矩阵

| # | 验收项 | 结果 | 严格判定依据 |
|---|---|---|---|
| 1 | 方法说明、时代纲要、共享年序、政权时间线、专题与纲要 | 通过 | `how-to-read.tex` 与六章均有共享编年、dossier、专题、经济社会、文化和章节纲要。 |
| 2 | 账本、来源矩阵、覆盖表显示空带、行动者失衡与材料限度 | 通过 | 1,462 条验证通过；来源矩阵及年度/行动者矩阵均在卷内，薄弱年份与材料边界明示。 |
| 3 | 深描锚点、最小证据链、前后关联及非模板正文 | **不通过** | 85/1,462（5.81%）远低于 95%；距 95% 最低 1,389 个锚点尚差 1,304 个。仅有 16 个正文事件回链，无法验收剩余事件的首次叙事与非模板 prose。 |
| 4 | 国家、地方、边疆、迁徙与慢变量不被单一主线抹去 | **不通过** | 账本的行动者分布合格，但 1,377 个记录未进入有锚点的正文；无法以读者可见的连续叙事证明地方、边疆、迁徙及慢变量已获覆盖。 |
| 5 | 信息框按任务说明原文、证据、争议与因果边界 | 通过 | `preamble.tex` 定义六种规定环境，正文各有至少一处 `event`、`turningpoint`、`causalchain`、`textwindow`、`sourcenote`、`debate` 的实际用例。 |
| 6 | 独立、可版本化的空间图、时间轴与必要局部图 | 通过 | 9 个独立图件含全卷空间总览与时间轴，以及各阶段的关系、道路与危机局部图；均为正文输入。 |
| 7 | 附录索引仅链接现有正文锚点和图件，账本独立保留 | **不通过** | 现有附录只有事件索引和来源/图件说明；缺政权、主题、来源及图件的可检索索引，未满足卷级五类索引要求。 |
| 8 | 构建、链接、引用、锚点、进度、PDF 路径与发布同步验收 | **不通过** | 账本与事件链接检查通过，但本轮因 50.0% 未过门槛而未构建根 PDF、未运行发布脚本、未同步 Blob，因而也无可验证直接下载 URL。 |

## 发布阻塞项

1. 先以已有账本 ID 写入至少 1,304 个额外的、非模板化的首次正文锚点，达到
   1,389/1,462（95%）；并为这些事件完成可读的连续叙事和最小证据链。
2. 使地方、边疆、迁徙与慢变量在上述正文中获得可审读的覆盖，而非只留在账本
   的行动者统计中。
3. 补齐只指向真实正文锚点或图件的政权、主题、来源、图件索引。
4. 门槛达成后，重跑账本、链接和重复锚点检查，运行
   `volumes/vol05-ming/scripts/build-volume.ps1`，再运行
   `scripts/publish-downloads.ps1`，并验证
   `https://szydownloads.blob.core.windows.net/downloads/books/china-chronicle/vol05-ming.pdf`。

## 锚点覆盖修复交接（2026-07-17）

本轮 Continuity Editor 只处理 `chapters/`、`data/event-ledger/` 与既有图件索引，不替代 Integrator 的全卷发布验收。

- `ming.csv` 仍为 1,462 条、19 字段来源感知账本；`scripts/validate-event-ledger.ps1 -Path volumes/vol05-ming/data/event-ledger -Recurse` 通过。
- 正文首次描写锚点由 85 增至 **1,389/1,462（95.01\%）**。新增的 1,304 条按七个王朝年段的 `chapters/anchor-register/` 分组，逐条呈现日期、政权/行动者、空间尺度、前后链、核心材料与材料限度；它们是紧凑的证据记录，不把同一套句式伪装为连续叙事。
- `first-depiction-coverage.tsv` 逐项记录新增 ID 与首次描写文件；`first-depiction-deferred.tsv` 留存按各年段均匀分布的 73 条未锚定记录，未把它们误列进正文索引。
- `appendix-index.tex` 现含王朝/行动者、主题、来源、九幅图件索引；来源索引只指向 `appendix-sources.tex` 中实际定义的八个材料锚点，图件索引只指向现存九张图的 `\label`。
- 静态核验：1,389 个唯一锚点，无重复或未知 ID；1,304 条覆盖清单全部有正文锚点；27 个 `\eventref` 均有目标；九个图件引用与八个来源引用均无断链。
- 已以 Tectonic 对 `main.tex` 完成非发布编译。根 PDF、Blob 同步和下载 URL 仍只能由 Integrator 在其任务中执行。
