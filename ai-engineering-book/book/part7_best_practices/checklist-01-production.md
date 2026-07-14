# Checklist 01 — Production Checklist

> 用于 LLM/AI 功能**第一次承接真实生产流量前**，以及**模型、prompt、工具链或上下文策略发生重大迁移前**的发布评审。它不回答“功能是否能跑”，而是回答“系统在真实流量、真实成本、真实故障下是否仍然可控”。

## SLO 与发布边界

- [ ] **[P0] 写清三类 SLO**: 只写 `200 OK` 比例没有意义；生产发布至少要同时约束 latency、availability、quality，避免“服务可用但答案不可用”的假健康。
  - 怎么验证：在发布文档或 `release.yaml` 中能看到 `slo.p95_ttft_ms`、`slo.p95_e2e_ms`、`slo.success_rate`、`slo.hallucination_rate` 四个字段；Dashboard `LLM / Release SLO` 已按模型版本分组展示。
  - 通过标准：每个指标都有数值阈值、统计窗口和 owner，且值班工程师知道哪个阈值触发阻断发布。
  - 失败信号：只有“接口可用率 99.9%”一条指标，或质量指标停留在“用户反馈不好”这类不可执行描述。

- [ ] **[P0] 区分 TTFT 与 TPOT 目标**: 首 token 慢通常是 prefill 或长上下文问题，逐 token 慢通常是 decode 或 provider 饱和问题，不拆开就无法定位。
  - 怎么验证：Tracing 中每次请求都落 `ttft_ms`、`tpot_ms`、`input_tokens`、`output_tokens`；Dashboard `LLM / Latency Decomposition` 能按 `model_id` 看 P50/P95。
  - 通过标准：同一请求能回答“为什么首字慢”和“为什么越答越慢”两个不同问题，而不是只给一个总时延数字。
  - 失败信号：压测报告只给 `latency_p95`，无法判断问题来自 prompt 过长、输出过长还是流式链路堵塞。

- [ ] **[P0] 为质量定义可量化失败口径**: “用户觉得不准”不能当生产指标；至少要定义 hallucination rate、tool success rate、retrieval groundedness 三项之一作为发布边界。
  - 怎么验证：`evals/release/production_gate.yaml` 包含 `hallucination_rate <= 1.5%`、`tool_call_success_rate >= 98%`、`grounded_answer_rate >= 95%` 等阈值；CI 任务 `make eval-prod-gate` 会阻断合并。
  - 通过标准：质量阈值能够映射到业务后果，例如客服误答、引用缺失、工具执行失败，而不只是抽象分数。
  - 失败信号：上线依据仅是开发者主观感受，或者只看一个通用 LLM benchmark 分数。

- [ ] **[P1] 明确不可承载的流量形态**: 生产事故往往来自“支持任意长输入、任意长输出、任意频率调用”这类默认开放，而不是模型本身。
  - 怎么验证：API 网关配置存在 `max_request_chars`、`max_input_tokens`、`max_output_tokens`、`rate_limit.rpm`；压测脚本 `tests/load/test_long_context_reject.ps1` 覆盖超限场景。
  - 通过标准：产品、后端、值班三方对哪些请求会被拒绝或降级有一致预期，文档和网关规则一致。
  - 失败信号：需求文档写“支持任意文档总结”，但系统没有任何输入上限、输出上限或流量整形策略。

- [ ] **[P1] 设定 canary 放量规则**: 大模型上线不是二元开关；先用小比例真实流量看质量漂移，能避免评测集之外的分布突变直接打满全量用户。
  - 怎么验证：发布配置存在 `traffic.canary_percent: 1 -> 5 -> 25 -> 100`；运行命令 `gh workflow run release-canary.yml -f feature=llm-prod` 后，Dashboard `LLM / Canary Compare` 能对比 control 与 canary。
  - 通过标准：每一档放量都有明确晋级条件和回退条件，不依赖某位工程师在线拍板。
  - 失败信号：第一次发布就 100% 切流，或者所谓 canary 只看 5xx 不看线上质量代理指标。

## 模型、Prompt 与配置版本控制

