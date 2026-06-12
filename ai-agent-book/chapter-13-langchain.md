# 第十三章：LangChain 全栈实战

如果说前几章解决了“为什么要做 Agent、Agent 由哪些模块组成”，那么本章解决的是“如何用一套工程化框架，把这些模块真正拼起来”。在 2025-2026 年的招聘市场里，要求候选人“会用 LangChain”的岗位已经不再满足于写一个两百行的 demo，而是希望你能回答：为什么要用 LCEL（LangChain Expression Language，LangChain 表达式语言）而不是旧式 Chain？什么时候要切到 LangGraph？如何做 tracing、评测、部署与回放？这些问题，决定了你是“会调包”，还是“能落地生产级 Agent”。

## 13.1 LangChain 生态全景

今天的 LangChain 已经不是一个单包，而是一组围绕 Agent 生命周期展开的组件：

| 组件 | 作用 | 典型使用场景 | 面试高频问法 |
|---|---|---|---|
| LangChain Core | 核心抽象层，包含 Runnable、Prompt、Parser、Model 接口 | 构建链路、封装工具、流式输出 | 为什么 LCEL 比传统 Chain 更适合生产？ |
| LangGraph | 有状态（stateful）的图执行框架 | 多步工具调用、分支决策、人工介入 | 为什么 Agent 最终会演进为状态机？ |
| LangSmith | 可观测性与评测平台 | tracing、数据集管理、回归评测 | 如何定位 Agent 某一轮推理失败？ |
| LangServe | 把 Runnable/Graph 暴露为 API 服务 | 内部平台化、HTTP 部署 | 如何把一个本地链部署给前端调用？ |

可以把它理解成一条流水线：

```text
+------------------+      +-------------------+      +------------------+
| LangChain Core   | ---> | LangGraph         | ---> | LangServe        |
| 组合基本能力      |      | 组织状态与流程      |      | 暴露为在线服务      |
+------------------+      +-------------------+      +------------------+
           \                         |
            \                        v
             \------------> +------------------+
                             | LangSmith        |
                             | tracing/eval     |
                             +------------------+
```

在工程实践里，一个非常常见的分层是：

1. **Core 层**：定义 prompt、模型、输出解析器、工具。
2. **Graph 层**：定义状态机、分支条件、重试策略、人工审批节点。
3. **Serve 层**：定义 API、鉴权、限流、版本管理。
4. **Observe 层**：把每次运行送到 LangSmith，做回放与评测。

这也是很多中大型团队在 2026 年默认采用的组织方式，因为它把“提示词工程”和“软件工程”真正结合起来。

## 13.2 核心抽象：不是记 API，而是理解数据流

### 13.2.1 ChatModel / LLM

`ChatModel` 代表对话式模型接口，输入通常是消息数组，输出是 `AIMessage`；`LLM` 更偏纯文本输入输出。对于现代 Agent 项目，优先选择 `ChatModel`，因为它天然支持 tool calling、system/user/assistant roles、structured output。

```python
from langchain_openai import ChatOpenAI

model = ChatOpenAI(
    model="gpt-4.1-mini",
    temperature=0.2,
    max_tokens=1200,
)
```

面试里常见追问是：为什么很多代码里已经几乎看不到 `LLMChain`，但依然需要理解 `LLM`？答案是：**底层仍然是“输入 -> 模型 -> 输出”的变换，只是现代框架把它统一抽象为 Runnable。**

### 13.2.2 PromptTemplate

`PromptTemplate` 或 `ChatPromptTemplate` 负责把结构化变量转成模型可消费的 prompt。它的价值不是“字符串替换”，而是**把提示词定义为可组合、可测试、可版本化的对象**。

```python
from langchain_core.prompts import ChatPromptTemplate

prompt = ChatPromptTemplate.from_messages([
    ("system", "你是一个严谨的技术研究助手，必须输出带来源的结论。"),
    ("human", "请分析主题：{topic}。输出三部分：背景、关键结论、待验证风险。")
])
```

### 13.2.3 OutputParser

输出解析器（OutputParser，输出解析器）解决的是“模型会说人话，但程序需要结构化数据”的问题。

