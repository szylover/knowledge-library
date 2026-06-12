# 第十九章：编程面试与实操

很多 AI Agent 岗位的编程面试，不是考你手撕红黑树，而是考你是否能把“模型系统里的常见问题”落成可靠代码。本章按五类题展开：算法、Python 数据处理、LLM API 编程、Prompt 设计、Take-home 项目。建议你练习时遵循同一套路：先说复杂度，再写可运行代码，最后补边界情况和测试。

在开始刷题前，先建立一个非常重要的认知：AI Agent 岗位的 coding 面试，考察的往往不是算法难度，而是**工程抽象能力**。同一道题，普通候选人会直接开始写；更强的候选人会先做四件事：一是澄清输入输出和异常边界，二是说明为什么选择这个数据结构，三是明确复杂度，四是补一句“如果上线我会怎么监控和测试”。这种表达方式会让面试官感觉你不是在做课堂作业，而是在设计一段会被别人长期维护的生产代码。你可以把本章所有题目都按这个标准来练：先口述 30 秒，再写代码，再用 30 秒讲优化方向。

另一个高频失分点是“代码能跑，但不解释为什么这样写”。例如并发题只写 `asyncio.gather`，却不说为什么要限制最大并发；RAG 相关题只写相似度函数，却不说零向量怎么处理；记忆系统题只写列表截断，却不说为什么优先保留 system prompt 和最新轮次。AI 面试中的代码题，本质上是“用代码证明你理解系统”。因此你在写每段代码时，都应该问自己两个问题：**这段逻辑对应哪个真实场景？这段实现最可能在哪些地方翻车？** 只要你养成这个习惯，答题质量会明显提升。

---

## A. 算法题精选（与 AI 相关的 LeetCode 风格题）

### 1. Top-K 相似文档检索（堆 / 优先队列）
- **题目**：给定一个 query 向量和若干文档向量，返回余弦相似度最高的前 k 个文档。
- **思路**：逐个计算相似度，并用最小堆维护 top-k。时间复杂度 `O(n log k)`，适合在线筛选。
- **完整 Python 解法**：

```python
from __future__ import annotations
import heapq
import math
from typing import List, Tuple


def cosine(a: List[float], b: List[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)


def top_k_similar(query: List[float], docs: List[Tuple[str, List[float]]], k: int):
    heap: List[Tuple[float, str]] = []
    for doc_id, vec in docs:
        score = cosine(query, vec)
        if len(heap) < k:
            heapq.heappush(heap, (score, doc_id))
        elif score > heap[0][0]:
            heapq.heapreplace(heap, (score, doc_id))
    return sorted(heap, reverse=True)


if __name__ == "__main__":
    query = [1.0, 0.0, 1.0]
    docs = [
        ("doc-a", [1.0, 0.0, 1.0]),
        ("doc-b", [0.0, 1.0, 0.0]),
        ("doc-c", [1.0, 0.2, 0.9]),
    ]
    print(top_k_similar(query, docs, 2))
```

### 2. 文本分块算法（滑动窗口）
- **题目**：实现一个文本分块器，支持 chunk size 和 overlap。
- **思路**：双指针按窗口滑动；每次前进 `chunk_size - overlap`。注意 overlap 不能大于等于 chunk size。
- **完整 Python 解法**：

```python
def chunk_text(text: str, chunk_size: int, overlap: int) -> list[str]:
    if chunk_size <= 0:
        raise ValueError("chunk_size must be > 0")
    if overlap < 0 or overlap >= chunk_size:
        raise ValueError("overlap must be >= 0 and < chunk_size")

    chunks = []
    step = chunk_size - overlap
    start = 0
    while start < len(text):
        chunks.append(text[start:start + chunk_size])
        start += step
    return chunks


if __name__ == "__main__":
    print(chunk_text("abcdefghijklmnopqrstuvwxyz", 8, 2))
```

### 3. Token 计数与截断（字符串处理）
- **题目**：实现一个简化版 token 预算控制器，超限时优先保留 system prompt 和最新消息。
- **思路**：面试里不必真的实现 GPT tokenizer，可以先用“按空格切词”模拟预算逻辑，重点是策略而不是库函数。
- **完整 Python 解法**：

```python
from dataclasses import dataclass


@dataclass
class Message:
    role: str
    content: str


def count_tokens(text: str) -> int:
    return len(text.split())


def trim_messages(messages: list[Message], max_tokens: int) -> list[Message]:
    if not messages:
        return []

    system_msgs = [m for m in messages if m.role == "system"]
    other_msgs = [m for m in messages if m.role != "system"]
    result = system_msgs[:]
    used = sum(count_tokens(m.content) for m in result)

    for msg in reversed(other_msgs):
        cost = count_tokens(msg.content)
        if used + cost <= max_tokens:
            result.insert(len(system_msgs), msg)
            used += cost
    return result


if __name__ == "__main__":
    msgs = [
        Message("system", "You are a helpful SQL agent."),
        Message("user", "show me sales by month"),
        Message("assistant", "which year do you want"),
        Message("user", "2025 only"),
    ]
    for m in trim_messages(msgs, 10):
        print(m)
```

