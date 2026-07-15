# 跨卷历史问题线索

`..\series-threads.yaml` 是读者导航和 Continuity Editor 的共享问题表，不是另一份年表、因果图或事件账本。它把可重复追问的问题固定下来，让每卷保有自己的时间、政权和材料节奏。

## 线索的边界

- 线索不是历史主体；不能写成“国家”“边疆”或“迁徙”自行造成了某件事。
- 线索中的相邻节点默认只具有时间顺序或比较价值。只有材料明确支持时才使用 `structural_condition`、`enabling_condition`、`documented_consequence` 或 `feedback_loop`。
- `comparison` 是默认的跨卷关系：它提出同一问题，不主张继承、影响或同一制度。
- 每项 connection 都必须有账本中的精确 `event_id` 和一个已存在的 `chapter_path`。`path_basis: prose_contains_event` 表示该事件已在此正文出现，而账本的 `target` 不必被本文件改写。
- connection 不能替代该卷的来源矩阵、账本 `source_caveat` 或独立 evidence passport；不因进入线索而新增事实或提高证据等级。

## 为新卷附接线索

1. 先在该卷 `data\source-corpus\` 确定材料、版本、语言、日期与争议，再确认事件已在 `data\event-ledger\` 中。
2. 用账本的完整 `id`，并以 PowerShell 确认它唯一；再确认 `chapter_path` 是仓库内已有文件。不要引用计划中的正文、PDF 或临时构建产物。
3. 选择 `relation_vocabulary` 中最弱而准确的词。若只是可比，使用 `comparison`；若材料冲突，使用 `contested` 并写出冲突，不用强因果词填补空白。
4. 在对应 thread 的 `initial_connections` 后添加一项，说明它回答的问题和不能据此推出的内容。不要把多个来源、政权或数十年压成一条无来源的“长线”。
5. 若材料需要额外审查，为同一账本 ID 建立独立 evidence passport；护照只记录材料边界，不授权把关系升级为因果。

```yaml
- volume: volNN-example
  ledger_file: 'volumes\volNN-example\data\event-ledger\period.csv'
  event_id: EX-0000-NODE
  chapter_path: 'volumes\volNN-example\chapters\period\cluster.tex'
  path_basis: ledger_target
  relation: comparison
  connection_note: '说明这个节点怎样进入问题，以及它不能证明什么。'
```

`path_basis` 只能是：

- `ledger_target`：账本 `target` 直接指向该现有正文；
- `prose_contains_event`：现有正文已写到该账本事件，但账本 `target` 仍指向别处。记录这一事实，不在本任务中改账本。

## 审核顺序

Continuity Editor 应先使用 `tasks\CONTINUITY_EDITOR_HANDOFF_TEMPLATE.md` 记录新增或移除的连接，再检查：

1. ID 精确存在且只出现一次；
2. 路径存在，且 `path_basis` 的说明可由账本或正文核对；
3. 每个关系词符合其 `not_a_claim` 限制；
4. 资料的成书距离、文体、地区与数字限制没有被跨卷叙述抹去；
5. 空白仍保持为空白。尚无合格事件时，写明 coverage gap，不以相近名词代替。

不要为“每卷都有一条线”而强行配对。一个明确标出的缺口比一条伪造的因果线更有用。
