# Checklist 09 — Code Review Checklist

> 用于评审任何触及 model call、prompt、RAG、agent/tool code 的 PR。它是**对常规 code review 的补充**，不是替代：你仍然要检查业务正确性、并发安全、接口兼容性、性能与安全，只是这里额外把 AI/LLM 特有的失效模式拉到台面上。

| 标记 | 含义 | 处理原则 |
|------|------|----------|
| **P0** | 上线阻断项 | 没有证据就不要 merge。 |
| **P1** | 高风险项 | 可以继续评审，但必须要求补证据、补测试或补监控。 |
| **P2** | 优化项 | 不阻断合并，但要进入 backlog，避免“永远以后再说”。 |

评审时不要接受“本地跑过了”或“模型大概率会这样”的说法。你要追问的是：**代码里真正执行了什么约束、失败时如何退化、线上如何观测、回归如何防漂移**。

---

## 模型客户端代码

- [ ] **[P0] 配置了 request timeout、connect timeout 和总 deadline**：LLM 调用最常见的线上事故不是模型答错，而是线程长期挂住、连接池被耗尽、调用链雪崩。
  - 怎么验证：查看 client 初始化和调用封装，确认 timeout 不是默认无限；检查是否区分连接超时、读超时、总超时，并且在调用栈上传递 deadline。

- [ ] **[P0] Retry 逻辑区分 retryable 与 non-retryable 错误**：`429`、部分 `5xx`、瞬时网络错误通常可重试；参数错误、认证失败、`content_filter`、大多数 `4xx` 直接重试只会放大成本和流量。
  - 怎么验证：检查错误分类代码或 middleware；确认 `429`/`408`/`502`/`503`/`504` 与连接重置进入 retry，`400`/`401`/`403`/schema error/content filter 不进入 retry。

- [ ] **[P1] Backoff 使用 exponential backoff + jitter，并设置 retry budget**：没有 jitter 会形成 thundering herd；没有上限会让上游故障变成你自己的资源故障。
  - 怎么验证：检查重试策略是否有 `base delay`、`max delay`、随机抖动和最大尝试次数；确认 PR 没把 retry 写成紧密循环。

- [ ] **[P0] 显式检查并处理 `finish_reason`**：`stop`、`length`、`content_filter`、`tool_calls`、`max_tokens` 代表完全不同的控制流；忽略它们会把截断输出当成功返回。
  - 怎么验证：搜索响应处理代码，确认对 `finish_reason='length'` 有补偿或报错，对 `content_filter` 有可见分支，对需要工具调用的结果不会被当自然语言文本直接落库。

- [ ] **[P1] 保留 provider-specific 错误细节而不是统一吞掉**：不同 SDK 对 rate-limit header、request id、safety category、token overrun 的表达不同；全都转成“LLM failed”会让排障失明。
  - 怎么验证：查看异常映射层，确认 error code、provider request id、限流头、原始 category 或 subtype 被保留下来，并进入日志/trace。

- [ ] **[P1] 流式响应处理了中途断流、半包和 cancel**：streaming 不是“拿到第一段就算成功”；断流时如果没有 close/cancel，会泄漏连接并产生残缺输出。
  - 怎么验证：检查 stream consumer 是否处理 `on_error`/EOF/timeout/cancel；确认 partial output 不会被误标记为完整答案。

- [ ] **[P0] 调用前做 context/token 预算检查并设置 `max_tokens`**：把超长 prompt 直接丢给 provider，通常得到的是高延迟、高成本或 `400 context_length_exceeded`。
  - 怎么验证：查看发送前是否统计 prompt token、预留 completion budget，并在代码中显式设置 `max_tokens`、`truncate` 或裁剪策略。

## Prompt 模板变更

