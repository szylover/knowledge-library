# 集成验收状态（2026-07-17）

**结论：没有卷在本轮被标记为验收通过。** 本记录只陈述已运行的检查，不能以
已有 PDF 或账本通过替代内容、来源、索引、图件与发布验收。

## 已运行的检查

- `scripts/validate-event-ledger.ps1 -Path volumes -Recurse`：11 个主账本均通过；
  6 种覆盖/审计 CSV 被明确识别为非账本而跳过。空必填字段、重复 ID 和未知
  表头的探针均被拒绝。
- Tectonic 0.15.0 对 9 个 `main.tex` 均退出 0。`vol03`、`vol04` 原有的
  分拆 `minipage` 信息框定义无法编译，已改为兼容的一参数 `tcolorbox`
  环境后复验通过。
- 事件锚点检查统计 `\eventanchor`、`\eventref` 与直接 `evt:` 链接；
  宏定义中的 `#1` 不计为事件。
- 发布路径由 `git -C <volume> rev-parse --show-toplevel` 解析为工作树根的
  `pdf/china-chronicle/`。9 个约定文件均存在；本轮没有覆盖它们、上传 Blob
  或把“文件存在”当作发布成功证据。

## 卷别结果与阻塞项

| 卷 | 账本 | 构建 | 事件锚点 | 未通过验收的直接原因 |
|---|---:|---|---|---|
| `vol01-zhou-qin` | 1,400（12 列） | 通过 | 1,452 锚点、541 引用、50 个重复 | 重复锚点：19 个在 `states/yan/northern-strategy.tex`，17 个在 `states/chu/wu-qi-and-southern-state.tex`，11 个在 `states/han/shen-buhai.tex`，另有 3 个涉及 `common/culture-thought.tex`；`PROGRESS.md` 仍列正文、专题和终稿为进行中。 |
| `vol02-han-division` | 1,705（10 列） | 通过 | 1,706 锚点、0 引用、无缺失/重复 | 本卷 `AGENTS.md` 仍将其定义为史料池阶段；6 个必需信息框环境均未定义，且 `PROGRESS.md` 列出大量待写事件簇。 |
| `vol02a-han` | 592（14 列） | 通过 | 8 锚点、8 引用、无缺失/重复 | 技术抽查通过，但 `PROGRESS.md` 明确只将 40 个正文事件链接串入连续叙事；未完成全卷蓝图验收。 |
| `vol02b-three-kingdoms` | 240（14 列） | 通过 | 19 锚点、12 引用、缺 1 个 | `EH-0220-HAN-ABDICATION` 被引用却没有锚点；修复前不接受。 |
| `vol02c-jin-northern-southern` | 876（14 列） | 通过 | 876 锚点、7 引用、无缺失/重复 | 技术抽查通过；本轮未完成根规范要求的内容、图件、索引、PDF 发布与 Blob 可访问性全项验收。 |
| `vol03-sui-tang-five` | 1,429（13 列） | 通过（修复后） | 1,405 锚点、10 引用、5 个重复 | 重复锚点分别在 `an-lushan-crisis`/`tang/event-anchors`、`five-dynasties-ten-kingdoms/event-anchors` 及其对应正文、`sui/ledger-depth-dossiers`/`tang/early-tang-foundation`；`PROGRESS.md` 仍列多个待写时期和材料空带。 |
| `vol04-song-yuan` | 529（13 列） | 通过（修复后） | 1,351 锚点、6 引用、6 个重复 | 每个重复均在一个 `event-anchor-batch.tex` 与相应 chronology/founding 文件之间；`PROGRESS.md` 显示辽、西夏、金、南宋、蒙古与元均待建账本或待写。 |
| `vol05-ming` | 1,462（19 列） | 通过 | 85 锚点、16 引用、无缺失/重复 | `PROGRESS.md` 的 177 条旧计数与现账本不一致，且仍列后续账本、正文、图件与索引工作；不得接受。 |
| `vol06-qing-1912` | 1,412（19 列） | 通过 | 14 锚点、14 引用、无缺失/重复 | `PROGRESS.md` 仍只列清初一个事件簇并要求补 1723--1912 年账本、正文、图件和索引；不得接受。 |

## 已发现的发布文件

`pdf/china-chronicle/` 中存在：
`vol01-zhou-qin.pdf`、`vol02-han-division.pdf`、`vol02a-han.pdf`、
`vol02b-three-kingdoms.pdf`、`vol02c-jin-northern-southern.pdf`、
`vol03-sui-tang-five.pdf`、`vol04-song-yuan.pdf`、`vol05-ming.pdf` 与
`vol06-qing-1912.pdf`。它们仅证明路径和命名存在；需在各卷通过验收后由
Integrator 重新构建、运行 `scripts/publish-downloads.ps1` 并验证直接 Blob
链接，才能记录为发布完成。
