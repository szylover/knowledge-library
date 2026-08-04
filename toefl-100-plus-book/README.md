# 在职 24 周新版托福 100+ 学习全书

面向在职学习者的 2026 新版 TOEFL iBT 中文自学教材。全书采用中文讲解和英文原创练习，按每周 10–12 小时、共 24 周设计。

## 内容

- 入门诊断和 24 周执行路线
- 词汇、语法、发音基础
- 阅读、听力、写作、口语完整教程
- 阶段测验和两套原创压缩模考
- 答案解析、评分量表和错题复盘工具
- *Sapiens* 辅助阅读支线
- ChatGPT 口语陪练提示词与记录表

当前 PDF 为 161 页 A4 精编版：

- [下载 PDF](../pdf/toefl-100-plus-book.pdf)
- [阅读源稿](./book/00-使用说明与诊断.md)

## 使用边界

本书可替代 Delta 的大部分渐进训练用途，但不能完全替代 OG 或 ETS 官方样题。OG 和官方材料仍用于校准正式题型、难度、界面及评分标准。本书不保证仅凭完成页数即可取得 100+。

所有练习均为原创，不复制 OG、Delta、TPO、*Sapiens* 或考试回忆题原文。

## 编译

需要：

- Windows Pandoc
- WSL
- WSL 中的 XeLaTeX 和 `latexmk`
- Microsoft YaHei、DejaVu Serif/Sans 等字体

```powershell
.\scripts\build.ps1
```

成品输出到仓库根目录的 `pdf/toefl-100-plus-book.pdf`。
