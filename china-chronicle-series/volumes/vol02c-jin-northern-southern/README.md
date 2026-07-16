# 《中国大事编年·第二卷丙：两晋与南北朝（280—589）》

本卷从西晋灭吴写到隋灭陈。它以 876 条可审查事件为编年骨架，同时追踪南渡和侨置、十六国的多政权空间、北魏的军镇与改革、南朝州镇、佛道网络、草原与西域边境，以及北周、隋如何重新接合道路、户籍、仓储和军队。

## 独立结构

- `data/event-ledger/jin-northern-southern.csv`：从第二卷 1,705 条总账本筛出的 876 条（280—589）事件；目标文件已改写为本卷章节 wrapper。
- `data/source-corpus/jin-northern-southern.md`：本卷的来源矩阵、交叉使用原则与材料缺口。
- `chapters/`：连续叙事；批量事件锚点文件不被当作主体正文。
- `figures/`：自绘 TikZ 约略示意图；不主张精确疆界。
- `appendices/`：来源、争议、跳转索引和书系路线图。

## 构建

```powershell
Set-Location D:\projects\knowledge-library\china-chronicle-series\volumes\vol02c-jin-northern-southern
.\scripts\build-volume.ps1
```

构建产物仅保存在被 Git 忽略的 `.build/`。本任务不发布、也不提交 PDF。
