# 第十一章：多智能体系统

单个 Agent 很强，但它不一定适合所有问题。现实世界里，复杂任务往往天然具有分工：有人搜集信息，有人做分析，有人负责审稿，有人做最终决策。多智能体系统（multi-agent system）正是把这种组织结构搬进 AI 系统里。

从转行与面试角度看，多智能体不是“更酷的 demo”，而是你是否具备**系统拆分、协作协议设计、成本与延迟权衡、故障控制**能力的试金石。

## 11.1 为什么需要多智能体

单 Agent 常见瓶颈：

1. 工具集过大，选择困难；
2. 上下文过长，推理噪声增加；
3. 既要检索、又要写作、又要审校，角色冲突；
4. 单次失败影响整个任务；
5. 很难并行。

而多 Agent 的核心收益有四个：

- **专业化（specialization）**：每个 Agent 只做一类事；
- **并行化（parallelism）**：多个子任务同时执行；
- **可替换（replaceability）**：某个 Agent 可独立迭代；
- **可治理（governability）**：更容易限制权限和审计。

但要牢记一句话：**多 Agent 不是免费午餐**。你把一个模型调用拆成 3 个 Agent，成本、延迟、协调复杂度通常会同步上升。

## 11.2 五种多智能体通信模式

### 11.2.1 Sequential Chain（顺序链）

最简单的模式：Agent A 输出交给 Agent B，再交给 Agent C。

```text
User Task
   |
   v
[Researcher] --> [Writer] --> [Reviewer] --> Final Output
```

适用场景：

- 数据清洗 → 生成报告 → 质量检查；
- 检索 → 总结 → 翻译；
- 需求理解 → 代码生成 → 测试建议。

优点：

- 结构清晰；
- 调试简单；
- 每步职责明确。

缺点：

- 串行延迟高；
- 上游错误会层层传递；
- 中间格式必须设计好。

### 11.2.2 Parallel Fan-out（并行扇出）

由一个 orchestrator（编排器）把任务分发给多个 Agent 并行执行，再聚合结果。

```text
                 +--> [Agent A: 法规检索] ---+
User Task --> Orchestrator --> [Agent B: 市场数据] --+--> Synthesizer
                 +--> [Agent C: 技术趋势] ---+
```

适合：

- 多来源调研；
- 多城市、多国家对比；
- 多候选方案评估。

它通常能把 15 秒串行任务压缩到 5~6 秒，但代价是同时消耗更多 token 与 API quota。

### 11.2.3 Hierarchical（层级式）

Supervisor Agent（主管 Agent）负责规划和分配，Specialist Agents（专家 Agent）负责执行。

```text
                 +--> [Search Specialist]
[Supervisor] ----+--> [Coding Specialist]
                 +--> [Review Specialist]
```

这是企业里最常见、也最像组织结构的模式。主管 Agent 不一定自己做事，而是：

- 拆任务；
- 指派角色；
- 跟踪进度；
- 决定是否重试或改派。

### 11.2.4 Debate / Adversarial（辩论 / 对抗）

多个 Agent 持不同立场，最后由裁判或聚合器综合。

例如：

- Agent A：支持采用 LangGraph；
- Agent B：反对，强调维护成本；
- Judge：根据证据做综合结论。

这种模式适合：

- 决策质量要求高；
- 需要显式暴露争议点；
- 防止单模型过早收敛。

但成本高，且若没有证据约束，很容易变成“高 token 的空谈”。

### 11.2.5 Swarm（群体式）

Swarm 指没有强中心控制，Agent 根据能力和局部状态自组织完成任务。它更接近分布式系统而不是简单工作流。

适合：

- 大规模模拟；
- 动态任务市场；
- 去中心化协作实验。

工程落地难点最大，包括：

- 发现机制；
- 冲突解决；
- 重复劳动抑制；
- 全局终止条件。

对转行求职者来说，理解概念即可，真正项目中最常见还是顺序链、并行扇出和层级式。

## 11.3 编排设计（Orchestration Design）

### 11.3.1 中央编排器模式

中央编排器模式中，所有任务调度由一个核心组件控制：

```text
                   +-------------------+
                   |   Orchestrator    |
                   +---------+---------+
                             |
        +--------------------+--------------------+
        |                    |                    |
        v                    v                    v
   [Agent A]            [Agent B]            [Agent C]
```