- [ ] **[P0] Pin 到不可歧义的模型版本**: 生产环境不能只写 `gpt-4o`、`claude-sonnet` 这类浮动别名，否则供应商静默升级会让输出分布漂移且难以追责。
  - 怎么验证：配置文件明确出现 `model_id: gpt-4o-2026-05-13` 或同等级别的版本串；Trace 字段 `model_id` 与请求配置完全一致，没有 `latest`、`default` 之类别名。
  - 通过标准：线上任意一条请求都能唯一定位到模型版本，而不是定位到“某个家族”。
  - 失败信号：出问题后只能说“最近供应商好像变了”，却无法证明哪一天、哪一版开始漂移。

- [ ] **[P0] 为 prompt 分配独立版本号**: prompt 是代码，不是文案；不做 `prompt_version` 管理就无法回滚，也无法解释为什么某次回答风格或结构突然变化。
  - 怎么验证：Prompt 仓库或目录存在版本化文件，如 `prompts/support_answer/v12.md`；请求日志包含 `prompt_name`、`prompt_version`、`prompt_hash`。
  - 通过标准：任意线上样本都能从 trace 反查到当时使用的完整 prompt 文本和差异记录。
  - 失败信号：prompt 直接写死在服务代码里，或由运营在后台热改且没有 diff、审批和发布记录。

- [ ] **[P0] 固定关键采样参数**: 温度、`top_p`、`max_tokens`、`tool_choice` 的漂移会直接改变质量、成本和尾延迟，不能让不同环境靠默认值运行。
  - 怎么验证：`config/llm-production.yaml` 中显式声明 `temperature`、`top_p`、`max_output_tokens`、`tool_choice`、`response_format`；启动时会打印配置摘要到 `release_config_snapshot.json`。
  - 通过标准：staging 和 production 使用同一套受控配置来源，而不是各自继承 SDK 默认值。
  - 失败信号：本地、测试、线上输出差异巨大，最后发现只是某个环境没设 `max_tokens` 或温度默认值不同。

- [ ] **[P1] 记录工具定义与 schema 版本**: tool calling 的失败常常不是模型差，而是 schema 改了但 prompt 仍在教旧字段；模型、prompt、tool schema 必须联动版本化。
  - 怎么验证：Trace 中存在 `tool_schema_version`；`tests/contracts/test_tool_schema_compat.py` 校验 prompt 中引用的字段名与 `schemas/*.json` 一致。
  - 通过标准：任一工具字段的 breaking change 都会在 CI 或发布评审中被发现，而不是等线上 JSON parse fail。
  - 失败信号：工具签名改了以后模型仍在输出旧参数名，日志里充满 `unknown field` 和解析失败。

- [ ] **[P1] 做配置快照归档**: 生产请求的可复现性来自“同一输入 + 同一模型 + 同一 prompt + 同一 config”，缺一项都无法做事后归因。
  - 怎么验证：每次发布产出 `artifacts/release/llm_bundle.json`，包含 `model_id`、`prompt_version`、`sampling`、`retrieval`、`guardrail`、`tool_schema_version`；发布单附带 bundle 哈希。
  - 通过标准：事故复盘时可以用 bundle 精确回放候选版本和前一版本，不依赖口头记忆。
  - 失败信号：复盘会议上有人说“应该不是配置问题吧”，但实际上没人能还原当时的完整运行参数。

## 上下文预算与检索控制

- [ ] **[P0] 为系统提示、历史、RAG、输出分别设 token budget**: 不做分项预算，线上最终一定演化成“哪个模块先塞进去就占满窗口”，然后随机触发 context overflow。
  - 怎么验证：配置中存在 `budget.system_tokens`、`budget.history_tokens`、`budget.retrieval_tokens`、`budget.output_tokens`；单测 `tests/context/test_budget_allocator.py` 覆盖总和不超过 `context_window`。
  - 通过标准：每次请求都能解释 token 花在了哪里，而不是只知道“总共用了很多”。
  - 失败信号：系统提示、聊天历史、检索片段彼此抢窗口，某次上线多加一个 few-shot 就把历史全挤没了。

