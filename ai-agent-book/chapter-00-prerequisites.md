# 第零章：在正式开始之前——你需要的所有前置知识

> 如果你是一个传统软件工程师，从没接触过 AI/ML，这一章是为你写的。
> 如果你已经用过 ChatGPT、调用过 OpenAI API，可以快速扫一遍，主要看术语表部分。

---

## 0.1 AI 到底是什么？用软件工程师的方式理解

先把最容易犯的错误排掉：

- ❌ AI 不是"会思考的程序"
- ❌ AI 不是按规则写 if-else 的专家系统
- ❌ AI 不是"查数据库然后返回答案"

那它是什么？

**AI（在 2026 年语境下）= 一个超大的函数，输入文字，输出文字。**

```
输入：  "帮我写一个冒泡排序的 Python 实现"
  ↓
AI 函数
  ↓
输出：  "def bubble_sort(arr): ..."
```

你可能会问：那和普通函数有什么区别？区别在于这个函数**不是人手写规则写出来的**，而是通过分析海量文本"学"出来的。它学了互联网上几乎所有的文章、代码、书籍，所以能处理几乎任何类型的文字任务——翻译、写代码、总结文档、回答问题、分析数据。

作为软件工程师，你需要记住的核心认知：

> **调用 AI = 调用一个 API，传入文字，得到文字。就这么简单。**

你不需要理解它内部怎么"学"的，就像你调 Google Maps API 不需要理解它的路径规划算法一样。

---

## 0.2 大语言模型（LLM）是什么

LLM 是 Large Language Model（大语言模型）的缩写。代表产品：

| 产品 | 公司 |
|------|------|
| GPT-4o、GPT-4.1 | OpenAI |
| Claude 3.5、Claude 4 | Anthropic |
| Gemini 2.x | Google |
| Llama 3 | Meta（开源） |
| Qwen（通义千问） | 阿里 |

你现在用的 GitHub Copilot、ChatGPT、Cursor、Claude Code，背后都是某个 LLM。

### LLM 做的一件事

LLM 只做一件事：**预测下一个词**。

比如输入 `"今天天气"`，它预测下一个最可能的词是 `"很好"`，然后再预测下一个，再下一个，直到生成完整的回复。

这听起来很简单，但当模型参数规模达到千亿级别、训练数据覆盖整个互联网时，"预测下一个词"就能涌现出理解、推理、写代码等复杂能力。

### 为什么叫"大"语言模型

| 代 | 参数量 | 类比 |
|----|--------|------|
| 2018 年 BERT | 3.4 亿 | 小型 |
| 2020 年 GPT-3 | 1750 亿 | 中型 |
| 2023-2026 主流 | 700B-2T | 超大型 |

参数量 = 模型"记住"的知识量。参数越多，能力越强，但推理成本也越高。

---

## 0.3 Token：AI 计费和计算的基本单位

你调用 AI API 的时候，计费单位不是字，不是句子，而是 **token（词元）**。

Token 是 LLM 内部处理文字的最小单位，通常：
- 英文：约 0.75 个单词 ≈ 1 个 token（`hello` = 1 token，`world` = 1 token）
- 中文：约 1-2 个汉字 ≈ 1 个 token（`你好` ≈ 2-3 tokens）
- 代码：标点、缩进、关键字各自算 token

**为什么你需要关心 token？**

1. **计费**：OpenAI 按 token 计费。输入 1000 个 token + 输出 1000 个 token = 合计 2000 token 的费用。
2. **Context Window（上下文窗口）**：模型能"记住"的最大 token 数。GPT-4o 是 128K tokens，Claude 3.5 是 200K tokens。超出这个限制，早期内容就会被"遗忘"。
3. **性能**：token 越多，推理越慢，成本越高。

```
常见估算：
一篇 1000 字中文文章 ≈ 1500-2000 tokens
一个 200 行 Kotlin 文件 ≈ 2000-3000 tokens
GPT-4o 的 128K context ≈ 约 10 万字中文
```

