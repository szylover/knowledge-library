# 证据护照（Evidence Passport）v1

证据护照为事件账本的**可选**证据层：它说明某项来源能支持什么、不能支持什么。它不替代 `core_sources`，不建立固定的来源等级，也不把后出的叙事、物证或现代解释自动当作同一种证据。

## 与现有账本的关系

现有账本继续使用原有十列，且无需迁移：

```text
id,date,polity,event,confidence,core_sources,modern_direction,cause,consequence,target
```

新审核的记录可在上述十列后追加下列三个字段，顺序固定：

```text
evidence_type,source_locator,source_caveat
```

三列出现时必须一同出现在表头；单行可以全部留空，以便同一文件中的既有记录继续有效。单行只要填写其中一项，就必须填写全部三项。需要记录多条彼此独立的证据时，使用多个 JSON 护照记录，而不是把不同材料层次混成一个笼统结论。

`scripts/validate-event-ledger.ps1` 接受原有十列，也接受这一追加形式；它不要求对现有 CSV 行作任何修改。

## 字段

| 字段 | 用途 | 要求 |
|---|---|---|
| `ledger_id` | 指向账本的稳定 `id` | 与目标账本事件 ID 完全一致。仅用于 JSON 护照；CSV 使用其既有 `id` 列。 |
| `evidence_type` | 说明材料的证据形态，不表示可信度排序 | 使用 schema 中的枚举值。一个材料可在不同问题上有不同的适用边界。 |
| `source_locator` | 让审核者能够重新找到材料 | 至少给出书名/报告、卷章、简号、器号、图版、页码或稳定档案号中的适用组合。 |
| `source_caveat` | 说明材料所能与所不能证明的内容 | 写明成书距离、编纂立场、传本、出土/释读、地域代表性、数字或动机等限制；不能留空。 |

允许的 `evidence_type` 值为：

- `annalistic_record`：保存日期、行动者或最小事件事实的编年记录；
- `narrative_text`：传世叙事、国别记忆或传记性文本；
- `retrospective_history`：后出综合史书或回顾性编纂；
- `official_or_administrative_document`：诏令、奏议、档案、簿籍或其他行政文书；
- `excavated_text_or_inscription`：简牍、铭文、碑刻、盟书等有文字的出土材料；
- `archaeological_context`：遗址、墓葬、城址、生产或区域调查等考古语境；
- `modern_research`：现代历史、考古、文本或制度研究。

## 文件

- `evidence-passport.schema.json`：单条 JSON 护照的机器可读定义。
- `example-evidence-passport.json`：不对应现有账本行的通用示例。

建议将实际护照作为独立 JSON 文件交付，并在任务交接中列出其 `ledger_id`。在来源矩阵 → 事件账本 → 正文的流程中，护照只使材料边界更可审查；它不授权在账本之外新增事实或在正文中抹去争议。

## 验证

```powershell
.\scripts\validate-event-ledger.ps1 `
  -Path volumes\vol01-zhou-qin\data\event-ledger\spring-autumn.csv,
        volumes\vol02-han-division\data\event-ledger\han-division.csv
```

验证器检查表头、必填的十个账本字段、重复 ID，以及已填写的护照三元组。它只检查结构和受控字段值，不能代替对原始材料、版本、释读或论证的人工核验。
