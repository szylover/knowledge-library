# Checklist 07 — RAG Checklist

> 适用于上线前，或对 RAG pipeline 做实质性变更之前：新增 source、调整 chunking、切换 embedding model、重建 index、引入 hybrid search / rerank。目标不是“能答出来”，而是“可解释、可回滚、可稳定演进”。

---

## 使用方式

| 标记 | 含义 | 处理原则 |
|---|---|---|
| **P0** | 上线阻断项 | 未满足不要发布；优先修 ACL、证据链、索引一致性、关键监控。 |
| **P1** | 高风险项 | 可以灰度，但要有 dashboard、告警、回滚和 owner。 |
| **P2** | 优化项 | 不阻断发布，但应进入 backlog，并约定复查时间。 |

评审这份清单时，不要接受“demo 看起来还行”。
至少要落到四类证据中的两类以上：离线 eval、线上 trace、配置 diff、故障演练记录。
如果一次变更同时触发 source、chunking、embedding、index 四类变更，不要合并发布。
优先拆成可归因的阶段，否则上线后很难判断退化来自哪一层。
RAG 的评审重点不是“模型是否聪明”，而是“检索链路是否把正确证据以正确权限、正确版本送进模型”。

## 数据源治理与 ACL

- [ ] **[P0] 数据源有 freshness SLO，而不是“按感觉同步”**：RAG 的第一失效模式不是模型变差，而是索引回答了过期事实。
  - 怎么验证：为每个 source 定义 `max_ingest_lag`，抽样查看最近 24 小时新增/更新文档的 `source_updated_at` 与 `indexed_at` 差值分布，并对超阈值告警。

- [ ] **[P0] ACL metadata 在 ingestion 时写入 chunk，并在 retrieval 时做 filter**：权限不能靠生成后再删句子；必须在召回前就阻断越权 chunk 进入候选集。
  - 怎么验证：检查索引 schema 中是否存在 `tenant_id`、`doc_acl`、`visibility_scope` 等字段；构造跨租户 query，确认向量召回请求自带 filter，而不是结果返回后再 post-filter。

- [ ] **[P0] 去重策略区分 exact duplicate 与 near-duplicate**：同一文档多副本会污染 top-k，让模型误以为“多份证据”支持同一错误。
  - 怎么验证：检查是否同时有 canonical hash 与 near-dup 指纹（如 SimHash / MinHash）；在热门文档集上统计重复 chunk 占比与 top-k 中同源重复率。

- [ ] **[P1] 每个 chunk 都能追溯到稳定 source identity**：没有稳定 `document_id` / `source_version`，就无法做增量更新、删除传播与 citation 绑定。
  - 怎么验证：抽样查看 chunk metadata，确认至少包含 `source_system`、`document_id`、`source_version`、`source_uri`、`source_updated_at`。

- [ ] **[P1] 删除、撤权、归档能传播到 index**：RAG 对“新增内容晚到”通常可容忍，但对“该删未删、该禁未禁”通常不可容忍。
  - 怎么验证：选择一篇已下线或已撤权文档，执行 tombstone / revoke 流程，确认其 chunk 在检索侧不可见，且缓存、rerank、answer trace 不再引用它。

## 解析质量与结构保真

- [ ] **[P0] 解析器按内容类型分流，而不是一个 parser 处理所有 source**：PDF、HTML、Confluence、Excel、代码仓库的结构信号不同，统一处理通常会丢布局。
  - 怎么验证：列出 source type 到 parser 的路由表；抽样查看每类文档的解析输出，确认没有把表格、标题层级、代码块全部降成纯文本。

- [ ] **[P0] 标题、列表、表格、代码块被保留下来**：很多“检索不到”其实不是 embedding 不行，而是 parser 在 ingestion 时已经把语义边界打碎。
  - 怎么验证：对带多级标题和表格的样本文档做人审，对比原文与解析结果，确认 heading level、table row/column、list item、code fence 仍可识别。

