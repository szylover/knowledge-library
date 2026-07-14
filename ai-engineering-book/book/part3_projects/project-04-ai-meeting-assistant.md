# Project 04 — AI Meeting Assistant

> AI Meeting Assistant 不是录音转文字再总结，而是一条异步、可恢复、可审计的媒体处理流水线：audio ingestion、ASR、speaker diarization、长 transcript 分块摘要、action item 结构化抽取、对象存储与权限治理。

---

## Business Goal

AI Meeting Assistant 的目标是把 meeting intelligence 从 demo 变成可采购、可审计、可扩展的企业能力。

本章默认读者熟悉分布式系统、后端服务和系统设计，不重复解释 HTTP、队列或数据库基础；重点讨论为什么这些 AI-specific 决策会影响质量、成本、延迟和安全。

交叉参考：Part1 Ch01 API 设计、Part2 Ch04 Structured Output、Part2 Ch10 RAG、Part2 Ch11 Memory、Part2 Ch15 Evaluation、Part2 Ch19 Safety。

| 维度 | 选择 | 原因 |
|---|---|---|
| 用户价值 | 可验证输出 | 没有证据链就没有信任 |
| 平台价值 | 租户治理 | 企业采购需要权限、审计、配额 |
| 工程价值 | 可回放链路 | 模型漂移和 prompt 变更必须能定位 |
| 商业价值 | 成本归因 | AI 毛利取决于 token/资源治理 |

### Business driver 1
支持 manual upload 与 Zoom/Teams/Meet webhook 导入。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Product Requirement

- 支持 manual upload 与 Zoom/Teams/Meet webhook 导入。
- 大文件 multipart upload 到对象存储，API 只签发 URL。
- Pipeline 状态细分 uploaded/transcribing/diarizing/summarizing/completed/failed。
- ASR 长音频切片并行，diarization 后对齐 speaker turns。
- Summary/action items 必须引用 transcript segment 和时间戳。
- Action item owner/due_date 不明确时填 null，不允许模型猜。

| 维度 | 选择 | 原因 |
|---|---|---|
| Functional | 核心路径流式/异步可见 | 长耗时 AI 任务不能黑盒等待 |
| Governance | tenant/user/resource 多维配额 | 单一 RPS 无法表达 token 成本 |
| Audit | 记录输入摘要、输出、版本、usage | 定位问题依赖事实链 |
| Reliability | 幂等、重试、阶段状态 | 用户重试不应重复扣费或重复副作用 |

### Requirement detail 1
支持 manual upload 与 Zoom/Teams/Meet webhook 导入。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Architecture

```mermaid
flowchart TB
    UI[Web/Calendar Bot] --> API[Meeting API]
    API --> OBJ[(Object Storage recordings/artifacts)]
    API --> PG[(Postgres meetings/segments/actions)]
    API --> WF[Workflow Queue]
    WF --> PRE[ffmpeg preprocess]
    PRE --> ASR[ASR Worker]
    ASR --> DIA[Diarization Worker]
    DIA --> SEG[Transcript Segmenter]
    SEG --> SUM[Hierarchical Summarizer]
    SUM --> EXT[Action Extractor]
    EXT --> PUB[Publisher Slack/Jira/Email]
    SUM --> MG[Model Gateway]
```

架构上要把用户 API、模型/工具网关、持久化、异步任务和观测面拆开。这样做不是微服务崇拜，而是把不同失败域隔离：用户连接可能断，模型可能 429，索引可能滞后，worker 可能重试，但产品事实必须可恢复。

| 维度 | 选择 | 原因 |
|---|---|---|
| API boundary | 稳定契约 | 屏蔽模型和内部 workflow 变化 |
| Gateway | 集中治理 | 路由、重试、降级、成本记录统一 |
| State store | 事实源 | 审计和重放不能依赖缓存 |
| Workers | 削峰填谷 | 长任务不占用交互请求线程 |

### Architecture decision 1
支持 manual upload 与 Zoom/Teams/Meet webhook 导入。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Directory Structure

```text
ai-meeting-assistant/
  apps/meeting_api/routers/uploads.py
  apps/workers/asr_worker.py
  packages/audio/chunking.py
  packages/diarization/speaker_mapping.py
  packages/summarization/hierarchical.py
  packages/security/retention.py
  tests/unit/
  tests/integration/
  tests/evals/
```

目录边界要反映运行时边界：API 层不直接调用供应商 SDK，worker 不绕过 repository，安全策略不散落在 prompt 字符串里。

