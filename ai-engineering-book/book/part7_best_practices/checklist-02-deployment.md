# Checklist 02 — Deployment Checklist

> 用于任何会改变线上 AI 行为的发布：新 `prompt` 版本、新 `model` 版本、新 `RAG` 索引、新 `embedding` 模型、新 `tool schema` 或 agent 策略。它关注的不是“代码是否能发”，而是“这一组会共同决定输出分布的资产，是否能作为一个可验证、可回滚、可灰度的发布单元进入生产”。

---

## 发布单元与版本绑定

先把“这次到底发布了什么”说清楚；否则事故发生时，你只能回滚代码，回不滚真正改变行为的那部分资产。

- [ ] **[P0] 把 prompt、model、config、index 打成一个原子 release unit**: LLM 输出分布通常由代码外资产共同决定，只给代码打 tag 会让线上结果无法复现。
  - 怎么验证：检查 `release-manifest.yaml` 是否同时包含 `release_id`、`prompt_version`、`model_id`、`provider_region`、`index_version`、`embedding_model`、`tool_schema_version`、`feature_flags`。
    并确认部署产物、trace 与 audit log 都以同一个 `release_id` 关联，而不是分别查不同系统。

- [ ] **[P0] 为每个 release unit 生成不可变 manifest**: 发布后仍允许手工改 prompt 文本或路由配置，等价于绕过了变更管理。
  - 怎么验证：查看 CI 产出的 manifest digest，例如 `sha256(prompt_bundle.tar.gz)`、`sha256(index_snapshot)` 与 `config_checksum`，确认生产只接受签名产物。
    抽查最近一次部署记录，确认没有通过控制台直接改 `system_prompt` 或 `routing_rule`。

- [ ] **[P1] 明确 release boundary 与兼容矩阵**: 同一个 prompt 未必兼容新工具参数；同一个索引也未必兼容旧 embedding 维度。
  - 怎么验证：在 `compatibility-matrix.md` 或发布说明中看到 `prompt_version -> tool_schema_version`、`index_version -> embedding_model`、`model_id -> response_format` 的兼容关系。
    评审时要求给出“不兼容时系统会拒绝启动还是静默降级”的机制说明。

- [ ] **[P1] 把运行时可变开关纳入发布记录**: 很多线上偏差不是主版本变了，而是 retrieval top-k、temperature、reranker 开关被单独改了。
  - 怎么验证：检查 manifest 中是否包含关键运行参数，如 `temperature`、`max_output_tokens`、`retrieval_top_k`、`rerank_enabled`、`tool_timeout_ms`。
    对照配置中心 diff，确认发布窗口内不存在“代码没发，但参数偷偷变了”的旁路变更。

- [ ] **[P1] 为数据与策略资产保留来源与 owner**: prompt 和索引经常由不同团队维护，没有 owner 就没人对质量回归负责。
  - 怎么验证：在 manifest 或 release note 中确认每个资产有 `owner`、`source_repo`、`build_job`、`created_at`、`approval_ticket`。
    随机抽一条线上请求，确认能追溯到对应 prompt 文件、索引构建任务和审批记录。

- [ ] **[P2] 在 PR 或变更单中记录本次只想改变什么分布**: Staff 级发布不是“全量试试看”，而是有意图地控制变量。
  - 怎么验证：查看 launch note 是否明确写出“本次只替换 `model_id`，其余 prompt/index/tool schema 保持不变”或“本次只切换 `index_version`，模型冻结”。
    若同时变更多个资产，要求给出为什么不能拆批发布，以及如何隔离归因。

## 环境一致性与依赖基线

AI 系统的“环境”不只是镜像和配置，还包括供应商模型别名、索引快照、embedding 维度、特征开关和上游数据视图。

