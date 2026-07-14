# Checklist 08 — Agent Checklist

> 用于评审任何会自主分步决策、调用 tool、写入外部系统，或会进一步派生 sub-agent 的系统。只要它不是“一次请求、一次回答”的简单调用，而是一个 agent loop，就应该在上线前过这份清单。

---

## 任务是否真的需要 Agent

先判断“要不要做成 agent”，再讨论“agent 怎么做”。大部分系统先输在问题建模，而不是输在 prompt。

- [ ] **[P0] 先拿 deterministic workflow / DAG 做基线对比**：如果任务可以用固定步骤、显式分支和少量规则稳定完成，agent loop 只会引入更高成本、更差可预测性和更难排障的执行路径。
  - 怎么验证：针对同一批真实任务，比较 single LLM call、workflow/DAG、agent loop 三种方案的成功率、P95 latency、平均 token、外部 API 调用次数和人工介入率。

- [ ] **[P0] 明确任务是否包含开放式搜索或不完全信息决策**：Agent 的价值通常来自“边走边看、边调用 tool 边修正计划”；如果输入完备、步骤固定，额外的规划环节没有价值。
  - 怎么验证：把任务拆成输入是否完备、步骤是否稳定、是否需要中途发现新信息三列；若三列都偏“确定”，默认退回 workflow。

- [ ] **[P0] 把“推理”与“执行”分开设计**：很多系统真正需要的是 LLM 生成参数、分类或选择路径，而不是一个拥有持续控制权的 agent。
  - 怎么验证：检查架构图，确认是否可以把系统改写为“LLM 产出结构化决策 + 代码执行固定流程”；若可以，说明 agent 不是默认解。

- [ ] **[P1] 为 agent 成功标准定义可检查的终态**：没有终态定义，agent 很容易把“继续尝试”误当成“继续逼近目标”，最终变成长时间试错循环。
  - 怎么验证：查看任务定义，确认存在 machine-checkable completion condition，例如状态变更成功、SQL 结果满足约束、工单字段被正确更新，而不是“模型觉得完成了”。

- [ ] **[P1] 先证明任务需要中间观察（observation）才能前进**：如果每一步都不依赖前一步真实返回值，而只是在“模拟思考”，多步 loop 只是把一次调用拆成多次收费。
  - 怎么验证：抽样 20 条运行轨迹，确认后续 action 的参数确实由前一步 observation 改变，而不是反复调用不同 wording 的同类 tool。

- [ ] **[P1] 为 agent 设计可退化的 simpler path**：即使长期目标是 agent，也应该保留一个可以覆盖主路径的低复杂度 fallback，避免 provider 漂移或 tool 故障时整条链路失效。
  - 怎么验证：检查运行时路由，确认存在“任务类型 A 走 workflow，只有任务类型 B 才走 agent”的开关，而不是所有请求统一进入 loop。

- [ ] **[P2] 用真实失败样本而不是 demo 决定是否上 agent**：Demo 往往放大 agent 的“灵活”，却掩盖其在脏数据、权限错误、超时和部分成功场景下的脆弱性。
  - 怎么验证：评审材料里必须包含线上历史 case、长尾异常、权限受限样本和跨系统不一致样本，而不是只看 happy path 演示。

## 规划与状态管理

Agent 不是“多轮 prompt”这么简单；它本质上是一个长生命周期状态机。没有状态设计，恢复、回放和审计都会失真。

- [ ] **[P0] 把 plan / state 设计成显式数据结构，而不是只藏在 prompt 里**：隐藏状态无法做持久化、差异比较、版本迁移，也无法被外部系统安全读取。
  - 怎么验证：检查 run schema，确认至少有 goal、current_plan、completed_steps、artifacts、tool_results、stop_reason 等字段，并有独立存储。

- [ ] **[P0] 为每次运行分配稳定的 run_id 与 checkpoint**：没有稳定标识，崩溃恢复、重试去重、审计追踪和跨服务串联都会变得不可靠。
  - 怎么验证：从一条生产 trace 反查数据库，确认能通过 run_id 找到该次运行的 plan 版本、每一步 observation、每次 tool call 和最终结果。

- [ ] **[P0] 崩溃恢复必须能 resume，而不是从头 replay**：对外部系统有副作用的 tool 一旦被重放，最常见后果就是重复下单、重复发信、重复删改数据。
  - 怎么验证：故意在 side-effecting tool 成功后、agent 写最终答案前注入崩溃，确认恢复逻辑会从最近 checkpoint 继续，且不会重复执行已提交 action。

