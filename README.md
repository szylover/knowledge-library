# 中文数学与物理教材

以数学的严谨，讲物理的直觉。本仓库包含 6 本中文 LaTeX 教材，涵盖数学（线性代数、抽象代数、模形式）和物理（微积分物理学）。

所有 PDF 集中存放在 `pdf/` 目录，共 **1339 页**。

> 📥 **[点击这里下载全部 PDF](https://github.com/szylover/chinese-math-physics/releases/tag/v1.0)**（GitHub Release 资源下载）

---

## 🖥️ Claude Code 技术分析

### 深入剖析 Claude Code — `claude-code-book/`（17 章）

基于 2026-03-31 泄露源码的全面技术分析书籍。涵盖架构设计、QueryEngine 查询引擎、上下文处理与 System Prompt、工具系统 (40+ 工具)、权限安全模型、五层上下文压缩管线、多智能体协调、MCP 协议、React + Ink 终端 UI、Feature Flag 与条件编译等。

👉 [阅读全书](./claude-code-book/README.md)

---

## 🤖 AI Agent 转行指南

### 从零到一：AI Agent 工程师转行与面试完全指南 — `ai-agent-book/`（20 章）

面向传统软件工程师的 AI Agent 转行路线图。涵盖行业全景与岗位分析、LLM/Embedding/RAG 基础、Agent 架构模式（ReAct/Function Calling/多智能体）、MCP 与 A2A 通信协议、LangChain/OpenAI SDK 实战、框架横评与选型、工程化部署，以及 50+ 面试理论题精讲、6 个系统设计案例和编程实操题。附 30/60/90 天学习路线图。

👉 [阅读全书](./ai-agent-book/README.md)

---

## 📖 数学部分

### 线性代数 — `linear-algebra-book/`（241 页）

从矩阵运算到谱定理，覆盖线性代数核心内容。

### 抽象代数 — `abstract-algebra-book/`（174 页）

群论、环论、域扩张与 Galois 理论入门。

### 模形式教科书 — `modular-forms-textbook/`（315 页）

《模形式与费马大定理》——从 $\mathrm{SL}_2(\mathbb{Z})$ 到 Wiles 定理。10 章 + 3 附录，每个定理含完整证明。

### 模形式习题集 — `modular-forms-exercises/`（182 页）

配套练习册，300+ 道题，三级难度（★ / ★★ / ★★★），每题含完整解答。

---

## 🔭 物理部分

### 物理教科书 — `physics-textbook/`（270 页）

**《从牛顿到爱因斯坦：用微积分重新理解物理》**

用微积分和微分方程的语言重新构建力学、电磁学与狭义相对论。面向有高中物理基础、希望用严格数学框架理解物理的读者。

| 部分 | 章节 |
|------|------|
| 数学预备 | Ch1 微积分速览（含二阶 ODE、PDE 初步） |
| 力学 | Ch2 运动学 · Ch3 牛顿定律 · Ch4 动量 · Ch5 功与能 · Ch6 万有引力 · Ch7 振动与波 |
| 电磁学 | Ch8 静电学 · Ch9 电势与电容 · Ch10 电路 · Ch11 磁学 · Ch12 电磁感应 · Ch13 Maxwell 方程组 |
| 狭义相对论 | Ch14 狭义相对论 · Ch15 相对论动力学 |
| 分析力学与对称性 | Ch16 Lagrangian 力学 · Noether 定理 · Hamilton 力学 · Lie 群视角 |
| 附录 | A 矢量分析 · B 常用微分方程（含 PDE、Fourier 级数） · C 物理常数表 |

特色：
- 全书 30+ 幅 pgfplots 函数图像
- Noether 定理：用 Lie 群统一能量/动量/角动量守恒
- 数学严格但可读，非苏联教材风格

### 物理习题集 — `physics-exercises/`（157 页）

**《微积分物理习题集》**

14 章习题，按经典题 · 竞赛题 · 大学物理 · 微分方程四个层次编排，含 Python 数值解法。

---

## 🛠️ 编译

所有书籍使用 **LuaLaTeX** 编译（需要 TeX Live + CJK 字体支持）：

```bash
cd physics-textbook && lualatex main.tex && lualatex main.tex
```

编译好的 PDF 在 `pdf/` 目录：

| 文件 | 页数 |
|------|------|
| `linear-algebra-book.pdf` | 241 |
| `abstract-algebra-book.pdf` | 174 |
| `modular-forms-textbook.pdf` | 315 |
| `modular-forms-exercises.pdf` | 182 |
| `physics-textbook.pdf` | 270 |
| `physics-exercises.pdf` | 157 |
| **总计** | **1339** |

## 目录结构

```
├── ai-agent-book/             # 《AI Agent 转行与面试指南》(20章)
├── claude-code-book/          # 《深入剖析 Claude Code》技术书 (17章)
├── linear-algebra-book/       # 线性代数
├── abstract-algebra-book/     # 抽象代数
├── modular-forms-textbook/    # 模形式教科书
├── modular-forms-exercises/   # 模形式习题集
├── physics-textbook/          # 物理教科书（16章+3附录）
├── physics-exercises/         # 物理习题集（14章+3附录）
├── pdf/                       # 所有编译好的 PDF
└── README.md
```

## 参考书目

**数学：**
1. Diamond & Shurman, *A First Course in Modular Forms*, GTM 228
2. Cornell, Silverman, Stevens (eds.), *Modular Forms and Fermat's Last Theorem*, 1997
3. Artin, *Algebra*, Pearson
4. Lang, *Algebra*, GTM 211

**物理：**
5. Halliday, Resnick & Walker, *Fundamentals of Physics*
6. Griffiths, *Introduction to Electrodynamics*
7. Taylor, *Classical Mechanics*
8. Landau & Lifshitz, *Mechanics* (Course of Theoretical Physics, Vol. 1)