- [ ] **[P0] 在请求前做 token 预估与硬拒绝**: 等 provider 返回 `context_length_exceeded` 再处理太晚，会把失败暴露给用户并污染重试链路。
  - 怎么验证：请求前日志记录 `estimated_input_tokens`；超限时返回受控错误码 `LLM_CONTEXT_BUDGET_EXCEEDED`；命令 `pytest tests/context/test_preflight_overflow.py -q` 通过。
  - 通过标准：超限请求在进入 provider 前就被拦截，并附带可解释的降级或提示文案。
  - 失败信号：监控里大量 400/422 来自 provider，应用层却没有任何关于预算或裁剪的上下文信息。

- [ ] **[P1] 控制检索片段数量与排序策略**: RAG 质量坏掉时，常见原因不是召回不到，而是把 20 个弱相关 chunk 全塞进 prompt，让高价值证据被淹没。
  - 怎么验证：检索配置存在 `retrieval.top_k`、`retrieval.max_context_chunks`、`retrieval.rerank.enabled`；Dashboard `LLM / Retrieval` 展示 `recall_at_5`、`avg_chunks_used`、`context_tokens_from_rag`。
  - 通过标准：检索管线有“召回多少、最终塞多少、排序依据是什么”三个清晰边界。
  - 失败信号：命中率看起来不低，但回答经常引用错文档或漏关键事实，因为上下文被低相关片段稀释。

- [ ] **[P1] 让稳定前缀前置以利用 prompt cache / KV cache**: 每次都把变化内容插在最前面，会破坏缓存命中，直接抬高 TTFT 与单位成本。
  - 怎么验证：Prompt 结构文档明确“system + tool defs + few-shot”位于前缀；Trace 字段存在 `prompt_cache_hit` 或 `cached_prefix_tokens`；Dashboard `LLM / Cache Efficiency` 已接入。
  - 通过标准：高重复度请求在相同模型与前缀下，TTFT 与 prompt cost 能稳定下降而不是随机波动。
  - 失败信号：同类请求结构几乎一样，TTFT 却始终很高，最后发现每次都把租户上下文插到最前面破坏缓存。

- [ ] **[P2] 对旧会话做摘要而不是无限保留原文**: 长对话里最贵的不是“回答”，而是把无关旧历史反复 prefill；摘要化是延迟和成本的共同优化点。
  - 怎么验证：会话编排里存在 `memory.summary_version`；集成测试 `tests/chat/test_history_compaction.py` 验证当 `history_tokens` 超阈值后触发摘要替换。
  - 通过标准：旧历史被压缩后，关键信息仍可追踪，且 `history_tokens` 随轮次增长不会无限线性上升。
  - 失败信号：对话进行到二三十轮后，答案质量和时延同时恶化，但历史里多数内容已与当前任务无关。

## 评测门禁与灰度发布

- [ ] **[P0] 发布前必须跑离线回归 eval**: 只靠开发者手工问几条 demo，无法发现长尾失败模式，更无法比较模型迁移后的真实收益与退化。
  - 怎么验证：CI 包含 `make eval-release`；输出工件 `artifacts/evals/release_report.json` 至少含 `pass_rate`、`hallucination_rate`、`format_error_rate`、`tool_error_rate`。
  - 通过标准：任何会改变线上行为的变更，都有一份可追溯的评测报告随发布一起归档。
  - 失败信号：PR 描述里写“我手测了几个问题没问题”，却没有任何系统化评测证据。

- [ ] **[P0] 评测集要覆盖真实任务分层**: 生产质量问题通常集中在 hard cases；如果评测集只有 happy path，发布门禁会被“平均分”掩盖。
  - 怎么验证：`evals/datasets/production.csv` 带 `segment` 列，如 `easy/medium/hard/long_context/tool_required`；报告按 `segment` 拆分而不是只给总分。
  - 通过标准：评测结果能直接回答“最脆弱的场景是什么”，而不是只回答“平均还行”。
  - 失败信号：总分提高了 2%，但真实投诉集中在需要引用依据或调用工具的 hard segment。

- [ ] **[P1] 对关键场景建立对比基线**: 模型升级、prompt 改写、RAG 参数变更都应与上一版本做 A/B 比较，否则“更智能了”只是主观感觉。
  - 怎么验证：评测报告同时输出 `candidate` 与 `baseline`，并标出 `delta`; 测试命令 `python scripts/evals/compare.py --baseline release-2026-06 --candidate HEAD` 可复现。
  - 通过标准：变更说明里能说清楚“哪些场景提高了、哪些场景退化了、是否接受这种 trade-off”。
  - 失败信号：新版本上线后才发现摘要更好但抽取更差，因为发布前根本没做场景级对比。