---

## 0.4 Prompt：你给 AI 的输入

**Prompt（提示词）** 就是你发给 AI 的输入文字。设计一个好的 prompt 是让 AI 稳定产出高质量结果的关键。

Prompt 通常分三个部分：

```text
┌────────────────────────────────────────────┐
│ System Prompt（系统提示，定义AI角色和规则）  │
│ "你是一个专业的 Android 代码审查员，..."     │
├────────────────────────────────────────────┤
│ User Message（用户消息，具体任务）           │
│ "请审查下面这段 Kotlin 代码的线程安全问题"   │
├────────────────────────────────────────────┤
│ Assistant Message（AI历史回复，用于多轮对话）│
│ "好的，我来分析..."                          │
└────────────────────────────────────────────┘
```

**System Prompt** 是控制 AI 行为最强大的工具。你在做 AI Agent 工程时，80% 的时间都在调整 System Prompt。

---

## 0.5 第一个 API 调用：Hello AI

你可能会想，"调 AI API 是不是很复杂？"其实极简代码只需要几行。

下面是 OpenAI API 的最小示例（Python）：

```python
from openai import OpenAI

client = OpenAI(api_key="your-api-key")

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[
        {"role": "system", "content": "你是一个代码助手"},
        {"role": "user", "content": "用 Python 写一个冒泡排序"}
    ]
)

print(response.choices[0].message.content)
```

如果你熟悉 Android/Kotlin，等价代码长这样：

```kotlin
// 使用 OkHttp 调用 OpenAI API
val client = OkHttpClient()
val json = """
{
  "model": "gpt-4o",
  "messages": [
    {"role": "system", "content": "你是一个代码助手"},
    {"role": "user", "content": "用 Python 写一个冒泡排序"}
  ]
}
""".trimIndent()

val body = json.toRequestBody("application/json".toMediaType())
val request = Request.Builder()
    .url("https://api.openai.com/v1/chat/completions")
    .header("Authorization", "Bearer $apiKey")
    .post(body)
    .build()

val response = client.newCall(request).execute()
println(response.body?.string())
```

本质上就是一个 **HTTP POST 请求**。AI API 和你调的任何其他 REST API 没有本质区别。

**返回的 JSON 结构：**

```json
{
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "def bubble_sort(arr):\n    n = len(arr)\n    ..."
      }
    }
  ],
  "usage": {
    "prompt_tokens": 32,
    "completion_tokens": 85,
    "total_tokens": 117
  }
}
```

关键字段：
- `choices[0].message.content` — AI 的回复文字
- `usage.total_tokens` — 本次消耗的 token 数（用于计费）

---

## 0.6 Temperature：控制 AI 的"随机性"

调用 API 时有一个常用参数 `temperature`（温度），控制输出的随机程度：

| temperature 值 | 效果 | 适用场景 |
|---------------|------|---------|
| 0.0 | 近乎确定性，每次输出相同 | 代码生成、数据提取、分类 |
| 0.3-0.7 | 适度随机，稳定但有变化 | 问答、总结、分析（大多数场景） |
| 0.9-1.2 | 高随机，创意丰富 | 写作、头脑风暴、创意生成 |

**经验：做工程任务（写代码、调 Agent）用低 temperature（0~0.3）；做创意任务用高 temperature。**

---

## 0.7 Embedding：把文字变成数字向量

这个概念在后面 RAG 章节会详细讲，这里先建立直觉。

**Embedding** 是把一段文字转换成一个数字向量的技术。

```
"苹果很好吃" → [0.23, -0.85, 0.12, 0.67, ..., 0.44]（768 或 1536 维）
"这个水果味道不错" → [0.21, -0.82, 0.14, 0.65, ..., 0.41]
"今天股市大跌" → [-0.91, 0.33, -0.27, 0.18, ..., -0.55]
```

意思相近的句子，向量也接近（可以用余弦相似度衡量）。