- [ ] **[P1] PDF / 扫描件有 OCR 置信度与 layout loss 标记**：低质量 OCR 文本进入统一索引，会显著拉低召回精度但在 dashboard 上不明显。
  - 怎么验证：检查解析输出是否记录 `ocr_confidence`、`layout_loss_score` 或类似字段；对低置信度文档设单独质检队列或降权策略。

- [ ] **[P1] 解析结果保留定位锚点**：没有 page / section / span anchor，就无法做精确 citation，也无法把错误追到解析阶段。
  - 怎么验证：抽样查看 chunk metadata，确认存在 `page_no`、`section_path`、`char_start/end`、`block_id` 中至少一组定位信息。

- [ ] **[P2] 对高价值 source 建立 parse QA 样本集**：parser 升级最容易“看起来没问题，局部严重退化”，需要固定样本做回归。
  - 怎么验证：准备包含 PDF 表格、双栏版式、嵌套列表、代码块的 golden docs；每次 parser 版本升级后对比结构保真率与人工 spot check 结果。

## 切分策略（Chunking）

- [ ] **[P0] chunk size / overlap 按内容类型调参，而不是一刀切**：FAQ、规范文档、财务表、代码注释的最优粒度不同，统一 500 字符通常既伤 recall 又伤 precision。
  - 怎么验证：按 source type 维护 chunking policy；在标注集上比较不同策略的 recall@k、context token 成本与 grounded answer rate。

- [ ] **[P0] chunk 边界尊重语义单元**：按固定字符数硬切会把标题和表格拆散，模型拿到的是“半句事实”而不是可用证据。
  - 怎么验证：抽样查看 chunk，确认不会在 header 下第一段之前截断，不会把一张表拆成多段孤立文本，不会把代码块切到语法不完整。

- [ ] **[P1] 长文档采用 parent-child 或 multi-granularity retrieval**：只存小 chunk 容易丢上下文，只存大 chunk 会浪费 token；工程上通常需要两级粒度。
  - 怎么验证：检查索引中是否同时存在 child chunk 与 parent section / document pointer；查看 query trace，确认召回后可向上聚合上下文。

- [ ] **[P1] chunk metadata 足够支撑过滤、排序和解释**：没有标题、章节路径、时间、来源等信息，后续 hybrid search 和 citation 都会变脆。
  - 怎么验证：确认 chunk 至少带 `title`、`section_path`、`language`、`source_updated_at`、`acl_scope`、`doc_id`、`chunk_id`。

- [ ] **[P2] chunking 变更必须走 side-by-side eval**：切分策略不是“离线看起来更整齐”就能上线，它直接改变索引分布和 ANN 邻域。
  - 怎么验证：同一批 query 同时跑 old/new chunking，比较 recall@k、precision@k、rerank 后命中率、平均上下文 token 与空检索率。

## Embedding 与向量索引

- [ ] **[P0] index-time 与 query-time 的 embedding model / version 被显式标记并校验**：最常见的隐蔽故障之一，是索引仍是旧模型向量，query 已切到新模型。
  - 怎么验证：检查索引 metadata 与在线服务配置是否都暴露 `embedding_model`、`embedding_version`、`dimension`；人为制造 mismatch，确认会触发告警或拒绝查询。

- [ ] **[P0] 文本预处理在索引侧与查询侧一致**：大小写、unicode normalize、分词前清洗不一致，会让“同一句话”映射到不同向量空间。
  - 怎么验证：对同一输入分别走 ingest pipeline 与 query pipeline，比对 normalize 后文本、token 计数和 embedding 请求 payload。

- [ ] **[P1] ANN 参数按 recall-latency benchmark 调优**：`ef_search`、`nprobe`、`search_k` 之类参数决定的是召回-延迟曲线，不是越大越好。
  - 怎么验证：准备 exact KNN 或高精度 baseline，在固定 query 集上扫描不同 ANN 参数，出 recall@k、p95 latency、CPU / memory 曲线。