- [ ] **[P1] 上线前走 shadow mode**: 某些失败只有真实用户输入分布能触发，但又不能直接让用户承受候选版本结果；shadow mode 是最便宜的真实流量样本。
  - 怎么验证：流量路由配置存在 `shadow.enabled: true` 与 `shadow.sample_percent`; 日志中能看到 `shadow_request_id` 与 `shadow_model_output`，但用户只收到 primary 输出。
  - 通过标准：shadow 数据能进入质量分析流水线，并和 primary 结果按同一请求对齐比较。
  - 失败信号：所谓 shadow 只是把日志打出来，却没有任何自动分析与对齐机制，最后没人看。

- [ ] **[P1] 灰度期间看线上质量而不只看错误率**: LLM 系统最危险的退化常是“还能返回，但内容更差”；灰度判断必须包含质量代理指标。
  - 怎么验证：Dashboard `LLM / Canary Quality` 展示 `deflection_rate`、`thumbs_down_rate`、`citation_coverage`、`tool_call_retry_rate`；Prometheus 告警规则含 `canary_quality_drop > threshold`。
  - 通过标准：canary 晋级条件至少有一项质量代理指标，而不是单看 availability。
  - 失败信号：5xx 很低就继续放量，结果全量后才发现用户转人工率和负反馈率同时上升。

## LLM 可观测性

- [ ] **[P0] 每个请求打通完整 LLM trace**: 没有 trace，就看不到 prompt 构成、检索命中、工具调用、finish reason，LLM 事故会退化成靠猜。
  - 怎么验证：OpenTelemetry span 至少包含 `provider`、`model_id`、`prompt_version`、`input_tokens`、`output_tokens`、`finish_reason`、`tenant_id`、`request_path` 字段。
  - 通过标准：从单条 trace 可以串起 API、RAG、模型、工具和后处理，而不是只有应用入口一个 span。
  - 失败信号：值班时只能看到 HTTP 200 和耗时，却不知道这次回答到底用了什么上下文和什么模型。

- [ ] **[P0] 区分 provider error、tool error、guardrail reject**: 把所有失败都记成 “500” 会让值班工程师错误地下沉到模型层，而真正故障可能在工具编排或策略层。
  - 怎么验证：错误码枚举明确区分 `LLM_PROVIDER_TIMEOUT`、`TOOL_CALL_FAILED`、`GUARDRAIL_BLOCKED`、`CONTEXT_OVERFLOW`；Dashboard `LLM / Error Taxonomy` 有分布图。
  - 通过标准：值班工程师能在一分钟内回答“是供应商挂了、工具坏了，还是策略主动拦截了”。
  - 失败信号：相同的用户报错在监控里都被算成通用 500，导致错误升级路径总是错误。

- [ ] **[P1] 记录 finish_reason 与 stop path**: 被 `length` 截断、被 `content_filter` 拦截、正常 `stop` 结束，后续处理完全不同；不采集就无法解释短答或半截答复。
  - 怎么验证：请求日志或数据仓库表 `llm_inference_events` 含 `finish_reason` 字段；SQL 检查 `SELECT finish_reason, count(*) ...` 可直接聚合。
  - 通过标准：任何异常短答都能在日志里看到是 token 打满、内容审核中断还是客户端取消。
  - 失败信号：用户说“答案总是只到一半”，团队却无法判断是 `max_tokens` 太小还是流式连接被截断。

- [ ] **[P1] 为检索和工具链建专用面板**: LLM 质量往往败在上下游——低召回、工具超时、JSON parse 失败，而不是模型 logits 本身。
  - 怎么验证：存在 Dashboard `LLM / Retrieval` 与 `LLM / Tool Calling`; 前者看 `retrieval_latency_ms`、`recall_at_5`，后者看 `tool_call_error_rate`、`tool_call_p95_ms`、`json_parse_fail_rate`。
  - 通过标准：当线上答案变差时，可以先排除 retrieval/tooling，再决定是否怀疑模型或 prompt。
  - 失败信号：所有问题最后都被归结为“模型不稳定”，因为团队根本看不到工具和检索链路的健康度。

