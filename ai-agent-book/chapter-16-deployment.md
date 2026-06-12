# 第十六章：Agent 工程化与部署

前面几章解决的是“怎么把 Agent 做出来”，本章解决的是“怎么把 Agent 稳定地跑在生产环境里”。这是很多转行工程师最容易被忽视、但在面试和工作中最值钱的一段能力。因为企业真正买单的从来不是一个会回答问题的 demo，而是一个**可部署、可观测、可限流、可审计、可回滚、可控成本**的系统。

## 16.1 从原型到生产：为什么工程化这么难

一个 notebook 里的 Agent，通常只有：

- 一个模型调用；
- 一个 prompt；
- 少量测试样例；
- 不考虑并发与异常。

而生产 Agent 至少要面对：

| 问题 | 原型常忽略 | 生产必须处理 |
|---|---|---|
| 并发 | 单用户调用 | 10-1000 QPS 峰值 |
| 成本 | 不敏感 | 每日预算、每用户配额 |
| 稳定性 | 手工重试 | 自动重试、降级、熔断 |
| 可观测性 | 看 print | tracing、metrics、日志 |
| 安全 | 不考虑 | 鉴权、脱敏、越权控制 |
| 发布 | 本地脚本 | CI/CD、灰度、回滚 |

所以工程化的本质，是把“概率上能跑”升级为“制度上可控”。

## 16.2 API 服务设计：FastAPI 是一个合理起点

对于 Python 生态，FastAPI（高性能 Python Web 框架）是非常适合 Agent 服务化的选择，原因包括：

1. 原生异步；
2. Pydantic schema 友好；
3. OpenAPI 文档自动生成；
4. 与 LangChain、OpenAI SDK、向量库客户端集成方便。

### 16.2.1 Request / Response Schema 设计

不要直接把“prompt 字符串”暴露给前端，而应设计稳定接口。

```python
from fastapi import FastAPI
from pydantic import BaseModel, Field
from typing import List, Optional

app = FastAPI(title="agent-service")

class ChatRequest(BaseModel):
    user_id: str = Field(..., min_length=3)
    session_id: str
    query: str = Field(..., min_length=1, max_length=4000)
    stream: bool = False
    metadata: Optional[dict] = None

class ChatResponse(BaseModel):
    answer: str
    trace_id: str
    tokens_in: int
    tokens_out: int
    tools_used: List[str]

@app.post("/v1/chat", response_model=ChatResponse)
async def chat(req: ChatRequest) -> ChatResponse:
    answer = f"echo: {req.query}"
    return ChatResponse(
        answer=answer,
        trace_id="trace-demo-001",
        tokens_in=len(req.query) // 2,
        tokens_out=len(answer) // 2,
        tools_used=[],
    )
```

这里有几个工程细节值得注意：

- `user_id`、`session_id` 与 `query` 分离，便于审计与记忆检索；
- 显式返回 `trace_id`，便于前端报障时回溯；
- 返回 token 指标，让调用方理解成本；
- `metadata` 预留给业务标签、A/B 分流、租户信息。

### 16.2.2 SSE 与 WebSocket

流式输出通常有两种：

| 方案 | 优点 | 缺点 | 典型场景 |
|---|---|---|---|
| SSE（Server-Sent Events，服务端推送事件） | 简单、HTTP 友好 | 单向通信 | 聊天回答流式展示 |
| WebSocket | 双向、灵活 | 网关与状态管理复杂 | 需要中途打断、补发指令 |

一个最小 SSE 示例：

```python
import asyncio
from fastapi.responses import StreamingResponse

async def token_stream(text: str):
    for token in text.split():
        yield f"data: {token}\n\n"
        await asyncio.sleep(0.1)
    yield "data: [DONE]\n\n"

@app.get("/v1/chat/stream")
async def chat_stream(query: str):
    return StreamingResponse(token_stream(f"streaming answer for {query}"), media_type="text/event-stream")
```

如果你的前端只是逐字展示模型输出，SSE 往往已经够用，而且在负载均衡和浏览器兼容性上更省心。

### 16.2.3 鉴权、限流、错误处理

生产接口至少要有三层保护：

1. **认证（authentication，身份认证）**：JWT、API Key、内部 OAuth。
2. **授权（authorization，权限控制）**：不同角色能否调用不同工具。
3. **限流（rate limiting，速率限制）**：按用户、租户、IP、API Key 做请求上限。

错误处理也不能只是返回 500。建议定义统一错误码：