优点：

- 逻辑集中，便于监控；
- 权限控制容易；
- 失败恢复可统一处理。

缺点：

- 单点瓶颈；
- 中心调度可能成为延迟热点；
- 可扩展性受限。

### 11.3.2 去中心化 Peer-to-Peer

Agent 之间直接通信，没有唯一中央调度者。

优点：

- 灵活；
- 可扩展；
- 某种程度上更鲁棒。

缺点：

- 协议设计复杂；
- 状态一致性难；
- 调试非常痛苦。

在面试中，如果对方问“生产里你更偏好哪种？”大多数场景下回答**中心编排优先**是更稳妥的。

### 11.3.3 Blackboard / Shared Memory（黑板模式）

黑板模式借鉴经典 AI：所有 Agent 从共享内存空间读取任务与事实，再写回结果。

```text
           +------------------------+
           |   Shared Blackboard    |
           | task / evidence / logs |
           +-----------+------------+
                       ^
          +------------+------------+
          |            |            |
      [Agent A]    [Agent B]    [Agent C]
```

适合：

- 需要共享证据；
- 多 Agent 逐步完善同一结果；
- 长任务可断点续跑。

共享黑板常落地为：

- Redis；
- Postgres；
- 文档数据库；
- 事件总线 + 状态存储。

## 11.4 多智能体框架对比

| Framework | Pattern | Strengths | Weaknesses | Best For |
|---|---|---|---|---|
| CrewAI | Role-based sequential / hierarchical | 概念直观、上手快、适合 demo | 状态控制不够细、复杂图编排一般 | 内容生产、轻量团队协作 |
| AutoGen | Conversational multi-agent | 对话式协作灵活、适合研究型实验 | 对生产治理要求高、token 成本易失控 | 原型验证、agent chat |
| LangGraph | Graph/state machine | 状态显式、可控、适合生产级复杂流程 | 学习曲线更陡 | 可恢复工作流、复杂编排 |
| Claude Code Coordinator | Supervisor + specialists | 工程任务分工自然、适合代码/CLI 任务 | 依赖具体执行环境 | 开发代理、命令执行协作 |
| OpenAI Swarm | Lightweight handoff | handoff 简单、概念清晰 | 更偏实验与轻编排 | 小型多 Agent 切换 |

面试时最好不要只背框架名字，而要说明你选型的理由。例如：

> 如果任务高度状态化、需要 checkpoint 和人工审核，我更倾向 LangGraph；如果只是角色分工清晰的内容任务，CrewAI 足够。

## 11.5 实际难题：多 Agent 比单 Agent 更容易出事

### 11.5.1 成本爆炸

假设一个单 Agent 任务平均 8k input token + 2k output token。如果拆成 3 个 Agent：

- Researcher：6k + 1k
- Writer：8k + 2k
- Reviewer：7k + 1k
- Orchestrator：3k + 0.5k

总量可能从 10k 变成 28.5k token，直接接近 3 倍。你必须问自己：质量提升是否值得这 3 倍成本？

### 11.5.2 协调失败与死锁

常见失败：

- Agent A 等 Agent B 结果，B 又在等 A；
- 多个 Agent 重复做同一件事；
- 上下游输出格式不兼容；
- 一个 Agent 无限请求“再给我更多上下文”。

解决思路：

- 显式任务状态机；
- 每个 Agent 最大轮数限制；
- 明确定义输入输出 schema；
- central timeout + cancellation。

### 11.5.3 上下文共享

共享太少：

- Agent 缺背景，做错事。

共享太多：

- token 成本高；
- 隐私边界模糊；
- 噪声干扰判断。

实践建议：

- 共享摘要，不共享全量；
- 共享证据链接，不共享全文；
- 共享结构化 facts，不共享冗长聊天。

### 11.5.4 调试困难

单 Agent 调试只看一条 trace，多 Agent 要看：

- 谁发给谁；
- 每个 Agent 看到了什么上下文；
- 是谁做的最终决策；
- 某条错误信息是否被正确传播。

所以必须记录：

- agent_id
- parent_task_id
- message_id
- input snapshot
- output snapshot
- latency
- token usage

### 11.5.5 延迟管理

多 Agent 最大的用户体验问题常常不是错，而是慢。

优化手段包括：