**为什么重要？**

AI 不能"直接搜索"你的文档库，但可以把文档都转成向量存起来，每次查询时找最相近的向量，这就是 **语义搜索**。这是构建"AI 读你的文档"类功能的基础。

---

## 0.8 关键术语速查表

在读后续章节之前，建议把这张表过一遍：

| 术语 | 白话解释 |
|------|---------|
| **LLM** | 大语言模型，就是 ChatGPT 背后的那个"大脑" |
| **Token** | AI 处理文字的最小单位，类似字节之于计算机 |
| **Prompt** | 你给 AI 的输入，包含指令、背景、问题 |
| **Context Window** | AI 一次能"看到"的最大文字量，超出就遗忘 |
| **Temperature** | 控制 AI 回复随机程度的参数，0=稳定，1=随机 |
| **Embedding** | 把文字转成数字向量，用于语义搜索 |
| **Fine-tuning** | 在预训练模型基础上，用特定数据再次训练，让它专注某个领域 |
| **Inference（推理）** | 模型"用"的阶段（和训练对应），即你调 API 那一刻 |
| **RAG** | 检索增强生成，让 AI 先搜文档再回答，防止"瞎编" |
| **Agent** | 能自主循环执行多步任务的 AI 系统（本书的主角） |
| **Tool Use / Function Calling** | AI 在回复中调用外部工具（搜索、数据库、API）的能力 |
| **MCP** | Model Context Protocol，标准化 AI 工具调用的协议 |
| **System Prompt** | 给 AI 定角色和规则的特殊指令，类似 Android 的 Application 初始化 |
| **Hallucination（幻觉）** | AI 编造不存在的事实，是当前最大的可靠性问题 |
| **Streaming** | AI 边生成边输出，像打字机一样逐字显示，而不是等全部生成完再返回 |
| **Few-shot** | 在 Prompt 里给 2-5 个示例，帮 AI 理解你要的格式 |
| **Zero-shot** | 不给示例，直接提问 |
| **Chain of Thought（CoT）** | 让 AI 先写出推理过程再给答案，显著提高复杂问题准确率 |
| **Tokenizer** | 把原始文字切成 token 的工具 |
| **API Key** | 调用 AI API 的身份凭证，相当于密码，绝对不能提交到代码库 |

---

## 0.9 AI 模型的能力边界：你必须知道的局限

AI 很强，但它有几个硬性局限，做工程必须心里清楚：

### 局限 1：知识有截止日期（Knowledge Cutoff）

LLM 的训练数据有时间截止点。GPT-4o 的训练数据截止到某个月份，之后发生的事情它不知道。

**应对**：用 RAG（检索增强生成）或 Tool Use（联网搜索）来补充实时信息。

### 局限 2：会"幻觉"（Hallucination）

AI 会自信地给出根本不存在的答案。比如：
- 编造不存在的论文引用
- 描述错误的 API 用法
- 给出听起来合理但其实是错的代码

这不是 bug，是 LLM 的本质特性——它在"预测最可能的词"，而不是"查数据库"。

**应对**：结构化输出 + 验证步骤 + RAG + 不信任关键数字/事实。

### 局限 3：Context Window 是有限的

超过上下文窗口限制后，早期内容会被截掉。一个 200K token 的窗口看起来很大，但：
- 100 个 Android 文件的完整代码 ≈ 20-40 万 tokens
- 大型 codebase 很容易就超出限制

**应对**：RAG（只把相关片段放入 context）+ 分块处理 + 摘要压缩。

### 局限 4：不擅长精确计算

AI 做数学计算是"预测正确答案的词"，而不是真的在算。

**应对**：让 AI 写代码/调计算工具，而不是直接算。

### 局限 5：非确定性

相同的输入，每次输出可能不同（受 temperature 影响）。在工程系统里，这意味着你无法像传统单元测试那样断言精确的输出。

**应对**：用结构化输出（JSON Schema）+ 专门的 Eval 体系（第十七章会讲）。

