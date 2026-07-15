# 《中国大事编年》多卷书系

这是一个可由多个 Agent 并行生产、由总编整合发布的中国史书系。

## 开始位置

1. 阅读 `SERIES_SPEC.md`：全系列内容、史料、文学与地图规范。
2. 阅读 `AGENTS.md`：协作、分支、worktree 和发布规则。
3. 查看 `WORK_QUEUE.yaml`：可认领任务。
4. 进入目标卷阅读卷内 `AGENTS.md` 和 `WORK_QUEUE.yaml`。

## 卷目录

| 目录 | 书名 | 状态 |
|---|---|---|
| `volumes/vol01-zhou-qin/` | 第一卷《周秦卷》 | 正在扩写 |
| `volumes/vol02-han-division/` | 第二卷《汉魏晋南北朝卷》 | 先建史料池 |
| `volumes/vol03-sui-tang-five/` | 第三卷《隋唐五代卷》 | 待启动 |
| `volumes/vol04-song-yuan/` | 第四卷《宋辽夏金元卷》 | 待启动 |
| `volumes/vol05-ming/` | 第五卷《明卷》 | 待启动 |
| `volumes/vol06-qing-1912/` | 第六卷《清至1912卷》 | 待启动 |

## 创建 Agent worktree

```powershell
Set-Location D:\projects\knowledge-library\china-chronicle-series
.\scripts\new-agent-worktree.ps1 -TaskId vol01-ledger-western
```

这会创建 `.chronicle-worktrees/<task-id>` 与 `chronicle/<task-id>` 分支。Agent 只能修改任务锁定的文件；总编 Agent 审查、编译和合并。

## 查看并行进度

在系列根目录运行：

```

每次更新上述目录后，同步到 Azure Blob Storage 账户 `zyshaobook` 的 `$web` 静态网站容器：

```powershell
Set-Location D:\projects\knowledge-library
az storage blob upload-batch `
  --account-name zyshaobook `
  --auth-mode key `
  --destination '$web' `
  --source pdf\china-chronicle `
  --overwrite
```

Blob 端点：<https://zyshaobook.blob.core.windows.net/>；发布站点：<https://zyshaobook.z7.web.core.windows.net/>。powershell
.\scripts\show-parallel-status.ps1
```

看板会列出每个活跃 worktree 的任务、分支、队列状态、未提交文件数、增删行数与最后提交。持续刷新使用：

```powershell
.\scripts\show-parallel-status.ps1 -Watch -RefreshSeconds 10
```

## 发布约定

本书系的发布 PDF 永远放在仓库根 `pdf/china-chronicle/`：

```text
pdf/china-chronicle/vol01-zhou-qin.pdf
pdf/china-chronicle/vol02-han-division.pdf
...
```
