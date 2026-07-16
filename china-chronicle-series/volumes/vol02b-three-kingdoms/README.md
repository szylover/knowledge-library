# 《中国大事编年·第二卷乙：三国》

这是一部可独立编译的 220—280 年三国史卷。它从汉魏禅代的军政接收
写到西晋灭吴，重点不是把三位皇帝排成并列年表，而是比较魏、蜀汉、
孙吴怎样把仓储、山道、江面、簿籍、继承和地方社会变成国家能力。

## 目录

- `data/event-ledger/three-kingdoms-220-280.csv`：从原第二卷账本按日期
  筛出的 240 条事件（包括两条 220 年的汉魏交接记录）。
- `data/source-corpus/three-kingdoms.md`：本卷的材料路径、使用边界和
  覆盖说明。
- `chapters/three-kingdoms/`：魏、蜀汉、孙吴的国家 dossier 及跨政权
  战争、社会和统一专题。
- `figures/three-kingdoms/`：独立维护的暖纸色 TikZ 示意图。

## 构建

在本目录运行：

```powershell
.\scripts\build-volume.ps1
```

脚本以 Tectonic 在 `.build/` 生成本地校验 PDF；该目录被忽略，出版 PDF
不属于本卷提交物。
