# Interview 09 — Coding 面试

> Coding 面试不是刷 LeetCode，而是检验你能否写出 AI 工程里真实会用的基础组件：token-aware 限流、上下文裁剪、重试、向量检索、SSE、chunking、hybrid search 和 judge harness。下面题目均给出完整 Python 解法。

### Q1: 实现 TPM-aware Token Bucket Rate Limiter

**Question**

实现一个支持 tokens-per-minute 的限流器。请求开始时根据 `prompt_tokens + max_output_tokens` 预留 token；请求完成后按实际使用量退款。要求线程安全。

**Model Answer**

```python
from __future__ import annotations
import threading
import time
from dataclasses import dataclass
@dataclass(frozen=True)
class Reservation:
    requested: int
    granted_at: float
class TokenBucket:
    def __init__(self, capacity: int, refill_per_second: float) -> None:
        if capacity <= 0:
            raise ValueError("capacity must be positive")
        if refill_per_second <= 0:
            raise ValueError("refill_per_second must be positive")
        self.capacity = capacity
        self.refill_per_second = refill_per_second
        self._tokens = float(capacity)
        self._updated_at = time.monotonic()
        self._lock = threading.Lock()
    def _refill(self, now: float) -> None:
        elapsed = max(0.0, now - self._updated_at)
        self._tokens = min(
            self.capacity,
            self._tokens + elapsed * self.refill_per_second,
        )
        self._updated_at = now
    def try_reserve(self, tokens: int) -> Reservation | None:
        if tokens <= 0:
            raise ValueError("tokens must be positive")
        if tokens > self.capacity:
            return None
        with self._lock:
            now = time.monotonic()
            self._refill(now)
            if self._tokens < tokens:
                return None
            self._tokens -= tokens
            return Reservation(requested=tokens, granted_at=now)
    def refund(self, reservation: Reservation, actual_tokens: int) -> None:
        if actual_tokens < 0:
            raise ValueError("actual_tokens must be non-negative")
        refund = max(0, reservation.requested - actual_tokens)
        with self._lock:
            now = time.monotonic()
            self._refill(now)
            self._tokens = min(self.capacity, self._tokens + refund)
    def available(self) -> int:
        with self._lock:
            self._refill(time.monotonic())
            return int(self._tokens)
class TpmLimiter:
    def __init__(self, tokens_per_minute: int) -> None:
        self.bucket = TokenBucket(
            capacity=tokens_per_minute,
            refill_per_second=tokens_per_minute / 60.0,
        )
    def admit(self, prompt_tokens: int, max_output_tokens: int) -> Reservation | None:
        return self.bucket.try_reserve(prompt_tokens + max_output_tokens)
    def complete(self, reservation: Reservation, actual_prompt: int, actual_output: int) -> None:
        self.bucket.refund(reservation, actual_prompt + actual_output)
```

复杂度：`try_reserve` 和 `refund` 都是 O(1)，空间 O(1)。生产中多实例需要 Redis/Lua、DynamoDB conditional update 或专用 rate limit service 保证原子性。

**Follow-up Questions**
如何同时支持 RPM、TPM 和 concurrency？；Streaming 输出超过预留怎么办？；多租户如何做公平调度？；Redis 实现如何避免竞态？

**Deep Dive**

强答案会在请求开始前预留 `max_output_tokens`，结束后 refund。弱答案只在结束后计数，那时资源已经被消耗。Staff 级会讨论分布式限流、retry-after、priority 和 budget。


### Q2: 实现 Sliding-window Conversation Trimmer

**Question**

给定系统提示、历史消息、RAG 片段和 context window，保留最近对话并为输出预留 token。要求支持 pinned message。

**Model Answer**

```python
from dataclasses import dataclass
@dataclass(frozen=True)
class Message:
    message_id: str
    role: str
    content: str
    pinned: bool = False
def count_tokens(text: str) -> int:
    # 面试可用近似；生产使用 tiktoken / sentencepiece。
    return max(1, len(text) // 4)
def message_cost(msg: Message) -> int:
    return count_tokens(msg.content) + 4
def trim_conversation(
    system_prompt: str,
    history: list[Message],
    rag_chunks: list[str],
    context_window: int,
    max_output_tokens: int,
    rag_budget: int,
) -> tuple[list[Message], list[str]]:
    fixed_cost = count_tokens(system_prompt) + max_output_tokens
    if fixed_cost >= context_window:
        raise ValueError("system prompt plus output reserve exceeds context window")
    remaining = context_window - fixed_cost
    kept_chunks: list[str] = []
    used_rag = 0
    for chunk in rag_chunks:
        cost = count_tokens(chunk)
        if used_rag + cost > min(rag_budget, remaining):
            break
        kept_chunks.append(chunk)
        used_rag += cost
    remaining -= used_rag
    pinned = [m for m in history if m.pinned]
    pinned_cost = sum(message_cost(m) for m in pinned)
    if pinned_cost > remaining:
        raise ValueError("pinned messages exceed available budget")
    remaining -= pinned_cost
    selected_ids = {m.message_id for m in pinned}
    selected_recent: list[Message] = []
    for msg in reversed(history):
        if msg.message_id in selected_ids:
            continue
        cost = message_cost(msg)
        if cost <= remaining:
            selected_recent.append(msg)
            selected_ids.add(msg.message_id)
            remaining -= cost
    selected_recent.reverse()
    final = [m for m in history if m.message_id in selected_ids]
    return final, kept_chunks
```

复杂度：O(n + k)，n 为消息数，k 为 chunk 数。生产中要保留安全边际，因为 tokenizer 估算和 provider 计数可能不同。

**Follow-up Questions**
如何加入旧历史摘要？；RAG 和 recent history 谁优先？；Lost-in-the-middle 如何缓解？；pinned messages 超预算怎么办？

**Deep Dive**

强答案会显式预留输出 token。上下文裁剪不是“塞最多”，而是把最高价值信息放在模型最容易使用的位置。


### Q3: 实现 LLM 调用 Retry with Backoff

**Question**

实现一个 retry wrapper：对 429、5xx、网络超时重试；对 4xx 不重试；支持 jitter、deadline 和最大重试次数。

**Model Answer**

```python
import random
import time
from collections.abc import Callable
from dataclasses import dataclass
class LLMError(Exception):
    def __init__(self, status_code: int | None, message: str = "") -> None:
        super().__init__(message)
        self.status_code = status_code
@dataclass(frozen=True)
class RetryPolicy:
    max_attempts: int = 4
    base_delay: float = 0.25
    max_delay: float = 4.0
    deadline_seconds: float = 15.0
def is_retryable(exc: Exception) -> bool:
    if isinstance(exc, TimeoutError):
        return True
    if isinstance(exc, LLMError):
        return exc.status_code == 429 or (
            exc.status_code is not None and 500 <= exc.status_code < 600
        )
    return False
def call_with_retry(fn: Callable[[], str], policy: RetryPolicy = RetryPolicy()) -> str:
    started = time.monotonic()
    last_exc: Exception | None = None
    for attempt in range(1, policy.max_attempts + 1):
        try:
            return fn()
        except Exception as exc:
            if not is_retryable(exc):
                raise
            last_exc = exc
            elapsed = time.monotonic() - started
            if attempt == policy.max_attempts or elapsed >= policy.deadline_seconds:
                break
            cap = min(policy.max_delay, policy.base_delay * (2 ** (attempt - 1)))
            sleep_for = random.uniform(0, cap)  # full jitter
            if elapsed + sleep_for > policy.deadline_seconds:
                break
            time.sleep(sleep_for)
    assert last_exc is not None
    raise last_exc
```

复杂度：最多 O(max_attempts) 次调用。生产中应读取 `Retry-After`，加入 retry budget、circuit breaker，并确保被重试操作幂等。

**Follow-up Questions**
Streaming 已输出 token 后能重试吗？；Tool call 成功但模型失败怎么办？；为什么需要 jitter？；Retry 与 fallback 的边界是什么？

**Deep Dive**

强答案不会重试所有异常。400/schema 错误通常是调用方 bug。AI workflow 的重试必须结合幂等和 checkpoint。


### Q4: 实现简单 Vector Similarity Search

**Question**

实现内存版向量检索，支持 cosine similarity、top-k 和 metadata filter。

**Model Answer**