### Module boundary 1
`apps/meeting_api/routers/uploads.py` 应只承担单一职责，并通过 schema 与其他模块交互。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Tech Stack

| 维度 | 选择 | 原因 |
|---|---|---|
| Workflow | Temporal/Celery | 长任务阶段可恢复 |
| Object | S3-compatible | 录音和中间 artifact |
| Audio | ffmpeg | 标准化采样率、声道、切片 |
| ASR | Whisper/Deepgram | 自托管与 SaaS 权衡 |
| DB | Postgres | segments、actions、权限 |

选型原则是可替换、可观测、可降级。AI 项目上线后最常见的重构，是把最初写死的供应商 SDK、prompt、索引和成本逻辑抽成独立层。

### Stack trade-off 1
Workflow 使用 Temporal/Celery：长任务阶段可恢复。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Prompt Design

Prompt 是版本化软件资产。它影响输出分布、延迟、成本、安全边界和评测结果，不能作为匿名字符串散落在 handler 里。

```python
from typing import Literal
from pydantic import BaseModel, Field
class Evidence(BaseModel):
    segment_id: str
    start_ms: int
    end_ms: int
    quote: str

class ActionItem(BaseModel):
    description: str
    owner: str | None = None
    due_date: str | None = None
    status: Literal["proposed", "confirmed"] = "proposed"
    confidence: Literal["low", "medium", "high"]
    evidence: list[Evidence]
```

| 维度 | 选择 | 原因 |
|---|---|---|
| 版本化 | 每次语义变更新版本 | 支持回滚和评测 |
| 稳定前缀 | system/developer 放前面 | 利用 prompt caching |
| 强 schema | 结构化输出用 Pydantic 校验 | 失败可重试/降级 |
| 安全边界 | 外部内容标记为 data | 降低 prompt injection 风险 |

### Prompt rule 1
支持 manual upload 与 Zoom/Teams/Meet webhook 导入。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Agent Workflow

```mermaid
stateDiagram-v2
    [*] --> Uploaded
    Uploaded --> Preprocessing
    Preprocessing --> Transcribing
    Transcribing --> Diarizing
    Diarizing --> Segmenting
    Segmenting --> ChunkSummarizing
    ChunkSummarizing --> Reducing
    Reducing --> ExtractingActions
    ExtractingActions --> Publishing
    Publishing --> Completed
    Transcribing --> Failed
    Failed --> RetryScheduled
```

Workflow 的价值是让状态、重试、超时和人工介入点显式化。简单链路可以不用重型 agent 框架，但一旦存在工具调用、长任务或副作用，就需要状态机。

```python
from typing import TypedDict
from langgraph.graph import StateGraph, END

class State(TypedDict):
    tenant_id: str
    trace_id: str
    status: str
    budget: dict

async def guard_budget(state: State) -> State:
    if state['budget'].get('remaining', 0) <= 0:
        state['status'] = 'blocked'
    return state

g = StateGraph(State)
g.add_node('guard_budget', guard_budget)
g.set_entry_point('guard_budget')
g.add_edge('guard_budget', END)
workflow = g.compile()
```

### Workflow invariant 1
支持 manual upload 与 Zoom/Teams/Meet webhook 导入。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## RAG Design

会议 RAG 分两层：meeting-local grounding 与 cross-meeting retrieval。摘要引用 segment_id/start_ms/end_ms；跨会议搜索索引 transcript chunks、summary、decision、action item，并按 meeting ACL filter。

```mermaid
flowchart TD
    Q[User intent] --> PLAN[Query/context planner]
    PLAN --> RET[Retrieval with tenant/ACL filter]
    RET --> RANK[Rerank/trim]
    RANK --> PACK[Context packing]
    PACK --> LLM[Generation]
    LLM --> VER[Verification/citation]
```

| 维度 | 选择 | 原因 |
|---|---|---|
| 召回 | dense + sparse + metadata | 单一路径会漏掉长尾 |
| 排序 | rerank top-N | 控制成本同时提高 precision |
| 预算 | context packing | 避免检索内容挤爆主任务 |
| 安全 | ACL before retrieval | 权限不是生成后处理 |

### RAG concern 1
会议 RAG 分两层：meeting-local grounding 与 cross-meeting retrieval。摘要引用 segment_id/start_ms/end_ms；跨会议搜索索引 transcript chunks、summary、decision、action item，并按 meeting ACL filter。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Database