- [ ] **[P2] 建立请求回放样本池**: 线上抽样回放不是为了“重现所有请求”，而是为了在不触碰原始用户会话的前提下分析稳定性漂移与非确定性。
  - 怎么验证：样本池只保存脱敏后的 `request_snapshot_id`; 命令 `python scripts/replay.py --sample weekly_canary_failures.jsonl` 能在 staging 回放并生成对比报告。
  - 通过标准：能定期回放“高成本样本、负反馈样本、失败样本”，并把回放结果输入下一轮评测。
  - 失败信号：线上异常每次都靠临时手抄 prompt 复现，无法做系统化回放和漂移监控。

## 回滚、降级与 Kill Switch

- [ ] **[P0] 回滚要能同时回滚 model、prompt、config**: 只回滚应用代码而不回滚 prompt/model 版本，等于没有回滚；线上行为仍然是新的。
  - 怎么验证：发布系统支持 `release bundle` 粒度回滚；命令 `gh workflow run rollback.yml -f bundle=release-2026-07-03-01` 会恢复同一套 `model_id + prompt_version + config_hash`。
  - 通过标准：回滚一次操作即可恢复完整行为，不需要临时再改三四处配置。
  - 失败信号：事故发生后应用回退了，但模型和 prompt 还是新版本，用户问题没有任何改善。

- [ ] **[P0] 准备 provider 级降级路径**: 单一 provider outage 是高概率事件，尤其当你依赖流式、tool calling 或 structured output 的特定实现时。
  - 怎么验证：配置中存在 `fallback.providers` 顺序；演练命令 `pytest tests/resilience/test_provider_failover.py -q` 模拟主 provider 429/5xx 后切到备 provider。
  - 通过标准：主 provider 故障时，系统能在 SLO 允许范围内切到次优方案，而不是完全不可用。
  - 失败信号：所有发布评审都写“后面再做多云”，直到第一次供应商故障时才发现根本没有切换脚本。

- [ ] **[P1] 设计 feature-level kill switch**: 当 hallucination、隐私泄露或异常成本暴涨出现时，需要能在分钟级关闭单一 AI 能力，而不是下线整个产品。
  - 怎么验证：运行时配置存在 `llm.kill_switch.enabled` 或按租户的 `feature_flags.ai_answering=false`; 值班文档写明修改入口和生效延迟。
  - 通过标准：值班工程师在无代码发布的前提下也能关闭高风险能力，并有审计记录。
  - 失败信号：只能靠重新部署整个服务来止损，导致停机范围远大于问题本身。

- [ ] **[P1] 定义无模型兜底路径**: 某些功能在 LLM 不可用时可以退化到 keyword search、FAQ 模板或人工转接，避免“AI 组件挂了 = 整个业务不可用”。
  - 怎么验证：E2E 测试 `tests/fallback/test_non_llm_degrade.py` 覆盖 provider 超时后的降级文案；产品文档说明哪些路由允许静态兜底。
  - 通过标准：降级后的用户体验虽然差一些，但任务仍然能继续，而不是直接空白页或 500。
  - 失败信号：一旦 LLM 超时，业务流程卡死在等待 AI 结果这一步，用户无法继续下一动作。

- [ ] **[P2] 把工具调用失败与模型失败分开降级**: 许多 agent 类系统的真实故障是工具链不稳定；保留纯文本回答能力往往比整体熔断更有业务价值。
  - 怎么验证：编排层支持 `tool_mode=disabled`；压测脚本 `scripts/chaos/disable_tools.ps1` 后，请求仍可返回 `text_only` 路径且不触发 500。
  - 通过标准：工具层故障不会强制拉低所有 AI 路由，而是只影响依赖该工具的能力集合。
  - 失败信号：单个搜索工具超时就让整个 agent 产品全面失败，即便模型本身仍可回答基础问题。

## 成本、配额与资源保护