| 错误码 | 含义 |
|---|---|
| `MODEL_TIMEOUT` | 模型超时 |
| `TOOL_UNAVAILABLE` | 工具服务不可用 |
| `BUDGET_EXCEEDED` | 超出预算 |
| `INPUT_BLOCKED` | 输入触发安全策略 |
| `DEGRADED_RESPONSE` | 使用降级模型或缓存结果 |

优雅降级（graceful degradation，优雅降级）的典型策略包括：

- 主模型超时后切换到便宜模型；
- 工具失败时退化为“基于已有上下文的保守回答”；
- 检索系统超时时返回缓存结果。

## 16.3 容器化：把“能跑”变成“可交付”

### 16.3.1 Dockerfile

下面是一个适用于 Agent API 的简化 Dockerfile：

```dockerfile
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

几个关键点：

- 选择 `slim` 镜像降低体积；
- `PYTHONUNBUFFERED=1` 让日志及时输出；
- 不要把 `.env` 和密钥打进镜像，统一走环境变量或密钥管理系统。

### 16.3.2 Docker Compose：多服务协同

Agent 服务很少单独存在，常见组合是：API + Redis + Vector DB（向量数据库）。

```yaml
version: "3.9"
services:
  agent-api:
    build: .
    ports:
      - "8000:8000"
    environment:
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      REDIS_URL: redis://redis:6379/0
      VECTOR_DB_URL: http://qdrant:6333
    depends_on:
      - redis
      - qdrant

  redis:
    image: redis:7
    ports:
      - "6379:6379"

  qdrant:
    image: qdrant/qdrant:latest
    ports:
      - "6333:6333"
```

在面试里，很多候选人会背“Docker 很重要”，但答不到点上。更好的回答是：**Redis 用于缓存、会话状态或队列；向量库承担 RAG 检索；Compose 用来在本地/测试环境快速还原多服务依赖。**

### 16.3.3 GPU 容器注意事项

如果你的 Agent 不只是调外部 API，而是本地部署 embedding 或 reranker 模型，就要考虑 GPU：

- 使用带 CUDA 的基础镜像；
- 控制显存占用；
- 区分推理型与训练型镜像；
- 做 readiness/liveness 检查，防止模型还没加载完就接流量。

## 16.4 监控与可观测性：没有数据，就没有运维

### 16.4.1 OpenTelemetry

OpenTelemetry（开放遥测标准）适合统一采集 trace、metric、log。对于 Agent 服务，至少要打通：

- HTTP 请求 trace；
- 模型调用 trace；
- 工具调用 trace；
- 数据库/向量库/缓存 trace。

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

def run_agent_step(step_name: str):
    with tracer.start_as_current_span(step_name) as span:
        span.set_attribute("agent.step", step_name)
        return {"ok": True}
```

### 16.4.2 LLM 指标与 Agent 指标

传统 Web 服务只看 CPU、内存、错误率远远不够。你至少要有两类指标：

| 类别 | 指标 |
|---|---|
| LLM-specific | tokens in/out、首 token 延迟、总延迟、每请求成本、缓存命中率 |
| Agent-specific | tool call success rate、task completion rate、fallback rate、human handoff rate |

一个常见监控面板会展示：

- P50/P95/P99 延迟；
- 每分钟 token 消耗；
- 各模型成本占比；
- 工具失败 Top 10；
- 提示注入拦截次数；
- 高风险租户异常增长。

### 16.4.3 Logging 最佳实践

日志不是越多越好，而是越可查询越好。建议使用结构化日志（JSON logging，结构化日志）：

```python
import json
import time

def log_event(event_type: str, payload: dict):
    record = {
        "ts": int(time.time()),
        "event_type": event_type,
        "payload": payload,
    }
    print(json.dumps(record, ensure_ascii=False))

log_event("tool_call", {"tool": "search_docs", "latency_ms": 182, "ok": True})
```

日志里应避免直接记录完整用户敏感数据，必要时做哈希、截断或脱敏。

### 16.4.4 告警

你至少要为以下情况设置告警：

1. P95 延迟连续 10 分钟超过阈值；
2. 每请求成本突然上涨 30% 以上；
3. 某个关键工具成功率低于 95%；
4. fallback rate 激增；
5. 安全拦截数异常增加。

## 16.5 成本管理：Agent 系统常见的隐形杀手

原型阶段每次请求可能只花 0.01 美元，但上线后如果：