```sql
CREATE TABLE transcript_segments (
    id UUID PRIMARY KEY, tenant_id UUID NOT NULL, meeting_id UUID NOT NULL, segment_index INT NOT NULL,
    speaker_label TEXT, speaker_user_id UUID, start_ms INT NOT NULL, end_ms INT NOT NULL,
    text TEXT NOT NULL, asr_confidence NUMERIC(5,4), diarization_confidence NUMERIC(5,4)
);
CREATE INDEX idx_segments_time ON transcript_segments(tenant_id, meeting_id, start_ms);
CREATE TABLE action_items (
    id UUID PRIMARY KEY, tenant_id UUID NOT NULL, meeting_id UUID NOT NULL, description TEXT NOT NULL,
    owner_user_id UUID, owner_text TEXT, due_date DATE, status TEXT NOT NULL, confidence TEXT NOT NULL,
    evidence JSONB NOT NULL, external_system TEXT, external_id TEXT
);
```

数据库保存的是产品事实和审计事实，向量库、搜索索引、缓存都应被视为可重建派生物。所有主表都必须包含 tenant_id，并在 repository 层强制过滤。

| 维度 | 选择 | 原因 |
|---|---|---|
| 事实源 | Postgres | 事务、审计、恢复 |
| 派生索引 | Vector/Search | 可重建，不承载唯一事实 |
| 幂等 | unique key/ledger | 防重复扣费和重复副作用 |
| Retention | 分区/TTL job | 满足企业合规 |

### Data invariant 1
支持 manual upload 与 Zoom/Teams/Meet webhook 导入。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## API

API 要把 AI 任务建模为可观测资源，而不是一次普通函数调用。长耗时路径使用 SSE 或异步 task；所有响应带 trace_id、version 和 usage/diagnostics。

```python
class CreateUploadRequest(BaseModel):
    title: str
    source: str = "manual_upload"
    content_type: str
    size_bytes: int

@router.post("/v1/meetings/{meeting_id}/complete-upload")
async def complete_upload(meeting_id: str, request: Request):
    meeting = await meeting_repo.get_for_update(request.state.principal.tenant_id, meeting_id)
    await object_store.assert_exists(meeting.recording_object_key)
    await workflow_client.start("meeting-pipeline", meeting_id, id=f"meeting-{meeting_id}")
    return {"meeting_id": meeting_id, "status": "processing", "current_stage": "preprocessing"}
```

| 维度 | 选择 | 原因 |
|---|---|---|
| 幂等 | Idempotency-Key | 用户重试不重复副作用 |
| 错误 | 稳定 error code | 不泄露供应商内部错误 |
| 流式 | delta/usage/error/done | 客户端可靠收尾 |
| 版本 | prompt/model/schema | 可回滚和 A/B |

### API contract 1
支持 manual upload 与 Zoom/Teams/Meet webhook 导入。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: production-service
spec:
  replicas: 6
  template:
    spec:
      containers:
        - name: app
          image: registry.example.com/service:2026.07.03
          env:
            - name: OTEL_SERVICE_NAME
              value: service
          resources:
            requests: { cpu: "500m", memory: "1Gi" }
            limits: { cpu: "2", memory: "4Gi" }