| Parser | 输出形式 | 适用场景 | 风险 |
|---|---|---|---|
| StrOutputParser | 纯字符串 | 总结、改写、草稿生成 | 后续处理需要再解析 |
| JsonOutputParser | JSON 字典 | 规则化输出、接口对接 | 模型可能漏字段 |
| PydanticOutputParser | Pydantic 模型 | 强校验、生产结构化输出 | 约束强时失败率可能升高 |

```python
from pydantic import BaseModel, Field
from langchain_core.output_parsers import PydanticOutputParser

class ResearchSummary(BaseModel):
    topic: str = Field(description="研究主题")
    findings: list[str] = Field(description="关键发现")
    risks: list[str] = Field(description="风险点")

parser = PydanticOutputParser(pydantic_object=ResearchSummary)
```

真正的工程经验是：**越靠近生产接口，越应使用强约束 parser；越靠近探索阶段，越可使用字符串 parser 提高吞吐与灵活性。**

### 13.2.4 Chain（legacy）vs LCEL

旧式 `Chain` 的思维方式是“框架提供一个类，你往里面塞 prompt、model、memory”；LCEL 的思维方式是“所有东西都是 Runnable，可以像 UNIX 管道一样组合”。后者更轻、更通用，也更适合流式与并行。

| 维度 | 传统 Chain | LCEL |
|---|---|---|
| 组合方式 | 面向类 | 面向数据流 |
| 可测试性 | 中等 | 高 |
| 流式支持 | 较弱 | 原生支持 |
| 并行支持 | 额外封装 | `RunnableParallel` 直接表达 |
| 调试 | 依赖内部实现 | 每个 Runnable 都可单测 |

一句话总结：**LCEL 让 LangChain 从“脚手架”变成“可编排运行时”。**

## 13.3 LCEL 深入：Runnable 是第一公民

### 13.3.1 `|` 管道操作符

LCEL 最核心的语法就是 `|`。左边的输出自动成为右边的输入。

```python
from langchain_core.output_parsers import StrOutputParser

chain = prompt | model | StrOutputParser()
result = chain.invoke({"topic": "向量数据库在客服系统中的应用"})
print(result)
```

这段代码本质上描述了一条明确的数据路径：

```text
input(dict) -> prompt(messages) -> model(AIMessage) -> parser(str)
```

一旦你把系统看成数据流，很多工程问题会变得简单：哪里失败、哪里加缓存、哪里加 tracing、哪里插入 guardrail，都更明确。

### 13.3.2 RunnablePassthrough

`RunnablePassthrough` 适合把输入原样传递下去，并在中间补充额外字段。

```python
from langchain_core.runnables import RunnablePassthrough

enrich_chain = (
    RunnablePassthrough.assign(
        query_length=lambda x: len(x["query"]),
        language=lambda _: "zh-CN",
    )
)

print(enrich_chain.invoke({"query": "比较 LangChain 和 LlamaIndex 的 RAG 方案"}))
```

这在面试中常被考察为“如何在不改写原始数据结构的前提下，逐步附加上下文”。

### 13.3.3 RunnableLambda

`RunnableLambda` 可以把普通 Python 函数包装进 LCEL，用来做轻量后处理、格式变换或条件路由前的预处理。

```python
from langchain_core.runnables import RunnableLambda

def normalize_topic(payload: dict) -> dict:
    payload["topic"] = payload["topic"].strip().lower()
    return payload

chain = RunnableLambda(normalize_topic) | prompt | model | StrOutputParser()
```

经验法则：涉及 I/O、重试、超时控制的工具，建议单独封装；只做本地纯函数变换时，`RunnableLambda` 很高效。

### 13.3.4 RunnableParallel

生产 Agent 经常需要“同一问题，多路分析同时进行”。例如同时做事实提取、风险提取、引用抽取：

```python
from langchain_core.runnables import RunnableParallel

fact_prompt = ChatPromptTemplate.from_template("提取主题 {topic} 的 3 个事实")
risk_prompt = ChatPromptTemplate.from_template("提取主题 {topic} 的 3 个风险")

parallel = RunnableParallel({
    "facts": fact_prompt | model | StrOutputParser(),
    "risks": risk_prompt | model | StrOutputParser(),
})

print(parallel.invoke({"topic": "企业内部部署 AI Agent"}))
```