### 4. 图遍历（知识图谱相关）
- **题目**：给定一个知识图谱邻接表，找出实体 A 到实体 B 的最短关系路径。
- **思路**：无权图最短路直接用广度优先搜索（Breadth-First Search, BFS）。
- **完整 Python 解法**：

```python
from collections import deque


def shortest_path(graph: dict[str, list[str]], start: str, target: str) -> list[str]:
    queue = deque([[start]])
    visited = {start}
    while queue:
        path = queue.popleft()
        node = path[-1]
        if node == target:
            return path
        for nxt in graph.get(node, []):
            if nxt not in visited:
                visited.add(nxt)
                queue.append(path + [nxt])
    return []


if __name__ == "__main__":
    graph = {
        "LLM": ["Transformer", "RAG"],
        "Transformer": ["Attention"],
        "RAG": ["Embedding", "VectorDB"],
        "Embedding": ["VectorDB"],
    }
    print(shortest_path(graph, "LLM", "VectorDB"))
```

### 5. 并发 API 调用管理（异步编程）
- **题目**：并发调用多个工具 API，但要求限制最大并发数并收集失败结果。
- **思路**：使用 `asyncio.Semaphore` 控制并发，`gather(return_exceptions=True)` 收集异常。
- **完整 Python 解法**：

```python
import asyncio
import random


async def fake_api(name: str) -> str:
    await asyncio.sleep(random.uniform(0.1, 0.5))
    if "bad" in name:
        raise RuntimeError(f"{name} failed")
    return f"ok:{name}"


async def run_limited(names: list[str], limit: int = 3):
    sem = asyncio.Semaphore(limit)

    async def worker(name: str):
        async with sem:
            return await fake_api(name)

    tasks = [worker(n) for n in names]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    return results


if __name__ == "__main__":
    print(asyncio.run(run_limited(["a", "b", "bad-c", "d"])))
```

### A 节面试官常见追问
算法题写完后，面试官通常不会马上满意，而是会追问三类问题。第一类是**复杂度和扩展性**：比如 top-k 是否能进一步优化、文本分块能否按句子边界切、图遍历是否能支持权重。第二类是**边界条件**：空输入怎么办、维度不一致如何处理、overlap 配置非法怎么报错。第三类是**工程映射**：这段代码如果放进 RAG、知识图谱或异步工具系统里，还缺哪些生产能力。你练习时一定要把这三类追问一并练掉，否则现场写完代码后很容易在追问环节失分。

---

## B. Python 数据处理实操题

### 1. 实现一个简单的 BPE tokenizer
- **题目**：实现一个教学版 BPE，包含训练和编码。
- **说明**：真实工业版会更复杂，这里重点是理解“统计高频相邻对并合并”。
- **完整代码**：

```python
from collections import Counter


class SimpleBPE:
    def __init__(self, num_merges: int = 10):
        self.num_merges = num_merges
        self.merges: list[tuple[str, str]] = []

    def _word_to_symbols(self, word: str) -> list[str]:
        return list(word) + ["</w>"]

    def fit(self, words: list[str]) -> None:
        vocab = [self._word_to_symbols(w) for w in words]
        for _ in range(self.num_merges):
            pairs = Counter()
            for symbols in vocab:
                for i in range(len(symbols) - 1):
                    pairs[(symbols[i], symbols[i + 1])] += 1
            if not pairs:
                break
            best = max(pairs, key=pairs.get)
            self.merges.append(best)

            new_vocab = []
            for symbols in vocab:
                i = 0
                merged = []
                while i < len(symbols):
                    if i < len(symbols) - 1 and (symbols[i], symbols[i + 1]) == best:
                        merged.append(symbols[i] + symbols[i + 1])
                        i += 2
                    else:
                        merged.append(symbols[i])
                        i += 1
                new_vocab.append(merged)
            vocab = new_vocab

    def encode(self, word: str) -> list[str]:
        symbols = self._word_to_symbols(word)
        for a, b in self.merges:
            i = 0
            merged = []
            while i < len(symbols):
                if i < len(symbols) - 1 and symbols[i] == a and symbols[i + 1] == b:
                    merged.append(a + b)
                    i += 2
                else:
                    merged.append(symbols[i])
                    i += 1
            symbols = merged
        return symbols


def test_bpe():
    bpe = SimpleBPE(num_merges=5)
    bpe.fit(["low", "lower", "lowest", "newer"])
    tokens = bpe.encode("lowest")
    assert len(tokens) > 0
    print("BPE test passed:", tokens)


if __name__ == "__main__":
    test_bpe()
```