- 每轮 3 次检索；
- 2 次大模型调用；
- 1 次长上下文总结；
- 5000 DAU；

那么月成本可能快速上升到数千甚至数万美元。

### 16.5.1 Token Tracking 与预算

建议至少按四个维度统计：

- 用户；
- 租户；
- 功能；
- 模型。

例如：

| 功能 | 平均输入 tokens | 平均输出 tokens | 单次成本 |
|---|---|---|---|
| FAQ 问答 | 1200 | 350 | $0.008 |
| 报告生成 | 4800 | 1200 | $0.064 |
| 多工具研究 | 7000 | 1800 | $0.11 |

### 16.5.2 缓存策略

缓存至少有两类：

| 类型 | 适合场景 |
|---|---|
| Exact cache 精确缓存 | 相同请求、相同上下文 |
| Semantic cache 语义缓存 | 相近问题、稳定答案场景 |

语义缓存可把常见 FAQ 成本压缩 30%-70%，但前提是业务允许一定程度的近似命中。

### 16.5.3 Model Routing

模型路由（model routing，模型路由）是降本利器。一个常见策略：

```text
简单问答 -> 小模型
结构化抽取 -> 小模型 + 严格 schema
复杂推理/高风险输出 -> 大模型
最终审校 -> 更强模型或人工
```

这类分层通常能在质量基本可接受的前提下，把总成本降低 20%-50%。

### 16.5.4 Throttling

节流（throttling，流量节流）不仅是防攻击，也是防预算爆炸。常见做法：

- 单用户每分钟 20 次；
- 单租户每天预算上限；
- 高成本接口需要更严格配额；
- 触发阈值后切换低成本模型。

## 16.6 CI/CD：AI Agent 不是“无法测试”的

### 16.6.1 测试分层

| 测试类型 | 覆盖内容 |
|---|---|
| Unit tests 单元测试 | prompt helper、tool wrapper、parser、route function |
| Integration tests 集成测试 | Agent + 向量库 + Redis + 外部 API mock |
| Evaluation tests 评测测试 | 真实样本下的回答质量、引用准确率、任务完成率 |

一个简单单元测试示例：

```python
def route_query(query: str) -> str:
    return "simple" if len(query) < 20 else "complex"

def test_route_query():
    assert route_query("你好") == "simple"
    assert route_query("请帮我对比三种部署方案并给出成本分析") == "complex"
```

### 16.6.2 Prompt Regression Testing

提示词回归测试的重点是：当你改 system prompt 或 tool description 后，历史样本表现是否退化。成熟团队往往维护：

- 50 条黄金样本；
- 200 条真实流量抽样；
- 每次 PR 自动跑评测；
- 不达标不得上线。

### 16.6.3 A/B Testing 与 Blue-Green Deployment

A/B 测试适合比较：

- 新旧 prompt；
- 新旧模型；
- 新旧检索策略；
- 新旧工具路由逻辑。

蓝绿发布（blue-green deployment，蓝绿部署）则适合降低上线风险：

```text
Traffic
  |
  +--> Blue (current stable)
  |
  +--> Green (new version, 5% traffic -> 50% -> 100%)
```

一旦发现质量或成本异常，可快速切回 Blue。

## 16.7 MLOps 基础：Agent 团队也绕不过去

虽然很多 Agent 系统不自己训练大模型，但仍然离不开 MLOps（机器学习运维）思想。

### 必须理解的四件事

1. **Model versioning 模型版本管理**：不同模型、不同 prompt、不同 tool schema 都要可追踪。
2. **Experiment tracking 实验跟踪**：每次调参、调 prompt、调检索策略的结果要能比较。
3. **Data pipeline management 数据流水线管理**：知识库更新、embedding 重建、评测集刷新要自动化。
4. **Feature store 特征存储**：在更复杂的推荐/风控/路由系统中，用户与上下文特征要可复用。

你不一定要做完整机器学习平台，但必须有“版本、实验、数据”的治理意识。

## 16.8 完整部署示例：Docker + FastAPI + Monitoring

一个生产级最小架构通常长这样：

```text
                +----------------------+
User/Frontend ->| API Gateway / Auth   |
                +----------+-----------+
                           |
                           v
                +----------------------+
                | FastAPI Agent Service |
                | routing / tools / llm |
                +---+----------+--------+
                    |          |
          +---------+          +------------------+
          v                                   v
   +-------------+                     +---------------+
   | Redis Cache |                     | Vector DB     |
   +-------------+                     +---------------+
                    \                /
                     v              v
                  +--------------------+
                  | Observability      |
                  | OTel + Metrics     |
                  +--------------------+
```

一个合理的发布清单应包括：

| 清单项 | 是否必须 |
|---|---|
| 健康检查 `/healthz` | 必须 |
| 就绪检查 `/readyz` | 必须 |
| 结构化日志 | 必须 |
| trace_id 贯穿链路 | 必须 |
| 每请求 token/cost 统计 | 必须 |
| 降级策略 | 强烈建议 |
| 灰度发布 | 强烈建议 |
| 自动评测 | 强烈建议 |

## 16.9 运行手册（Runbook）与故障处理

很多团队做到监控就停了，但真正的生产治理还差一步：运行手册（runbook，故障处置手册）。当凌晨 2 点告警响起时，值班工程师不能再从头猜系统怎么工作，而要按手册执行。

一个最小 runbook 至少包括：

| 场景 | 立即动作 | 后续动作 |
|---|---|---|
| 模型 API 大面积超时 | 切换备用模型或降级模式 | 统计影响范围，回补失败请求 |
| 向量库不可用 | 关闭检索增强，回退 FAQ 缓存 | 排查索引服务与网络 |
| Redis 故障 | 关闭缓存依赖，保留核心读路径 | 修复后逐步恢复缓存 |
| 工具服务 5xx 激增 | 熔断对应工具 | 检查上游依赖与重试风暴 |
| 成本异常上涨 | 限流高成本接口 | 审查 prompt 变更与路由策略 |

成熟团队还会定义故障等级，例如：

- Sev1：核心功能不可用，10 分钟内响应；
- Sev2：性能显著下降，30 分钟内响应；
- Sev3：边缘功能故障，工作时间内处理。

这类内容非常适合写进面试回答，因为它说明你真正接触过线上系统，而不是只会本地调试。

## 16.10 SLO、SLA 与容量规划

如果没有服务目标，所谓“稳定”就只是主观感觉。建议为 Agent 服务定义 SLO（Service Level Objective，服务级别目标）：

| 指标 | 示例目标 |
|---|---|
| 可用性 | 月度 99.5% |
| P95 延迟 | < 5 秒 |
| 工具调用成功率 | > 97% |
| 任务完成率 | > 90% |
| 高风险请求人工转交率 | 100% 命中策略 |

一旦有了 SLO，就可以反推出容量规划。例如：

- 平均每秒 8 个请求；
- 峰值 40 QPS；
- 每请求平均 2 次模型调用；
- 每次调用平均耗时 1.2 秒；

那么你至少要评估：

1. provider 的并发配额是否够；
2. API 服务的协程数和连接池是否够；
3. Redis、向量库是否能承受峰值压力；
4. 降级方案能否在峰值时及时触发。

很多 Agent 系统“平时没问题，一发活动就崩”，根本原因不是模型不够强，而是没有做容量规划。

## 16.11 CI/CD 细化：从 PR 到上线的自动化流水线

一个成熟的 Agent 项目，CI/CD 不应只是“pytest 通过就部署”。更完整的流水线是：

```text
Pull Request
   |
   +--> Lint / Unit Test
   |
   +--> Integration Test
   |
   +--> Eval Test
   |
   +--> Build Docker Image
   |
   +--> Deploy to Staging
   |
   +--> Smoke Test
   |
   +--> Blue/Green or Canary Release
```

你甚至可以把 prompt 文件、tool schema、模型路由规则都纳入代码审查。因为在 Agent 项目里，影响线上行为的早已不只是 `.py` 文件。

一个实用建议是：为每次发布生成“发布摘要”，其中包括：

- 变更了哪些 prompt；
- 切换了哪个模型；
- 新增/修改了哪些工具；
- 评测分数变化；
- 预估成本变化；
- 是否需要灰度。

这比传统软件单纯写“fix bug”更重要，因为 Agent 行为变化往往来自配置与提示词。

## 16.12 安全与合规最小清单

Agent 系统非常容易跨越数据边界，因此至少应有一个最小安全清单：

1. 请求日志默认脱敏；
2. API Key 不落盘、不写入镜像；
3. 工具执行层按租户和角色做权限控制；
4. 高风险操作必须二次确认；
5. 文件上传做类型、大小、恶意内容检查；
6. 对外部检索结果做来源标记；
7. 保留可审计 trace；
8. 明确数据保留与删除策略。

