# 多邻国 Android 面试通关手册

一本按 **Duolingo 官方真实面试轮次**组织的中文备战手册，面向 **Android / Kotlin 工程师**岗位。

与本仓库的《Airbnb 面试通关手册》采用同一套排版体系，但内容取向完全不同：Airbnb 那本重「算法 + 后端系统设计」，本书重 **「查错（Code Review）+ Android 架构设计」**——因为这正是 Duolingo 面试与 FAANG 最不一样的两轮。

## 为什么结构长这样

Duolingo 官方公布的工程面试轮次（`blog.duolingo.com/interviewing-with-duolingos-engineering-team/`）：

| 轮次 | 平台 | 时长 | Android 岗语言 |
|------|------|------|----------------|
| Recruiter Screen | Zoom | 60 min | — |
| Technical Video Interview（算法） | CodeSignal / CoderPad | 60 min | Kotlin |
| **Pair Programming（结对编程）** | VS Code + Live Share | **75 min** | Kotlin |
| **Code Review（查错）** | CodeSignal | 60 min | Kotlin（Android 专属版本） |
| **Design Interview** | 白板 / 文档 | 60 min | **Android 架构设计**（非后端 System Design） |
| Behavioral / Values | Zoom | 60 min | — |

两个容易踩空的认知差：

1. **Code Review 是独立一轮**，不是走过场。Android 岗有专属的 Kotlin 版本，考的是协程 scope、生命周期泄漏、StateFlow 暴露、Compose 副作用这些**平台反模式**。
2. **Android 岗的 Design 轮不是画后端分布式架构图**，而是客户端架构：本地存储选型、离线同步、乐观更新与回滚、状态管理、边界情况。

## 内容结构

- **第一部分 · 面试全景**：官方轮次表、各轮权重、Duolingo Android 技术底座（100% Kotlin、Android Reboot 后的 MVVM + Hilt、Server-Driven UI、Frontend Prediction）、12 条 Operating Principles、级别差异。
- **第二部分 · 编码轮**：Kotlin 惯用写法心法 + 已报告算法题精解；75 分钟结对编程轮的完整打法。
- **第三部分 · 查错轮（本书重点一）**：Code Review 方法论与七类 Checklist + **17 道查错题**（协程并发 6 题、生命周期与列表 6 题、Compose / 空安全 / 惯用性 5 题）。
- **第四部分 · 设计轮（本书重点二）**：Android 架构设计六步框架 + **9 道设计题精讲**（离线同步、Streak、排行榜 XP 预测、A/B 实验 SDK、SDUI、资产缓存、推送、间隔重复、全局状态重构）。
- **第五部分 · 项目、行为面与冲刺**：项目深挖题库、12 条价值观对应的 STAR 故事、两周冲刺计划。

## 排版特色

沿用五种彩框承载主线：

| 框 | 含义 |
|----|------|
| 💡 设计思想 | 这道题真正考的可迁移心法 |
| ⚠ 常见陷阱 | 最容易写错 / 漏掉的边界 |
| ↪ 面试官追问 | 现场常见的 follow-up 与应答 |
| ✓ 要点 | 复杂度与速记结论 |
| 🗣 话术 | Code Review / 设计轮中「该怎么说出口」 |

查错题的代码采用双色区分：**红框 = 带 bug 的原始代码**，**绿框 = 修正后的代码**。

## 信息可靠性标记

面经类内容最大的风险是把「网上流传」当「确认真题」。本书对每条信息标注来源等级：

- **[官方]** —— Duolingo 官方博客 / 官网 / Google Android 官方合作案例
- **[面经报告]** —— 候选人社区报告（Glassdoor、interviewing.io、一亩三分地等）
- **[高置信推断]** —— 基于 Duolingo 官方技术文章推断的高概率考点，**无直接候选人报告**

## 遮蔽版习题册

查错题和设计题在正文里与答案同页。顺着读会让人以为自己掌握了，但那是**再认**，
面试考的是**回忆**——看到 bug 认得出来，和面对一段陌生代码自己报出五条并排好序，
完全是两件事。

```bash
make drills       # -> drills.pdf，35 页
```

`make-drills.mjs` 从正文抽出 17 道查错题与 9 道设计题的**题面**（场景 + 有 bug 的代码 /
题面与常见变体），剥掉 findings、修复代码、话术和追问，每题后面留下限时与答题要求。
做完再回正文对答案，两者的差集就是要补的东西。

脚本会断言抽出 17 + 9 题，数量不对直接报错——一本悄悄少了几题的习题册比没有更糟。
`drills.tex` 与 `drills.pdf` 都是生成物，已在 `.gitignore` 中，不要手改。

## 构建

```bash
# WSL / Linux（推荐）
make              # 两遍 xelatex
make drills       # 遮蔽版习题册
# 或
make tectonic     # 用 tectonic，无需本地 texlive
```

等宽字体使用 **DejaVu Sans Mono**，需预先安装到系统字体。

产物：`main.pdf`（正文）、`drills.pdf`（习题册）。
