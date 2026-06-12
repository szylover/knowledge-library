# 第八章：Agent 架构模式

很多工程师第一次做 Agent，实际上只是把一个大语言模型（Large Language Model, LLM）包装成“问一句、答一句”的聊天接口。这样的系统当然有价值，但它离真正的 Agent 还有明显距离。判断一个系统是不是 Agent，关键不在 UI 长得像不像聊天框，而在它是否具备**自主性、工具使用能力、规划能力、状态维持能力以及基于反馈继续迭代的闭环执行能力**。这一章我们把这些能力拆开，讲清楚主流架构模式，并从零实现一个可以运行的 ReAct Agent。

## 8.1 什么样的系统才算 Agent

先看最小对比：

| 类型 | 输入 | 输出 | 是否自主决策 | 是否调用工具 | 是否有循环 |
|---|---|---|---|---|---|
| 单次 LLM 调用 | Prompt | 文本 | 否 | 否 | 否 |
| 带函数调用的问答 | Prompt + Tools | 文本/工具结果 | 弱 | 是 | 弱 |
| 工作流式 Agent | Goal | 多步执行结果 | 中 | 是 | 是 |
| 通用 Agent | Goal + 环境状态 | 多轮计划、执行、反思结果 | 强 | 是 | 是 |

一个“简单 LLM 调用”通常只有两步：拼 Prompt，拿输出。它可以回答“北京今天天气如何”，但不能自己去查天气 API、不能在失败后自动重试、不能分解“帮我比较未来三天上海和深圳的出行建议”这种任务。

而 Agent 具备以下四个核心特征：

1. **Autonomy（自主性）**：接到目标后，不需要每一步都由用户显式指挥。
2. **Tool Use（工具使用）**：会调用搜索、数据库、代码执行、文件系统、浏览器等外部能力。
3. **Planning（规划）**：面对复杂目标时，会分解任务、排序步骤、决定先做什么再做什么。
4. **Memory（记忆）**：能保留上下文、追踪中间状态，甚至跨会话保留事实与经验。

如果你把“工具调用”理解成 API 编排，把“规划”理解成任务调度，把“记忆”理解成状态管理，那么 Agent 架构其实就是**传统软件工程 + 概率模型决策层**。这也是为什么后端、平台、基础设施工程师转做 Agent 非常有优势。

## 8.2 Agent Loop：Perceive → Reason → Act → Observe

绝大多数 Agent 架构，本质上都是一个循环（loop）：

```text
+-----------+      +-----------+      +--------+      +-----------+
| Perceive  | ---> |  Reason   | ---> |  Act   | ---> |  Observe  |
| 感知输入   |      | 推理决策    |      | 执行动作 |      | 观察结果    |
+-----------+      +-----------+      +--------+      +-----------+
      ^                                                        |
      |                                                        |
      +-------------------- State / Memory --------------------+
```

四个阶段的工程含义如下：

- **Perceive（感知）**：读取用户目标、历史上下文、工具返回值、外部环境状态。
- **Reason（推理）**：模型决定当前最合理的下一步，是回答、调用工具、修改计划还是结束。
- **Act（行动）**：真正执行动作，比如调用 HTTP API、写文件、执行 SQL。
- **Observe（观察）**：收集动作结果，并写回工作记忆（working memory）。

这不是理论图，而是生产系统中的最小执行机。你可以把它想象为：

- Perceive = 请求解析层
- Reason = LLM 决策层
- Act = Tool Runtime
- Observe = State Reducer

很多面试题都会问：“Agent 为什么比 Workflow 更灵活？”答案就在这里：Workflow 的路径大多是预先编码的，而 Agent 的路径是在 **Reason 阶段动态生成** 的。

## 8.3 核心架构模式一：ReAct（Reason + Act）

ReAct 是目前最经典、最容易落地的 Agent 模式。它把“思考”和“行动”交替展开，让模型在每一步先判断需要什么，再调用对应工具。

### 8.3.1 ReAct 的核心格式

典型 ReAct trace：

