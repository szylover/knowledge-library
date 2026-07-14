# 中国编年因果史：周至清末

一部以可靠纪年事件为骨架、以因果关系为线索的中国史书稿。`main.tex`
只负责编排；每个时期各有独立章节文件，大时期再拆为事件簇子文件。

```powershell
Set-Location D:\projects\knowledge-library\china-chronicle-book
D:\projects\tools\tectonic\tectonic.exe -X compile main.tex
Copy-Item main.pdf ..\pdf\china-chronicle-book.pdf -Force
```

## 条目标准

- 每个事件写明日期、地点、行动者、事件类型与年代可信度。
- 区分结构性原因、触发因素、直接后果、中期影响和长期遗产。
- 对存在争议的纪年或解释明确标注，避免把后世叙事当作同时代事实。