如果一个请求原本串行需要 2.8 秒，两路并行后可能下降到 1.5-1.7 秒。真实收益取决于模型端并发配额与网络开销，但在“摘要 + 分类 + 风险识别”类任务中通常很明显。

### 13.3.5 Streaming 与 Batch

流式（streaming，流式输出）是前端体验的关键；批处理（batch，批量处理）是离线效率的关键。

```python
for chunk in chain.stream({"topic": "MCP 与 A2A 的差异"}):
    print(chunk, end="", flush=True)

batch_inputs = [
    {"topic": "RAG 评测"},
    {"topic": "Agent memory"},
    {"topic": "Tool calling"},
]
results = chain.batch(batch_inputs, config={"max_concurrency": 3})
```

面试里如果你能讲出“在线场景优先 stream，离线评测优先 batch，并结合 provider 的速率限制设置 `max_concurrency`”，通常会被认为有真实项目经验。

## 13.4 LangGraph：为什么复杂 Agent 最终都像状态机

当流程出现“多轮判断、工具调用、失败重试、人工审批、长期记忆”时，仅靠线性链已经不够。LangGraph 以图（Graph，图结构）表达状态流转。

核心概念如下：

| 概念 | 含义 | 工程价值 |
|---|---|---|
| Graph | 整体流程图 | 显式描述 Agent 生命周期 |
| Node | 一个执行单元 | 模型调用、工具执行、人工审批都可做节点 |
| Edge | 节点之间的连接 | 表达顺序、条件和回路 |
| State | 整个运行上下文 | 把“对话”和“程序变量”统一管理 |

ASCII 图示例如下：

```text
START
  |
  v
[planner] ---> if need_tool? ----yes----> [tool_node]
  |                                   |
  no                                  v
  |                               [synthesizer]
  v                                   |
[answer] <-----------------------------+
  |
 END
```

### 13.4.1 用 TypedDict 定义 State

与其把状态散落在全局变量或 message history 中，不如显式定义 schema：

```python
from typing import TypedDict, List

class AgentState(TypedDict, total=False):
    user_query: str
    plan: str
    search_queries: List[str]
    documents: List[str]
    answer: str
    needs_human_review: bool
```

这个设计的价值很大：类型可检查、节点边界清晰、调试时一眼能看出每一步对 state 做了什么修改。

### 13.4.2 条件边（Conditional Edges）

Agent 的本质不是“永远调用工具”，而是“根据状态决定下一步”。

```python
def route_after_planning(state: AgentState) -> str:
    if state.get("needs_human_review"):
        return "human_review"
    if state.get("search_queries"):
        return "search"
    return "answer"
```

这类条件路由非常适合实现：

- 风险问题升级人工审批；
- 查询词为空时直接回答；
- 工具失败次数超过 3 次时进入降级节点。

### 13.4.3 Checkpointing 与 Human-in-the-loop

检查点（checkpointing，检查点持久化）意味着图在任意节点可中断、保存、恢复。对于长任务尤为重要，比如一份行业报告需要 8-12 次工具调用、总耗时 40-90 秒。如果第 9 步失败，没有 checkpoint 就只能从头再跑。

人工介入（human-in-the-loop，人类参与闭环）常见在：

1. 法务/财务/医疗等高风险输出；
2. 高成本操作，比如真正执行外部 API 写入；
3. 用户对中间计划不满意，需要修改。

LangGraph 的好处是：**人工节点不是“旁路逻辑”，而是图上的正式节点**。

### 13.4.4 Subgraph：把大 Agent 拆成模块

当图超过 10 个节点后，建议拆成子图（subgraph，子图）：

- 查询理解子图；
- 检索与证据整理子图；
- 输出合成子图；
- 风险评审子图。

这会显著提高可维护性。面试里你可以强调：**子图的价值不只是复用，更是让每一段状态转换有稳定边界。**

## 13.5 端到端实战：研究助手 Agent

下面构建一个“技术研究助手”，输入主题后自动生成研究计划、调用搜索工具、汇总证据、输出结构化结论，并保留可审计轨迹。

### 13.5.1 状态与工具定义

```python
from __future__ import annotations
import os
from typing import TypedDict, List
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langgraph.graph import StateGraph, START, END

class ResearchState(TypedDict, total=False):
    topic: str
    plan: str
    queries: List[str]
    documents: List[str]
    draft: str
    final_answer: str

model = ChatOpenAI(model="gpt-4.1-mini", temperature=0.2)

def search_web(query: str) -> str:
    mock_results = {
        "langgraph checkpointing best practices": "LangGraph 支持 checkpoint saver，可恢复中断执行。",
        "langsmith evaluation datasets": "LangSmith 可管理数据集并做回归评测。",
    }
    return mock_results.get(query, f"未命中：{query}")
```

这里用本地 mock 工具，保证示例无需真实搜索 API 也能运行。真实项目里可替换为 Tavily、SerpAPI、内部检索服务。

### 13.5.2 规划节点

```python
planner_prompt = ChatPromptTemplate.from_template(
    "你是技术研究员。针对主题：{topic}，输出两行内容。\n"
    "第1行：研究计划。\n"
    "第2行：最多2个英文搜索词，用逗号分隔。"
)

planner_chain = planner_prompt | model | StrOutputParser()

def planner_node(state: ResearchState) -> ResearchState:
    text = planner_chain.invoke({"topic": state["topic"]})
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    queries = []
    if len(lines) >= 2:
        queries = [q.strip() for q in lines[1].split(",") if q.strip()]
    return {"plan": lines[0] if lines else "", "queries": queries}
```

### 13.5.3 工具节点与汇总节点

```python
def search_node(state: ResearchState) -> ResearchState:
    docs = [search_web(q) for q in state.get("queries", [])]
    return {"documents": docs}

synthesis_prompt = ChatPromptTemplate.from_template(
    "主题：{topic}\n"
    "计划：{plan}\n"
    "证据：\n{documents}\n\n"
    "请输出：1）核心结论 2）风险 3）下一步建议"
)

synthesis_chain = synthesis_prompt | model | StrOutputParser()

def synthesize_node(state: ResearchState) -> ResearchState:
    docs_text = "\n".join(f"- {d}" for d in state.get("documents", []))
    draft = synthesis_chain.invoke({
        "topic": state["topic"],
        "plan": state.get("plan", ""),
        "documents": docs_text,
    })
    return {"final_answer": draft}
```

### 13.5.4 构图

```python
graph = StateGraph(ResearchState)
graph.add_node("planner", planner_node)
graph.add_node("search", search_node)
graph.add_node("synthesize", synthesize_node)

graph.add_edge(START, "planner")
graph.add_edge("planner", "search")
graph.add_edge("search", "synthesize")
graph.add_edge("synthesize", END)

app = graph.compile()

if __name__ == "__main__":
    result = app.invoke({"topic": "LangChain 在生产环境中的可观测性实践"})
    print(result["final_answer"])
```

这是最小可运行版本。真实项目会继续补：

- 失败重试；
- 查询质量判定；
- 人工审批；
- 外部记忆；
- LangSmith tracing；
- LangServe 部署。

### 13.5.5 加入 Memory 与 Checkpoint

对于对话式研究助手，至少要区分两种记忆：

| 类型 | 保存内容 | 生命周期 |
|---|---|---|
| Thread memory | 本轮对话上下文 | 一个 session |
| Long-term memory | 用户偏好、历史主题、常用数据源 | 跨 session |

LangGraph 常见做法是把短期状态放入 graph state，把长期记忆放数据库或向量库，并在入口节点做检索补全。不要把所有历史都塞回 prompt；到 30-50 轮后，成本与延迟都会失控。

## 13.6 LangServe：把图真正发布出去

很多候选人会写本地 notebook，却不会部署。LangServe 的价值，是把 Runnable 或 Graph 暴露为 HTTP endpoint。

```python
from fastapi import FastAPI
from langserve import add_routes

server = FastAPI(title="research-assistant")
add_routes(server, app, path="/research")
```

常见接口包括：

- `POST /research/invoke`
- `POST /research/stream`
- `POST /research/batch`

这意味着前端、BFF、内部自动化系统都可以统一调用。你也可以在网关层加 JWT 鉴权、速率限制与审计日志。

## 13.7 LangSmith：从“能跑”到“可运营”

很多 Agent 项目的失败，不在模型能力，而在团队无法回答三个问题：

1. 这次输出为什么错？
2. 最近一周质量是变好还是变差？
3. Prompt 改版后是不是只优化了 demo，而损伤了真实数据集？

LangSmith 正是解决这三个问题。

### 13.7.1 Tracing Runs

每次调用链路都可记录：

- 输入 prompt；
- 中间节点输出；
- 工具调用参数；
- token 消耗；
- 延迟；
- 最终结果。

当用户说“这个 Agent 昨天还好好的，今天乱回答”，你需要的不是猜，而是打开 trace 对比 run diff。

### 13.7.2 Evaluating Outputs

评测（evaluation，评估）至少分两层：

| 层级 | 例子 | 指标 |
|---|---|---|
| 单步评测 | 查询改写质量 | exact match、BLEU、人工打分 |
| 端到端评测 | 研究报告是否可信 | task success rate、citation accuracy |

2026 年成熟团队通常维护 100-1000 条内部 eval 数据。每次 prompt、parser、tool、model 变更后自动回归，避免“线上回归靠感觉”。

### 13.7.3 Dataset Management 与 Prompt Versioning

LangSmith 的数据集管理适合保存：

- 用户真实问题抽样；
- 边界 case；
- 面试场景测试集；
- 高风险失败样本。

而 prompt versioning 则让你能回答：“`research_v17` 比 `research_v16` 的通过率高了 6.2%，但平均 token 上升了 14%。”这已经不是提示词技巧，而是标准工程治理。

## 13.8 生产实践建议

1. **简单链用 LCEL，复杂决策用 LangGraph。** 不要一上来就把所有东西做成图，也不要把复杂 Agent 硬写成 if-else。
2. **所有关键节点都要结构化输出。** 一旦进入生产，字符串拼接会成为故障源。
3. **把 tracing 当默认配置。** 没有 trace 的 Agent，出了问题几乎无法追责。
4. **先做 20 条黄金样本，再做大规模迭代。** 否则你的“优化”没有客观参照。
5. **图的节点应低耦合。** 每个节点只做一件事，输入输出清晰，便于替换模型或工具。

## 13.9 从 Demo 到生产：LangChain 项目的典型分层

很多人把 LangChain 项目写成一个 `main.py`，把 prompt、模型、工具、API、日志全堆在一起。这个结构在第一个星期看似很快，第二个星期开始就会全面失控。更好的组织方式如下：

```text
app/
  prompts/         # PromptTemplate 定义
  tools/           # 搜索、数据库、HTTP、内部 RPC
  chains/          # LCEL 组合
  graphs/          # LangGraph 工作流
  schemas/         # Pydantic / TypedDict
  services/        # 业务封装层
  api/             # FastAPI / LangServe 路由
  observability/   # LangSmith / logging / metrics
  tests/           # 单元、集成、评测
```

为什么这样分层有效？因为它恰好对应了 Agent 生命周期中的不同变化频率：

- prompt 会高频改；
- tool wrapper 中频改；
- graph 结构低频改；
- API 合约更低频改。

把高频变化和低频变化隔离，可以显著降低回归风险。例如一个检索工具从内部 ES 切换到混合检索服务时，理论上只应影响 `tools/` 与少量 graph node，而不应牵连前端 API 或评测脚本。

在真实团队中，还会进一步要求：

| 层 | 交付物 | 责任人 |
|---|---|---|
| prompts | 模板、few-shot、输出约束 | Agent 工程师 |
| tools | 鉴权、超时、重试、幂等 | 后端工程师 |
| graphs | 状态流转、人工审批、降级路径 | 资深 Agent 工程师 |
| observability | trace、eval、成本面板 | 平台/基础设施工程师 |

这类回答在系统设计面试里很加分，因为它说明你理解的不只是框架 API，而是工程分工。

## 13.10 LangGraph 常见陷阱与规避策略

LangGraph 很强，但也容易踩坑。下面列出 5 个非常常见的问题：

### 13.10.1 State 设计过宽