```text
Thought: 我需要先确认用户说的“本周票房冠军”具体指哪个市场。
Action: web_search
Action Input: {"query": "2026 中国内地 本周票房冠军"}
Observation: 搜索结果显示《X》位列本周中国内地票房第一。
Thought: 用户还问了导演是谁，我需要继续查询电影信息。
Action: movie_db_lookup
Action Input: {"title": "X"}
Observation: 导演为 Y。
Thought: 我已经得到完整答案。
Final Answer: 本周中国内地票房冠军是《X》，导演是 Y。
```

这个模式的好处有三个：

1. **可解释**：可以回放每步 Thought / Action / Observation。
2. **易调试**：工具失败时能看到是模型选错工具、参数不对，还是外部系统有问题。
3. **泛化强**：只要工具描述合理，模型能把不同任务映射到统一执行循环。

### 8.3.2 一个完整示例

用户目标：“帮我判断一篇 AI 新闻是否值得转发到团队群，并给出一句摘要。”

ReAct trace 可以设计成：

```text
Thought: 我需要先获取新闻内容。
Action: fetch_url
Action Input: {"url": "https://example.com/ai-news"}
Observation: 文章讲的是某模型发布新推理 API，包含价格与延迟数据。

Thought: 我需要提取关键信息：发布时间、能力提升、成本变化、是否影响工程实践。
Action: extract_facts
Action Input: {"text": "..."}
Observation: 提取到 4 个核心事实。

Thought: 用户关心“是否值得转发”，我需要从新颖性、可信度、与团队相关性三方面评估。
Action: none
Observation: none

Final Answer: 值得转发。原因是……一句摘要：……
```

注意，ReAct 中的 Thought 不一定需要向最终用户暴露。生产环境通常会：

- 对用户隐藏完整推理；
- 但在日志中保留结构化 trace；
- 只展示必要的 tool call 和 final answer。

### 8.3.3 ReAct 的局限

ReAct 并不万能。典型问题包括：

- 复杂任务时，模型容易一步一步试错，成本高；
- 循环次数过多时，状态膨胀，token 成本上升；
- 如果工具很多，模型会“犹豫”或乱选工具；
- 缺少显式长程规划，做项目级任务时效率偏低。

因此实际系统里 अक्सर会把 ReAct 与规划器组合，形成 Plan-and-Execute 或 LangGraph 式状态图。

## 8.4 核心架构模式二：Function Calling

Function Calling（函数调用）不是完整 Agent 架构，但它是现代 Agent 最重要的基础协议之一。它允许模型不再输出“请你调用某个函数”，而是直接生成结构化调用请求。

### 8.4.1 OpenAI / Anthropic 的基本思想

核心思路相同：开发者把工具列表和参数模式（schema）发给模型，模型在生成时可选择：

1. 直接返回文本；
2. 返回一个或多个工具调用；
3. 等工具结果回来后再继续回答。

典型工具定义包含三部分：

| 字段 | 作用 | 示例 |
|---|---|---|
| name | 工具唯一标识 | `get_weather` |
| description | 告诉模型何时使用 | “获取某城市未来 3 天天气预报” |
| parameters schema | 参数约束 | JSON Schema / Pydantic model |

### 8.4.2 JSON Schema 示例

```json
{
  "name": "get_weather",
  "description": "获取指定城市未来最多7天的天气预报，适用于用户询问天气、温度、降雨概率",
  "parameters": {
    "type": "object",
    "properties": {
      "city": {
        "type": "string",
        "description": "城市名称，例如 Beijing 或 Shanghai"
      },
      "days": {
        "type": "integer",
        "minimum": 1,
        "maximum": 7,
        "description": "查询天数"
      }
    },
    "required": ["city", "days"],
    "additionalProperties": false
  }
}
```

模型看到这个 schema 后，会尽量输出类似：

```json
{
  "tool_name": "get_weather",
  "arguments": {
    "city": "Shanghai",
    "days": 3
  }
}
```

### 8.4.3 Function Calling 的价值

- 大幅降低解析自然语言 Action 的脆弱性；
- 参数验证可以交给 schema 层；
- 更利于并行工具调用；
- 更适合接企业 API、数据库、内部服务。

当面试官问“Function Calling 和 Prompt-based tool use 的区别是什么”，你可以回答：**前者把工具调用从文本协议升级成结构化协议，使推理和执行之间的接口更稳定、可验证、可监控。**

## 8.5 核心架构模式三：Plan-and-Execute

Plan-and-Execute（规划后执行）适合中长任务。它把系统拆成两个角色：

1. **Planner（规划器）**：先给出步骤列表；
2. **Executor（执行器）**：逐步执行每一步，必要时再局部调整。

ASCII 示意图：

```text
User Goal
   |
   v
+-----------+
|  Planner  | ---> Step 1, Step 2, Step 3...
+-----------+
   |
   v
+-----------+    tool calls / retries / state updates
| Executor  | ---------------------------------------->
+-----------+
   |
   v
 Final Result
```

### 8.5.1 为什么复杂任务更适合这样做

假设任务是：“分析竞争对手最近 30 天发布的 AI 产品动态，给出对我们路线图的建议。”

如果纯 ReAct，模型可能会边搜边想，十几步后还没有全局结构；而 Plan-and-Execute 可以先规划：

1. 找出竞争对手名单；
2. 抓取最近 30 天新闻与产品更新；
3. 提取发布内容中的能力、价格、目标用户；
4. 横向比较；
5. 结合我方路线图输出建议。

优点：

- 更适合长任务；
- 执行器上下文更聚焦；
- 可以对计划做审计、缓存与人工审批；
- 易于插入 checkpoint。

缺点：

- 计划质量决定上限；
- 计划可能过时，需要中途重规划（re-plan）；
- 额外增加一次 LLM 调用。

## 8.6 核心架构模式四：Reflexion

Reflexion（反思）可以理解为“Agent 给自己做复盘”。它不是单独替代 ReAct，而是加在执行之后的一层自评机制。

典型流程：

```text
执行任务 -> 检查结果 -> 判断是否满足目标 -> 若不满足则生成改进策略 -> 再执行
```

例如写 SQL：

1. 模型先生成 SQL；
2. 执行报错：`column usernmae does not exist`；
3. Reflexion 模块总结：“我拼错了列名 username”；
4. 下一轮带着纠错经验重试。

Reflexion 的收益在于：

- 让错误信息转化为下一轮可利用的显式经验；
- 对代码、查询、搜索类任务特别有效；
- 可把历史失败模式沉淀为 procedural memory（程序性记忆）。

但注意，Reflexion 不是“让模型空想”。好的反思必须绑定**可验证反馈**，比如测试失败日志、HTTP 403、schema validation error、单元测试断言差异等。

## 8.7 工具使用（Tool Use）设计

Agent 能不能稳定工作，70% 取决于工具层设计。

### 8.7.1 工具描述的最佳结构

推荐统一格式：

| 字段 | 说明 | 设计建议 |
|---|---|---|
| name | 短小唯一 | 动词开头，如 `search_docs` |
| description | 告诉模型何时用、何时不用 | 写清楚适用边界 |
| parameters | 严格 schema | 限制类型、范围、枚举 |
| examples | 可选 | 给 1~2 个典型调用 |
| permissions | 可选 | 标注 read-only / write |

差的描述：“查询信息。”

好的描述：“在公司知识库中搜索技术文档。适用于查找内部 API、部署流程、架构设计；不适用于互联网公开搜索。”

### 8.7.2 模型如何选择工具

模型本质上会做一个隐式分类问题：

> 当前用户意图更适合直接回答，还是调用哪一个工具？

因此你要让工具集合具备：

- **低歧义**：避免同时有 `search_web`、`web_lookup`、`internet_search` 三个几乎一样的工具；
- **高可分性**：工具边界清晰；
- **有限数量**：常见经验是 10~30 个核心工具比 100 个泛工具更稳定。

### 8.7.3 并行工具调用

并行（parallel tool calling）非常关键。比如用户问：

“比较北京、上海、深圳今天温度，并给出最高和最低城市。”

如果串行查三次天气，整体延迟可能是：

- 每次 API 400ms
- 串行 = 1.2s + LLM 推理
- 并行 = 0.4s + 聚合

并行调用架构：

```text
            +--> get_weather(Beijing) --+
User Query -+--> get_weather(Shanghai) -+--> Aggregator --> Final Answer
            +--> get_weather(Shenzhen) -+
```

适合并行的前提：

- 工具间无依赖；
- 结果聚合规则明确；
- 成本可控；
- 下游能处理部分失败。

### 8.7.4 工具结果处理与错误恢复

工具执行不只是“返回字符串”。推荐统一返回结构：

```python
{
    "ok": True,
    "data": {...},
    "error": None,
    "retryable": False
}
```

错误恢复策略：

1. 参数校验失败：把 schema error 回传模型，让其自修正；
2. 临时网络失败：自动重试 2~3 次；
3. 权限不足：立即终止该工具并提示用户；
4. 非关键工具失败：降级回答；
5. 关键路径失败：触发 re-plan。

## 8.8 规划策略

### 8.8.1 Chain-of-Thought Planning

Chain-of-Thought（思维链）规划适合短任务。模型先在内部展开若干步思考，再给出行动。它的优点是简单，缺点是对长任务不稳定，而且不适合完全暴露给用户。

### 8.8.2 递归任务分解

工程上更有价值的是递归分解：

```text
Goal: 生成竞品分析
 ├─ 收集竞品名单
 ├─ 获取每个竞品最近版本信息
 │   ├─ 读取官网
 │   ├─ 搜新闻
 │   └─ 提取功能
 ├─ 汇总对比表
 └─ 输出建议
```

递归分解的核心不是“拆得越细越好”，而是把每个子任务拆到：

- 输入明确；
- 工具明确；
- 完成标准明确；
- 可独立验证。

### 8.8.3 目标导向规划与回溯

当任务存在障碍时，Agent 需要 backtracking（回溯）。例如：

1. 原计划通过 API 获取价格；
2. API 权限不足；
3. 回退到公开文档抓取；
4. 若仍失败，再输出“基于现有公开数据”的近似结果。

这和搜索算法里的 DFS/BFS 不完全一样，但思想相通：**不是失败就结束，而是换路径继续逼近目标。**

## 8.9 Agent Loop 中的状态管理

没有状态管理的 Agent，通常活不过 5 轮。

最少需要管理三类状态：

| 状态 | 作用 | 示例 |
|---|---|---|
| Conversation State | 保存对话与工具历史 | messages, tool traces |
| Task State | 保存当前目标和计划 | 当前 step=3/5 |
| Environment State | 保存外部执行上下文 | 文件路径、session id、权限级别 |

常见工程问题：

- 循环次数上限如何设？常见 6~20 步；
- 何时终止？可由模型输出 `finish`，也可由外部策略判断；
- 工具结果要不要全文写回上下文？通常只写摘要和关键字段；
- 如何避免重复调用同一工具？给状态加去重缓存。

一个实用状态对象可能包含：

```python
state = {
    "goal": "...",
    "history": [],
    "observations": [],
    "plan": [],
    "current_step": 0,
    "tool_cache": {},
    "failures": [],
    "finished": False
}
```

## 8.10 架构模式对比：什么时候用哪一种

| 模式 | 适合场景 | 优势 | 劣势 | 面试回答关键词 |
|---|---|---|---|---|
| ReAct | 通用问答、检索、轻执行 | 简单、可解释、易实现 | 长任务效率一般 | trace、interleaving |
| Function Calling | 企业 API、结构化工具 | 稳定、可验证、强约束 | 不是完整规划框架 | schema、structured call |
| Plan-and-Execute | 复杂多步任务 | 全局性更强、便于审计 | 多一次规划成本 | planner/executor |
| Reflexion | 需要试错纠错 | 利于自改进 | 额外 token 成本 | self-evaluation、feedback |

一个很好用的面试表达是：

> 小任务用 ReAct，中任务用 Function Calling + ReAct，大任务用 Plan-and-Execute，失败率高的任务叠加 Reflexion。

## 8.11 从零实现一个简单 ReAct Agent

下面我们不用任何框架，只用 Python + OpenAI API 风格接口，实现一个最小可运行 ReAct Agent。为了让代码自包含，示例工具使用本地函数模拟搜索与计算。

### 8.11.1 项目结构

```text
react_agent/
├─ agent.py
└─ requirements.txt
```

`requirements.txt`

```txt
openai>=1.40.0
```

### 8.11.2 完整代码

```python
import json
import math
from typing import Any, Dict, List

from openai import OpenAI


client = OpenAI(api_key="YOUR_API_KEY")


def calculator(expression: str) -> Dict[str, Any]:
    allowed = {
        "abs": abs,
        "round": round,
        "sqrt": math.sqrt,
        "pow": pow,
    }
    try:
        value = eval(expression, {"__builtins__": {}}, allowed)
        return {"ok": True, "data": {"expression": expression, "result": value}, "error": None}
    except Exception as exc:
        return {"ok": False, "data": None, "error": str(exc)}


def fake_search(query: str) -> Dict[str, Any]:
    corpus = {
        "python release date": "Python 3.12 was released on 2023-10-02.",
        "openai founded": "OpenAI was founded in 2015.",
        "anthropic founded": "Anthropic was founded in 2021."
    }
    result = corpus.get(query.lower(), "No exact result found.")
    return {"ok": True, "data": {"query": query, "result": result}, "error": None}


TOOLS = {
    "calculator": {
        "description": "执行数学表达式计算，适用于加减乘除、平方根、幂运算。",
        "schema": {
            "type": "object",
            "properties": {
                "expression": {"type": "string", "description": "例如 (32 + 18) / 5"}
            },
            "required": ["expression"],
            "additionalProperties": False,
        },
        "handler": calculator,
    },
    "search": {
        "description": "搜索小型知识库，适用于查询已知事实。",
        "schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "搜索关键词"}
            },
            "required": ["query"],
            "additionalProperties": False,
        },
        "handler": fake_search,
    },
}


SYSTEM_PROMPT = """
你是一个 ReAct Agent。
你必须严格遵循以下格式之一：

1. 如果需要调用工具，输出 JSON：
{"type":"tool_call","name":"工具名","arguments":{...},"thought":"简短说明"}

2. 如果已经可以回答，输出 JSON：
{"type":"final","answer":"最终答案","thought":"简短说明"}

不要输出额外文本。
"""


def build_tool_spec() -> str:
    specs = []
    for name, meta in TOOLS.items():
        specs.append({
            "name": name,
            "description": meta["description"],
            "parameters": meta["schema"],
        })
    return json.dumps(specs, ensure_ascii=False, indent=2)


def call_model(messages: List[Dict[str, str]]) -> Dict[str, Any]:
    response = client.chat.completions.create(
        model="gpt-4.1-mini",
        temperature=0,
        messages=messages,
        response_format={"type": "json_object"},
    )
    content = response.choices[0].message.content
    return json.loads(content)


def run_agent(user_goal: str, max_steps: int = 8) -> str:
    messages: List[Dict[str, str]] = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {
            "role": "user",
            "content": (
                f"可用工具如下：\n{build_tool_spec()}\n\n"
                f"用户目标：{user_goal}"
            ),
        },
    ]

    for step in range(1, max_steps + 1):
        decision = call_model(messages)
        print(f"[Step {step}] Decision => {decision}")

        if decision["type"] == "final":
            return decision["answer"]

        if decision["type"] != "tool_call":
            raise ValueError(f"Unknown decision type: {decision}")

        tool_name = decision["name"]
        arguments = decision["arguments"]

        if tool_name not in TOOLS:
            observation = {
                "ok": False,
                "error": f"Tool {tool_name} not found",
                "retryable": False,
            }
        else:
            try:
                observation = TOOLS[tool_name]["handler"](**arguments)
            except TypeError as exc:
                observation = {
                    "ok": False,
                    "error": f"Bad arguments: {exc}",
                    "retryable": True,
                }

        messages.append(
            {
                "role": "assistant",
                "content": json.dumps(decision, ensure_ascii=False),
            }
        )
        messages.append(
            {
                "role": "user",
                "content": "Observation: " + json.dumps(observation, ensure_ascii=False),
            }
        )

    return "超过最大执行步数，任务未完成。"


if __name__ == "__main__":
    answer = run_agent("OpenAI 成立于哪一年？再计算 2026 - 该年份。")
    print("Final Answer:", answer)
```

### 8.11.3 代码解读

这个实现虽然小，但具备了 ReAct 的关键要素：

1. **显式循环**：`for step in range(...)`；
2. **工具注册表**：`TOOLS`；
3. **结构化决策**：模型只能输出 `tool_call` 或 `final`；
4. **Observation 回写**：工具结果重新注入上下文；
5. **最大步数保护**：避免死循环。

如果要扩展到生产环境，下一步通常是：

- 用真正的 function calling 替代 JSON 文本协议；
- 加入参数校验；
- 接入日志与 trace id；
- 对工具结果做摘要压缩；
- 增加重试、缓存与权限控制；
- 把状态持久化到 Redis 或数据库。

## 8.12 面试中如何讲 Agent 架构

如果面试官问：“请你设计一个企业知识库问答 Agent 架构”，你可以按以下顺序回答：

1. 明确目标：问答、检索、引用、权限控制；
2. 选模式：用 Function Calling + ReAct；
3. 状态：保留会话历史、工具 trace、检索缓存；
4. 工具：搜索、文档读取、权限校验；
5. 错误恢复：检索无结果时扩大召回，工具失败时重试；
6. 可观测性：记录每步 thought summary、tool name、latency、token usage；
7. 安全：只读工具、敏感文档 ACL。

这样的回答会让人感觉你不是“会调模型”，而是在设计一套可上线系统。

## 8.13 生产中如何组合这些模式

实际项目里很少只用一种模式。更常见的做法是把几种模式叠加成分层架构：

1. 最外层用 **Plan-and-Execute** 做长任务编排；
2. 每个执行步骤内部用 **ReAct** 做短循环；
3. 工具层统一走 **Function Calling**；
4. 遇到失败率高的步骤，再插入 **Reflexion** 做自我修正。

一个真实感很强的例子是“代码仓库分析 Agent”：

- 用户目标：分析某仓库中最近 30 天的性能回归并给出修复建议；
- Planner 先拆成“找 commit、定位回归、读取性能日志、生成建议”四步；
- “定位回归”这一步内部，Executor 用 ReAct 反复调用 `git_log`、`read_file`、`search_trace`；
- 工具调用全部使用结构化 schema；
- 如果生成的根因解释与测试日志矛盾，则启动 Reflexion，再读一次关键信息。

这种组合方式的好处，是把“全局规划”和“局部试错”分开。全局层追求正确方向，局部层追求灵活执行。如果把两者混在一起，模型很容易在细枝末节上花掉全部上下文预算。

再看一个适用于面试的选型表：

| 任务类型 | 推荐组合 | 原因 |
|---|---|---|
| 查询天气、库存、订单 | Function Calling + ReAct | 步骤短，重点是工具稳定性 |
| 文档总结、资料调研 | ReAct + Summary Memory | 检索后快速整合即可 |
| 数据分析、代码修复 | ReAct + Reflexion | 错误反馈可验证，适合自修正 |
| 长流程自动化 | Plan-and-Execute + Function Calling | 先规划、后分步执行更稳 |
| 高风险写操作 | Plan-and-Execute + Human Approval | 需要检查点与审批点 |

一个成熟工程师与初学者的差别，往往不在于会不会背这些名字，而在于能否说清楚“为什么这个场景要这样组合”。

## 8.14 Agent 架构的关键监控指标

如果系统要上线，就不能只看“回答像不像人”。至少要埋以下指标：

| 指标 | 含义 | 典型阈值 |
|---|---|---|
| loop_steps | 单次任务循环步数 | 6~12 步为常见范围 |
| tool_success_rate | 工具调用成功率 | 核心工具应 > 95% |
| repeated_action_rate | 重复调用同一工具的比例 | 持续升高通常表示陷入局部循环 |
| final_answer_rate | 能正常收敛到最终答案的比例 | 生产目标通常 > 90% |
| avg_tokens_per_task | 单任务 token 消耗 | 用于成本治理 |
| replanning_rate | 需要重规划的比例 | 过高说明 planner 质量不足 |

其中最容易被忽略的是 `repeated_action_rate`。很多 Agent 表面上“没有报错”，但它会连续三次调用同一个搜索工具，只是换着措辞问。这类问题如果不靠日志统计，很难单凭肉眼发现。

另一个关键点是 **工具观察结果的可压缩性**。如果某个工具每次返回 20KB 原始 JSON，而模型真正需要的只有两个字段，那么系统应该在 Observe 阶段就做 reducer，把结果压成：

```text
订单状态=已发货；预计送达=2026-06-14；物流单号=SF123456789
```

这样既减少 token，又能提升后续推理质量。

## 8.15 三个常见反模式

### 反模式一：把 Thought 当成对用户的产品功能

有些系统把模型的内部思考原样展示给用户，结果既冗长又不稳定。正确做法是：**内部 trace 用于调试，面向用户的解释单独生成**。

### 反模式二：工具层太薄，只返回“成功/失败”

如果工具错误只返回 `failed`，模型根本不知道如何修。更好的返回应该告诉它：

- 哪个字段错了；
- 期望类型是什么；
- 是否可重试；
- 是否建议改用别的工具。

### 反模式三：没有显式终止条件

很多新人写 Agent Loop 时，只让模型自己判断何时结束，没有外部硬限制。结果一旦模型进入循环，就会一直消耗 token。实际工程中至少要同时有三道闸：

1. 最大循环步数；
2. 最大工具调用次数；
3. 最大 token / 成本预算。

你在面试里如果能主动提这三点，面试官通常会认为你做过真实系统，而不是只跑过 notebook。

## 8.16 一个实战设计题的回答框架

假设面试官让你现场设计“一个能够读取企业文档、查询工单系统、自动生成处理建议的客服 Agent”。你可以直接按下面框架展开：

第一步，说明为什么它不是简单问答，而是 Agent：因为它要根据用户问题自主决定查知识库、查工单还是结束回答，还要在多步调用后汇总证据。

第二步，说明架构模式：外层使用 Function Calling + ReAct，复杂问题再加一个轻量 planner。理由是客服场景大部分问题在 3~6 步内可收敛，不一定需要重型 Plan-and-Execute，但又必须具备显式工具调用能力。

第三步，说明状态：

- 会话状态保存最近问答；
- 任务状态保存当前是否已查工单、是否已查知识库；
- 环境状态保存用户身份、权限、工单号。

第四步，说明终止条件：当模型拿到足够证据并且置信度达到阈值，比如 0.8，就输出最终答案；否则转人工。

第五步，说明监控：统计平均循环数、工具成功率、转人工率、重复调用率、引用证据覆盖率。

这种回答方式的价值在于，它把“模式名词”落到了“如何上线”。

## 本章要点

- Agent 与单次 LLM 调用的根本区别在于自主性、工具使用、规划和记忆。
- 绝大多数 Agent 都可抽象成 Perceive → Reason → Act → Observe 的循环。
- ReAct 适合通用场景，优点是简单、透明、易调试。
- Function Calling 把工具调用接口结构化，是现代 Agent 工程的基础设施。
- Plan-and-Execute 适合复杂长任务，Reflexion 适合高失败率、可验证反馈场景。
- 工具设计要强调 schema、边界、并行能力、错误恢复和统一返回格式。
- 没有状态管理与终止条件的 Agent，很容易失控、重复调用或无限循环。

## 延伸阅读

1. ReAct: Synergizing Reasoning and Acting in Language Models
2. Toolformer: Language Models Can Teach Themselves to Use Tools
3. OpenAI Function Calling / Responses API 官方文档
4. Anthropic Tool Use 与 Model Context Protocol 官方文档
5. LangGraph 关于 stateful agent loops 的设计文档