- [ ] **[P0] 确保 dev、staging、prod 使用同一类模型标识**: `gpt-4o` 这类浮动别名在不同环境可能解析到不同后端，回归结果会失真。
  - 怎么验证：检查三套环境的配置是否都使用固定 `model_id`，例如 `gpt-4.1-mini-2026-06-18`，而不是仅写一个别名。
    用发布前脚本打印 `resolved_model_id` 与 `provider_region`，确认 staging 与 prod 没有隐式漂移。

- [ ] **[P0] 保证索引快照与 embedding 模型在各环境维度一致**: 维度不匹配不一定立刻报错，但会造成静默召回劣化。
  - 怎么验证：读取 `index_manifest.json`，核对 `embedding_model`、`dimension`、`chunker_version`、`metadata_schema_version`。
    在 staging 跑一次检索 smoke case，确认 ANN 服务返回的向量维度与查询向量完全一致。

- [ ] **[P1] 让 staging 看到与 prod 同分布的数据切片**: 只拿开发样例做回归，会错过真实文档噪声、长尾租户、权限裁剪和多语言分布。
  - 怎么验证：检查 staging 是否加载了生产镜像的脱敏文档快照，或至少有按租户、语言、文档长度分层抽样的数据集。
    查看数据构建作业报告，确认采样覆盖 top tenants、长文档、表格 PDF、近期增量数据。

- [ ] **[P1] 校准 provider 配额、限流和超时基线**: staging 往往流量小、配额宽，不能代表生产 rollout 时的真实背压。
  - 怎么验证：对比各环境的 `rpm`、`tpm`、`concurrency_limit`、`timeout_budget_ms`、`retry_policy` 配置。
    在预发布压测中观察 `429`、排队时延和 token 吞吐，确认 prod 头部容量至少保留既定 headroom。

- [ ] **[P1] 校验 feature flag 与租户路由规则的环境对齐**: 一个 flag 只在 prod 打开，会让 staging 通过的回归在生产失效。
  - 怎么验证：导出各环境的 flag snapshot，核对 `tenant_allowlist`、`tool_enablement`、`provider_fallback_order`、`cache_namespace`。
    重点检查按租户灰度的规则表达式，确认没有引用仅在 prod 存在的 tenant tag。

- [ ] **[P2] 冻结发布窗口内的上游数据口径**: 同时改 ingestion、chunking 和检索配置，会让质量变化无法归因。
  - 怎么验证：在变更单中查看本次发布窗口的冻结范围，确认 `etl_job_version`、`chunker_version`、`reranker_version` 是否被锁定。
    如果必须联动发布，要求生成分阶段 cutover 计划，而不是“一次性全部切换”。

## 灰度、金丝雀与 Shadow

模型发布不能只看 5xx；很多最危险的回归，是回答“看起来正常”，但事实性、引用准确率或工具调用路径已经偏了。

- [ ] **[P0] 先做 shadow，再做 canary**: 对 LLM 来说，先观察新版本在真实请求上的输出分布，比直接吃用户流量更便宜。
  - 怎么验证：检查路由配置是否支持 `read-prod, execute-shadow`，让新 release 复制线上请求但不回写用户结果。
    查看 `shadow_compare_dashboard`，确认至少有回答长度、引用命中率、tool plan 差异、拒答率等对比指标。

- [ ] **[P0] 为 canary 定义逐级放量阈值，而不是固定百分比**: 同样是 5% 流量，低峰和高峰代表的样本量完全不同。
  - 怎么验证：查看 rollout plan 是否以“样本数 + 时间窗 + 指标门槛”控制阶段，如 `1%/500 requests/30 min` 再进 `5%/2k requests/60 min`。
    确认门槛包含质量与稳定性联合条件，而不是只有 HTTP error rate。

- [ ] **[P1] 把模型类指标纳入 canary gate**: 新模型不报错，不代表它没有更高的 hallucination rate 或引用错位。
  - 怎么验证：检查 canary dashboard 是否包含 `answer_accept_rate`、`citation_precision`、`tool_success_rate`、`guardrail_block_rate`、`median_tokens`。
    若没有在线标签，至少用 LLM-as-judge 或规则校验对影子结果做近实时打分。