### 2. 计算两个文本的余弦相似度
- **题目**：不依赖外部库，计算两个文本的词袋（bag of words）余弦相似度。
- **完整代码**：

```python
import math
from collections import Counter


def text_to_vector(text: str) -> Counter:
    tokens = text.lower().split()
    return Counter(tokens)


def cosine_similarity_text(a: str, b: str) -> float:
    va = text_to_vector(a)
    vb = text_to_vector(b)
    vocab = set(va) | set(vb)
    dot = sum(va[t] * vb[t] for t in vocab)
    na = math.sqrt(sum(va[t] ** 2 for t in vocab))
    nb = math.sqrt(sum(vb[t] ** 2 for t in vocab))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)


def test_similarity():
    s = cosine_similarity_text("ai agent retrieval", "ai retrieval system")
    assert 0 < s < 1
    print("similarity:", s)


if __name__ == "__main__":
    test_similarity()
```

### 3. 实现一个基于 TF-IDF 的简单检索器
- **题目**：给定一个文档列表和 query，返回最相关文档。
- **完整代码**：

```python
import math
from collections import Counter


class TfidfRetriever:
    def __init__(self, docs: list[str]):
        self.docs = docs
        self.doc_tokens = [doc.lower().split() for doc in docs]
        self.df = Counter()
        for tokens in self.doc_tokens:
            for t in set(tokens):
                self.df[t] += 1
        self.n = len(docs)

    def _tfidf(self, tokens: list[str]) -> dict[str, float]:
        tf = Counter(tokens)
        vec = {}
        for t, c in tf.items():
            idf = math.log((self.n + 1) / (self.df.get(t, 0) + 1)) + 1
            vec[t] = c * idf
        return vec

    def _cos(self, a: dict[str, float], b: dict[str, float]) -> float:
        vocab = set(a) | set(b)
        dot = sum(a.get(t, 0.0) * b.get(t, 0.0) for t in vocab)
        na = math.sqrt(sum(v * v for v in a.values()))
        nb = math.sqrt(sum(v * v for v in b.values()))
        if na == 0 or nb == 0:
            return 0.0
        return dot / (na * nb)

    def search(self, query: str, top_k: int = 3):
        qvec = self._tfidf(query.lower().split())
        scored = []
        for i, tokens in enumerate(self.doc_tokens):
            dvec = self._tfidf(tokens)
            scored.append((self._cos(qvec, dvec), self.docs[i]))
        return sorted(scored, reverse=True)[:top_k]


def test_retriever():
    docs = [
        "rag combines retrieval and generation",
        "transformer uses self attention",
        "embedding maps text to vectors",
    ]
    r = TfidfRetriever(docs)
    print(r.search("retrieval generation"))


if __name__ == "__main__":
    test_retriever()
```

### 4. JSON schema 验证器（用于 tool definitions）
- **题目**：实现一个简化版 JSON schema validator，检查字段存在、类型是否匹配。
- **完整代码**：

```python

def validate(schema: dict, data: dict) -> list[str]:
    errors = []
    required = schema.get("required", [])
    props = schema.get("properties", {})

    for key in required:
        if key not in data:
            errors.append(f"missing required field: {key}")

    type_map = {
        "string": str,
        "integer": int,
        "number": (int, float),
        "boolean": bool,
        "object": dict,
        "array": list,
    }

    for key, rule in props.items():
        if key not in data:
            continue
        expected = rule.get("type")
        if expected and not isinstance(data[key], type_map[expected]):
            errors.append(f"field {key} should be {expected}")
    return errors


def test_validator():
    schema = {
        "required": ["name", "age"],
        "properties": {
            "name": {"type": "string"},
            "age": {"type": "integer"},
            "active": {"type": "boolean"},
        },
    }
    assert validate(schema, {"name": "Ada", "age": 18, "active": True}) == []
    assert len(validate(schema, {"name": "Ada", "age": "18"})) == 1
    print("validator tests passed")


if __name__ == "__main__":
    test_validator()
```

### B 节答题提示
数据处理题最能拉开差距，因为它直接体现你对“模型周边基础设施”的掌握程度。面试官往往不要求你写出工业级 tokenizer 或完整 JSON Schema 标准实现，但会希望你展示出**抽象能力**：能否抓住核心机制，能否写出清晰 API，能否自己补测试。你还可以主动说出“教学版实现”和“生产版实现”的差异，例如 BPE 真实场景会有特殊 token、Unicode 处理和更复杂的 merge 规则；TF-IDF 检索真实场景会加入停用词、归一化、倒排索引；Schema 校验真实场景会递归校验嵌套对象。把这些说出来，哪怕代码不长，也会非常加分。