- [ ] **[P0] 把“已观察到什么”和“下一步想做什么”分离存储**：把 observation 与 plan 混在同一自由文本字段里，后续既难做程序校验，也难检测 agent 是否基于过期信息行动。
  - 怎么验证：检查状态模型，确认 tool output、planner decision、executor command 是独立字段，且都带时间戳和来源。

- [ ] **[P1] 定义 re-plan 触发条件，而不是每步都重写整份计划**：无限制重规划会让 agent 在局部噪声下反复推翻原计划，表现为“看起来很忙，实际没推进”。
  - 怎么验证：查看 planner 逻辑，确认只有在目标变化、关键假设失效、tool 返回硬错误或发现新约束时才触发 re-plan。

- [ ] **[P1] 区分 source of truth 与 scratchpad**：临时思考、草稿总结、候选方案可以是易变的；业务状态、工具结果和审批记录必须进入结构化、可复现的 source of truth。
  - 怎么验证：检查存储层，确认 scratchpad 清理不会影响 resume；删除 scratchpad 后仍能从结构化状态恢复执行。

- [ ] **[P1] 为状态 schema 做版本化和兼容迁移**：Agent 往往是长运行或延迟恢复的任务；升级代码后无法读旧状态，会直接把未完成任务变成“孤儿 run”。
  - 怎么验证：检查 state_version、migration 脚本和回放测试，确认旧 run 能在新版本代码上继续执行或被安全终止。

## 工具治理

Tool 是 agent 的真实执行面。模型是否“聪明”排在第二位；第一位是 tool contract 是否稳定、最小权限、可安全重试。

- [ ] **[P0] 每个 tool schema 都要有显式版本和兼容策略**：参数名、枚举值、默认行为一旦漂移，旧 prompt 或旧 policy 会在无编译错误的情况下 silently break。
  - 怎么验证：查看 tool registry，确认存在 schema_version、deprecation policy 和 contract test；变更时能同时支持旧版一段时间或明确阻断。

- [ ] **[P0] 对 tool 权限实行 least privilege 和 deny-by-default**：Agent 不应因为“未来可能有用”而默认拿到全库读写、全组织搜索或生产删除权限。
  - 怎么验证：检查不同 agent role 的 tool allowlist，确认只暴露该任务需要的最小集合，且写操作需要独立 scope。

- [ ] **[P0] 所有有副作用的 tool 都要支持 idempotency key**：重试不可避免；没有幂等键，网络抖动会把一次 action 变成多次提交。
  - 怎么验证：检查 create/update/send/pay/delete 类 API，确认请求包含可追踪的 idempotency_key，重复提交返回同一业务结果而不是再次执行。

- [ ] **[P0] 把 dry-run / preview 与 commit 分成两个 tool 或两个模式**：让 agent 先拿到 diff、影响范围和风险摘要，再决定是否真正执行，可以显著降低误操作概率。
  - 怎么验证：查看危险 tool 设计，确认存在 preview 接口，且生产策略要求先 preview、后 approval、再 commit。

- [ ] **[P1] 为每个 tool 单独定义 timeout、retry 和 circuit breaker**：数据库查询、搜索、支付、发信的失败语义不同，统一“失败就重试三次”通常会制造更多副作用。
  - 怎么验证：检查 tool policy 配置，确认 retry 只作用于 transient error，side-effecting tool 默认不做盲重试，并能在连续失败时熔断。

- [ ] **[P1] 对 tool 输出做 typed validation 和 normalization**：Agent 如果直接消费松散文本，很容易把“未找到”“权限不足”“部分成功”混成同一种 observation。
  - 怎么验证：检查 executor，确认 tool output 会先被解析成结构化结果，至少区分 success、retryable_error、fatal_error、partial_success。

- [ ] **[P1] 冻结每次发布可见的 tool catalog**：运行中动态热插入未评审 tool，会让同一 prompt、同一请求在不同时间看到不同能力边界，破坏可复现性。
  - 怎么验证：检查 release manifest，确认一次发布对应固定的 tool 列表、schema hash 和 policy 版本，运行态不会临时扩权。

## Human-in-the-Loop（HITL）

HITL 不是“让人兜底”，而是把不可逆、高损失、高歧义动作放在明确的审批边界之后执行。

- [ ] **[P0] 对 destructive / irreversible action 强制人工确认**：转账、删库、发送外部邮件、修改权限、发布到生产等动作，不应由 agent 直接落地。
  - 怎么验证：检查 policy，确认 payment、delete、send_email、grant_access、deploy 等 tool 在无 approval token 时无法执行。