- [ ] **[P1] 决定模型替换用 blue-green 还是 gradual rollout**: 大模型跨供应商替换常伴随分布突变，直接蓝绿切全量比渐进灰度更危险。
  - 怎么验证：在 launch plan 中写明选择依据：若协议、输出 schema、上下文上限完全一致，可用 blue-green；若输出分布差异大，优先 gradual rollout。
    评审时要求看到上一轮 shadow diff 结果，证明新旧模型分布接近到可以接受的程度。

- [ ] **[P1] 让 canary 支持按租户、功能、地区细粒度 kill switch**: AI 事故通常先出现在某类租户或某种查询上，不能只提供全局回滚。
  - 怎么验证：检查网关或 routing service 是否支持 `release_id + tenant_id + feature` 级别开关。
    实际演练一遍：关闭单个高价值租户的新模型流量，其余租户继续保持 rollout 进度。

- [ ] **[P2] 对 shadow 差异做可解释抽样而不是只看聚合均值**: 均值相近时，长尾失败仍可能显著增加。
  - 怎么验证：在 compare job 中保留按 query class、语言、文档长度、是否触发 tool 的分桶 diff。
    抽查 worst 50 diff 样本，确认不是被总体平均数掩盖了关键长尾回归。

## 索引、Embedding 与缓存迁移

RAG 发布最容易出问题的地方，是“代码切了，但索引、embedding、cache 还活在旧世界里”；这类问题经常不报错，只是答案悄悄变差。

- [ ] **[P0] 迁移 embedding 模型前先确认是否需要全量 re-embedding**: 只换查询侧模型、不重建文档向量，检索会在几乎无告警的情况下失真。
  - 怎么验证：查看迁移计划中是否明确列出 `old_embedding_model -> new_embedding_model` 的兼容性判断与重建范围。
    若供应商、维度、归一化策略、语言覆盖任一改变，就应看到全量或分片 re-embedding 任务。

- [ ] **[P0] 采用 dual index cutover，而不是原地覆盖索引**: 原地替换一旦失败，既无法比较新旧召回，也无法快速回切。
  - 怎么验证：检查检索层是否支持同时持有 `index_v_old` 与 `index_v_new`，并通过 `index_version` 路由。
    在发布日志中确认存在“读旧 / 影子读新 / 双索引对比 / 切主 / 回收旧索引”的分阶段记录。

- [ ] **[P1] 对增量写入执行 read-both、write-new 或 dual-write 策略**: 发布窗口内若仍有新文档进入系统，只建新索引不接增量会产生时间裂缝。
  - 怎么验证：查看 ingestion pipeline 是否在迁移期把新增文档同时写入旧索引和新索引，或至少保证查询阶段能读新旧两套数据。
    检查 `dual_write_lag_seconds`、失败重试队列和补偿作业，确认不存在长时间落后分片。

- [ ] **[P1] 用召回级指标比较新旧索引，而不是只比较最终答案**: 最终答案受模型采样影响，不能单独用来判断检索迁移是否成功。
  - 怎么验证：运行离线检索回放，比较 `recall@k`、`mrr`、`doc_overlap@k`、`citation_coverage`、`empty_hit_rate`。
    对差异最大的 query bucket 做 root cause，区分是 chunking 变化、embedding 变化，还是 metadata filter 漏配。

- [ ] **[P1] 校验 metadata schema 与过滤语义的前后兼容**: 索引重建时最常见的不是向量错，而是过滤字段名或 ACL 语义变了。
  - 怎么验证：检查 `metadata_schema_version`、ACL 字段、租户字段、时间戳字段在新旧索引中的定义。
    用真实过滤条件回放查询，确认新索引不会因为字段缺失而扩大召回范围或误伤合法文档。