---

## C. LLM API 编程题

### 1. 实现带重试和流式输出的 API 调用
- **题目**：实现一个调用 OpenAI-compatible 接口的函数，支持失败重试与 streaming。
- **设计要点**：指数退避、超时、逐块打印、错误分类。
- **完整代码**：

```python
import json
import os
import time
import requests


def stream_chat(messages, model="gpt-4o-mini", max_retries=3):
    url = os.environ["OPENAI_BASE_URL"].rstrip("/") + "/chat/completions"
    headers = {
        "Authorization": f"Bearer {os.environ['OPENAI_API_KEY']}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "messages": messages,
        "stream": True,
    }

    for attempt in range(max_retries):
        try:
            with requests.post(url, headers=headers, json=payload, stream=True, timeout=60) as resp:
                resp.raise_for_status()
                for line in resp.iter_lines():
                    if not line:
                        continue
                    line = line.decode("utf-8")
                    if not line.startswith("data: "):
                        continue
                    data = line[6:]
                    if data == "[DONE]":
                        print()
                        return
                    chunk = json.loads(data)
                    delta = chunk["choices"][0].get("delta", {}).get("content", "")
                    if delta:
                        print(delta, end="", flush=True)
                return
        except requests.HTTPError as e:
            if resp.status_code in (400, 401, 403):
                raise
            wait = 2 ** attempt
            time.sleep(wait)
        except requests.RequestException:
            wait = 2 ** attempt
            time.sleep(wait)
    raise RuntimeError("stream_chat failed after retries")
```

### 2. 实现一个简单的 ReAct agent（约 100 行）
- **题目**：从零写一个支持工具调用的迷你 agent。
- **设计要点**：工具 schema、循环控制、最终回答、错误兜底。
- **完整代码**：

```python
import json
import os
import requests


def get_weather(city: str) -> str:
    fake = {"beijing": "30C sunny", "shanghai": "28C cloudy"}
    return fake.get(city.lower(), "unknown")


def calculator(expression: str) -> str:
    return str(eval(expression, {"__builtins__": {}}, {}))


TOOLS = {
    "get_weather": get_weather,
    "calculator": calculator,
}

TOOL_SCHEMAS = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get weather by city name",
            "parameters": {
                "type": "object",
                "properties": {"city": {"type": "string"}},
                "required": ["city"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "calculator",
            "description": "Evaluate a math expression",
            "parameters": {
                "type": "object",
                "properties": {"expression": {"type": "string"}},
                "required": ["expression"],
            },
        },
    },
]


def chat(messages):
    url = os.environ["OPENAI_BASE_URL"].rstrip("/") + "/chat/completions"
    headers = {
        "Authorization": f"Bearer {os.environ['OPENAI_API_KEY']}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": "gpt-4o-mini",
        "messages": messages,
        "tools": TOOL_SCHEMAS,
        "tool_choice": "auto",
    }
    r = requests.post(url, headers=headers, json=payload, timeout=60)
    r.raise_for_status()
    return r.json()["choices"][0]["message"]


def run_agent(user_query: str, max_steps: int = 5) -> str:
    messages = [
        {"role": "system", "content": "You are a helpful ReAct agent. Use tools when needed."},
        {"role": "user", "content": user_query},
    ]

    for _ in range(max_steps):
        msg = chat(messages)
        messages.append(msg)

        tool_calls = msg.get("tool_calls", [])
        if not tool_calls:
            return msg.get("content", "")

        for call in tool_calls:
            name = call["function"]["name"]
            args = json.loads(call["function"]["arguments"])
            try:
                result = TOOLS[name](**args)
            except Exception as e:
                result = f"tool_error: {e}"
            messages.append(
                {
                    "role": "tool",
                    "tool_call_id": call["id"],
                    "name": name,
                    "content": result,
                }
            )
    return "Agent stopped: max steps reached"


if __name__ == "__main__":
    print(run_agent("北京天气如何？顺便算一下 12 * 7"))
```

### 3. 实现 conversation memory with sliding window
- **题目**：实现对话记忆，只保留最近 N 轮并自动生成摘要位。
- **完整代码**：