对于金融、医疗、政务等行业，还要进一步考虑：

- 数据是否允许发送到第三方模型；
- 是否必须本地部署 embedding / reranker；
- 是否需要对回答做人工复核留痕；
- 是否需要审计每次工具调用。

面试里如果你能主动补这一段，通常会与只会谈“部署一个 API”候选人拉开明显差距。

## 16.13 配置管理与环境隔离

部署 Agent 服务时，另一个经常被低估的问题是配置管理。至少要区分：

| 环境 | 配置重点 |
|---|---|
| local | 开发调试、mock 工具、低成本模型 |
| staging | 接近生产的数据与权限模型 |
| production | 真正的密钥、预算、审计开关 |

推荐做法包括：

1. 所有模型名、速率限制、缓存开关、工具超时都配置化；
2. prompt 版本与模型路由规则可单独发布；
3. 不同环境使用不同向量库 collection、不同 Redis namespace；
4. 灰度环境单独记录 metrics，避免与生产混淆。

如果团队未来会支持多个客户或多个业务线，建议进一步引入租户级配置覆盖。例如 A 客户使用本地 reranker，B 客户使用云端 API；A 客户预算更严格，B 客户允许更长上下文。配置治理能力越早设计，后期越省事。

## 16.14 发布检查清单与回滚策略

真正上线前，最好维护一份可执行清单，而不是靠“感觉没问题”：

| 检查项 | 说明 |
|---|---|
| 模型与 API Key 就绪 | 生产密钥、配额、备用模型可用 |
| 向量索引已更新 | 文档版本与索引版本一致 |
| 评测通过 | 黄金样本与回归样本达标 |
| 告警已接入 | 延迟、成本、工具失败率有监控 |
| 回滚路径明确 | 能在 5-10 分钟内切回旧版本 |

回滚策略也应提前演练。常见方式包括：

- 回滚镜像版本；
- 回滚 prompt / tool schema 配置；
- 关闭新工具或新路由规则；
- 将流量切回旧模型或旧服务组。

对 Agent 系统来说，最危险的不是代码错误，而是“行为回归却没人第一时间发现”。因此回滚判断不应只看 500 错误，还应看评测得分、用户投诉率、人工接管率与成本异常。

## 16.15 一套可运行的最小监控栈

如果你要把本章内容真正落地，一个非常实用的最小监控栈是：

| 组件 | 作用 |
|---|---|
| Prometheus | 抓取服务 metrics |
| Grafana | 展示延迟、成本、成功率仪表板 |
| Loki / ELK | 聚合结构化日志 |
| OpenTelemetry Collector | 汇总 trace、metric、log |

推荐优先落地的 8 个面板指标：

1. 请求总量与成功率；
2. P50/P95/P99 延迟；
3. 每模型 token 输入/输出；
4. 每租户成本；
5. 工具成功率与超时率；
6. 缓存命中率；
7. 人工接管率；
8. 安全拦截次数。

如果团队资源有限，不必一次到位，但至少要确保“请求 -> trace_id -> 工具调用 -> 成本 -> 最终结果”这条链路能被查到。否则线上一旦出现“贵、慢、错”三类问题，你几乎无法快速定位。

## 16.16 性能压测与容量演练

Agent 服务上线前，强烈建议做两类演练：压测与故障演练。压测并不是简单地把 QPS 打高，而是要尽量接近真实负载模型。例如：

- 70% 是普通 FAQ；
- 20% 是带检索的复杂问答；
- 10% 是多工具调用或长上下文分析。

这样得到的延迟分布与成本分布，才更接近真实线上。建议记录：

| 指标 | 目标 |
|---|---|
| 峰值 QPS | 预计峰值的 1.5 倍 |
| SSE 首 token 延迟 | < 1.5 秒 |
| P95 总延迟 | < 6 秒 |
| 工具超时率 | < 2% |
| 压测期间错误率 | < 1% |

故障演练则要模拟：

1. 主模型接口超时；
2. 向量库响应变慢；
3. Redis 不可用；
4. 某个关键工具大量失败；
5. 某租户流量突然暴涨。

只有演练过，你才知道降级、熔断、限流和回滚是否真的有效。很多系统平时看起来“架构完整”，但一到峰值流量或上游故障时就会暴露出隐藏问题。

## 16.17 交付物清单：一名合格 Agent 工程师应提交什么

很多人以为“把服务部署起来”就算完成，其实在企业里，交付物至少应包括：