- [ ] **[P2] 迁移期间为 cache key 引入 index 与 embedding 维度**: 如果缓存只按 query 文本命中，切索引后你仍可能拿到旧召回结果。
  - 怎么验证：检查 retrieval cache 与 answer cache 的 key 是否至少包含 `index_version`、`embedding_model`、`reranker_version`、`prompt_version`。
    发布前跑一次 cache key dump，确认同一 query 在新旧索引下会生成不同 namespace。

## Agent / Tool 变更发布

Agent 发布的风险不只是“多了一个工具”，而是计划器、tool schema、权限边界和失败处理全都可能一起变化。

- [ ] **[P0] 为 tool schema 做显式版本化**: 仅靠函数名识别工具，新增必填字段或改枚举值时会直接破坏旧 prompt 或旧 planner。
  - 怎么验证：检查工具注册表是否暴露 `tool_name`、`tool_schema_version`、`input_schema_hash`、`deprecation_date`。
    在 staging 调一次 `describe_tools` 或等价接口，确认旧 agent 不会无提示地看到不兼容 schema。

- [ ] **[P0] 把 planner prompt 与工具集合一起发布**: 只改工具不改 planner，模型通常不会自动学会新的调用前提与错误恢复路径。
  - 怎么验证：查看 manifest，确认 `planner_prompt_version` 与 `tool_bundle_version` 被同一 `release_id` 绑定。
    回放典型多步任务，确认 planner 生成的 tool arguments 与新 schema 一致，并能处理工具返回的新错误码。

- [ ] **[P1] 为工具变更准备 capability gating**: 不是所有租户、所有地区、所有模型都应立即看到新工具。
  - 怎么验证：检查 agent gateway 是否支持按 `tenant`、`region`、`model_family`、`feature` 暴露工具能力。
    演练关闭某个高风险工具后，agent 仍能退回到检索回答或安全拒答，而不是循环重试。

- [ ] **[P1] 验证 tool output contract 的后向兼容性**: 工具返回字段顺序、单位、空值语义变化，都会改变模型后续推理链。
  - 怎么验证：在 golden traces 中回放旧版本工具输出与新版本输出，比较 agent 后续 plan、final answer 与 error recovery 差异。
    对关键工具保留 contract test，例如 `tool_response_schema_test`、单位换算样例、空返回样例。

- [ ] **[P1] 对新工具设置独立的 timeout、budget 和 circuit breaker**: agent 在发布日最容易因为一个慢工具把整体 tail latency 拉爆。
  - 怎么验证：检查每个工具是否配置 `timeout_ms`、`retry_budget`、`max_calls_per_turn`、`breaker_threshold`。
    在 staging 故意注入慢调用和 5xx，确认 agent 能及时中断、降级或切到替代路径。

- [ ] **[P2] 记录工具权限与审计边界的变化**: 新增“可写”工具时，发布风险从答案错误升级为真实副作用。
  - 怎么验证：在发布说明中看到哪些工具是 read-only、哪些会产生写操作，以及相应的 approval mode。
    抽查审计日志，确认 tool call 至少记录 `actor`、`tenant`、`tool_schema_version`、`args_hash`、`result_status`。

## 发布后自动验证

上线后第一小时不是“观察一下就好”；应该有自动验证替你做第一轮故障筛查，而且验证对象要覆盖生成质量、检索质量和工具链路。

- [ ] **[P0] 部署完成后立即跑 smoke eval**: 如果最基本的问答、检索、tool call 都过不了，越早阻断越便宜。
  - 怎么验证：触发 `scripts\run_smoke_evals.ps1 --release <release_id>` 或等价流水线，覆盖最小可用集：纯聊天、RAG、单工具、多工具、长上下文。
    要求结果回写到发布工单，不能只在某个人本地终端看一眼。