- [ ] **[P0] 审批前必须向人展示精确的 action payload**：只有“你要继续吗”没有意义；审批人需要看到目标对象、参数、diff、影响范围和回滚方式。
  - 怎么验证：抽样 approval UI 或日志，确认展示的是结构化 payload、变更前后 diff、风险级别和 requestor/run_id，而不是一句自然语言摘要。

- [ ] **[P1] 对高风险动作使用 two-person rule 或角色分离**：当 agent 可以动到金钱、隐私或生产可用性时，单人点击确认仍然过于脆弱。
  - 怎么验证：检查审批流，确认高风险类别需要第二审批人或独立角色确认，且审批人与发起人不能是同一主体。

- [ ] **[P1] 人工修正必须写回结构化状态，而不是只在聊天框里说一句**：如果人类只是“口头纠偏”，agent 下一步可能仍基于旧状态继续执行。
  - 怎么验证：检查 pause/resume 机制，确认人工修改会更新 plan/state 字段、失效旧计划并留下审计记录。

- [ ] **[P1] 设定 approval 的有效期和上下文绑定**：批准“删除 A”不应被 agent 复用到“删除 B”；过期审批也不应在状态变化后继续有效。
  - 怎么验证：检查 approval token，确认绑定 run_id、tool_name、normalized_args、过期时间和审批版本。

- [ ] **[P1] 为等待人工输入的 run 设计暂停、超时和撤销语义**：无限等待的 run 会占住资源、留下一堆悬挂状态，且用户通常不会知道当前系统停在哪。
  - 怎么验证：查看状态机，确认 pending_human_approval 有 SLA、到期处理策略和显式通知渠道，超时后会自动 abort 或回滚。

- [ ] **[P2] 对人工 override 做可审计的理由记录**：长期看，override 数据是改进 prompt、tool policy 和审批门槛的重要反馈源。
  - 怎么验证：抽样审计日志，确认每次人工批准、拒绝、改参或强制终止都有 operator、时间、理由和关联轨迹。

## 终止条件与失控防护

能开始不代表能结束。上线前要先证明这个 loop 在坏路径上也会停，而且停得可预期。

- [ ] **[P0] 同时设置 max_steps 和 wall-clock timeout**：只设步数不设时间，慢 tool 会把一次 run 拖成几十分钟；只设时间不设步数，快循环会在几秒内烧掉大量 token。
  - 怎么验证：检查服务端 enforcement，确认两个阈值都由 orchestrator 强制执行，而不是仅靠 prompt 提醒模型“不要太久”。

- [ ] **[P0] 实现 repeated-action detector**：同一个 tool + 归一化后的同一组参数被连续调用 N 次，通常不是“更接近成功”，而是 agent 已经卡死。
  - 怎么验证：用回放测试构造同参重试场景，确认系统会在阈值命中时 abort，并把 stop_reason 标成 repeated_action。

- [ ] **[P0] 检测 no-progress loop，而不是只检测同参循环**：参数不同但 observation 没有新增信息，仍然是 loop，只是换了一种 wording。
  - 怎么验证：检查是否对 observation 做 hash/semantic diff；当连续几步没有新增 artifact、状态未推进或错误类别不变时，系统应停止或升级处理。

- [ ] **[P1] 限制递归深度和子目标展开深度**：planner 很容易把一个模糊目标不断拆成更多模糊目标，最终形成 fan-out 爆炸而不是真实推进。
  - 怎么验证：检查 orchestrator 配置，确认 subgoal depth、reflection 次数和 self-critique 次数都有硬上限。

- [ ] **[P1] 为 provider / parser / tool failure 设置错误预算**：某一步失败后直接无限重试，是最常见的成本事故来源之一。
  - 怎么验证：查看 error policy，确认对同类错误有 per-run retry budget；超过阈值后会降级、转人工或终止，而不是继续试。

- [ ] **[P1] 暴露明确的 stop_reason 给上游和日志系统**：不知道“为什么停”的 agent，无法做运营分流、用户提示或后续自动恢复。
  - 怎么验证：抽样运行记录，确认 completion、budget_exhausted、timeout、repeated_action、approval_timeout、fatal_tool_error 等 stop_reason 可查询。

- [ ] **[P1] 提供 operator kill switch 和 rollout kill switch**：当模型版本漂移、tool 权限误配或批量任务异常时，必须能快速停掉单次 run 和整类流量。
  - 怎么验证：在 staging 演练强制停止，确认停止后不会继续发起新 tool call，且已有 side effect 有清晰的补救手册。

## 成本与步数预算

Agent 的成本不是“多几个 token”这么简单，而是 token、tool、外部 API、人工审批和长尾重试叠加后的单位经济性问题。

