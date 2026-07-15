# Evidence Auditor Handoff Template

## Task identity and scope

- Task ID:
- Branch:
- Auditor:
- Owned files:
- Read-only ledger files:
- Source matrices and editions consulted:

## Passport records

| Ledger ID | Passport file or future CSV row | Evidence type | Source locator | Caveat summary |
|---|---|---|---|---|
| | | | | |

## Checklist

- [ ] The ledger’s existing ten columns and rows were not rewritten for this audit.
- [ ] Each passport `ledger_id` exactly matches an existing ledger `id`.
- [ ] Each populated passport has `evidence_type`, `source_locator`, and `source_caveat`.
- [ ] `evidence_type` describes material form rather than a universal reliability rank.
- [ ] Each locator identifies a retrievable chapter, document/slip/object number, plate, page, or archive identifier as applicable.
- [ ] Each caveat states what the material cannot independently establish, including relevant textual, provenance, regional, numerical, or interpretive limits.
- [ ] Conflicting witnesses, dates, readings, or modern interpretations remain visible rather than being silently harmonized.
- [ ] No passport is used to add an event not already present in the ledger or to authorize unsupported prose.
- [ ] `scripts\validate-event-ledger.ps1` passed for every audited ledger.

## Validation commands and results

```powershell
# Record the exact commands and concise PASS/FAIL output here.
```

## Handoff

- Modified files:
- Ledger IDs audited:
- Sources and edition/locator notes:
- Unresolved disputes or coverage gaps:
- Recommended next task:
