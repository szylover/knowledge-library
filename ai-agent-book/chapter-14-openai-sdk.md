# 第十四章：OpenAI Agents SDK 与 Assistants API

如果 LangChain 代表“开放式编排框架”，那么 OpenAI 官方体系代表的是“模型能力与平台能力深度一体化”。在 2025-2026 年，大量企业开始同时评估三条路线：直接用 Chat Completions（聊天补全接口）、用 Assistants API（助理接口）快速搭系统，或使用更新的 Agents SDK（智能体软件开发工具包）构建多 Agent 应用。作为转行工程师，你必须理解三者的边界，否则很容易在面试里陷入“能讲 demo，讲不出选型逻辑”的尴尬。

## 14.1 Assistants API：线程化、托管化的 Agent 容器

Assistants API 的核心对象有四个：

| 对象 | 含义 | 类比 |
|---|---|---|
| Assistant | 一个预配置的助理 | 预设好 system prompt、工具和模型的服务实例 |
| Thread | 一条会话线程 | 某个用户或任务的上下文容器 |
| Message | 线程中的消息 | 用户输入、系统追加、模型回复 |
| Run | 一次执行过程 | “让这个 Assistant 在某个 Thread 上跑一轮” |

ASCII 示意图：

```text
User ---> Thread
           |
           +--> Message(历史消息...)
           |
           +--> Run ---> Assistant(model + tools + instructions)
                              |
                              +--> Tool calls / final response
```

这种设计与传统“每次请求都自己拼 history”的模式不同，它把上下文管理托管给平台。优点是开发速度快，缺点是可控性相对弱、平台耦合更深。

### 14.1.1 创建一个 Assistant

```python
from openai import OpenAI

client = OpenAI()

assistant = client.beta.assistants.create(
    name="Data Analyst",
    model="gpt-4.1",
    instructions=(
        "你是一个数据分析助手。优先使用 Python 做统计、画图和异常值分析，"
        "输出必须包含结论、方法、局限性。"
    ),
    tools=[
        {"type": "code_interpreter"},
        {"type": "file_search"},
    ],
)

print(assistant.id)
```

面试高频点：为什么把“系统提示词”和“工具列表”绑定到 Assistant，而不是每次请求动态传？答案是为了**复用配置、统一审计、降低客户端复杂度**。

### 14.1.2 Thread、Message、Run 的调用顺序

```python
thread = client.beta.threads.create()

client.beta.threads.messages.create(
    thread_id=thread.id,
    role="user",
    content="请分析附件 CSV 中 2025 年每月营收趋势，并找出异常月份。"
)

run = client.beta.threads.runs.create(
    thread_id=thread.id,
    assistant_id=assistant.id,
)

print(run.id)
```

这四步看似啰嗦，但非常适合复杂异步任务。比如数据分析、文档问答、代码解释，都可能需要数秒到数十秒执行，Run 可以被轮询、流式订阅或异步回调。

## 14.2 Assistants API 内置工具

### 14.2.1 Code Interpreter

代码解释器（Code Interpreter，代码执行沙箱）是许多“半结构化任务”的关键能力。它适合：

- CSV/Excel 数据分析；
- 绘图；
- 数值计算；
- 简单文件清洗；
- 生成结果文件供用户下载。

一个最小数据分析示例：

```python
import time
from openai import OpenAI

client = OpenAI()

assistant = client.beta.assistants.create(
    name="Revenue Analyst",
    model="gpt-4.1",
    instructions="你是财务数据分析师，请用 Python 进行计算并解释结果。",
    tools=[{"type": "code_interpreter"}],
)

thread = client.beta.threads.create()

csv_file = client.files.create(
    file=open("monthly_revenue.csv", "rb"),
    purpose="assistants",
)

client.beta.threads.messages.create(
    thread_id=thread.id,
    role="user",
    content="分析营收趋势、计算环比增速，并指出异常月份。",
    attachments=[{
        "file_id": csv_file.id,
        "tools": [{"type": "code_interpreter"}],
    }],
)

run = client.beta.threads.runs.create(thread_id=thread.id, assistant_id=assistant.id)

while True:
    run = client.beta.threads.runs.retrieve(thread_id=thread.id, run_id=run.id)
    if run.status in ("completed", "failed", "cancelled", "expired"):
        break
    time.sleep(2)

messages = client.beta.threads.messages.list(thread_id=thread.id)
for msg in messages.data[:3]:
    print(msg.role, msg.content[0].text.value[:200])
```

注意：真实项目中不要只看最终文本，还要读取生成的文件、图表与步骤日志。很多面试官会问：“如何验证 Code Interpreter 没有胡算？”正确答案不是“相信模型”，而是**保留中间代码、输出表格与可复现实验记录**。

### 14.2.2 File Search

文件搜索（File Search，文件检索）本质上是托管版检索增强生成（RAG，检索增强生成）。它适合：

- FAQ 文档问答；
- 政策库问答；
- 合同/手册/产品说明书检索；
- 中小团队快速上线知识助手。

优势是免去向量切片、嵌入、索引管理的复杂度；劣势是控制面有限。对于要求精细召回、混合检索、私有排序策略的团队，通常还是会自建 RAG。

### 14.2.3 Function Calling

函数调用（Function Calling，函数调用）让模型输出结构化调用意图，再由你的服务执行真实函数。它是连接企业系统的关键，例如：

- 查询库存；
- 创建工单；
- 触发支付风控检查；
- 调用内部搜索。

## 14.3 Function Calling 深入：Agent 工程的分水岭

### 14.3.1 JSON Schema 定义函数

函数定义的本质是 JSON Schema（JSON 模式约束）：

```python
tools = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "查询指定城市天气",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "城市名，如 Shanghai"},
                    "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}
                },
                "required": ["city", "unit"],
                "additionalProperties": False
            },
            "strict": True
        }
    }
]
```

这里的 `strict: True` 非常重要。严格模式（strict mode，严格模式）要求模型严格遵守 schema，显著降低“字段缺失、字段名漂移、额外参数污染”的概率。生产系统强烈建议开启。

### 14.3.2 并行函数调用

在 2025-2026 年，模型已支持并行函数调用（parallel function calling，并行函数调用）。例如一个旅行助手可同时查询天气、机票和酒店：

```text
User: 下周去东京三天，帮我看天气并给出预算建议
Model:
  - call get_weather(city="Tokyo")
  - call search_flights(destination="Tokyo", days=3)
  - call search_hotels(city="Tokyo", nights=3)
```

优点是延迟下降明显；风险是**你必须处理部分成功、部分失败、超时不一致**。如果天气成功、机票超时、酒店失败，聚合层如何降级？这是工程经验题，不是 API 题。

### 14.3.3 Structured Outputs

结构化输出（Structured Outputs，结构化输出）适用于“最终答案也必须是机器可读”的情况，例如评分、分类、抽取、工作流驱动。相比后处理正则，schema-first 的方式更稳。

```python
from pydantic import BaseModel
from openai import OpenAI

class InterviewScore(BaseModel):
    score: int
    strengths: list[str]
    weaknesses: list[str]

client = OpenAI()
response = client.responses.parse(
    model="gpt-4.1-mini",
    input="评估候选人对 RAG 的回答：知道召回、重排、评测，但不会讲缓存策略。",
    text_format=InterviewScore,
)
print(response.output_parsed)
```

### 14.3.4 错误处理模式

函数调用的四类常见错误：

| 错误类型 | 现象 | 应对策略 |
|---|---|---|
| Schema 错误 | 参数缺失、类型不符 | 严格模式 + 自动重试 1 次 |
| 业务错误 | 库存不存在、权限不足 | 返回标准错误码给模型重写答案 |
| 超时错误 | 外部 API 过慢 | 设 2-5 秒超时，必要时部分降级 |
| 幻觉调用 | 模型调用了不该调用的工具 | 工具白名单 + policy 校验 |

一个稳定模式是：**模型负责决定“要不要调用”，应用负责决定“能不能调用、调用成功后如何回填”。**

## 14.4 OpenAI Agents SDK：从单 Agent 到多 Agent 协作

Assistants API 更像托管运行时，而 Agents SDK 更像开发框架。它强调以下能力：

1. Agent 定义与配置；
2. 工具注册；
3. Agent 之间的 handoff（交接）；
4. guardrails（护栏）；
5. tracing 与调试。

### 14.4.1 架构概览

可以把 Agents SDK 理解为：

```text
User Request
    |
    v
[Router Agent] ---> [Search Agent]
    |                    |
    +----------------> [Analysis Agent]
    |                    |
    +----------------> [Action Agent]
                         |
                     Tools / Validation / Trace
```

与自己手写多 Agent 编排相比，官方 SDK 的优势在于与模型能力、tool calling、trace 体系深度整合；缺点是平台绑定与抽象限制。