- 并行优先；
- 设定最快足够策略（good-enough threshold）；
- 提前流式返回中间进度；
- 对稳定中间结果做缓存；
- 对 Reviewer 只检查高风险段落，而非全文重审。

## 11.6 示例：构建一个 3 Agent 研究团队

目标：给用户生成一份“某技术主题研究报告”。

角色分工：

1. **Researcher Agent**：搜索、收集事实；
2. **Writer Agent**：把资料整合成报告；
3. **Reviewer Agent**：检查准确性、缺口和表达质量。

### 11.6.1 通信架构图

```text
                            +----------------------+
                            |   User / Client      |
                            +----------+-----------+
                                       |
                                       v
                            +----------+-----------+
                            |   Orchestrator       |
                            | task_id / state /    |
                            | retries / timeouts   |
                            +----+-----------+-----+
                                 |           |
                                 |           |
                                 v           |
                      +----------+-----+     |
                      | Researcher     |-----+
                      | search, fetch  |     |
                      +----------+-----+     |
                                 | evidence  |
                                 v           |
                      +----------+-----+     |
                      | Writer         |-----+
                      | draft report   |     |
                      +----------+-----+     |
                                 | draft     |
                                 v           |
                      +----------+-----+     |
                      | Reviewer       |-----+
                      | critique, fix  |
                      +----------------+
```

### 11.6.2 完整 Python 示例

下面给一个最小可运行版本。为避免依赖真实模型 API，这里用简单函数模拟三个 Agent 的行为，重点展示 orchestration 结构。

```python
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List


def fake_search(topic: str) -> List[str]:
    corpus = {
        "mcp": [
            "MCP uses JSON-RPC 2.0 as the base protocol.",
            "MCP supports tools, resources, prompts and sampling.",
            "MCP commonly runs over stdio, HTTP+SSE or WebSocket."
        ],
        "a2a": [
            "A2A focuses on agent-to-agent task coordination.",
            "Agent Cards advertise capabilities and auth requirements.",
            "OAuth 2.1 is commonly used for authentication."
        ],
    }
    return corpus.get(topic.lower(), [f"No data found for {topic}"])


@dataclass
class AgentMessage:
    sender: str
    content: str


class ResearcherAgent:
    name = "researcher"

    def run(self, topic: str) -> Dict[str, List[str]]:
        facts = fake_search(topic)
        return {"topic": topic, "facts": facts}


class WriterAgent:
    name = "writer"

    def run(self, research_result: Dict[str, List[str]]) -> str:
        bullet_points = "\n".join(f"- {x}" for x in research_result["facts"])
        return f"# Research Report: {research_result['topic']}\n\n## Key Findings\n{bullet_points}\n"


class ReviewerAgent:
    name = "reviewer"

    def run(self, draft: str) -> Dict[str, str]:
        issues = []
        if "No data found" in draft:
            issues.append("缺少有效证据")
        if "Key Findings" not in draft:
            issues.append("结构不完整")
        if issues:
            return {"approved": "false", "feedback": "；".join(issues)}
        return {"approved": "true", "feedback": "报告结构完整，已包含主要事实。"}


@dataclass
class Orchestrator:
    researcher: ResearcherAgent = field(default_factory=ResearcherAgent)
    writer: WriterAgent = field(default_factory=WriterAgent)
    reviewer: ReviewerAgent = field(default_factory=ReviewerAgent)
    logs: List[AgentMessage] = field(default_factory=list)

    def execute(self, topic: str) -> Dict[str, str]:
        research = self.researcher.run(topic)
        self.logs.append(AgentMessage("researcher", str(research)))

        draft = self.writer.run(research)
        self.logs.append(AgentMessage("writer", draft))

        review = self.reviewer.run(draft)
        self.logs.append(AgentMessage("reviewer", str(review)))

        if review["approved"] == "true":
            return {"status": "done", "report": draft, "review": review["feedback"]}

        improved_draft = draft + f"\n## Reviewer Feedback\n{review['feedback']}\n"
        return {"status": "needs_revision", "report": improved_draft, "review": review["feedback"]}


if __name__ == "__main__":
    orchestrator = Orchestrator()
    result = orchestrator.execute("mcp")
    print(result["status"])
    print(result["report"])
    print(result["review"])

    print("\n=== Logs ===")
    for log in orchestrator.logs:
        print(f"[{log.sender}] {log.content}")
```

### 11.6.3 如何升级到生产版本