- [ ] **[P0] 对每次 run 施加服务端 token / cost hard cap**：预算如果只写在 prompt 里，本质上只是建议，不是控制。
  - 怎么验证：检查 orchestrator 代码，确认会实时累计 prompt_tokens、completion_tokens、tool 成本和外部 API 花费，超过阈值立即硬停止。

- [ ] **[P0] 把预算分配到阶段，而不是一个总额通吃**：planning、retrieval、execution、reflection 全抢同一个池子时，前半段很容易把后半段预算花光。
  - 怎么验证：查看 budget config，确认至少有 planner_budget、execution_budget、tool_budget 或等价分桶，并记录各阶段实际消耗。

- [ ] **[P1] 在高成本动作前做成本预估**：大上下文 summarize、全仓代码搜索、批量 API fan-out 或多 agent 派生，都应该在执行前先问“这一步值不值”。
  - 怎么验证：检查策略，确认在扩展上下文、批量检索或 spawn sub-agent 前会估算预期 token / latency / API 次数，并与剩余预算比较。

- [ ] **[P1] 为不同任务和租户配置不同预算档位**：高价值、低频任务和低价值、高频任务不应共享同一 cost profile。
  - 怎么验证：查看配置中心，确认预算按 task_type、tenant_tier、environment 或 user role 区分，而不是全局一个数字。

- [ ] **[P1] 把 expensive tool 单独计费并限额**：很多系统的主要成本不在 LLM，而在搜索、浏览器自动化、第三方 SaaS API 或代码执行。
  - 怎么验证：检查 metering，确认 tool 调用次数、每类工具成本和超限告警可单独观测，且能阻止某类工具被无限刷。

- [ ] **[P1] 预算耗尽时要有 graceful degradation**：硬停是必要的，但用户还需要知道当前做到哪一步、哪些结果可信、接下来怎么补救。
  - 怎么验证：构造 budget exhausted 场景，确认系统返回 partial artifacts、stop_reason、可重试入口或人工接管路径，而不是简单 500。

- [ ] **[P2] 用 trajectory 级单位经济性评审 agent**：看单次 demo 的“完成了”没有意义，关键是平均要走几步、要调多少 tool、成本波动多大。
  - 怎么验证：查看周报或 dashboard，确认有 cost per successful run、median steps、P95 tool calls、人工复核率和失败后补救成本。

## 多 Agent 协作风险

多 agent 不是“多开几个线程”这么简单；它会同时放大状态同步、责任边界、资源放大和评测难度。

- [ ] **[P0] 限制 sub-agent 的 spawn depth、count 和 concurrency**：不加边界的 supervisor 很容易把一个问题扩成指数级 fan-out，最后把预算和队列都打爆。
  - 怎么验证：检查 orchestrator，确认存在 max_spawn_depth、max_children_per_parent、max_concurrent_agents 等硬限制，并有命中日志。

- [ ] **[P0] 为共享状态定义 owner 和写入规则**：多个 agent 同时写同一个 plan、同一个 artifact 或同一业务对象，最容易出现 race condition 和最后写入覆盖。
  - 怎么验证：检查状态存储，确认共享字段有 optimistic lock、version check、租约锁或单写者原则，而不是任何 worker 都能直接改。

- [ ] **[P1] 隔离 worker memory，只把审核过的摘要写回 shared state**：让所有 sub-agent 直接共享长上下文，会快速造成噪声扩散、上下文膨胀和错误相互污染。
  - 怎么验证：查看通信设计，确认 worker 只能提交结构化产物或 summary，不能把整段 scratchpad 原样广播给其他 agent。

- [ ] **[P1] 用 task registry 避免重复劳动**：两个 worker 同时去查同一对象、跑同一搜索或写同一文件，是多 agent 系统最常见的隐性浪费。
  - 怎么验证：检查是否存在 task_id / artifact_id 去重机制；构造重复委派场景，确认后发任务会合并、拒绝或复用已有结果。

- [ ] **[P1] 为 agent 间通信定义固定协议，而不是自由对话**：自由文本协作看似灵活，但很难校验、归档和自动消费，且极易引入歧义。
  - 怎么验证：检查 coordinator 与 worker 的接口，确认使用结构化 message schema，至少包含任务目标、输入依赖、输出格式和状态码。

- [ ] **[P1] 把最终决策权收敛到单一 coordinator**：如果多个 worker 都能直接对外提交结果或执行副作用，系统将失去一致性和责任归属。
  - 怎么验证：查看执行流，确认只有 coordinator 或受控 executor 能调用 commit 类 tool，worker 只能提案或产出中间 artifact。