- [ ] **[P0] Prompt 改动在 PR 中可读、可 diff，而不是埋在字符串拼接里**：如果 reviewer 看不到完整模板，就无法判断语义边界、system/user 角色分层和指令冲突。
  - 怎么验证：确认 prompt 以独立模板、常量块或 render 函数呈现；PR diff 能直接看到新增、删除和顺序变化，而不是一堆拼接表达式。

- [ ] **[P0] 用户可控变量插值有明确分隔和 escaping**：把工单标题、网页文本、聊天消息直接拼进指令区，等价于把 untrusted content 提升成 system instruction。
  - 怎么验证：检查模板渲染是否使用三引号、XML tag、JSON string encode 或其他 delimiter；确认用户字段不会直接拼到“你必须……”这类 instruction 段落中。

- [ ] **[P1] Prompt 变更附带 eval run 链接或结果摘要**：prompt 改动不是“文案改一行”；它改变的是系统行为分布，没有回归证据就不能只靠 reviewer 直觉。
  - 怎么验证：在 PR 描述中查找 eval report、golden set 通过率、关键失败样例和 run id；没有证据就要求补跑。

- [ ] **[P1] Prompt 变更附带 token count delta 与成本/延迟影响**：多几个 few-shot 示例可能让质量提升 1%，也可能把 TTFT、成本和 cache miss 拉高 30%。
  - 怎么验证：查看变更前后的 prompt token 统计、`max_tokens` 配置和预估成本；确认 reviewer 能看到 delta，而不是只看文本内容。

- [ ] **[P0] 输出契约变化与 parser/schema 同步更新**：prompt 一旦把“输出 JSON”改成“输出带解释的 JSON”，老 parser 往往直接炸在生产上。
  - 怎么验证：检查 prompt diff 是否伴随 structured output schema、解析器、校验器和相关测试一起修改。

- [ ] **[P1] 稳定前缀的顺序没有被无意打乱**：很多系统依赖 prompt caching；把稳定 system prefix 挪到后面，会同时损伤成本、延迟和一致性。
  - 怎么验证：对比模板顺序，确认稳定前缀、tool definition、few-shot 是否仍位于可缓存区域；必要时附上 cache hit 影响说明。

- [ ] **[P2] Few-shot 示例和 hard negative 仍然代表当前任务边界**：示例不是装饰品；过期示例会把模型推向旧行为，尤其在分类、路由和格式化任务里更明显。
  - 怎么验证：抽查新增/保留示例是否覆盖最新边界条件、失败模式和禁止行为，而不是只保留“最漂亮的成功样例”。

## RAG 相关代码

- [ ] **[P0] ACL filter 在 query time 的代码路径里执行**：权限不能只存在于索引配置、文档说明或上游约定中；只要 query path 漏一次，就可能跨租户泄露。
  - 怎么验证：检查检索函数签名和实际查询构造，确认 tenant/user/group/doc visibility filter 在代码里被强制注入，而不是由调用方“记得传”。

- [ ] **[P0] 检索 filter 逻辑与业务条件严格对应**：产品线、语言、文档状态、发布时间窗任何一个条件写错，模型看到的就是“技术上合法、业务上错误”的上下文。
  - 怎么验证：审查 where/filter builder、枚举映射和默认值；特别检查 `OR/AND`、空 filter、默认语言、软删除字段和时间条件。

- [ ] **[P1] Chunking 改动不会破坏语义边界与元数据继承**：把 chunk 切得更小不一定更好；标题丢失、表格被拆断、source metadata 丢失，都会直接伤害引用质量。
  - 怎么验证：查看 chunker 代码，确认 heading、page、section、doc id、ACL metadata 被继承；必要时用真实文档抽样看切块结果。

- [ ] **[P1] Query rewrite、hybrid search 或 rerank 没有绕开原始过滤条件**：很多 bug 出现在“先粗召回后重排”的中间层，filter 在第一步有，第二步丢了。
  - 怎么验证：顺着 retrieval pipeline 看每一步输入输出，确认 query rewrite、vector search、keyword search、rerank 使用同一组权限和业务过滤。