生产化时，建议加入：

- 每个 Agent 单独 system prompt；
- 工具权限差异化；
- 中间结果 schema；
- 任务状态表；
- 审稿打分标准；
- 人工接管入口；
- agent-level timeout；
- streaming progress。

## 11.7 什么时候不应该用多 Agent

以下场景用单 Agent 更合适：

- 任务只需 1~3 次工具调用；
- 所有步骤强顺序且不复杂；
- 上下文共享极多，拆分后反而重复传输；
- 延迟预算极小，比如必须 1 秒内返回；
- 成本极度敏感。

一个很成熟的工程判断是：**先用单 Agent 跑通，再在瓶颈处引入多 Agent，而不是从第一天就把系统拆成“AI 微服务集群”。**

## 11.8 任务应该如何拆给多个 Agent

多 Agent 最大的设计问题，不是“能不能再加一个 Agent”，而是“任务边界怎么划分才合理”。一个实用判断标准是看子任务是否同时满足四个条件：

1. **输入明确**：拿到什么信息才能开工；
2. **输出明确**：产出是什么格式；
3. **能力独立**：是否需要独立工具集或独立角色提示；
4. **可验证**：结果能否被下游或审稿者检查。

例如“研究 + 写作 + 审核”适合拆，因为三者目标不同、输出也不同；但“先写第一段，再写第二段，再写第三段”往往不值得拆，因为强依赖同一上下文，拆开只会增加拼接成本。

可以用下面这张表快速判断：

| 问题 | 若回答是“是” | 更倾向多 Agent |
|---|---|---|
| 子任务是否可并行 | 多地调研、多个数据源 | 是 |
| 是否需要不同角色视角 | 研究、写作、审核 | 是 |
| 是否需要不同权限 | 只读检索 vs 写入系统 | 是 |
| 子任务之间是否高度耦合 | 共享全部上下文 | 否 |

工程上一个很重要的原则是：**按能力拆，不按想象中的“团队角色”硬拆**。否则很容易出现 5 个 Agent 名字很酷，但只有 1 个在真正做事。

## 11.9 多 Agent 之间共享什么上下文

多 Agent 协作最忌讳“全量转发全部历史”。更推荐共享结构化上下文包：

```json
{
  "task_id": "task-2026-0612-001",
  "goal": "生成 MCP 与 A2A 对比报告",
  "constraints": ["必须给出协议层差异", "需要带代码示例"],
  "evidence": [
    {"source": "doc-1", "fact": "MCP 基于 JSON-RPC 2.0"},
    {"source": "doc-2", "fact": "A2A 强调 Agent Card 与任务生命周期"}
  ],
  "budget": {
    "max_tokens": 6000,
    "deadline_seconds": 30
  }
}
```

这样的好处有三点：

1. 下游 Agent 看到的是“任务对象”，不是一团聊天记录；
2. 编排器可插入成本、时间、权限约束；
3. 审稿 Agent 可以只看证据和草稿，不必看全部搜索过程。

在生产系统中，通常会把共享内容分层：

- **必须共享**：目标、约束、证据、草稿版本；
- **可选共享**：中间推理摘要、失败原因；
- **不共享**：冗长内部思考、无关聊天、敏感凭证。

## 11.10 生产治理：避免“Agent 会议开不完”

多 Agent 常见坏味道是：每个 Agent 都很能说，但系统不收敛。解决方法不是写更长 prompt，而是做治理。

### 一、给每个 Agent 设退出条件

例如：

- Researcher 最多检索 5 个来源；
- Writer 最多修订 2 轮；
- Reviewer 若无致命问题则必须通过，不允许无限挑小毛病。

### 二、给 Orchestrator 设总预算

总预算包括：

- 总 token；
- 总 wall-clock 时间；
- 总调用轮数；
- 总并行度。

如果预算快用完，编排器应主动降级，例如减少 reviewer 深度、只保留前 3 个证据源。

### 三、日志必须可回放

你需要能回答：

- 哪个 Agent 首先引入了错误事实；
- 哪个 Agent 忽略了关键约束；
- 某个任务为什么卡了 40 秒；
- 为什么这次成本是上次的 2 倍。

因此每条通信都应带：

- `task_id`
- `agent_id`
- `parent_agent_id`
- `message_type`
- `created_at`
- `latency_ms`
- `token_usage`

### 四、对人类可解释