- [ ] **[P0] 为请求设 token spend cap**: 单次异常长上下文或 runaway generation 就可能把单位经济模型打穿，尤其在多轮对话或 agent 循环里。
  - 怎么验证：配置存在 `spend.max_prompt_tokens`、`spend.max_completion_tokens`、`spend.max_total_tokens_per_request`; 超限事件会记录 `budget_exceeded_reason`。
  - 通过标准：任何请求的理论最坏成本都可计算，且在业务可接受区间内。
  - 失败信号：账单暴涨时团队只能说“最近用户用得多”，却不知道是长输入、长输出还是死循环重试造成。

- [ ] **[P0] 建立按租户与功能归因的成本看板**: 不知道钱花在哪，就无法做路由、缓存、prompt 精简或配额策略，后续优化只能靠拍脑袋。
  - 怎么验证：Dashboard `LLM / Cost Attribution` 按 `tenant_id`、`feature_name`、`model_id` 展示 `prompt_cost_usd`、`completion_cost_usd`、`cache_savings_usd`。
  - 通过标准：月底成本复盘时可以明确指出最贵租户、最贵功能和最贵模型，而不是只看总账单。
  - 失败信号：团队争论“是不是 RAG 太贵”，但没有任何按功能归因的数据支撑。

- [ ] **[P1] 对高风险路径做速率与并发保护**: agent、代码生成、长文总结这类请求既贵又慢，缺少 queue 或 concurrency cap 时会放大 provider 限流与账单峰值。
  - 怎么验证：网关或 worker 配置包含 `concurrency_limit`、`queue_timeout_ms`、`burst_rpm`; 压测 `tests/load/test_burst_control.ps1` 不会把后端打到雪崩。
  - 通过标准：突发流量来时，系统优先排队、限流或拒绝，而不是把所有请求同时压向最贵后端。
  - 失败信号：一次营销活动或机器人刷量就把 provider 额度和内部队列一起打满。

- [ ] **[P1] 监控 cache 命中与无效大输出**: 成本治理不只是“少调模型”，还包括识别 prompt cache miss、无引用长答案、重复工具调用等结构性浪费。
  - 怎么验证：Dashboard `LLM / Cost Efficiency` 追踪 `prompt_cache_hit_rate`、`avg_output_tokens`、`tool_calls_per_request`、`empty_citation_rate`。
  - 通过标准：成本异常时，团队能分辨是业务增长还是结构性低效，而不是一刀切压缩体验。
  - 失败信号：回答越来越长但引用越来越少，说明系统在花更多 token 生成更低价值的内容。

- [ ] **[P2] 为不同任务做模型路由策略**: 把摘要、分类、抽取、复杂推理全部打到同一个最贵模型，是最常见也最懒惰的成本反模式。
  - 怎么验证：路由配置存在 `routes.classification.model_id`、`routes.summarization.model_id`、`routes.reasoning.model_id`; 回归测试 `tests/routing/test_task_model_router.py` 断言路由选择。
  - 通过标准：高价值推理任务用高能力模型，低复杂度任务用便宜模型，且质量门槛通过评测验证。
  - 失败信号：所有流量默认打到旗舰模型，只因为“先这样最省事”。

## 隐私、PII 与安全边界

- [ ] **[P0] 在进模型前做 PII redaction 或最小化传输**: 生产事故里最难收拾的不是 5xx，而是把身份证号、病历、工资等原文发给不该看到的模型或日志系统。
  - 怎么验证：预处理链路存在 `pii_redaction.enabled`; 单测 `tests/privacy/test_redaction_before_llm.py` 校验姓名、手机号、邮箱在 provider 请求体中已被掩码。
  - 通过标准：模型只收到完成任务所需的最小字段，而不是原始全量用户数据。
  - 失败信号：为了“提高回答质量”直接把完整 CRM、工单原文和附件全文无差别送进 prompt。

- [ ] **[P0] 明确日志与 trace 的敏感字段策略**: LLM observability 很容易因为“要排障”而过度记录 prompt 原文，结果把日志平台变成新的数据泄露面。
  - 怎么验证：日志 schema 标注 `prompt_text`、`retrieved_docs` 为受限字段或仅存 hash；安全检查命令 `rg \"prompt_text|retrieved_docs\" D:\\projects\\chinese-math-physics\\ai-engineering-book -g \"*.yaml\"` 能看到脱敏策略。
  - 通过标准：默认路径下看不到明文敏感内容，只有经过授权的样本池或受控环境才能查看原文。
  - 失败信号：任何有日志平台读权限的人都能直接看到用户 prompt 和检索文档原文。