- [ ] **[P0] Empty retrieval 有显式处理分支**：没有检索结果时最危险的默认行为是继续让模型自由回答，因为它往往会用流畅的语气补齐事实空洞。
  - 怎么验证：检查空结果集是否触发拒答、澄清问题或回退策略；测试里要覆盖 `0 hit` 而不是只覆盖“命中 1 条文档”。

- [ ] **[P1] 引用链路保留了 doc id、chunk id 和可回溯位置**：RAG 不是“检索过就算可信”；如果 answer 无法回链到具体 chunk，事故复盘和用户申诉都站不住脚。
  - 怎么验证：检查 context assembly 和 response schema，确认引用中至少包含 doc id、chunk id、标题或 offset，而不是只留下纯文本片段。

- [ ] **[P1] Embedding/index 版本变更有迁移和回填策略**：换 embedding model、维度或 distance metric 后，如果线上新旧向量混跑，召回会悄悄退化。
  - 怎么验证：检查索引版本号、回填任务、兼容窗口和 cutover 逻辑；确认 PR 里没有把“先写新 embedding，旧索引慢慢过期”当成默认正确。

## 工具与 Function Calling 代码

- [ ] **[P0] Tool schema 与真实实现一致，且字段约束足够严格**：schema 不是文档；它直接决定模型如何构造参数。宽松 schema 会把解析负担和安全风险留给运行时。
  - 怎么验证：检查 required/enum/range/`additionalProperties`/nullable 设置，确认 schema 没遗漏必填字段，也没允许任意自由文本穿透到执行层。

- [ ] **[P0] 权限检查在代码执行路径中真实发生**：把“仅管理员可调用”写在 docstring、tool description 或 prompt 里，等于没有权限控制。
  - 怎么验证：顺着 handler 到 side-effect 函数，确认 authz check 在真正执行前发生，并且不是由模型自己决定“我应该有权限”。

- [ ] **[P0] 有副作用的 tool 具备 idempotency、确认或 HITL 机制**：付款、删除、发消息、改配置这类动作一旦重放，损害往往比答错一句话严重得多。
  - 怎么验证：检查是否使用 idempotency key、dry-run、二次确认、人工审批或幂等写接口；确认 retry 不会重复执行副作用。

- [ ] **[P1] Tool 参数在执行前再次做服务端校验**：模型产出的 JSON 即使通过 schema，也可能语义错误，如负数金额、跨租户 id、非法状态迁移。
  - 怎么验证：查看 handler 是否重新校验业务约束、对象归属、状态机前置条件和单位转换，而不是“parse 成功就执行”。

- [ ] **[P1] Tool 输出被当作 untrusted input 处理**：外部工具返回的 HTML、日志、错误堆栈或数据库内容，可能再次注入到后续 prompt 或 UI。
  - 怎么验证：检查 tool output 是否经过截断、清洗、转义和角色隔离；确认不会把原始报错全文直接塞回 system prompt。

- [ ] **[P1] 限制 tool call 深度、并发度和递归预算**：Agent 类代码最容易在“模型继续调用工具”上失控，最后形成无限循环或成本爆炸。
  - 怎么验证：查看 orchestrator 是否有 `max_steps`、`max_tool_calls`、并发上限和 stop condition；测试里要覆盖重复调用同一 tool 的情况。

- [ ] **[P1] Tool failure 被结构化暴露，而不是静默吞掉后让模型硬编**：如果工具失败只返回空字符串，模型大概率会拿空白当成功并补出一段看似合理的答案。
  - 怎么验证：检查 tool error 是否以结构化状态回传给 planner/model，区分 timeout、permission denied、validation failed、not found 等分支。

## 可观测性与审计

- [ ] **[P0] 新增的 LLM、retrieval、tool 调用都发出了 trace span**：没有 span 的一步，事故时就会变成“中间黑洞”；你看不到延迟、失败点和成本归因。
  - 怎么验证：查看 instrumentation 代码或 sample trace，确认每个新调用点都有 span，而不是只在最外层 API 打一个总耗时。