```

- 交互 API 与长任务 worker 分开扩缩容。
- 灰度按 tenant/user hash 切流，保留旧 prompt/model 版本。
- readiness probe 检查 DB、cache、关键下游；liveness 不做昂贵依赖检查。
- 发布时先 shadow traffic，再小流量 canary，最后全量。

### Deployment rule 1
支持 manual upload 与 Zoom/Teams/Meet webhook 导入。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Monitoring

| 维度 | 选择 | 原因 |
|---|---|---|
| Latency | ttft_ms / stage_duration / total_ms | 用户体验与瓶颈定位 |
| Reliability | error_rate / retry_count / timeout | 供应商和 worker 健康 |
| Cost | tokens / audio_minutes / sandbox_seconds | 毛利与预算控制 |
| Quality | feedback / eval_score / regeneration | 模型或 prompt 回归 |
| Safety | policy_block / acl_denied / dlp_hit | 安全治理 |

OpenTelemetry span 必须携带 tenant_id、trace_id、model/prompt/index/workflow version，但不能携带完整敏感内容。

### Alert 1
P95 延迟突增时先查输入规模、供应商健康和缓存命中。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Cost

- 成本由 audio minutes、ASR/diarization、LLM transcript tokens、存储共同驱动。
- 静音裁剪能直接降低 ASR 和 diarization 成本。
- 长会议用 hierarchical summarization，避免一次塞入完整 transcript。
- 录音和 artifact 用 lifecycle policy，摘要可保留更久。

| 维度 | 选择 | 原因 |
|---|---|---|
| 预算前置 | 请求前估算资源 | 防止生成后才发现超支 |
| 分层路由 | 按任务价值选择模型/资源 | 最大成本杠杆 |
| 缓存 | 缓存稳定前缀或检索结果 | 注意权限和新鲜度 |
| 归因 | usage ledger | 没有归因就没有优化 |

### Cost lever 1
成本由 audio minutes、ASR/diarization、LLM transcript tokens、存储共同驱动。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Scaling

- 水平扩展不能只看 CPU；AI 系统常由长连接、外部限流、GPU/worker 队列或 token throughput 限制。
- 超级租户要单独 shard 或 dedicated pool，避免影响长尾租户。
- 所有派生索引都要支持版本化和后台重建。
- 热路径做 bounded work；昂贵压缩、重建、发布放入异步 worker。

| 维度 | 选择 | 原因 |
|---|---|---|
| 小规模 | 共享集群 | 降低复杂度 |
| 中规模 | tenant shard + queue isolation | 限制 blast radius |
| 大规模 | dedicated pool + regional routing | 满足合规和容量 |
| 极端峰值 | 降级/排队/预算保护 | 保护核心链路 |

### Scaling pattern 1
支持 manual upload 与 Zoom/Teams/Meet webhook 导入。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Security

- 录音前 consent 记录，按地区和 tenant policy 配置。
- Meeting ACL 来自 organizer、participants、calendar visibility 与分享策略。
- Signed audio URL 短 TTL，服务端每次签发前校验权限。
- 日志不写完整 transcript；推送外部系统前做 DLP。

| 维度 | 选择 | 原因 |
|---|---|---|
| Identity | tenant/user/group/service principal | 所有资源访问的根 |
| Authorization | RBAC/ABAC before action | 权限不能只靠 UI |
| Data | encryption + retention + redaction | 企业合规基础 |
| Execution | sandbox/tool allowlist | prompt 不是安全边界 |
| Audit | append-only events | 事故复盘和合规证明 |

### Security control 1
录音前 consent 记录，按地区和 tenant policy 配置。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Future Improvements

- Eval-driven routing：用离线集和线上反馈决定模型/策略。
- Tenant-specific policy：把合规、预算、数据驻留做成可配置控制面。
- Verifier layer：对关键输出做引用、schema、权限和事实校验。
- Adaptive context：根据任务和预算动态选择上下文，而不是固定 top-k。
- Human-in-the-loop：高风险操作进入审批流。
- Private deployment：高合规客户提供 VPC、专用 key、专用索引。

### Improvement 1
Eval-driven routing：用离线集和线上反馈决定模型/策略。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Lessons Learned

- 生产级 AI 项目首先是治理系统，其次才是模型调用。
- 版本号、trace、usage、tenant 是定位线上问题的最小集合。
- 不要把权限、成本和安全留到生成后处理；它们必须进入检索和执行前置路径。
- 质量优化必须有评测集，否则只是在 prompt 上做无证据调参。
- AI 系统的失败常是部分成功：partial output、partial index、partial tool result 都要建模。
- 能回滚的设计比一次性完美设计更重要。

### Lesson 1
生产级 AI 项目首先是治理系统，其次才是模型调用。

工程判断：该点必须以 tenant、trace_id、版本号和预算为输入，而不是写死在业务分支里。

失败模式：忽略该点不会立刻崩溃，但会在规模化后表现为质量漂移、权限事故、成本失控或不可解释的长尾延迟。

## Key Takeaways

- AI Meeting Assistant 的生产形态是 API 契约、状态机、权限、观测、成本和模型能力的组合。
- 把模型输出当不可信外部依赖处理：校验、审计、限流、回滚。
- 从第一天记录版本和 usage；这些字段后补成本极高。

---

## Further Reading

- Part1 Ch01 API 设计、Part2 Ch04 Structured Output、Part2 Ch10 RAG、Part2 Ch11 Memory、Part2 Ch15 Evaluation、Part2 Ch19 Safety
- Part1 Ch01：长耗时、流式和异步 API 契约。
- Part2 Ch15：用评测驱动 prompt、模型和检索变更。
- Part2 Ch19：不可信输入、prompt injection、权限和数据安全。