### 14.4.2 Agent 定义与工具注册

下面给出一个可运行的简化示例，展示多工具 Agent：

```python
from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class ToolResult:
    ok: bool
    data: Dict[str, Any]

def search_docs(query: str) -> ToolResult:
    return ToolResult(ok=True, data={"hits": [f"doc for {query}"]})

def estimate_cost(tokens: int, price_per_1k: float = 0.15) -> ToolResult:
    return ToolResult(ok=True, data={"usd": round(tokens / 1000 * price_per_1k, 4)})

def orchestrate(user_query: str) -> dict:
    docs = search_docs(user_query)
    cost = estimate_cost(tokens=2400)
    return {
        "query": user_query,
        "docs": docs.data["hits"],
        "estimated_cost": cost.data["usd"],
    }

if __name__ == "__main__":
    print(orchestrate("LangGraph checkpointing"))
```

真实 Agents SDK 会提供更标准的 Agent、Tool、Runner 接口，但你必须先理解底层思想：**Agent 是“带策略的模型包装器”，Tool 是“受控副作用”，Runner 是“执行与调度器”。**

### 14.4.3 Handoffs Between Agents

Agent 交接（handoff，任务交接）常用于：

- Router Agent 把问题交给专业 Agent；
- Planner Agent 生成计划后交给 Executor Agent；
- Analyst Agent 提取事实后交给 Writer Agent。

经验法则：不要为了“看起来高级”而切太多 Agent。一个普通企业场景中，2-4 个角色通常已经足够。超过 6 个 Agent，延迟、可观测性和调试成本会陡升。

### 14.4.4 Guardrails 与 Validation

护栏（guardrails，安全/质量护栏）至少要覆盖三层：

| 层 | 示例 |
|---|---|
| 输入层 | 敏感词、越权请求、提示注入检测 |
| 中间层 | 工具参数校验、预算限制、允许工具白名单 |
| 输出层 | schema 校验、敏感信息脱敏、引用完整性检查 |

这类内容在 2026 年面试里非常重要，因为企业越来越关心“Agent 不只是能做事，还不能乱做事”。

### 14.4.5 Tracing 与 Debugging

一个多 Agent 系统如果没有 trace，你几乎无法回答：

- 是 Router 分错类，还是 Search Agent 检索差？
- 是工具超时，还是最终 Writer Agent 编造？
- 是 prompt 回归，还是上游文件索引过期？

因此官方 tracing 能力不是锦上添花，而是生产必需品。

## 14.5 Assistants API vs Agents SDK vs Raw Chat Completions

| 维度 | Raw Chat Completions | Assistants API | Agents SDK |
|---|---|---|---|
| 灵活性 | 最高 | 中 | 高 |
| 平台托管程度 | 低 | 高 | 中 |
| 开发速度 | 中 | 高 | 中高 |
| 多 Agent | 需自建 | 较弱 | 强 |
| 内置工具 | 无 | 强 | 可整合 |
| 可控性 | 最高 | 相对较低 | 高 |
| 典型场景 | 极致定制、低层控制 | 快速上线知识助手/分析助手 | 中大型多工具、多 Agent 系统 |

### 什么时候选哪一个？

1. **选 Raw Chat Completions**：当你需要完全控制消息格式、缓存、重试、工具执行和跨模型路由。
2. **选 Assistants API**：当你要快速上线一个带文件、代码解释器、检索能力的单 Agent 系统。
3. **选 Agents SDK**：当你要做多工具、多角色协作，并希望官方提供更好的 handoff 与 tracing 支撑。

## 14.6 完整示例一：多工具 Agent

下面示例展示一个“预算研究助手”，同时调用搜索、计算与结构化输出。

```python
from pydantic import BaseModel

class BudgetAnswer(BaseModel):
    summary: str
    estimated_cost_usd: float
    action_items: list[str]

def search_market_price(topic: str) -> dict:
    return {"topic": topic, "avg_daily_cost": 120.0}

def calc_total(days: int, daily_cost: float) -> float:
    return round(days * daily_cost, 2)

def build_budget_plan(topic: str, days: int) -> BudgetAnswer:
    market = search_market_price(topic)
    total = calc_total(days, market["avg_daily_cost"])
    return BudgetAnswer(
        summary=f"{topic} 的预计总预算为 {total} 美元",
        estimated_cost_usd=total,
        action_items=["确认汇率", "预留 15% 风险缓冲", "拆分固定成本与可变成本"],
    )

if __name__ == "__main__":
    print(build_budget_plan("东京差旅", 3).model_dump_json(indent=2))
```

这个例子虽然没有直接依赖线上 SDK，但它很好地映射了 Agents SDK 的核心价值：**把模型决策、工具执行、结果校验分层管理。**

## 14.7 完整示例二：Assistants API + Code Interpreter + File Search

真实企业中一个非常常见的组合是：上传财务文档或知识库文件，让 Assistant 一边检索、一边分析。

```python
import time
from openai import OpenAI

client = OpenAI()

assistant = client.beta.assistants.create(
    name="Ops Copilot",
    model="gpt-4.1",
    instructions="你是运营分析助手，回答时先检索文档，再用 Python 做计算。",
    tools=[{"type": "file_search"}, {"type": "code_interpreter"}],
)

thread = client.beta.threads.create()

client.beta.threads.messages.create(
    thread_id=thread.id,
    role="user",
    content="根据上传的运营手册和 sales.csv，分析退款率过高的可能原因。",
)

stream = client.beta.threads.runs.create_and_stream(
    thread_id=thread.id,
    assistant_id=assistant.id,
)

for event in stream:
    print(event)
```

生产环境里你不会直接把 event 原样打印，而是：

- 把 tool call 事件写入日志；
- 把增量文本推给前端；
- 记录 token、延迟、文件命中率；
- 对失败的 run 自动告警。

## 14.8 面试与实战建议

1. **不要把 Assistants API 理解成“更高级的聊天接口”。** 它本质上是托管式线程 + 工具执行容器。
2. **Function Calling 才是企业集成的关键。** 能讲清 schema、严格模式、错误处理，远比会发一个请求更重要。
3. **Agents SDK 的重点在协作与护栏。** 多 Agent 系统的难点从来不是“多几个 prompt”，而是状态、调度、调试与责任边界。
4. **生产落地要关心成本。** 一次查询如果串联文件检索、代码解释和多个工具调用，成本会从几分钱迅速涨到几毛甚至更高。

## 14.9 文件处理与检索生命周期设计

很多候选人会演示“上传一个 PDF 然后问答”，但企业真正关心的是文件生命周期。一个文件从上传到被问答，至少经历：

1. 上传；
2. 权限校验；
3. 解析；
4. 索引；
5. 关联到 Assistant 或 Thread；
6. 检索；
7. 过期与删除。

这意味着你必须回答几个现实问题：

- 文件是对单个用户可见，还是对整个租户可见？
- 文件删除后，索引是否同步清理？
- 同一个文件是否允许多个 Assistant 复用？
- 如何处理 200MB 大文件或上千页 PDF 的超时问题？

建议实践是把文件元数据单独存到数据库，例如：

| 字段 | 说明 |
|---|---|
| `file_id` | OpenAI 平台文件 ID |
| `tenant_id` | 租户隔离 |
| `owner_user_id` | 所属用户 |
| `source_name` | 原始文件名 |
| `purpose` | assistants / eval / temp |
| `expires_at` | 过期时间 |
| `classification` | public/internal/restricted |

这类设计能帮助你在面试中显示出“平台级思维”，而不是停留在单脚本调用层面。

## 14.10 Streaming：不仅是边吐字，还是事件驱动

很多工程师把流式输出理解成“前端逐字显示”，这只看到表面。对于 Assistants API 和 Agents SDK，流式更深层的价值是事件驱动（event-driven，事件驱动）：

- 模型开始输出；
- 工具调用开始；
- 工具调用结束；
- 中间 reasoning 片段出现；
- 文件生成完成；
- 最终答案结束。

如果你把这些事件标准化，就能做出非常强的前端体验：

```text
[Thinking...]
[Searching knowledge base...]
[Running Python analysis...]
[Summarizing results...]
[Final answer]
```

这比单纯输出一段最终文本更可信，因为用户能看到 Agent 做了什么。对于客服、投研、财务等场景，这种“过程可见性”会显著提升用户信任。

在工程实现上，建议把平台事件映射为统一内部事件模型：

| 内部事件 | 来源 |
|---|---|
| `assistant.delta` | 文本增量 |
| `tool.started` | 工具调用开始 |
| `tool.completed` | 工具调用结束 |
| `run.failed` | run 失败 |
| `run.completed` | run 结束 |

这样无论底层你用 OpenAI 还是别的 provider，前端与监控系统都不用跟着大改。

## 14.11 多 Agent 交接设计：不是“分工越多越高级”

Agents SDK 支持 handoff 后，最容易出现的误区就是把一个简单系统拆成十几个 Agent。经验上，Agent 拆分应遵循三个原则：

1. **职责边界清晰**：例如 Router 只分类，不写最终答案。
2. **上下文最小化**：不要把全部历史都传给所有 Agent。
3. **交接标准化**：handoff 的输入输出最好是结构化 schema，而不是自由文本。

一个推荐的多 Agent 模式如下：

```text
User Query
   |
   v
Router Agent ----> Retrieval Agent
   |
   +-------------> Calculator Agent
   |
   +-------------> Policy Agent
             \         |         /
              \        |        /
               v       v       v
                  Synthesizer Agent
```

为什么这比“Researcher/Writer/Reviewer”式无限细分更稳？因为它是按**能力边界**而不是按**人类角色想象**来拆分，更适合程序化验证和性能优化。比如 Calculator Agent 的输出可以严格要求 JSON，Policy Agent 的输出可以要求必须附带政策来源。

## 14.12 Guardrails：企业系统的生死线

在消费级 demo 里，护栏常常被忽视；在企业系统里，护栏往往比回答质量更先决定能否上线。至少要考虑以下风险：

- 提示注入要求泄露内部规则；
- 用户诱导 Agent 调用越权工具；
- 模型输出未经验证的财务建议；
- 文件搜索结果包含敏感字段；
- 工具回包异常导致模型继续编造。

一个可操作的护栏流水线是：

1. 输入前做分类：普通请求、敏感请求、禁止请求；
2. 生成工具调用前做 policy check；
3. 工具返回后做 schema 与权限校验；
4. 最终输出前做脱敏与引用完整性检查。

在实际实现里，很多团队会把 guardrail 独立成模块或服务，而不是散落在业务代码中。因为一旦你要支持多个 Agent、多个租户、多个业务线，统一治理会极大降低风险。

## 14.13 选型落地建议

如果你站在技术负责人角度，要在 4 周内做一个“企业知识助手 + 文件问答 + 简单工单创建”的系统，我会建议如下：

| 阶段 | 建议 |
|---|---|
| 第 1 周 | 用 Assistants API 验证文件问答体验与工具调用路径 |
| 第 2 周 | 明确哪些工具必须自建执行层，补齐审计与错误码 |
| 第 3 周 | 若出现多角色协作需求，再评估 Agents SDK 或自建 orchestration |
| 第 4 周 | 建 tracing、成本统计、评测集与灰度策略 |

也就是说，**先用托管能力验证需求，再决定是否升级到更复杂的 Agent 编排层**。这比一开始就设计一个“宇宙级多 Agent 架构”更符合企业交付节奏。

## 14.14 测试与评测：官方 SDK 也不能跳过工程验证

许多人误以为“既然 Assistants API 帮我管了线程和工具，那测试就简单了”。事实恰恰相反：托管能力越多，你越要在系统边界上补足测试。

建议至少准备三类测试：

### 14.14.1 合约测试

验证你与平台 API 的交互是否稳定，例如：

- 创建 Assistant 时工具定义是否合法；
- 文件上传后能否正确关联到消息；
- streaming 事件是否能被前端消费；
- function calling 返回后是否能顺利继续 run。

### 14.14.2 业务测试

围绕真实业务问题构建样本，例如 100 条客服问答、50 条财务分析、30 条工单创建。关注的不只是“答得像不像”，更要看：

- 是否调用了正确工具；
- 是否引用了正确文件；
- 是否出现越权行为；
- 是否在失败时正确降级。

### 14.14.3 成本回归测试

这一项最容易被忽略。随着 prompt 变长、文件更多、工具更复杂，一次 run 的成本可能在两周内翻倍。建议记录：

| 指标 | 示例 |
|---|---|
| 平均输入 tokens | 3200 |
| 平均输出 tokens | 650 |
| 文件检索次数 | 1.4 次 / run |
| 工具调用次数 | 2.1 次 / run |
| 单次平均成本 | $0.028 |

如果你在面试里能说出“SDK 不是免维护，而是把复杂度转移到了边界治理和评测体系”，通常会显得非常成熟。

## 14.15 企业落地中的组织分工

OpenAI 官方体系在企业里通常不会只由一个人维护，而是多人协作：

| 角色 | 职责 |
|---|---|
| Agent 工程师 | prompt、tool schema、handoff 设计 |
| 后端工程师 | API 编排、鉴权、限流、重试、日志 |
| 平台工程师 | tracing、密钥管理、预算面板 |
| 产品经理 | 用例定义、成功标准、失败样本回收 |

这意味着你做技术方案时，要把“谁来维护 Assistant 配置、谁来管理文件生命周期、谁来审核工具权限”讲清楚。很多系统失败，不是因为模型不行，而是责任边界模糊。

最后给出一个经验判断：如果系统未来 6 个月内都以“单 Agent + 文件 + 分析 + 少量内部工具”为主，那么 Assistants API 往往是性价比最高的；如果你已经确认要进入“多角色协作 + 复杂路由 + 深度治理”阶段，那么尽早评估 Agents SDK 或自建编排层，能避免后期重复迁移。

再补充一个面试里很实用的判断标准：如果你的需求核心是“让模型更聪明”，那重点应放在 prompt、tool schema 和 eval；如果核心是“让系统更可靠”，那重点应放在 run 生命周期、事件流、权限、超时和成本面板。很多人把这两类问题混在一起，导致方案既不快也不稳。能把“模型问题”和“平台问题”拆开讲，是区分初级与中高级 Agent 工程师的关键。

还有一个常被忽略的现实因素是供应商锁定。官方 SDK 的开发体验通常更好，但一旦你将文件生命周期、事件模型、trace 查询、工具执行协议都深度绑定到单一平台，未来迁移成本会显著上升。因此建议在系统边界上保留自己的抽象，例如统一内部消息模型、统一工具返回格式、统一 trace_id 规范。这样即便未来更换 provider，也能把影响控制在适配层，而不是推倒业务服务重写。

如果你要做求职作品集，一个很有竞争力的方案是：先实现一个 Assistants API 版“数据分析助手”，再实现一个 Agents SDK 风格的“多工具研究助手”，最后写出一份对比报告，说明两者在开发速度、调试难度、成本、控制力上的差异。这样的作品往往比单独展示一段代码更能证明你的工程判断。

你甚至可以进一步补上“迁移计划”：如果用户量从每天 100 人增长到 1 万人，哪些部分还能继续依赖托管能力，哪些部分必须下沉到自建层。这类思考特别能体现候选人是否具备从 demo 走向平台化的视角。

同样重要的是，不要把 OpenAI 官方体系只理解成“写几个接口调用”。真正的门槛在于：你是否能围绕 Thread、Run、Tool、File、Trace 设计出稳定的服务边界，并让前端、后端、平台、产品都能围绕这条边界协同工作。

从这个角度看，学习官方 SDK 的真正收益不只是“更快出效果”，还在于你会被迫思考事件模型、资源生命周期、权限边界和平台治理。这些能力一旦形成，迁移到别的模型供应商时也仍然有价值。

所以本章最应该带走的，不只是几个对象名，而是一套“如何把模型平台能力包装成企业可用服务”的方法论。

当你能把这套方法论讲清楚时，面试官通常会认为你不仅会调用接口，也理解平台工程。

这正是官方生态学习的长期价值所在。

只要你能把平台能力、工程边界和业务约束三者同时讲明白，这一章的内容就真正转化成了岗位竞争力。

从求职角度看，这类系统性表达能力往往比单一代码片段更能打动面试官。

因为它说明你理解的不只是接口，更是系统。

这也是官方生态最值得投入学习的地方。

学会它，也是在学习平台化思维。

这点非常关键。

也是长期价值。

更是工程价值。

## 本章要点

- Assistants API 通过 Assistant、Thread、Message、Run 四个对象，提供托管式上下文与工具运行模型。
- Code Interpreter、File Search、Function Calling 三类能力覆盖了多数企业单 Agent 场景。
- Function Calling 的关键是 JSON Schema、严格模式、并行调用和鲁棒错误处理。
- Agents SDK 更适合多 Agent、多工具、多阶段协作系统，重点能力是 handoff、guardrails、tracing。
- 选型时要区分托管便利性与底层可控性，不存在“永远最优”的统一答案。

## 延伸阅读

1. OpenAI 官方 API 文档：重点看 Responses、Assistants、Files、Tools。
2. Structured Outputs 与 JSON Schema 最佳实践：重点关注 `additionalProperties: false`、枚举约束、严格模式。
3. 建议做两个作品集项目：一个是财务/数据分析助手（Code Interpreter），一个是企业知识助手（File Search + Function Calling）。
4. 如果准备面试，重点练习：设计一个“可调用 CRM、工单、知识库”的企业助手，并说明权限边界与错误处理。