有些项目把所有中间结果都塞进一个巨大的 state，比如 `messages`、`retrieved_docs`、`draft_versions`、`debug_logs`、`tool_raw_payloads` 全放进去。短期方便，长期灾难：状态越来越大，序列化成本上升，checkpoint 恢复慢，调试时也难看懂。更好的方法是：

- state 中只存“流程推进必需”的字段；
- 大对象放外部存储，仅在 state 中存 ID；
- 对 message history 做窗口化或摘要化。

### 13.10.2 节点粒度过粗

一个节点如果同时做“查询改写 + 搜索 + 重排 + 总结”，那么任何一步出错都难定位。一般建议一个节点只做一个清晰职责，例如：

- `rewrite_query`
- `retrieve_docs`
- `rerank_docs`
- `draft_answer`
- `review_answer`

这样 trace 更短、测试更明确，也便于未来替换某一节点的模型。

### 13.10.3 条件边过多导致图不可读

有些图一旦超过 15 条条件边，阅读难度会急剧上升。应对方法有两个：

1. 把局部复杂流程抽成 subgraph；
2. 把复杂条件判断收敛为“路由函数 + 枚举状态”。

例如不要直接返回 7 个字符串分支，不如先定义：

```python
from enum import Enum

class Route(str, Enum):
    SEARCH = "search"
    HUMAN = "human_review"
    ANSWER = "answer"
```

路由值标准化后，图会清晰很多。

### 13.10.4 忽视失败路径

大多数 demo 只定义 happy path：能检索、能总结、能输出。但生产系统里真正决定可用性的，是失败路径：

- 搜索工具 502 怎么办？
- parser 校验失败怎么办？
- 用户中途修改需求怎么办？
- 模型输出空结果怎么办？

成熟做法通常是每条关键链路至少定义：

- 1 条正常路径；
- 1 条重试路径；
- 1 条降级路径；
- 1 条人工升级路径。

### 13.10.5 过度迷信“全自动”

很多新人以为 Agent 越自动越高级。其实在财务、法务、招聘、风控场景中，**最优秀的系统往往是“自动生成 + 人工确认”**。LangGraph 的价值正在于它可以自然地把人工节点放进流程，而不是把人工审批当成框架外补丁。

## 13.11 LangSmith 驱动的评测闭环

如果你已经有一个能工作的 LangGraph Agent，下一步最该做的不是继续加功能，而是建立评测闭环。一个可执行的最小闭环如下：

1. 收集 50 条真实用户问题；
2. 人工标注期望答案特征，例如是否有引用、是否包含风险提示、是否调用正确工具；
3. 在 LangSmith 建 dataset；
4. 每次改 prompt 或 node 后跑一次 evaluation；
5. 对比通过率、延迟、token 成本。

实践中，你至少应定义三类指标：

| 指标类型 | 例子 | 建议阈值 |
|---|---|---|
| 正确性 | 是否命中核心结论 | >85% |
| 稳定性 | 同一输入多次运行的一致性 | >90% |
| 成本效率 | 单次任务平均成本 | 按业务预算设定 |

一个经常被忽略的点是：**评测集必须持续更新**。如果你只用早期 20 条样本，Agent 会很快“过拟合你的测试集”。成熟团队会每周抽样新增失败案例，把它们纳入 eval 集；这和传统软件把线上 bug 变成回归测试，本质是同一套工程思维。

## 13.12 面试视角：如何回答“为什么选 LangChain？”

在面试中，不要说“因为它流行”。更有说服力的回答结构是：

1. **先说需求形态**：我们的问题包含多步工具调用、结构化输出、流式响应和评测回放。
2. **再说框架匹配**：LCEL 适合可组合链路，LangGraph 适合状态机，LangSmith 适合 tracing 与 eval。
3. **再说替代方案**：如果只是简单 RAG，LlamaIndex 或平台型产品也可以；如果要求极高控制与极低依赖，可考虑自研。
4. **最后说风险**：LangChain 版本迭代快，需要封装自己的抽象边界，避免业务代码直接耦合底层 API。

这类回答展示的不是“会不会写示例”，而是“你是否有架构判断力”。