- [ ] **[P0] 对 golden set 做发布前后 replay diff**: 只有看同一批样本在新旧 release 上的差异，才能把“真实提升”和“随机波动”分开。
  - 怎么验证：运行类似 `python scripts/replay_golden.py --baseline <old_release> --candidate <new_release>` 的任务。
    检查输出是否至少包含通过率变化、引用 diff、token 成本 diff、拒答率变化与 worst regression 样本链接。

- [ ] **[P1] 为关键路径建立结构化断言，而不是只看自由文本**: LLM 输出表面正常时，格式错误、引用缺失、工具遗漏仍可能隐藏在线上。
  - 怎么验证：查看自动验证规则，确认对 JSON schema、引用数量、必须字段、tool call 次数、禁止字段都有机器可判定的断言。
    对问答类样本至少保留“引用必须来自检索结果集”的校验，而不是只做语义相似度打分。

- [ ] **[P1] 监控发布后 token、延迟与缓存命中率的形状变化**: 新 prompt 或新模型经常让输出更长、prefill 更慢、cache 失效更多。
  - 怎么验证：发布后对比 `ttft_p95`、`latency_p95`、`prompt_tokens`、`completion_tokens`、`cache_hit_ratio`、`tool_calls_per_request` 的前后 1 小时曲线。
    若指标跳变超过预设阈值，要求自动暂停继续放量，而不是等人工注意到。

- [ ] **[P1] 抽样审查失败样本的根因归类**: 只知道“通过率下降”还不够，必须分清是模型、检索、工具还是安全策略导致。
  - 怎么验证：在回放报告中为失败样本打上 `generation_error`、`retrieval_miss`、`citation_mismatch`、`tool_timeout`、`guardrail_overblock` 等标签。
    对 top regression bucket 至少做一次人工复核，防止 judge 模型本身误判。

- [ ] **[P2] 为成功发布保留基线报告**: 没有“这次发完是什么样”的基线，下次发布就没有可比较的参照物。
  - 怎么验证：把 smoke eval、golden replay、canary 指标摘要、容量水位和已知例外统一归档到 `release-report/<release_id>.md` 或等价系统。
    确认报告能从值班 runbook 一跳访问，而不是散落在聊天记录和临时脚本输出里。

## 回滚、故障切换与容量风险

AI 发布的回滚对象不是单一二进制；你要能同时回 prompt、model、index、tool bundle、provider 路由和 cache namespace。

- [ ] **[P0] 让回滚以 release unit 为粒度执行**: 只回滚代码、不回滚 prompt 或索引，会制造“代码已旧、数据仍新”的混搭状态。
  - 怎么验证：检查 runbook 是否提供类似 `ops rollback release --to <release_id>` 的一步式操作，而不是要求人工分别改模型、索引和配置。
    在演练中确认回滚后 trace 中的 `prompt_version`、`model_id`、`index_version`、`tool_schema_version` 同时恢复到目标版本。

- [ ] **[P0] 明确 cache 在回滚时是保留、隔离还是清空**: 回滚后继续命中由新 prompt 生成的缓存，会把旧版本重新污染。
  - 怎么验证：检查 answer cache、retrieval cache、tool result cache 是否按 `release_id` 或关键版本字段分 namespace。
    演练回滚后立即发同一请求，确认命中的不是新版本残留条目，而是旧版本空间中的结果。

- [ ] **[P1] 为 provider failover 预留部署期专用策略**: 发布时本来就有额外流量波动，此时再遇到单区域故障，容易把备用通道也压垮。
  - 怎么验证：查看 `provider_fallback_order`、`region_failover_policy`、`max_failover_share` 是否在发布计划中单独声明。
    人工触发主区域 5xx 或超时，确认系统按预定比例切到备区域或备供应商，而不是所有流量瞬间雪崩式切换。

- [ ] **[P1] 校验 failover 后的语义兼容与容量 headroom**: 备用模型能接请求，不代表它能接受同样的上下文长度、工具 schema 或输出格式。
  - 怎么验证：检查备选模型的 `context_window`、`function_calling`、`json_mode`、`rate_limit`、`latency_slo` 是否满足当前功能需求。
    在预演中统计切换后 `429`、`context_overflow`、格式解析失败率，确认 headroom 足够覆盖发布期峰值。