多 Agent 系统上线后，业务方最常问的不是“用了几个模型”，而是“为什么这个结论是这么来的”。因此最好保留：

- 证据链；
- 角色分工；
- 审核意见；
- 最终裁决依据。

## 11.11 什么时候需要 Debate，什么时候不需要

辩论式模式很吸引人，因为它看起来像“让两个专家互相挑错”。但不是所有任务都值得这样做。适合 Debate 的场景通常有两个特征：

1. 任务存在多种合理方案；
2. 你能给出明确裁判标准。

例如“选 LangGraph 还是 AutoGen 做下一代平台”的确值得让两个 Agent 站在不同立场辩论；但“把数据库连接串从配置里读出来”这类任务就完全没必要辩论。

如果没有裁判标准，Debate 很容易退化成：

- 双方重复相同事实；
- 消耗双倍 token；
- 最后仍需要人工判断。

所以实战里，Debate 应该是高价值任务的增强模块，而不是默认配置。

## 11.12 一个多 Agent 平台的运行指标

如果单 Agent 关注的是工具成功率和 loop 次数，多 Agent 还要额外看协作指标：

| 指标 | 含义 |
|---|---|
| delegation_rate | 任务被拆分与委派的比例 |
| parallelism_factor | 平均并发子任务数 |
| handoff_success_rate | Agent 之间交接成功率 |
| revision_rounds | 草稿被 reviewer 打回的次数 |
| duplicate_work_rate | 多个 Agent 重复劳动比例 |
| cost_per_completed_task | 完成一个任务的总成本 |

其中 `duplicate_work_rate` 非常关键。很多多 Agent 系统表面看起来“很勤奋”，实际上 3 个 Agent 在查同样的资料，只是用不同表述重复劳动。解决这个问题，往往要靠共享证据池和任务去重键，而不是靠更强模型。

## 11.13 从单 Agent 迁移到多 Agent 的推荐路径

最安全的方式不是“一步拆成 5 个 Agent”，而是逐步迁移：

### 阶段一：单 Agent + 多工具

先把任务跑通，搞清楚真正瓶颈是检索、写作、审校还是执行。

### 阶段二：拆出第一个专家 Agent

通常先拆检索或审稿，因为它们职责边界最清晰。比如保留主 Agent 负责对话，把“资料收集”交给 Research Agent。

### 阶段三：引入编排器

只有当你确定存在多角色、多阶段、多预算控制需求时，再引入 Supervisor 或 Orchestrator。否则编排器本身会成为额外复杂度来源。

### 阶段四：协议化与治理

当 Agent 数量增多后，再做消息 schema、共享状态、权限和可观测性统一。

这种迁移思路在面试里很有说服力，因为它体现了你不会为了架构而架构，而是先验证价值，再增加复杂度。

## 11.14 一个常见失败案例

某团队想做“自动写周报系统”，一开始就设计了选题 Agent、搜集 Agent、写作 Agent、润色 Agent、审稿 Agent、排版 Agent 六个角色。结果上线后发现：

- 任务本身并不复杂；
- 六个 Agent 共享几乎同一份上下文；
- 每轮都要传递大段草稿；
- 延迟从 6 秒变成 28 秒；
- 成本接近单 Agent 的 4 倍。

最后他们把系统收缩为：Researcher + Writer + Reviewer 三个角色，成本与时延显著下降，质量变化却不大。

这个案例说明，多 Agent 的核心不是“角色越多越专业”，而是**边界越清晰越高效**。

## 11.15 一个适合面试展示的系统设计回答

如果面试官让你设计“一个自动生成行业研究报告的多 Agent 系统”，你可以按下面顺序回答：

第一，定义角色：

- Researcher：负责搜索、抓取、提取事实；
- Analyst：负责把事实转成结构化比较；
- Writer：负责成稿；
- Reviewer：负责事实核验和表达质量；
- Orchestrator：负责分配任务、汇总状态、控制预算。

第二，定义通信协议：

- Researcher 向共享黑板写证据条目；
- Analyst 读取证据并生成对比表；
- Writer 只读对比表和证据摘要；
- Reviewer 输出问题清单与通过/不通过结果。

第三，定义状态：

- 任务级状态：创建、执行中、待审稿、完成；
- Agent 级状态：空闲、运行中、阻塞、失败；
- 资源级状态：预算剩余、超时、证据数量。