## 13.13 版本迁移经验：从旧式 Chain 到 LCEL / LangGraph

很多团队在 2024 年写下了大量 `LLMChain`、`SequentialChain`、`AgentExecutor` 风格代码，到了 2026 年开始逐步迁移。迁移时不要想着“一夜推倒重写”，更稳妥的路径是：

1. 先把 prompt、tool、parser 单独抽出来；
2. 再把线性链迁移为 `prompt | model | parser`；
3. 对于含 if-else、循环、人工介入的链路，再迁移到 LangGraph；
4. 最后统一接 LangSmith 做回归对比。

迁移时最容易出的问题包括：

- 旧代码把 message history 和业务 state 混在一起；
- parser 依赖弱约束字符串；
- 工具返回格式不统一；
- 监控口径在新旧系统间不一致。

因此，**迁移的核心不是换语法，而是统一契约**。一个实用做法是先定义内部标准：

| 契约 | 示例 |
|---|---|
| 模型输入 | 始终使用消息对象而非裸字符串 |
| 工具输出 | 始终返回 `{"ok": bool, "data": ..., "error": ...}` |
| 结构化结果 | 始终经 parser / schema 校验 |
| trace 字段 | 每一跳都携带 `trace_id`、`user_id`、`session_id` |

当这些契约稳定后，你用不用 LangChain 只是实现细节；而一旦契约混乱，框架再强也救不了系统复杂度。

另外，迁移最好采用“双写对比”策略：新旧链路在一段时间内并行运行，对同一批样本记录输出质量、延迟和成本差异。只有当新链路在至少 30-50 条关键样本上稳定优于旧链路时，才值得正式切流。这种做法虽然麻烦，却能显著降低“重构后线上质量倒退”的风险。

最后补一句实战经验：如果团队里既有后端工程师，也有算法或 Prompt 工程师，那么最值得优先统一的不是模型，而是“节点输入输出格式”和“评测口径”。只有接口稳定，团队协作才不会因为版本升级而频繁互相阻塞。

如果你在做作品集，建议至少展示三样东西：一是 `LCEL` 基础链；二是 `LangGraph` 条件分支图；三是 `LangSmith` 评测截图或评测数据结构。因为招聘方真正关心的是你是否具备“从原型到工程”的完整视角，而不是只会把模型接起来。

换句话说，LangChain 学习的终点不是“我会几个类”，而是“我能把模型能力、工具能力和软件工程能力组织成可维护系统”。只要你能把这句话落实到代码结构、评测方法和部署流程上，本章的价值就真正吸收了。

对转行者而言，这也是一个很好的能力分层：先学会写链，再学会写图，再学会做评测与部署。只要按这个顺序推进，成长路径会比一开始追求“超复杂多 Agent”更稳。

而且这条路径几乎与真实岗位要求完全一致：先能交付，再能维护，最后能抽象与复用。

这也是从“会写 demo”走向“能独立负责模块”的关键跃迁。

真正理解这一点，才算把 LangChain 学到位。

也才真正具备生产级 Agent 工程师的视角。

## 本章要点

- LangChain 在 2026 年应被理解为一个生态：Core 负责抽象，LangGraph 负责状态机，LangSmith 负责可观测性，LangServe 负责部署。
- LCEL 的本质是 Runnable 数据流组合，`|`、`RunnableLambda`、`RunnableParallel` 能显著提升表达力。
- 当 Agent 涉及分支、记忆、人工审批与恢复执行时，LangGraph 比线性链更自然。
- 真正的工程能力不在于写出 demo，而在于能做 tracing、eval、checkpoint、deploy。
- 面试中，能把“为什么要从 Chain 迁移到 LCEL/LangGraph”讲清楚，通常比背 API 更有说服力。

## 延伸阅读

1. LangChain 官方文档：重点看 LCEL、Runnable、structured output。
2. LangGraph 官方文档：重点看 state schema、conditional edges、checkpoint saver。
3. LangSmith 官方文档：重点看 tracing、dataset、evaluation、prompt playground。
4. 建议亲手完成一个最小项目：`FAQ Agent -> RAG Agent -> Graph Agent -> LangServe 部署 -> LangSmith 回归评测`，这条路径最接近真实工作流。
