# 模形式与费马大定理

本仓库包含两本配套书籍：

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

## 目录结构

```
├── textbook/
│   ├── main.tex
│   ├── preamble.tex
│   ├── Makefile
│   ├── chapters/
│   │   ├── ch01/ … ch10/
│   │   └── app-a-algebra.tex, app-b-*, app-c-*
│   └── figures/
│       └── ch01-*.tex … ch10-*.tex
├── exercises-book/
│   ├── main.tex
│   ├── preamble.tex
│   ├── Makefile
│   └── problems/
│       ├── ch01-problems.tex … ch10-problems.tex
│       └── app-a-problems.tex
└── README.md
```

## 参考书目

1. Diamond & Shurman, *A First Course in Modular Forms*, GTM 228
2. Cornell, Silverman, Stevens (eds.), *Modular Forms and Fermat's Last Theorem*, 1997
