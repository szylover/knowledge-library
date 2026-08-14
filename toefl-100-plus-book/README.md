# 在职 24 周新版托福 100+ 学习全书

面向在职学习者的 2026 新版 TOEFL iBT 中文自学教材。全书采用中文讲解和英文原创练习，按每周 6–6.5 小时设计：工作日 5 天各 45–75 分钟，周末不排托福任务、只保持墨墨背词。24 周的内容在这一强度下实际约需 36–40 周。

## 内容

- 入门诊断和 24 周执行路线
- 词汇、语法、发音基础
- 阅读、听力、写作、口语完整教程
- 阶段测验和两套原创压缩模考
- 答案解析、评分量表和错题复盘工具
- *Sapiens* 辅助阅读支线
- ChatGPT 口语陪练提示词与记录表

当前 PDF 成品（均为 A4）：

- [主教材：792 页](../pdf/toefl-100-plus-book.pdf)
- [可打印训练附册：98 页](../pdf/toefl-100-plus-printables.pdf)
- [完整合并版：888 页](../pdf/toefl-100-plus-complete.pdf)
- [阅读源稿](./book/00-使用说明与诊断.md)

## 使用边界

本书不是 ETS 官方材料，不能完全替代 OG、ETS 当期 Test Specifications 或官方样题；它们仍用于核对正式题型、难度、界面和评分说明。Delta 仅可作为可选训练补充：本书不依赖、不复制、也不冒充 Delta。本书不保证完成页数或训练任务即可取得旧分制 100+、新版约 5 分档或任何录取结果。

所有练习均为原创，不复制 OG、Delta、TPO、*Sapiens*、真题、机经或考试回忆题原文；*Sapiens* 只作为读者合法取得的辅助阅读，非考试材料。

## 编译

需要：

- Windows Pandoc
- WSL
- WSL 中的 XeLaTeX 和 `latexmk`
- Microsoft YaHei、DejaVu Serif/Sans 等字体

```powershell
.\scripts\build.ps1
```

成品输出到仓库根目录的 `pdf/`：主教材、可打印训练附册和完整合并版各一份。