```python
import heapq
import math
from dataclasses import dataclass
from typing import Any, Callable
@dataclass(frozen=True)
class Document:
    doc_id: str
    vector: tuple[float, ...]
    text: str
    metadata: dict[str, Any]
def cosine(a: tuple[float, ...], b: tuple[float, ...]) -> float:
    if len(a) != len(b):
        raise ValueError("dimension mismatch")
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)
class VectorIndex:
    def __init__(self, docs: list[Document]) -> None:
        self.docs = docs
    def search(
        self,
        query: tuple[float, ...],
        k: int,
        where: Callable[[dict[str, Any]], bool] | None = None,
    ) -> list[tuple[float, Document]]:
        if k <= 0:
            return []
        heap: list[tuple[float, str, Document]] = []
        for doc in self.docs:
            if where is not None and not where(doc.metadata):
                continue
            score = cosine(query, doc.vector)
            item = (score, doc.doc_id, doc)
            if len(heap) < k:
                heapq.heappush(heap, item)
            elif item > heap[0]:
                heapq.heapreplace(heap, item)
        return [(score, doc) for score, _, doc in sorted(heap, reverse=True)]
```

复杂度：暴力扫描 O(n·d)，heap O(n log k)，空间 O(k)。真实系统用 HNSW/IVF 等 ANN 索引，并把权限 filter 下推。

**Follow-up Questions**
为什么不能生成后再做权限过滤？；ANN 的 recall/latency 如何权衡？；embedding 模型升级怎么办？；cosine 与 dot product 何时等价？

**Deep Dive**

强答案会指出这是 baseline，不是大规模方案。面试重点是正确性、过滤、复杂度和生产迁移路径。


### Q5: 实现 FastAPI SSE Streaming Endpoint

**Question**

用 FastAPI 实现 SSE endpoint，流式返回 LLM token，并支持错误事件和 done 事件。

**Model Answer**

```python
import asyncio
import json
from collections.abc import AsyncIterator
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
app = FastAPI()
def sse(event: str, data: dict) -> str:
    payload = json.dumps(data, ensure_ascii=False)
    return f"event: {event}\ndata: {payload}\n\n"
async def fake_llm_stream(prompt: str) -> AsyncIterator[str]:
    for token in ["你好", "，", "这是", "流式", "回答"]:
        await asyncio.sleep(0.05)
        yield token
@app.post("/chat/stream")
async def chat_stream(request: Request) -> StreamingResponse:
    body = await request.json()
    prompt = body["message"]
    async def gen() -> AsyncIterator[str]:
        yield sse("message.created", {"id": "msg_123"})
        try:
            async for token in fake_llm_stream(prompt):
                if await request.is_disconnected():
                    break
                yield sse("token", {"text": token})
            yield sse("done", {"finish_reason": "stop"})
        except Exception as exc:
            yield sse("error", {"message": str(exc)})
    return StreamingResponse(gen(), media_type="text/event-stream")
```

复杂度由模型流决定；endpoint 自身 O(tokens)。生产中要加鉴权、deadline、心跳、backpressure、内容安全过滤和事件持久化。

**Follow-up Questions**
Nginx buffering 如何关闭？；客户端断线是否继续生成？；如何 resume stream？；SSE 与 WebSocket 如何选择？

**Deep Dive**

强答案会包含事件类型，而不是只吐字符串。生产前端需要知道工具调用、引用、错误和完成状态。


### Q6: 实现 Chunking with Overlap

**Question**

实现一个按 token 近似长度切分文本的 chunker，支持 overlap，并避免死循环。

**Model Answer**

```python
from dataclasses import dataclass
@dataclass(frozen=True)
class Chunk:
    text: str
    start_token: int
    end_token: int
def simple_tokens(text: str) -> list[str]:
    return text.split()
def chunk_text(text: str, chunk_size: int, overlap: int) -> list[Chunk]:
    if chunk_size <= 0:
        raise ValueError("chunk_size must be positive")
    if overlap < 0 or overlap >= chunk_size:
        raise ValueError("overlap must be >= 0 and < chunk_size")
    tokens = simple_tokens(text)
    chunks: list[Chunk] = []
    start = 0
    step = chunk_size - overlap
    while start < len(tokens):
        end = min(len(tokens), start + chunk_size)
        chunks.append(
            Chunk(
                text=" ".join(tokens[start:end]),
                start_token=start,
                end_token=end,
            )
        )
        if end == len(tokens):
            break
        start += step
    return chunks
```