- [ ] **[P0] Span 和日志包含关键字段**：AI 代码的最小可排障集通常包括 `provider`、`model`、`prompt_version`、`finish_reason`、token 用量、latency、retry count、tool name、retrieved_doc_ids。
  - 怎么验证：抽样 trace/log，确认字段存在且可检索；不要接受“这些信息在 debug 模式能看到”。

- [ ] **[P1] 记录了 provider request id 与内部 correlation id**：跨团队排障时，如果不能把用户请求、你方 trace 和 provider 工单串起来，恢复速度会非常慢。
  - 怎么验证：检查响应 metadata 是否进入日志/trace，并能从一次用户请求追到 provider request id。

- [ ] **[P1] 版本信息可回溯到 prompt、schema、retriever 和 index**：只记录 model name 不够；很多回归来自 prompt 版本、retriever 过滤或索引切换，而不是模型本身。
  - 怎么验证：查看埋点字段，确认能定位到 prompt revision、tool schema version、retriever version、index alias 或 embedding version。

- [ ] **[P0] 日志与 trace 对 prompt、文档片段、tool 参数做了 redaction**：AI 系统最容易把敏感上下文原样打进 observability 后台，事后几乎无法补救。
  - 怎么验证：检查采样日志和序列化器，确认 PII、secret、access token、长文档内容有脱敏或 hash；必要时只记录长度、摘要和 id。

- [ ] **[P1] 为 AI 特有故障建立了 dashboard 与告警**：如果只监控 HTTP 5xx，你会错过 content filter、parse failure、empty retrieval、tool timeout、rate limit 飙升这些真正影响质量的事件。
  - 怎么验证：查看监控面板或告警规则，确认至少覆盖 provider error rate、finish_reason 分布、structured parse failure、retrieval hit rate、tool failure rate。

- [ ] **[P2] 高风险 tool 动作有审计日志和 approval 记录**：事后复盘时，你需要知道是谁触发、模型建议了什么、谁批准、实际执行了什么参数。
  - 怎么验证：检查审计事件模型，确认包含 actor、tool、参数摘要、审批人、审批时间和执行结果。

## 测试覆盖与 Mock 策略

- [ ] **[P0] 单元测试与集成测试优先使用 mocked/recorded provider response**：把真实模型当测试 oracle，会把速度、成本和随机性一起引入 CI。
  - 怎么验证：查看测试依赖和 fixture，确认默认路径使用 stub、VCR、golden response 或 fake server，而不是直接调线上模型。

- [ ] **[P0] 覆盖 malformed JSON、schema mismatch 和半截输出**：生产里的 structured output 失败，常常不是“完全不是 JSON”，而是缺字段、字段类型错、流式被截断。
  - 怎么验证：检查测试用例是否包含非法 JSON、缺失 required 字段、多余字段、字符串代替数组、流式中断后的残缺片段。

- [ ] **[P0] 覆盖 `finish_reason='length'` 与 `finish_reason='content_filter'`**：这两个分支最容易在 happy path 测试中被遗漏，但它们恰好代表“输出不完整”和“输出被审查阻断”。
  - 怎么验证：在测试 fixture 中构造对应 provider 响应，确认业务代码不会把它们当普通成功结果。

- [ ] **[P0] 覆盖 empty retrieval、低质量 retrieval 与无引用场景**：RAG 系统的失败常常不是 crash，而是在没有足够证据时仍然生成自信答案。
  - 怎么验证：检查 tests/evals 是否包含 `0 hit`、只命中噪声 chunk、引用找不到原文、chunk metadata 缺失等情形。

- [ ] **[P1] 覆盖 timeout、retry exhaustion 与 non-retryable error**：你不测失败路径，reviewer 就无法确认 backoff、fallback 和用户提示是否真的生效。
  - 怎么验证：通过 fake clock、stub transport 或 mock SDK 触发 `429`、`503`、`400`、socket timeout，确认每种错误走到预期分支。

