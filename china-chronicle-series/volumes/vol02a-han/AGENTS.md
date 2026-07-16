# 第二卷《汉帝国》Agent 入口

先读 `../../SERIES_SPEC.md`、`../../AGENTS.md` 与
`data/source-corpus/han.md`。根规范是本卷的生产、角色、审阅、构建与发布
标准；本文件只定义汉帝国卷的例外。

## 范围与结构

- 范围为前206年至220年：西汉、新、东汉和汉魏禅代必须连读；秦末起事仅作
  开国条件，220年是本卷终点而非可省略的三国背景。
- 事件先入 `data/event-ledger/han.csv`。它由母账本筛出；正文只能扩写已有
  ID，全量导航留在 `chapters/appendices/appendix-ledger-navigation.tex`。
- 正文以 `western-han/`、`eastern-han/` 与 `synthesis/` 的事件簇和四项
  综合专题组织，不得逐条改写账本。

## 材料与争议

- 以《史记》《汉书》《后汉书》《后汉纪》《资治通鉴》维持年序；制度和
  边地问题结合《食货志》、盐铁材料、居延/肩水金关/悬泉置简牍与考古。
- 核验楚汉战争、汉匈战争和汉末战争的数字、路线与言辞；户口财政数字的
  口径；“羌”“匈奴”“鲜卑”等政治分类；王莽、东汉和曹魏禅代的仪式文本。

## 卷内交付

图件仅在 `figures/` 维护为 TikZ 示意图；事件名对读者使用中文。运行
`scripts/build-volume.ps1` 做临时验证；仅 Integrator 可用
`-KeepPublishedPdf` 发布 `vol02a-han.pdf`。