复杂度 O(n)。生产 chunking 应尽量按结构边界（标题、段落、代码块）切，而不是机械 token 切。Overlap 提高跨边界召回，但增加索引成本和重复上下文。

**Follow-up Questions**
中文没有空格怎么办？；代码文档如何 chunk？；overlap 太大会怎样？；如何保存 source citation？

**Deep Dive**

强答案会说 chunking 是 retrieval quality 的核心变量。面试代码可简单，生产要结构感知、版本化和可回溯。


### Q7: 实现 Reciprocal Rank Fusion (RRF)

**Question**

给定 BM25 和 vector search 两个排序结果，实现 RRF 融合。

**Model Answer**

```python
from collections import defaultdict
from dataclasses import dataclass
@dataclass(frozen=True)
class SearchHit:
    doc_id: str
    score: float
def rrf_fuse(
    rankings: list[list[SearchHit]],
    k: int = 60,
    top_n: int = 10,
) -> list[tuple[str, float]]:
    scores: dict[str, float] = defaultdict(float)
    for hits in rankings:
        for rank, hit in enumerate(hits, start=1):
            scores[hit.doc_id] += 1.0 / (k + rank)
    return sorted(scores.items(), key=lambda x: (-x[1], x[0]))[:top_n]
```

复杂度 O(total_hits log m)，m 是候选文档数。RRF 的优点是不要求不同检索器分数可比，只使用 rank。

**Follow-up Questions**
RRF 中 k 的含义是什么？；为什么不直接加 BM25 和 cosine 分？；融合后还需要 reranker 吗？；权限过滤放在融合前还是后？

**Deep Dive**

强答案会解释 score calibration 问题。BM25 分数和向量相似度来自不同分布，直接相加通常不稳；RRF 是简单强基线。


### Q8: 实现 LLM-as-Judge Harness

**Question**

实现评测 harness：读取样本，调用被测 answer 函数和 judge 函数，输出通过率。judge 返回 JSON，并处理解析失败。

**Model Answer**

```python
import json
from collections.abc import Callable
from dataclasses import dataclass
@dataclass(frozen=True)
class EvalCase:
    case_id: str
    question: str
    reference: str
@dataclass(frozen=True)
class EvalResult:
    case_id: str
    score: int
    passed: bool
    rationale: str
def parse_judge(raw: str) -> tuple[int, str]:
    try:
        data = json.loads(raw)
        score = int(data["score"])
        rationale = str(data.get("rationale", ""))
    except Exception as exc:
        raise ValueError(f"invalid judge output: {raw}") from exc
    if not 1 <= score <= 5:
        raise ValueError(f"score out of range: {score}")
    return score, rationale
def run_eval(
    cases: list[EvalCase],
    answer_fn: Callable[[str], str],
    judge_fn: Callable[[EvalCase, str], str],
    pass_score: int = 4,
) -> list[EvalResult]:
    results: list[EvalResult] = []
    for case in cases:
        answer = answer_fn(case.question)
        raw = judge_fn(case, answer)
        try:
            score, rationale = parse_judge(raw)
        except ValueError as exc:
            score, rationale = 1, str(exc)
        results.append(
            EvalResult(
                case_id=case.case_id,
                score=score,
                passed=score >= pass_score,
                rationale=rationale,
            )
        )
    return results
def pass_rate(results: list[EvalResult]) -> float:
    if not results:
        return 0.0
    return sum(r.passed for r in results) / len(results)
```

复杂度 O(n) 次 answer 与 judge 调用。生产 harness 要记录 model/prompt/dataset/judge 版本，支持并发、重试、成本统计、slice metrics 和人工抽检。

**Follow-up Questions**
Judge flaky 怎么办？；如何做 pairwise evaluation？；如何防止被评答案 prompt-inject judge？；解析失败算失败还是重试？

**Deep Dive**

强答案会把 judge 当不可靠外部依赖：schema validation、失败降级、版本记录、人工校准。弱答案只看平均分。


## Further Reading

- Part 1：后端 API、限流、异步任务、可观测和数据存储章节。
- Part 2 Chapter 01：LLM 基础与 Transformer 概览，用于理解 token、context window 和流式生成。
- Part 2 Chapter 15：Evaluation 与实验体系，尤其是 judge harness、回归和线上指标。
- Part 2 Chapter 16/19：Guardrails、安全和工具调用风险。