第四，定义治理：

- 每个 Agent 最大轮次；
- 最大并发数；
- 证据最少来源数量，比如至少 3 个独立来源；
- 总成本超过阈值时降级为“短报告模式”。

第五，定义可观测性：

- 每个 handoff 的延迟；
- 每个 Agent 的 token 消耗；
- 草稿被 reviewer 打回的次数；
- 最终报告的引用覆盖率。

这种答题方式的优势是，它让“多 Agent”听起来像真正的分布式协作系统，而不只是几个 Prompt 拼起来。

## 11.16 为什么多 Agent 特别适合传统软件工程师转型

因为它几乎把所有你熟悉的工程能力都重新用了一遍：

- 任务拆分类似服务边界设计；
- Agent 间通信类似 RPC 或消息队列；
- 共享黑板类似数据库或事件总线；
- 重试、幂等、超时、取消都是分布式系统老问题；
- 成本、延迟、吞吐量权衡也和后端系统非常像。

所以你不必把多 Agent 看成一个神秘的新世界。它本质上是：在经典系统设计问题上，再加一层由 LLM 驱动的决策与语言接口。这也是为什么面试官特别喜欢在这一章考察候选人的工程感觉。

## 11.17 一个落地判断标准

如果你在项目里犹豫“要不要上多 Agent”，可以问自己三个问题：  
第一，这个任务是否真的存在可独立优化的子角色？  
第二，拆开后是否能换来并行、质量或权限上的明显收益？  
第三，新增的协调成本是否小于收益？

只要这三个问题里有两个回答是否定的，就先别急着拆。这个判断标准非常朴素，但在真实项目里极其有用。

也正因为如此，优秀的多 Agent 设计往往显得“克制”：角色不多、协议清楚、边界稳定、日志完整。它追求的是系统收益最大化，而不是视觉上看起来像一个“很热闹的 AI 团队”。
真正优秀的方案，常常是把复杂度精确地放在最有价值的环节，而不是平均分散到每个 Agent 身上。
如果你能在设计中始终回答“为什么必须拆、拆开后收益是什么、谁来协调失败”，那你的多 Agent 架构通常就不会走偏。
否则，它很容易从协作系统退化成昂贵而混乱的消息风暴。
从系统设计视角看，多 Agent 的难点和微服务并没有本质区别：服务拆分之后，真正的复杂度会转移到通信、状态一致性、失败恢复和观测层。差别只在于，这里的“服务”既有确定性程序，也有带概率性的模型决策模块。所以，越是复杂的多 Agent 系统，越要在接口、状态机和回放能力上做硬约束，而不是把希望寄托在 Prompt 足够长、模型足够聪明上。
这也是为什么越成熟的团队，越会把多 Agent 当成系统工程题，而不是单纯的 Prompt 题。
一旦把这个认知立住，你的架构判断会稳很多。
你会更愿意先算清收益，再决定要不要拆分角色、增加链路和引入新的协作状态。
这是一种非常工程化的思维：先确认瓶颈，再增加结构；先证明价值，再引入复杂度。对转型中的软件工程师来说，这正是你相对纯算法背景候选人的优势所在。
多 Agent 不是“会不会搭”的问题，更是“值不值得搭、搭完如何收敛”的问题。
只有把收敛性、预算和可观测性一起设计进去，多 Agent 才会从概念图变成真正能上线的系统。
换句话说，多 Agent 的上限不由角色数量决定，而由协作质量决定。

## 本章要点

- 多智能体系统适合复杂任务分工、并行处理和角色专业化。
- 常见模式包括顺序链、并行扇出、层级式、辩论式和群体式。
- 生产中最常见且最稳妥的是中央编排 + 专家 Agent 的层级式设计。
- 多 Agent 的主要代价是成本上升、协调失败、上下文共享困难、调试复杂和延迟增加。
- 框架选型要看状态管理需求、可恢复性、成本控制和开发复杂度，而不是只看流行度。
- 一个好的多 Agent 设计，必须先定义协议、状态、边界，再讨论模型与 prompt。

## 延伸阅读

1. AutoGen 官方论文与文档
2. CrewAI 官方文档
3. LangGraph 多 Agent / state graph 设计指南
4. OpenAI Swarm 示例仓库
5. 关于 blackboard architecture 与 distributed systems coordination 的经典资料