- [ ] **[P1] 让取消、超时和预算信号向下传播**：父 agent 已经超时或被终止，子 agent 还在继续跑，是多 agent 资源泄漏的典型形态。
  - 怎么验证：在 staging 终止父 run，确认所有子 agent 会收到 cancel signal、停止新 tool call 并回收占用资源。

## 轨迹评测与可观测性

Agent 系统不能只看 final answer；同样答案，走 3 步和走 30 步，工程质量完全不是一个等级。

- [ ] **[P0] 记录完整 trajectory**：plan、每一步 prompt、tool calls、tool args、observation、state diff、approval、stop_reason 都是排障和审计必需证据。
  - 怎么验证：抽样一条线上 run，确认可以按时间顺序还原完整轨迹，而不是只能看到最后答案或零散日志。

- [ ] **[P0] 评测时同时衡量结果正确性与路径合理性**：final answer 对，不代表路径对；如果它靠多余步骤、错误工具或偶然命中完成，生产上仍然不可靠。
  - 怎么验证：在 eval report 中加入 step count、unique tool count、无效 tool ratio、重复动作次数和是否命中不必要 HITL 的指标。

- [ ] **[P1] 单独评测 tool-call correctness**：Agent 失败很多时候不是“不会想”，而是“会想但不会正确调用工具”。
  - 怎么验证：构造带标准 action 的数据集，检查 tool 选择、参数填写、顺序依赖和错误处理是否正确，而不仅是最终回答文本像不像。

- [ ] **[P1] 用 golden trajectories 做回归，而不只用 golden answers**：模型、tool schema 或 planner policy 小改动后，答案可能一样，但路径已经明显退化。
  - 怎么验证：保存一组代表性基线轨迹；每次发布对比步骤数、工具序列、关键状态转移和 stop_reason 是否漂移。

- [ ] **[P1] 支持 stubbed replay 和 deterministic simulation**：很多生产 bug 无法稳定复现，必须靠录制 observation 或 mock tool 输出来复盘。
  - 怎么验证：检查测试框架，确认能在不访问真实外部系统的前提下重放一条 run，并复现相同的 planner / executor 决策。

- [ ] **[P1] 对失败轨迹做 taxonomy，而不是只看“失败率”**：timeout、budget_exhausted、approval_timeout、tool_4xx、tool_5xx、parser_error 的治理手段完全不同。
  - 怎么验证：查看 dashboard，确认失败按根因分类，且每类都有趋势、样本链接和 owner，而不是一个笼统的 failed 数字。

- [ ] **[P2] 对高成本或高风险 run 做人工轨迹抽检**：自动指标能发现“坏”，但很难判断“为什么路径设计不优雅”。
  - 怎么验证：建立每周抽检机制，评审记录里包含轨迹点评、无效步骤分析、策略调整建议和后续实验结论。

## 常见反例

| 反例 | 为什么危险 | 更合理的替代 |
|---|---|---|
| 用 agent 做一个规则三行代码就能写清楚的任务 | 引入额外 latency、token 和不可预测路径，且没有任何能力增益 | 改成 deterministic workflow 或普通后端逻辑 |
| 把 plan、状态、审批都塞在 prompt 里 | 崩溃后无法恢复，升级后无法迁移，也无法做审计 | 用结构化 state store + checkpoint |
| 危险操作（转账 / 删除 / 发邮件）没有人工确认直接执行 | 一次 hallucination 或参数误填就会变成真实事故 | preview + explicit HITL approval + commit |
| 同一个 tool 报错后无限重试 | 最终通常不是修复成功，而是把成本和副作用放大 | 为每类错误设置 retry budget、熔断和 stop_reason |
| 多个 sub-agent 共享一段长聊天记录自由协作 | 噪声扩散、上下文膨胀、责任不清，且极难复盘 | coordinator + 结构化消息协议 + 共享状态最小化 |
| 只评 final answer，不评轨迹 | 可能用 20 步绕远路才碰巧成功，上线后成本不可控 | 评测 step efficiency、tool correctness 和 stop pattern |
| 预算只写在 system prompt 里 | 模型不一定遵守，真正超支时也拦不住 | 服务端 hard cap + 实时计量 |

## 关联章节

- [Chapter 12 — Agent](../part2_ai_engineering/chapter-12-agent.md)
- [Chapter 13 — Multi-Agent](../part2_ai_engineering/chapter-13-multi-agent.md)
- [Chapter 14 — Planning & Reflection](../part2_ai_engineering/chapter-14-planning-reflection.md)
- [Chapter 18 — Workflow & HITL](../part2_ai_engineering/chapter-18-workflow-hitl.md)
- [Chapter 05 — Function / Tool Calling](../part2_ai_engineering/chapter-05-function-tool-calling.md)
