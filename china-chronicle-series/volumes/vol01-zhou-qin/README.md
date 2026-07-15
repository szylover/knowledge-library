# 《中国大事编年·第一卷：周秦卷》

本卷是多 Agent 历史书系的第一卷，覆盖西周、春秋、战国与秦。阅读系列总规范：

- `../../SERIES_SPEC.md`
- `../../AGENTS.md`
- 本卷 `AGENTS.md`、`WORK_QUEUE.yaml` 与 `PROGRESS.md`

| 卷 | 范围 | 目标 |
|---|---|---|
| 第一卷 | 西周、春秋、战国、秦 | 封建网络、诸侯国家、变法竞争与统一帝国 |
| 第二卷 | 汉、三国、两晋、南北朝 | 帝国统治的调整、分裂与再统一 |
| 第三卷 | 隋、唐、五代 | 再统一、世界帝国、藩镇与财政转型 |
| 第四卷 | 宋、辽、夏、金、元 | 多政权、商业财政与征服帝国 |
| 第五卷 | 明 | 皇权、白银、边疆与晚期危机 |
| 第六卷 | 清至1912 | 征服王朝、近代冲击与帝国终结 |

```powershell
Set-Location D:\projects\knowledge-library\china-chronicle-series\volumes\vol01-zhou-qin
.\scripts\build-volume.ps1
```

发布版只在仓库根目录：

```text
pdf/china-chronicle/vol01-zhou-qin.pdf
```

## 多 Agent

```powershell
Set-Location D:\projects\knowledge-library\china-chronicle-series
.\scripts\new-agent-worktree.ps1 -TaskId vol01-ledger-western
```

每个 Agent 在独立 worktree/分支工作，先认领 `WORK_QUEUE.yaml` 中的任务，再修改其锁定文件范围。详情见系列和本卷 `AGENTS.md`。

## 条目标准

- 每个事件写明日期、地点、行动者、事件类型与年代可信度。
- 区分结构性原因、触发因素、直接后果、中期影响和长期遗产。
- 对存在争议的纪年或解释明确标注，避免把后世叙事当作同时代事实。