- [ ] **[P1] 覆盖 provider-specific payload 和兼容层**：同样叫“tool call”，不同 provider 的字段名、嵌套层级、stream delta 都可能不同。
  - 怎么验证：检查适配层测试是否直接断言原始 payload 到内部数据结构的映射，而不只是测一个抽象后的 happy path。

- [ ] **[P1] 权限与过滤逻辑有代码级测试，不只靠 end-to-end demo**：ACL、tenant filter、tool permission 这类约束一旦失效，代价通常高于一般功能 bug。
  - 怎么验证：查看测试是否直接断言未授权用户查不到文档、调不了 tool、跨租户 id 会被拒绝，而不是只看“管理员样例能成功”。

## 确定性与 Flaky 测试

- [ ] **[P0] 调真实模型的测试被显式隔离，不进入默认 CI 路径**：否则 CI 成败将依赖外部网络、provider 稳定性和模型漂移，而不是你的代码质量。
  - 怎么验证：检查 test marker、tag 或 job 配置，确认 live-model tests 只有在手动或夜间任务中运行。

- [ ] **[P1] 对生成结果断言 invariant，而不是逐字相等**：只要接入真实模型，逐字比对几乎注定脆弱；真正应该测的是结构、字段、引用、分类标签和拒答行为。
  - 怎么验证：查看断言代码，确认它校验 schema、关键信号、正则或语义标签，而不是整段 prose snapshot。

- [ ] **[P1] 固定 temperature、top_p、seed（如果 provider 支持）并在测试里显式声明**：没有固定采样参数，任何一次“小抖动”都可能被误判为代码回归。
  - 怎么验证：检查测试配置和调用参数，确认 deterministic task 使用低温或固定 seed，而不是继承生产默认值。

- [ ] **[P1] 使用 fake clock / stubbed sleep 测 backoff，而不是靠真实等待**：真实 sleep 会让测试慢、脆弱，还难以覆盖多次 retry 的精确时序。
  - 怎么验证：查看 retry 测试是否替换时钟和 sleep 函数，并断言退避序列而非消耗真实秒数。

- [ ] **[P1] Streaming 测试按事件序列断言，不按 wall-clock 断言**：streaming 的关键是 chunk 顺序、结束事件和错误分支，不是“150ms 内应该收到第二段”。
  - 怎么验证：检查测试 fixture 是否构造 chunk/delta 序列，并断言 assembled output、finish event、tool call delta 合并逻辑。

- [ ] **[P2] Snapshot 或 golden output 绑定到具体 model/version**：同一逻辑在不同模型别名下可能表现不同；不绑定版本的 snapshot 会把模型升级的漂移误算成代码 bug。
  - 怎么验证：查看 fixture 命名和元数据，确认包含 provider/model/version，而不是只有 `expected_output.json`。

- [ ] **[P2] 对已知 nondeterministic case 有 quarantine 或重复运行策略**：有些测试天生不是 100% 稳定，问题不在于存在，而在于团队是否知道并隔离它。
  - 怎么验证：查看 flaky test policy、rerun 规则和 quarantine 列表，确认不是简单地“失败就重跑直到过”。

## 依赖与版本管理

- [ ] **[P0] Model SDK、tokenizer 和关键 adapter 版本被 pin 住**：`latest`、宽松 `^` 或无 lockfile，等于把生产行为交给未来某次安装时的偶然结果。
  - 怎么验证：查看依赖文件和 lockfile，确认 SDK/tokenizer/structured-output 相关包有明确版本，而不是浮动范围。

- [ ] **[P1] 升级 SDK 前看过 changelog 中与 token counting、schema、streaming 相关的 breaking change**：很多“只是补丁升级”实际改变了字段名、默认 timeout、usage 统计或 tool call 表达。
  - 怎么验证：在 PR 描述或提交记录中查找 changelog 链接和 reviewer 备注，确认关注了 token 统计、finish_reason、JSON schema、stream delta 等条目。