| 交付物 | 内容 |
|---|---|
| 服务代码 | API、工具封装、路由、缓存、降级逻辑 |
| 部署配置 | Dockerfile、Compose、环境变量说明 |
| 监控面板 | 延迟、成本、成功率、告警 |
| 评测集 | 黄金样本、失败样本、回归结果 |
| 运维手册 | 故障等级、回滚步骤、值班联系人 |
| 安全文档 | 权限边界、敏感数据处理、审计说明 |

为什么要强调这点？因为很多面试官真正想判断的是：你能否独立负责一个 Agent 服务的生命周期，而不只是写一个模型调用函数。能把“代码、配置、监控、评测、文档、运行手册”一起交付，才算具备生产责任感。

再进一步说，Agent 工程化的价值不只是把模型包进容器，而是让系统在压力、失败、回滚、审计和预算约束下依然可预测。谁能把“可预测性”做出来，谁就真正完成了从原型开发者到生产工程师的跃迁。

因此，本章所有技术点都可以压缩成一句工程原则：**让 Agent 的行为可观测、可限制、可恢复、可复盘。** 只要系统能做到这四点，即使模型、框架、供应商不断变化，你的工程底盘仍然会很稳。

如果你把本章内容真正落实成作品集，最好同时展示：部署脚本、监控图、评测结果、回滚说明和一次故障演练记录。因为这些材料比单纯一段 API 代码更能证明你具备生产思维。

很多招聘方在筛选候选人时，真正稀缺的不是“会调用模型”的人，而是“知道上线后怎么保命”的人。能把稳定性、成本、安全和回滚讲透，往往就是拿到更高评价的分水岭。

所以如果你只能多练一项能力，我会建议优先练“如何把一个能跑的 Agent 变成一个能值班的 Agent”。前者决定你能否入门，后者决定你能否在团队里独立负责关键系统。

真正的工程竞争力，往往就藏在这些“不显眼”的细节里：日志是否可查、告警是否可信、预算是否可控、回滚是否演练过。把这些细节做扎实，Agent 才不是演示品，而是可以稳定创造业务价值的系统。

也因此，部署章节往往最能区分“会做实验的人”和“能扛线上的人”。前者关注功能是否实现，后者关注系统是否长期可运行、可演进、可交接。对准备转行的人来说，把这部分补齐，常常就是从普通候选人跨到强候选人的关键一步。

而这恰恰也是企业最愿意为你付薪水的部分。

真正稳定的系统，都是靠这些工程细节堆出来的。

没有这些细节，所谓上线往往只是碰运气。

而工程化的目标，就是尽量把运气变成机制。

机制越清晰，系统越可靠。

这就是工程化。

## 16.18 面试答题模板

如果面试官问：“如何把一个 Agent 从 demo 做到生产？”

你可以按下面顺序答：

1. 先服务化：FastAPI + 明确 schema；
2. 再稳定化：超时、重试、熔断、降级；
3. 再容器化：Docker + 多服务依赖；
4. 再可观测：trace、metrics、structured logs；
5. 再控成本：缓存、模型路由、预算控制；
6. 再持续交付：CI/CD、评测、灰度发布；
7. 最后治理：权限、安全、审计、版本管理。

这个回答框架非常贴近真实工程，不容易被追问击穿。

## 本章要点

- Agent 工程化的核心是稳定性、可观测性、成本控制与持续发布，而不是“把调用包成 API”这么简单。
- FastAPI 很适合做 Python Agent 服务，SSE 适合大多数流式问答场景，WebSocket 适合更复杂交互。
- Docker 与 Docker Compose 让 Agent、Redis、向量库等依赖能被一致地交付与复现。
- 监控必须覆盖 LLM 指标与 Agent 指标，日志要结构化，告警要围绕延迟、成本、工具成功率和安全异常。
- 真正成熟的 Agent 团队一定会做缓存、模型路由、评测测试、灰度发布和版本治理。

## 延伸阅读

1. FastAPI 官方文档：重点看依赖注入、异步、StreamingResponse。
2. OpenTelemetry 官方文档：重点看 Python trace 与 metrics。
3. Docker 与 Compose 文档：重点看多服务编排、环境变量与健康检查。
4. 建议亲手完成一个最小生产项目：`FastAPI Agent API + Redis 缓存 + 向量库 + Prometheus/Grafana + Docker Compose`，这是面试中非常有说服力的作品集。