- [ ] **[P1] index rebuild 有双写、回填和切换策略**：embedding 维度变化、距离函数变化、schema 变更时，直接原地覆盖往往不可回滚。
  - 怎么验证：检查是否支持 blue/green index、dual-write、回填完成率检查和别名切换；演练失败回滚，确认能切回旧 index。

- [ ] **[P2] 保留一条 exact / brute-force 小样本基线**：没有高精度参考，就很难知道问题出在 embedding、本体数据，还是 ANN 配置。
  - 怎么验证：为抽样子集维护 exact 检索结果，对比线上 ANN top-k；当 recall 下滑时先看 baseline 是否同步下滑。

## 混合检索与 Rerank

- [ ] **[P0] 默认评估 BM25 + vector，而不是只押注单路召回**：纯向量对语义相似有效，但对错误码、SKU、函数名、法规条款号通常不稳。
  - 怎么验证：在包含 ID、缩写、专有名词、长尾实体的 query 集上，对比 BM25、vector、hybrid 三路的 recall@k 与 precision@k。

- [ ] **[P1] hybrid 权重按领域调参**：法律文本、产品文档、工单知识库的词法信号密度不同，固定线性权重通常不是最优。
  - 怎么验证：为不同 query class 记录最优融合参数，比较 RRF、线性融合、分段策略的离线指标与在线点击/采纳率。

- [ ] **[P1] metadata filter 发生在 candidate generation 之前**：先全库召回再按时间、语言、租户筛掉，既浪费资源，也会让真实可见候选不足。
  - 怎么验证：查看检索请求链路，确认 filter 下推到向量库 / 搜索引擎；统计 filter 前后 candidate 数量，避免 post-filter 后 top-k 被打空。

- [ ] **[P1] rerank 要证明有 top-k 重排收益，而不是“大家都在用”**：cross-encoder / LLM rerank 会引入明显延迟和成本，必须证明值得。
  - 怎么验证：在同一候选集上比较 rerank 前后的 MRR、nDCG、top-3 命中率，并记录新增 p95 latency、token / GPU 成本。

- [ ] **[P2] query rewrite / decomposition 是显式、可观测的步骤**：自动改写 query 可能提升召回，也可能悄悄改掉用户意图。
  - 怎么验证：在 trace 中记录原 query、rewritten query、触发原因和效果；抽样检查改写是否引入实体漂移、时间范围漂移或权限范围漂移。

## 引用、归因与可溯源性

- [ ] **[P0] citation 绑定真实检索到的 chunk_id，而不是模型自由生成 source 名称**：看起来像引用，不等于真的可追溯。
  - 怎么验证：检查 answer schema，确认引用字段来自 retrieval context 中的 `chunk_id` / `doc_id` 白名单；构造虚假文档名提示，确认模型不能凭空产出 citation。

- [ ] **[P0] 每条引用都能反查到精确锚点**：引用“某文档”但找不到具体页码/小节，用户无法自行核实，也无法做审计。
  - 怎么验证：从线上样本中随机抽取答案，逐条点击 citation，确认能定位到 page、section 或 span，而不是只跳到文档首页。

- [ ] **[P1] answer trace 保存完整检索证据链**：没有证据链，就无法区分“没召回到”与“召回到了但模型没用”。
  - 怎么验证：检查 trace 是否记录原 query、filters、top-k 候选、rerank 后顺序、送入 prompt 的 chunk 列表、最终引用列表。

- [ ] **[P1] 无足够证据时，UI 和 API 会显式降级**：citation 缺失时仍输出肯定句，是许多“看起来很专业”的错误答案来源。
  - 怎么验证：构造空检索、低分检索、证据冲突三类 case，确认系统返回“不足以回答/请缩小范围/列出可用来源”，而不是伪造来源。

- [ ] **[P2] 引用渲染尊重 ACL 与原文展示边界**：检索系统可能有权看到摘要，但前端不一定有权展示原文全文。
  - 怎么验证：检查 citation 展示接口是否再次做 ACL 校验，并限制 snippet 长度；对受限文档确认不会在引用 hover 中泄露敏感内容。