- [ ] **[P1] Model 标识使用稳定版本，不依赖易漂移的 alias**：`gpt-4o`、`claude-sonnet-latest` 这类 alias 适合探索，不适合需要可复现回归的生产路径。
  - 怎么验证：检查配置是否使用带日期或 revision 的 model id；如果必须用 alias，确认有自动回归和快速回滚。

- [ ] **[P1] 相关解析/校验库版本兼容**：升级 provider SDK 往往会连带影响 `pydantic`、`jsonschema`、OpenAPI generator 或你自己的 response parser。
  - 怎么验证：查看依赖 diff 和测试覆盖，确认 schema 生成、序列化、反序列化和 validation 层没有被隐式破坏。

- [ ] **[P1] 录制的 fixture、golden response 和 eval baseline 随版本变更同步更新**：依赖升级后如果测试数据还是老格式，CI 可能全绿，但生产路径已经悄悄漂移。
  - 怎么验证：检查 PR 是否同时更新 recorded response、snapshot、baseline 报表，并解释哪些变化来自 SDK/model，哪些来自业务逻辑。

- [ ] **[P2] 为 provider deprecation、限额变化和 API 迁移准备了 fallback**：AI 依赖的寿命通常比传统数据库驱动短，今天可用的 endpoint 明天可能就退役。
  - 怎么验证：查看配置和 runbook，确认有替代模型、兼容层或 feature flag，而不是把迁移风险压到未来某次线上故障。

- [ ] **[P2] 依赖更新不会绕过安全与合规检查**：AI SDK 常附带遥测、默认日志或新的外连行为；只看功能是否可用是不够的。
  - 怎么验证：检查新增依赖的 license、默认 telemetry、数据出境说明和安全审查记录，确认没有把 prompt/content 默认上传到第三方分析服务。

## 常见反例

| 反例 | 为什么危险 | Review 时要追问什么 |
|------|------------|---------------------|
| PR 里改了 prompt，但没有 eval 结果链接 | 你看到的是文本差异，不是行为差异 | “这次改动跑了哪些样例？失败样例是什么？” |
| 响应处理里完全不看 `finish_reason` | 截断输出会被当成功，content filter 会被静默吞掉 | “`length` 和 `content_filter` 分支在哪里处理？” |
| Retry 对所有异常一视同仁 | 非 retryable 错误会被放大成成本和流量问题 | “哪些 code 会重试，哪些不会？依据是什么？” |
| RAG 检索默认不过滤 tenant/ACL | 一次漏 filter 就可能跨租户泄露文档 | “过滤条件在 query builder 哪一行强制注入？” |
| 工具函数的权限检查只写在注释里 | 模型不会替你执行授权逻辑 | “真正的 authz check 在哪个执行路径里？” |
| 新增了 tool call，但 trace 里没有 span | 线上出故障时你无法知道卡在模型、检索还是工具 | “sample trace 给我看一下新增 span 和字段。” |
| 测试直接调用真实模型并断言整段文本相等 | CI 会同时受网络、模型漂移和随机采样影响 | “为什么不能改成 mocked response + invariant assertion？” |
| SDK 升级后没看 changelog，也没更新 recorded fixture | 解析器或 token 统计可能已经悄悄变了 | “这次升级影响了哪些响应字段和 baseline？” |

## 关联章节

- [Structured Output](..\part2_ai_engineering\chapter-04-structured-output.md)
- [Function / Tool Calling](..\part2_ai_engineering\chapter-05-function-tool-calling.md)
- [RAG](..\part2_ai_engineering\chapter-10-rag.md)
- [Evaluation](..\part2_ai_engineering\chapter-15-evaluation.md)
- [AI Observability](..\part2_ai_engineering\chapter-20-ai-observability.md)