```python
from dataclasses import dataclass, field


@dataclass
class ConversationMemory:
    max_turns: int = 4
    summary: str = ""
    turns: list[tuple[str, str]] = field(default_factory=list)

    def add(self, role: str, content: str) -> None:
        self.turns.append((role, content))
        if len(self.turns) > self.max_turns:
            old = self.turns.pop(0)
            self.summary += f" [{old[0]}:{old[1][:20]}]"

    def build_messages(self) -> list[dict]:
        messages = []
        if self.summary:
            messages.append({"role": "system", "content": f"Conversation summary: {self.summary}"})
        messages.extend({"role": r, "content": c} for r, c in self.turns)
        return messages


if __name__ == "__main__":
    mem = ConversationMemory(max_turns=3)
    mem.add("user", "你好")
    mem.add("assistant", "你好，我能帮什么")
    mem.add("user", "帮我查订单")
    mem.add("assistant", "请给订单号")
    print(mem.summary)
    print(mem.build_messages())
```

### 4. 实现 parallel tool calling with asyncio
- **题目**：当模型一次提出多个工具调用时，如何并行执行？
- **完整代码**：

```python
import asyncio


async def tool_search(query: str) -> str:
    await asyncio.sleep(0.2)
    return f"search:{query}"


async def tool_db(user_id: str) -> str:
    await asyncio.sleep(0.1)
    return f"db:{user_id}"


TOOL_MAP = {
    "search": tool_search,
    "db_lookup": tool_db,
}


async def execute_tool_call(call: dict) -> dict:
    name = call["name"]
    args = call["args"]
    result = await TOOL_MAP[name](**args)
    return {"tool_call_id": call["id"], "name": name, "result": result}


async def run_parallel(calls: list[dict]) -> list[dict]:
    return await asyncio.gather(*(execute_tool_call(c) for c in calls))


if __name__ == "__main__":
    calls = [
        {"id": "1", "name": "search", "args": {"query": "latest rag paper"}},
        {"id": "2", "name": "db_lookup", "args": {"user_id": "u-42"}},
    ]
    print(asyncio.run(run_parallel(calls)))
```

### C 节面试官常见追问
LLM API 编程题最常见的追问，不是“你会不会调接口”，而是“这个接口出问题时系统会怎样”。因此建议你在答题时主动补充：重试应区分可重试和不可重试错误；流式输出要支持客户端取消；tool call 执行前要做参数校验和权限校验；conversation memory 不能无限增长，必须有摘要或裁剪策略；并行工具调用要考虑超时、部分失败和结果合并顺序。只要你能把这些生产问题说出来，面试官通常会默认你线上踩过坑。

---

## D. Prompt 设计题

### 1. SQL Query Agent 的 system prompt
- **题目**：为一个只能读数据库的 SQL agent 设计系统提示词。
- **实际 Prompt**：

```text
You are a read-only SQL analysis agent.
Goals:
1. Understand the business question.
2. Generate safe SQL for SQLite/PostgreSQL.
3. Never modify data. Only SELECT or WITH queries are allowed.
4. Before writing SQL, restate the user's intent in one sentence.
5. If schema is missing, ask for tables or inspect schema first.
6. Add LIMIT unless the user explicitly requests full results.
7. If the request may expose PII, refuse and explain why.
8. Return:
   - Intent
   - SQL
   - Explanation
   - Risks / assumptions
```

- **设计说明**：这个 prompt 的关键是把“能力边界”写死：只读、默认 LIMIT、先澄清意图、遇到 PII 拒答。面试时你要讲出：好的系统 prompt 不是写得像作文，而是像接口契约。

### 2. 简历结构化抽取 Prompt
- **题目**：设计一个从候选人简历中抽取结构化字段的 prompt。
- **实际 Prompt**：

```text
你是一个简历信息抽取器。请从输入简历中抽取以下字段，并仅输出合法 JSON：
{
  "name": "",
  "email": "",
  "phone": "",
  "years_of_experience": 0,
  "skills": [],
  "education": [
    {"school": "", "degree": "", "major": "", "graduation_year": ""}
  ],
  "work_experience": [
    {"company": "", "title": "", "start": "", "end": "", "highlights": []}
  ]
}
规则：
1. 不要编造不存在的信息。
2. 无法确定的字段填 null。
3. skills 只保留简历中明确出现的技能。
4. 输出前检查 JSON 是否可解析。
```

- **设计说明**：结构化抽取最怕“半结构化正确”。所以 prompt 要明确：只输出 JSON、不能脑补、未知填 null、输出前自检。越靠近生产，越要减少自由发挥空间。

### 3. 研究任务的多步 Prompt Chain
- **题目**：为一个 research agent 设计多步提示链。
- **实际 Prompt Chain**：

```text
Step 1 - Planner Prompt:
你是研究规划器。根据用户问题，拆出 3-6 个可并行的研究子问题，并说明每个子问题需要的证据类型。

Step 2 - Researcher Prompt:
你是事实研究员。只收集证据，不下最终结论。每条证据必须包含来源、日期、摘要、可信度说明。

Step 3 - Synthesizer Prompt:
你是综合分析员。基于多个 researcher 返回的证据，合并一致结论，指出冲突点和信息缺口。

Step 4 - Writer Prompt:
你是报告撰写者。输出最终答复时必须区分“事实”“推断”“不确定项”，并引用证据编号。
```