## 忠实度与幻觉抑制

- [ ] **[P0] 对“没有证据”与“证据冲突”定义 abstain 策略**：RAG 的目标不是把每个问题都答满，而是在证据不足时可靠拒答。
  - 怎么验证：定义最低证据门槛（如 top-1 分数、top-k 覆盖、来源数、一致性规则），在无答案样本上测拒答率与误答率。

- [ ] **[P0] 生成后做 claim-to-evidence 检查**：即使检索命中了相关 chunk，模型也可能把事实拼错、扩写过头或跨段误归因。
  - 怎么验证：对输出中的句子级 claim 做 entailment / contradiction 检查，或基于规则抽取数字、日期、实体后与引用 chunk 对齐比对。

- [ ] **[P1] 数字、日期、版本号、阈值等高风险字段有额外校验**：这类信息最容易被“语义上差不多”的 chunk 污染。
  - 怎么验证：对包含金额、日期、SLA、版本号的评测集单独出准确率；若业务允许，要求模型直接复制原文 span 而不是自由改写。

- [ ] **[P1] prompt 明确区分“引用事实”与“综合判断”**：当答案既包含 source 中的事实，又包含模型的总结时，边界不清最容易误导用户。
  - 怎么验证：检查输出 schema 或模板，确认事实陈述带 citation，综合建议单独成段并标记为基于已检索证据的推断。

- [ ] **[P2] 针对 prompt injection 与 irrelevant context 做鲁棒性测试**：检索到的文本本身也可能包含“忽略上文”“改答为 X”之类恶意指令。
  - 怎么验证：把注入片段混入知识库或候选集，确认模型不会把它当系统指令执行，且会优先依据检索协议而非文档中的元指令。

## 检索质量评测

- [ ] **[P0] 有按任务类型分层的标注 query 集**：只拿“问得很像 demo 的问题”做评测，会高估真实线上表现。
  - 怎么验证：评测集至少覆盖 fact lookup、比较问答、时间敏感问题、ID lookup、无答案问题、多跳问题，并标注期望证据。

- [ ] **[P0] 指标同时看 recall@k、precision@k 与 groundedness**：只看最终答案好坏，无法定位问题在召回、重排还是生成。
  - 怎么验证：离线报告按阶段输出 `recall@k`、`precision@k`、MRR / nDCG、grounded answer rate、unsupported-claim rate。

- [ ] **[P1] 有 hard negative、近义文档与同名实体样本**：RAG 线上事故往往不是“完全没找到”，而是“找到了很像但不对的东西”。
  - 怎么验证：在评测集中加入版本接近、部门不同、时间过期、实体同名的对抗样本，单独统计误召回率。

- [ ] **[P1] 指标按 source / tenant / query class 切片**：总体平均数经常掩盖局部灾难，尤其是新接入 source 或小租户。
  - 怎么验证：dashboard 可按 source、语言、租户、内容类型、是否带 filter、是否 time-sensitive 过滤；检查是否存在局部极差但整体均值正常的情况。

- [ ] **[P2] 线上变更采用 interleaving / A/B，而不是只靠离线结论**：retrieval 质量受真实 query 分布影响很大，离线集不可能完全覆盖。
  - 怎么验证：对 chunking、embedding、hybrid 权重、rerank 变更运行在线实验，比较采纳率、二次追问率、空检索率与人工复核结果。

## 运维与索引生命周期

- [ ] **[P0] 监控 empty-retrieval rate 与 low-score rate**：空检索率和低相似度率通常是索引陈旧、解析退化、filter 错配的领先指标。
  - 怎么验证：为每类 query 记录 top-k 为空占比、top-1 分数低于阈值占比、post-filter 后候选不足占比，并设置基线告警。