---

## 0.10 Python vs 你熟悉的语言

本书的代码示例主要用 Python，因为 AI/ML 生态在 Python 里最成熟。但这不代表你必须深入学 Python 才能做 AI 工程。

**你需要掌握的 Python 基础（一周可学完）：**

```python
# 1. 变量和基本类型
name = "hello"
count = 42
is_done = True
items = [1, 2, 3]          # list（类似 ArrayList）
config = {"key": "value"}  # dict（类似 HashMap）

# 2. 函数
def greet(name: str) -> str:
    return f"Hello, {name}"

# 3. 类（比 Kotlin 简单）
class Agent:
    def __init__(self, name: str):
        self.name = name
    
    def run(self, task: str) -> str:
        return f"{self.name} is running: {task}"

# 4. 异步（Python 的 async/await 和 Kotlin 协程很像）
import asyncio

async def fetch_data() -> str:
    await asyncio.sleep(1)  # 模拟网络请求
    return "data"

# 5. pip 包管理（等价于 Gradle 依赖）
# pip install openai langchain
```

**Kotlin vs Python 对照：**

| Kotlin | Python |
|--------|--------|
| `val x: Int = 5` | `x = 5` |
| `fun foo(s: String): String` | `def foo(s: str) -> str:` |
| `listOf(1, 2, 3)` | `[1, 2, 3]` |
| `mapOf("a" to 1)` | `{"a": 1}` |
| `data class User(val name: String)` | `@dataclass class User: name: str` |
| `coroutineScope { launch { } }` | `async def` + `await` |
| `build.gradle.kts` 依赖 | `pip install xxx` |
| `println()` | `print()` |

如果你能看懂 Kotlin，看 Python 代码顶多花你 10% 的额外时间。

---

## 0.11 这本书的阅读地图

读完这一章，你应该已经建立了足够的上下文。下面告诉你各章的定位，方便你按需阅读：

```
第零章（本章）: 零基础扫盲，所有前置知识
    │
    ▼
第一章: AI Agent 是什么，和普通 AI 应用的区别
    │
    ▼
第二章: 行业地图，现在市场上有哪些公司在做什么
    │
    ▼
第三章: 你该往哪个岗位转，不同背景的路径
    │
    ▼
第四-七章: 核心技术知识（LLM、Prompt、Embedding、RAG）
    │      ← 想快速入行可以跳过细节，先看第八章
    ▼
第八-十二章: Agent 核心技术（架构、工具、记忆、多Agent、协议）
    │
    ▼
第十三-十六章: 实际框架和工程化（LangChain、OpenAI SDK、部署）
    │
    ▼
第十七-十九章: 面试准备
    │
    ▼
第二十章: 学习资源和路线图
    │
    ▼
第二十一章: 大型项目 Agentic Engineering 实战（有工程经验再看）
```

**快速入行建议路线（3-4 周）：**
1. 第零章（本章）→ 第一章 → 第三章（确定目标岗位）
2. 第五章（Prompt）→ 自己调 API 练练手
3. 第七章（RAG）→ 第八章（Agent 架构）→ 第九章（工具系统）
4. 第十七-十九章（面试准备）
5. 其余章节按需补充

---

## 本章小结

- AI = 调 API，输入文字，得到文字
- LLM = 大语言模型，通过预测下一个词实现复杂能力
- Token = AI 计费和处理的基本单位，中文约 1-2 字 = 1 token
- Prompt = 你给 AI 的输入，System Prompt 是控制 AI 行为最强的工具
- Embedding = 文字的数字向量，用于语义搜索和 RAG
- Temperature = 控制随机程度，工程任务用低值
- AI 的核心局限：幻觉、知识截止、上下文有限、非确定性
- Python 代码对 Kotlin 开发者来说学习曲线很平，一周能上手

**下一章**正式开始讲 AI Agent 是什么，为什么它比普通 AI 应用更有工程价值。