- [ ] **[P1] 对外部内容做 prompt injection 防护**: 检索结果、网页内容、用户上传文件都可能携带“忽略之前指令”之类恶意文本；不隔离角色边界就会污染系统行为。
  - 怎么验证：Prompt 模板明确把外部内容包在 `quoted context` 或工具字段中，而不是拼进 system 指令；测试 `tests/security/test_prompt_injection_guard.py` 覆盖典型注入样本。
  - 通过标准：外部文本被当作数据而非指令处理，且注入样本无法提升权限或改写系统目标。
  - 失败信号：一个恶意网页片段就能让模型忽略政策、泄露系统 prompt 或绕过工具使用约束。

- [ ] **[P1] 为工具调用做最小权限设计**: 当模型能调用搜索、发消息、改数据时，真正的安全边界在 tool permission，而不是“相信模型不会乱来”。
  - 怎么验证：每个工具声明 `allowed_actions`、`tenant_scope`、`approval_required`; 合约测试 `tests/security/test_tool_scope_enforcement.py` 校验越权调用被拒绝。
  - 通过标准：模型即便生成了错误参数，也无法越权访问他人数据或执行高风险动作。
  - 失败信号：同一组工具凭证在所有租户、所有环境通用，模型只要调到工具就等于拿到全权限。

- [ ] **[P2] 设定数据保留与删除策略**: 线上评测、回放、标注样本若无限期保存，会把“排障需要”慢慢演化成长期合规债务。
  - 怎么验证：配置存在 `retention.raw_prompts_days`、`retention.redacted_samples_days`; Runbook 里写明删除命令或作业名，如 `cleanup-llm-samples`.
  - 通过标准：样本池、评测集、日志归档都能说明保留期限、删除责任人和审计方式。
  - 失败信号：没人知道一年前的生产 prompt 和附件样本是否还在对象存储里，更没人负责删除。

## 事故响应就绪度

- [ ] **[P0] 为 hallucination spike 准备专门 runbook**: 幻觉飙升往往不是“模型坏了”这么简单，可能来自检索失效、prompt 漏引用约束、provider 模型切换或缓存污染。
  - 怎么验证：`runbooks\\llm-hallucination-spike.md` 存在，并包含检查项：`retrieval recall`、`citation coverage`、`prompt_version diff`、`model_id drift`、`rollback command`。
  - 通过标准：值班工程师不需要临场发明步骤，就能从症状快速收敛到检索、prompt、模型或缓存层。
  - 失败信号：每次幻觉升高都从头开会讨论“先看哪里”，导致止损时间过长。

- [ ] **[P0] 为 provider outage 准备切换演练**: 供应商 429、流式中断、区域故障都属于应当预期的事故；没有演练过的 failover 基本等于没有。
  - 怎么验证：季度演练记录能看到 `provider outage game day`；命令 `python scripts/drill_provider_outage.py --provider primary` 会生成演练报告并记录切换耗时。
  - 通过标准：演练中切换动作、告警确认、用户沟通和回切条件都有明确时间线。
  - 失败信号：文档里写了备 provider，但从未真实验证认证、配额、结构化输出兼容性是否可用。

- [ ] **[P1] 为 context overflow 建立报警与自愈路径**: overflow 通常是输入分布变化或上游检索失控的信号，不能只在应用日志里静默失败。
  - 怎么验证：告警规则 `llm_context_overflow_rate > 0.5% for 5m` 已配置；自愈策略会自动降低 `retrieval.top_k` 或截断历史，并记录 `overflow_mitigation_applied=true`。
  - 通过标准：出现 overflow 峰值时，系统先自我收缩，再通知值班介入，不把所有故障直接暴露给用户。
  - 失败信号：监控长期安静，但用户不断反馈“有时提示内容太长”，说明 overflow 只存在于边缘日志。