- [ ] **[P1] 为高风险发布准备按租户或功能局部回退**: 全局回滚有时代价过大，尤其在只影响某类工作流时。
  - 怎么验证：检查 routing service 是否支持 `rollback_scope=tenant|feature|region`，以及对应的审批和审计记录。
    用真实配置演练一次“仅回退企业检索问答，不回退通用聊天”的场景，确认局部回退不会破坏共享缓存和会话状态。

- [ ] **[P2] 把发布期容量观测纳入值班手册**: 模型切换时的 token 形状变化，经常比 QPS 变化更早暴露风险。
  - 怎么验证：在 runbook 中看到值班人需要盯的指标：`input_tpm`、`output_tpm`、`ttft_p95`、`queue_depth`、`provider_429_rate`、`failover_share`。
    确认这些 dashboard 已经按 `release_id` 与 `provider_region` 维度切分，便于定位是哪一批流量在抖动。

## 常见反例

| 反例 | 为什么危险 | 正确做法 |
|---|---|---|
| 只回滚代码，不回滚 `embedding index` 版本 | 检索仍来自新索引，生成逻辑却回到旧 prompt，引用与答案会出现跨版本错配 | 以 `release_id` 为原子回滚，保证 prompt、model、index、tool bundle 同步恢复 |
| canary 只看错误率，不看 hallucination / citation 指标 | LLM 最常见的退化不是 500，而是“答错但看起来像对” | 在 canary gate 中加入引用准确率、拒答率、tool success rate、answer acceptance 等质量指标 |
| 迁移 embedding 模型时不重建文档向量 | 查询向量和文档向量落在不同空间，召回会静默恶化 | 明确兼容性判断；模型、维度或归一化策略变化时执行 re-embedding + dual index cutover |
| 复用旧 cache key，不把 `prompt_version` / `index_version` 编进去 | 发布后仍命中新版本前的回答或检索结果，导致线上表现不可解释 | 让 answer/retrieval cache 至少包含 `release_id` 或关键版本字段，并支持回滚隔离 |
| 新工具上线只改 schema，不改 planner prompt | 模型不知道何时调用新工具，也不知道新错误码怎么恢复 | 把 planner prompt 与 tool bundle 作为同一发布单元，并回放多步任务验证 |
| blue-green 一次切全量到新模型，没有 shadow diff | 新旧模型输出分布不同，问题会在全量用户上同时爆发 | 先 shadow，对差异做分桶分析；只有协议和分布都足够接近时才考虑蓝绿 |
| 发布时把主区域故障切换逻辑留给默认 SDK 重试 | SDK 重试不了解全局配额，容易在峰值时把备用区域一起打爆 | 明确 provider/region failover policy、切流比例和容量 headroom，并在发布前演练 |

## 关联章节

- [Chapter 22 — Deployment](../part2_ai_engineering/chapter-22-deployment.md)：发布流水线、灰度与回滚的总设计。
- [Chapter 17 — Streaming & Long Context](../part2_ai_engineering/chapter-17-streaming-long-context.md)：模型切换后 `TTFT`、长上下文成本与流式体验的变化。
- [Chapter 20 — AI Observability](../part2_ai_engineering/chapter-20-ai-observability.md)：如何按 `release_id` 观察质量、延迟、tokens 与 tool 链路。
- [Chapter 02 — Gateway, Proxy & Load Balancer](../part1_system_design/chapter-02-gateway-proxy-lb.md)：按租户、地区、功能做流量分流、限流与 kill switch。
- [Chapter 08 — Scheduler](../part1_system_design/chapter-08-scheduler.md)：re-embedding、双写补偿、golden replay 与发布后批处理验证任务。