- **设计说明**：这里体现的是“角色分离”。Planner 负责拆题，Researcher 负责证据，Synthesizer 负责归纳，Writer 负责表达。把这些职责混在一个 prompt 里，通常更容易出现幻觉和遗漏。

### D 节答题提示
Prompt 设计题真正考察的是“约束能力”。很多候选人写 prompt 时只会堆礼貌用语，却不写输出格式、异常处理、拒答条件和检查步骤。更好的答案应该像写接口文档：角色是什么、输入是什么、输出必须满足什么、哪些情况不能瞎猜、发生冲突时按什么优先级处理。你在解释设计思路时，也要尽量用系统语言表达，例如“我在 prompt 里加入结构化返回，是为了降低解析成本和失败率”；“我要求先重述用户意图，是为了减少 SQL 类任务的误解风险”。这会比单纯说“这样写效果更好”更有说服力。

---

## E. Take-home Project 攻略

### 1. 常见作业类型
AI Agent 岗位 take-home 常见有五类：
1. 小型 RAG 问答系统；
2. 带工具调用的 agent；
3. 文档抽取/结构化处理；
4. 多轮客服或 Copilot；
5. 对现有系统做评估与优化。

### 2. 时间管理（通常 4-8 小时）
推荐分配：
- 第 1 小时：读题、澄清需求、列出最低可交付版本。
- 第 2-4 小时：完成主路径功能。
- 第 5-6 小时：补测试、日志、错误处理、README。
- 最后 1 小时：录屏、截图、代码自查、删掉脏代码。

高分候选人和普通候选人的区别，常常不在“功能多”，而在“是否按时交付一个干净的最小可用版本”。

### 3. Reviewer 在看什么
- 代码结构是否清晰；
- 是否有合理的模块拆分；
- 是否考虑异常和边界；
- 是否说明模型、Prompt、评估和已知限制；
- 是否能跑起来，而不是只有截图。

### 4. 推荐项目结构模板

```text
ai-agent-takehome/
├─ app/
│  ├─ main.py
│  ├─ agents/
│  ├─ tools/
│  ├─ prompts/
│  ├─ retrieval/
│  └─ schemas/
├─ tests/
├─ data/
├─ scripts/
├─ .env.example
├─ requirements.txt
└─ README.md
```

### 5. README 应该写什么
最少包含：
- 项目目标与假设；
- 技术栈；
- 如何运行；
- 核心设计说明；
- 已知限制；
- 如果再给 1 天你会继续做什么。

### 6. 文档化你的方法，而不是只展示结果
一个非常实用的模板是：
1. **问题定义**：我理解的目标是什么；
2. **方案选择**：为什么选这个模型、这个索引、这个 prompt；
3. **实现细节**：模块划分与数据流；
4. **评估结果**：给出至少 3 个测试样例；
5. **局限与后续**：体现工程判断。

### 7. 面试加分建议
- 如果时间不够，优先保证主链路可跑。
- 明确写出“安全限制”，比如只读工具、不执行任意代码。
- 给出简单自动化测试，哪怕只有 3 到 5 个。
- 展示日志和可观测性，而不是让 reviewer 猜你的系统做了什么。

### 8. 一个高分 take-home 的最小清单
如果你只有半天时间，建议把交付目标压缩成下面这份清单：主功能可运行；README 可直接带人启动；至少有一个配置示例文件；至少 3 个测试样例；关键日志可读；异常路径不会直接崩溃；如果用了模型 API，要明确环境变量和限额说明；如果用了 RAG，要给出索引构建脚本或最小样例数据。很多候选人把时间花在 UI 和花哨效果上，但 reviewer 通常更在意“仓库拉下来能不能一把跑起来”。

### 9. reviewer 最容易扣分的地方
第一，代码结构混乱，所有逻辑都堆在一个文件里；第二，路径、密钥、模型名硬编码；第三，没有任何错误处理；第四，只展示 happy path，没有边界测试；第五，README 含糊，别人不知道怎么运行；第六，系统声称支持很多能力，但没有解释限制条件。你完全可以在项目文档里诚实写明“为了在 6 小时内完成，我优先做了主链路，暂未实现多租户与权限系统”，这种坦诚比假装做完更专业。

### 10. 提交前自查清单
提交作业前，建议你像上线前走 checklist 一样自查：
1. 本地从零启动是否成功；
2. 环境变量是否有 `.env.example`；
3. 是否存在未删除的调试打印和临时代码；
4. 是否明确记录模型、Prompt、索引和测试样例；
5. 是否说明安全边界，比如“不执行任意用户代码”“高风险操作仅模拟”；
6. 是否给出后续优化方向。
这份清单看起来基础，但它恰恰体现了工程成熟度。很多 offer 的差距，不在于模型调用多高级，而在于你是否让 reviewer 感到“这个人进组后交付会省心”。