- [ ] **[P0] re-index pipeline 是幂等的，并支持断点续跑**：大规模回填总会中断；非幂等流程会制造重复 chunk、脏版本和难以解释的召回抖动。
  - 怎么验证：对同一批 source 重复运行 ingestion，确认 `doc_id + source_version + chunk_id` 不重复；中途失败后重跑不会产生双份数据。

- [ ] **[P1] index staleness 有 dashboard，不靠人工猜**：知道“同步任务成功”不等于知道“线上正在回答多旧的数据”。
  - 怎么验证：展示 `now - newest_indexed_at`、`now - median_source_updated_at_in_index`、各 source backlog 深度，并与 freshness SLO 关联告警。

- [ ] **[P1] rebuild / rollback 有 runbook 和演练记录**：向量库 schema、embedding model、parser 变更都可能要求全量重建，事到临头再写脚本通常来不及。
  - 怎么验证：检查是否存在回滚步骤、别名切换步骤、容量预估、回填顺序、失败判定标准；至少演练过一次切换与回退。

- [ ] **[P2] 监控 source skew、热门文档垄断与容量膨胀**：索引不只会“坏掉”，也会慢慢劣化成只会返回少数热门 source。
  - 怎么验证：统计 top-k 来源分布、重复文档命中率、平均 chunk 数增长、存储占用与 compaction 周期，发现异常时回看 dedup 与 ranking 配置。

## 评审输出物

- [ ] **发布清单**：记录 source 范围、chunking policy、embedding model version、index alias、hybrid / rerank 开关。
- [ ] **离线评测报告**：至少包含 recall@k、precision@k、MRR / nDCG、grounded answer rate、unsupported-claim rate。
- [ ] **线上观测面板**：至少包含 empty-retrieval rate、low-score rate、index staleness、p95 retrieval latency。
- [ ] **故障演练记录**：至少演练 ACL 撤权、index rollback、parser 回退、空检索降级。
- [ ] **抽样审计样本**：保留一组可回放 query，能从答案一路追到 chunk、文档、source 与 parser 版本。

## 常见反例

| 反例 | 为什么危险 | 更合理的做法 |
|---|---|---|
| chunk 尺寸一刀切，不管内容类型 | FAQ、规范、表格、代码的最佳粒度完全不同，统一策略会同时伤 recall 和 precision | 按 source type 维护 chunking policy，并用标注集调参 |
| ACL 在答案生成后再删敏感句子 | 越权 chunk 已进入 prompt，泄露风险已经发生 | ingestion 写 ACL metadata，retrieval-time filter 强制执行 |
| citation 是模型“写出来的”，不绑定真实 chunk id | 用户无法核查，审计时也无法回放证据链 | 引用字段只能从检索上下文白名单里选 |
| 切 embedding model 但不重建 index | query 向量和库中向量不在同一空间，召回会静默退化 | index / query 双侧标记 model version，mismatch 直接告警或阻断 |
| 只看最终答案满意度，不看 recall@k | 无法定位问题在 parser、chunking、ANN、rerank 还是生成 | 分阶段监控 retrieval metrics 与 groundedness |
| rerank 一上来就全量启用 | 可能只增加延迟和成本，没有实际重排收益 | 先做 side-by-side benchmark，再决定是否启用和启用范围 |
| PDF 解析成纯文本就算完成 | 表格、双栏、页眉页脚噪声会严重污染 chunk | 保留 layout / table 结构，并对低 OCR 置信度文档降权或隔离 |

## 关联章节

- [Chapter 07 — Embedding 与向量数据库](../part2_ai_engineering/chapter-07-embedding-vector-db.md)
- [Chapter 08 — Chunking 与 Retrieval](../part2_ai_engineering/chapter-08-chunking-retrieval.md)
- [Chapter 09 — Hybrid Search 与 Reranking](../part2_ai_engineering/chapter-09-hybrid-search-reranking.md)
- [Chapter 10 — RAG](../part2_ai_engineering/chapter-10-rag.md)
- [Chapter 16 — Guardrails 与 Hallucination](../part2_ai_engineering/chapter-16-guardrails-hallucination.md)