- [ ] **[P1] 为 tool failure storm 定义隔离动作**: 当单个工具依赖抖动时，若 agent 持续重试，往往会造成 token、延迟和下游压力的三重放大。
  - 怎么验证：Runbook 写明当 `tool_call_error_rate` 超过阈值时切到 `tool_mode=disabled` 或禁用特定工具；Chaos 测试 `tests/chaos/test_tool_failure_isolation.py` 通过。
  - 通过标准：工具故障被限制在局部，不会因为重试放大成全站级别的成本与延迟事故。
  - 失败信号：一个下游检索接口变慢后，agent 开始反复重试并触发长输出解释，最终把 GPU 和队列一并拖垮。

- [ ] **[P2] 明确值班时的观测顺序**: LLM 事故排障若没有固定顺序，现场容易同时看十个面板却得不到结论；先看 provider，再看 prompt/config，再看 retrieval/tooling，效率最高。
  - 怎么验证：值班卡片或 `ops\\llm-triage-order.md` 写明排障顺序；新值班工程师按文档演练一次能在 15 分钟内定位模拟故障类别。
  - 通过标准：不同值班人采用相似的排障路径，复盘中不会出现“各看各的面板，没人收敛结论”。
  - 失败信号：事故群消息刷屏，但没有任何统一 triage 顺序，导致决策和执行同时混乱。

## 常见反例

| 反例 | 为什么危险 | 正确做法 |
|---|---|---|
| 只用 5 条 demo 验证就上线 | 只能证明 happy path 能工作，无法覆盖长上下文、坏检索、工具异常、真实用户噪声输入 | 发布前跑分层 eval，并在灰度阶段用 shadow mode 看真实流量样本 |
| prompt 改动没有 diff/版本号，直接热更新 | 出现质量回退时无法定位责任版本，也无法做精确回滚 | 为每个 prompt 维护 `prompt_version`、`prompt_hash`，发布产出 bundle |
| 把 500 错误率当唯一 SLO | LLM 完全可能“成功返回错误答案”，表面可用率高但业务结果很差 | 同时定义 latency、availability、quality 三类 SLO，并纳入告警 |
| 允许任意长输入，溢出后依赖 provider 报错 | 用户直接看到失败，重试链路和成本也会被放大 | 请求前做 token 预估、预算分配和受控拒绝 |
| 回滚只回滚代码，不回滚 prompt/model 版本 | 线上行为依旧是新 prompt 或新模型，事故不会真正解除 | 用 release bundle 一次性回滚 `model + prompt + config` |
| 观测里只存总 token 数，不存 finish_reason | 看不到为什么答案被截断、被过滤或提前终止，排障只能猜 | 日志与 trace 必须记录 `finish_reason`、`stop_reason`、`output_tokens` |
| 工具调用失败后无限重试 | 会同时放大延迟、token 成本和下游故障面，agent 还可能进入坏循环 | 为工具设置 retry cap、circuit breaker，并支持 `tool_mode=disabled` 降级 |
| 为了排障把完整 prompt 和检索文档写进所有日志 | 调试方便一时，合规和数据泄露风险长期存在 | 默认只存脱敏字段、hash 或受控样本池，原文访问需最小权限 |

## 关联章节

- [Chapter 01 — LLM 基础与 Transformer 概览](../part2_ai_engineering/chapter-01-llm-fundamentals.md)
- [Chapter 02 — Token、Context Window 与成本模型](../part2_ai_engineering/chapter-02-token-context-window.md)
- [Chapter 05 — Function Calling / Tool Calling](../part2_ai_engineering/chapter-05-function-tool-calling.md)
- [Chapter 15 — 评测（Evaluation）](../part2_ai_engineering/chapter-15-evaluation.md)
- [Chapter 16 — Guardrails 与 Hallucination](../part2_ai_engineering/chapter-16-guardrails-hallucination.md)
- [Chapter 19 — AI Security](../part2_ai_engineering/chapter-19-ai-security.md)
- [Chapter 20 — AI Observability](../part2_ai_engineering/chapter-20-ai-observability.md)
- [Chapter 22 — Deployment](../part2_ai_engineering/chapter-22-deployment.md)
- [Chapter 10 — Observability](../part1_system_design/chapter-10-observability.md)
- [Chapter 11 — Cost Optimization](../part1_system_design/chapter-11-cost-optimization.md)