---

## 本章小结

编程面试的本质，不是“把代码写出来”这么简单，而是让面试官看到你有完整的工程脑回路：输入如何验证、失败如何处理、并发如何控制、上下文如何裁剪、结果如何测试、系统如何解释。建议你至少把本章所有代码亲手敲一遍，并尝试做两件事：

1. 把所有示例改造成你自己的代码模板；
2. 挑一个 take-home 题目，在 6 小时内完整做一次。

到这里，第五部分“面试准备”就完整了。你已经具备理论答题、系统设计和现场 coding 三条主线的复习框架。接下来真正决定 offer 的，是练习次数，而不是收藏了多少题目。

## 现场 coding 的口述模板

为了让你在真正的面试中把代码题答得更像工程师，最后再给你一个“口述模板”。拿到题目后，你可以按下面顺序说：第一句先确认输入输出，例如“我理解输入是若干文本块和一个 query，输出是按相似度排序后的 top-k 结果”；第二句说明核心数据结构，例如“这里我会用最小堆，因为我们只关心前 k 个而不是完整排序”；第三句给复杂度，例如“整体是 O(n log k)，如果 k 远小于 n，会比全量排序更省”；第四句说边界情况，例如“我会处理零向量、空输入和维度不一致”；第五句再开始写代码。这样做有两个好处：一是你把思路先占住，哪怕代码中途卡住，面试官也知道你会做；二是你主动暴露工程意识，能显著降低“写得对但讲不清”的风险。

代码写完后也别急着沉默。你还可以主动补三层内容。第一层是**测试**：给一两个正常输入，再给一个边界输入。第二层是**上线视角**：如果这是生产功能，我会加日志、监控和超时控制。第三层是**优化方向**：如果数据规模更大，我会换索引、加缓存、分层路由，或者把同步调用改成异步。面试官之所以喜欢追问，不是为了故意难为你，而是想看你能否从“脚本思维”切换到“系统思维”。只要你每次都按这个模板收尾，稳定性会大幅提升。

## 从代码题延伸到项目题：你还应该准备什么

很多候选人只刷单题，却忽略了题目之间的组合方式。实际上，AI Agent 面试很喜欢把两个能力拼起来考。例如先让你写一个文本分块函数，再追问“如果我要做一个支持多轮问答的 RAG 系统，分块结果如何进入检索链路”；或者先让你写一个并发工具调用器，再追问“如果其中一个工具超时，你怎么保证 agent 不会死循环”。所以你在练习本章时，不要把题目当成孤立片段，而要思考它在真实系统里的位置：它属于摄取层、检索层、编排层、记忆层，还是评估层。

建议你给自己建立一份“代码题到系统题”的映射表。比如：Top-K 检索题对应向量召回阶段；滑动窗口题对应上下文裁剪和记忆管理；BFS 题对应知识图谱查询和工作流依赖遍历；JSON Schema 验证器对应 tool calling 的参数校验；异步并发题对应多工具执行和 fan-out/fan-in 编排。只要你能在回答里把这层映射说出来，面试官就很容易把你归类为“懂 Agent 工程”的人，而不只是“Python 还可以”的人。

## 最后一轮冲刺建议

如果你准备时间有限，我建议按下面优先级冲刺。第一优先级：把本章 A、B、C 三部分亲手敲一遍，因为它们最容易被现场要求改代码。第二优先级：把 D 部分的三个 prompt 背后的设计逻辑讲顺，不一定逐字背 prompt，但要能说出为什么这样约束。第三优先级：拿 E 部分的模板做一个 4 到 6 小时的迷你作业，哪怕只是本地 CLI 版，也要练一次“按时交付”。准备面试时，广度当然重要，但真正让你在现场不慌的，是熟练度和手感。

你也可以把复习安排得更工程化一些：第一天只练算法与数据处理；第二天只练 API 编排和 memory；第三天专门做 take-home；第四天做一轮模拟面试，把“先讲思路、再写代码、最后扩展”的节奏练顺。很多人刷了很多题却还是发挥不好，问题往往不在知识不足，而在于没有把知识组织成稳定可重复的输出流程。面试本质上是高压下的结构化表达比赛，而结构化表达完全可以通过刻意练习获得。

## 常见失误模式与修正方法

