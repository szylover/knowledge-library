# 模形式与费马大定理

本仓库包含三本配套书籍：

## 📚 textbook/ — 主教材

《模形式与费马大定理》——从 $\mathrm{SL}_2(\mathbb{Z})$ 到 Wiles 定理

- 10章 + 3个附录，约315页
- 每个定理含完整证明，每节有 TikZ 图
- 基于 Diamond & Shurman GTM 228 与 Cornell-Silverman-Stevens 1997

**编译：**
```bash
cd textbook && make
```

## 📝 exercises-book/ — 习题集

《模形式与费马大定理习题集》——配套练习册

- 10章 + 附录A习题，共 300+ 道题
- 三级难度（基础★ / 进阶★★ / 挑战★★★）
- 每题含完整解答

**编译：**
```bash
cd exercises-book && make
```

## 📐 algebra-book/ — 代数基础（新）

《模形式的代数基础》——从矩阵到 Galois 理论

- 12章 + 2个附录，约 750+ 道习题
- 覆盖线性代数（5章）、群论（3章）、环/模/域（4章）
- 三级难度（基础★ / 进阶★★ / 挑战★★★）
- 每章带星号小节关联模形式教材中的具体应用

**章节概览：**

| 部分 | 章节 | 习题数 |
|------|------|--------|
| 线性代数 | Ch1 矩阵与行列式 | 60 |
| | Ch2 线性空间 | 60 |
| | Ch3 线性映射 | 65 |
| | Ch4 特征值与对角化 | 70 |
| | Ch5 内积空间与谱定理 | 60 |
| 群论 | Ch6 群的基本理论 | 70 |
| | Ch7 矩阵群与群作用 | 65 |
| | Ch8 表示论入门 | 60 |
| 环、模与域 | Ch9 环与理想 | 65 |
| | Ch10 模论 | 55 |
| | Ch11 域扩张 | 55 |
| | Ch12 Galois 理论初步 | 60 |
| 附录 | A 范畴语言初步 | 20 |
| | B 常用符号与记号表 | — |

**编译：**
```bash
cd algebra-book && make
```

## 目录结构

```
├── textbook/          # 主教材（10章+3附录）
├── exercises-book/    # 习题集（300+题）
├── algebra-book/      # 代数基础（12章+2附录，750+题）
│   ├── main.tex
│   ├── preamble.tex
│   ├── Makefile
│   └── chapters/
│       ├── ch01-matrices.tex … ch12-galois.tex
│       ├── app-a-categories.tex
│       └── app-b-notation.tex
└── README.md
```

## 参考书目

1. Diamond & Shurman, *A First Course in Modular Forms*, GTM 228
2. Cornell, Silverman, Stevens (eds.), *Modular Forms and Fermat's Last Theorem*, 1997
3. Artin, *Algebra*, Pearson（线性代数与抽象代数经典参考）
4. Lang, *Algebra*, GTM 211（研究生代数全面参考）