最后补一组非常实战的“失误模式”。第一类失误是**一上来就写代码，不澄清需求**。修正方法很简单：先复述输入、输出、约束，再动手。第二类失误是**只会 happy path**，比如并发调用题只写成功结果，不处理超时和异常；记忆题只做列表裁剪，不考虑 system prompt 保留和摘要压缩。修正方法是强迫自己在每道题里至少说出两个失败场景。第三类失误是**把教学代码当生产代码**，例如直接 `eval` 不解释风险、把 API key 写在代码里、完全没有 schema 校验。修正方法是主动说明“这里为了演示简化实现，真实系统会增加沙箱、权限、审计和输入验证”。第四类失误是**会写不会讲**，代码交上去以后沉默不语。修正方法是固定一句收尾：“如果这段代码放进生产，我会补日志、超时、测试和监控。”面试官很多时候并不是在看你写得多快，而是在看你有没有把工程风险提前想到。

还有一类特别常见但容易被忽略的失误，是**沉迷细节，忘了业务目标**。比如被问到文本分块算法时，候选人一直讨论字符串切片，却不提分块质量会影响召回率和 token 成本；被问到 JSON Schema 验证时，只讨论 Python 类型，却不提它是 tool calling 安全边界的一部分；被问到并发工具调用时，只讲 `asyncio` 语法，却不提为什么需要限流、为什么要做幂等和重试。你必须训练自己把“代码局部”重新连接回“系统全局”。只有当你能做到这一点，面试官才会觉得你不是单点刷题，而是真的具备 Agent 工程落地能力。

## 如何用这一章做模拟面试

最推荐的练习方式不是默读，而是计时模拟。你可以请朋友或用录音软件给自己出题：先随机抽一道算法题，要求 2 分钟口述思路、10 分钟写代码、3 分钟讲测试和优化；再抽一道 API 编排题，要求你重点解释异常处理、重试、超时和权限边界；最后再抽一个 take-home 场景，让你在 5 分钟内说出目录结构、主链路和 README 应该写什么。这样的训练会逼你把零散知识压缩成稳定的输出节奏。

如果你是自学，也可以用“三遍法”。第一遍，只求写出来；第二遍，强制补边界测试和错误处理；第三遍，不看答案重新写，并在写完后录一段 3 分钟讲解。你会非常明显地发现：真正难的不是代码本身，而是在有限时间内把代码、原理和工程权衡讲清楚。只要你把这一步练出来，现场 coding 的通过率会明显提升。

还有一个非常有效的小技巧：为自己准备一套“可复用代码骨架”。比如并发题先写 `Semaphore + gather(return_exceptions=True)` 模板，API 题先写“重试 + 超时 + 日志 + 配置读取”模板，结构化输出题先写“schema 校验 + 失败重试 + JSON 解析”模板。这样做不是作弊，而是工程师正常的工作方式：把重复问题沉淀成稳定模板，然后把脑力留给真正需要判断的部分。面试官通常不会因为你有模板而扣分，反而会因为你代码结构稳定、异常路径完整而更认可你的工程习惯。

如果你愿意再多做一步，我非常建议你给自己做一个小型“错题本”。每次练习后，不要只记“这题我做出来了”，而要记下三件事：第一，我最先卡在哪；第二，面试官可能会怎么追问；第三，下次我能不能用更短的话把思路讲清楚。长期来看，真正决定 coding 面稳定性的，不是你看过多少题，而是你是否把自己的失误模式识别出来并持续修正。很多候选人在第三轮、第四轮面试表现越来越好，本质上就是因为他们开始复盘“表达上的错误”和“工程上的盲点”，而不只是复盘某一行代码写错了什么。

你还可以把本章内容按“白板版”和“实战版”各练一次。白板版要求你不依赖编辑器补全，重点训练思路组织和核心语法；实战版要求你真的跑通代码，补上测试和 README，重点训练交付能力。两种训练缺一不可：只练白板，代码容易浮；只练实战，现场表达又容易散。把两种模式结合起来，你的编程面试表现通常会更均衡、更稳定。

最后送你一句非常实用的复盘标准：每做完一道题，都问自己“如果这是我入职后第一周写进仓库的代码，我敢不敢提交给团队看？” 如果答案是否定的，就继续补命名、异常处理、注释、测试和文档。这个问题听起来简单，但它会迫使你从“刷题者视角”切换到“工程师视角”，而这正是 AI Agent 编程面试最想筛选出的能力。

当你真的能这样要求自己时，题目本身就不再只是题目，而会变成你工程判断力的练习场。

而一旦工程判断力开始稳定，你面对不同公司的不同题型时，就不会再只靠临场发挥，而是能依靠一套可复用的方法论稳定输出。

这，才是真正的面试护城河。

当别人还在背答案时，你已经在训练可迁移的工程表达能力了。

这会长期复利。

也会直接提高你的拿 offer 概率。

越练越稳。

别停。

练。
