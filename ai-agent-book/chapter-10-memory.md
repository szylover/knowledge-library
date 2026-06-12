# 第十章：记忆系统

如果说工具系统决定 Agent 能“做什么”，那么记忆系统（memory system）决定 Agent 能“记住什么、忘掉什么、如何在未来再次利用过去”。很多初学者把“把历史消息原样拼回 prompt”理解成记忆，但这只是最原始的 conversation buffer。真正的生产级记忆系统要处理上下文窗口限制、多会话连续性、个性化、经验沉淀、检索效率和隐私治理。

本章我们从认知科学式分类讲到工程落地，再实现一套多层记忆系统。

## 10.1 为什么 Agent 需要记忆

没有记忆的 Agent，只能活在当前轮输入里。它会遇到至少三个问题：

1. **上下文窗口限制**：即使模型支持 128k token，也不是无限的，长对话很快爆掉。
2. **多会话断裂**：用户上午说过的偏好，下午新会话就忘了。
3. **无法从经验中学习**：上次某个 API 总是 403，本次仍会重复踩坑。

在企业里，这三个问题会直接变成成本问题：

- 每轮都重新喂上下文，token 成本增加 2~10 倍；
- 用户体验割裂，感觉系统“不像助理，像金鱼”；
- 相同错误不断复现，自动化收益被吞噬。

## 10.2 记忆分类（Memory Taxonomy）

### 10.2.1 Sensory Memory（感觉记忆）

感觉记忆是最短暂的一层，类似原始输入缓冲区。它保存：

- 用户最新消息；
- 工具刚返回的原始结果；
- 实时事件流片段。

它的生命周期可能只有几百毫秒到几秒。工程上常体现为：

- WebSocket 消息缓存；
- 当前请求对象；
- 还没经过摘要的原始网页内容。

### 10.2.2 Short-term / Working Memory（短期/工作记忆）

工作记忆是 Agent Loop 的主战场。它保存：

- 当前会话的最近若干轮消息；
- scratchpad（草稿区）；
- 当前任务计划；
- 本轮工具调用历史；
- 中间推理产物摘要。

这是最常见、也最容易做差的一层。因为如果什么都放进去，很快会膨胀；如果压缩过度，又会丢任务关键状态。

### 10.2.3 Long-term Memory（长期记忆）

长期记忆跨会话存在，可进一步分三类。

#### Episodic Memory（情景记忆）

记录“发生过什么”：

- 用户 2026-06-01 问过 LangGraph 与 CrewAI 差异；
- 上次修复某部署脚本用了代理；
- 某次对话里用户明确要求答复风格简洁。

#### Semantic Memory（语义记忆）

记录“事实是什么”：

- 用户当前所在团队是增长平台主管；
- 公司内部 API 基础地址；
- 某术语定义与约定。

#### Procedural Memory（程序性记忆）

记录“怎么做”：

- 查询订单先调 `get_user` 再调 `list_orders`；
- 提交 PR 前先跑 `pytest -q`；
- 当网页抓取 403 时改用内部镜像。

从面试角度看，这三类长期记忆的区别非常重要。很多候选人只会说“向量数据库存历史对话”，但说不清“经验”和“事实”的存储形态差异。

## 10.3 记忆实现技术

### 10.3.1 Conversation Buffer Memory

最简单的方法：把消息按顺序放列表。

```python
history = [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
]
```

优点：

- 实现成本最低；
- 对短对话效果好；
- 调试直观。

缺点：

- 长对话 token 爆炸；
- 无法跨会话；
- 无检索能力。

### 10.3.2 Conversation Summary Memory

当历史太长时，把旧消息摘要成一段压缩文本。例如 40 轮对话压成 400~800 token：

```text
摘要：用户正在准备 AI Agent 面试，重点关注多 Agent 协作、MCP、工具设计。之前已讨论过 RAG 和向量数据库。用户偏好：回答尽量结构化、包含代码示例。
```

这种做法的本质是：**用信息密度换 token 空间**。

### 10.3.3 Sliding Window Memory

滑动窗口（sliding window）保留最近 N 轮，如最近 8 轮或最近 4000 token。旧内容不一定删除，而是移到摘要层或长期存储层。

这是最常见的生产策略，因为它简单且效果稳定。

### 10.3.4 Vector Store Memory

向量存储（vector store）用于语义召回。把历史片段 embedding 后，按相似度检索与当前问题最相关的过去记忆。

典型流程：

1. 将记忆文本切块；
2. 生成 embedding；
3. 存入向量数据库；
4. 新查询到来时 embedding；
5. top-k 检索相关记忆；
6. 把召回结果注入 prompt。

适合：

- 跨会话召回；
- 海量知识片段；
- 个性化偏好记忆；
- 历史案例检索。

### 10.3.5 Entity Memory（实体记忆）

实体记忆专门跟踪对话中出现的人、组织、产品、项目、变量等实体。

例如一段会话里：

- 用户：我在做项目 Atlas，负责人是 Alice，数据库用 PostgreSQL。

实体记忆可抽取为：

| 实体 | 类型 | 属性 |
|---|---|---|
| Atlas | Project | owner=Alice |
| Alice | Person | role=负责人 |
| PostgreSQL | Tech | used_by=Atlas |

后续用户只说“那个项目部署到哪了”，Agent 就能解析“那个项目”大概率指 Atlas。

### 10.3.6 Knowledge Graph Memory（知识图谱记忆）

当实体及关系足够复杂，图结构比纯向量更合适。比如：

```text
(User)-[works_on]->(Project Atlas)
(Project Atlas)-[uses]->(PostgreSQL)
(Project Atlas)-[owned_by]->(Alice)
```

图记忆特别适合：

- 企业组织关系；
- 依赖关系追踪；
- 复杂事件链；
- 多实体问答。

## 10.4 上下文窗口管理

记忆系统最大的现实约束是 token budget（token 预算）。

### 10.4.1 Token 计数与预算分配

假设模型上下文窗口 128k token，并不意味着你应该把 128k 全塞满。生产系统通常会预留：

| 区域 | 建议预算 |
|---|---|
| System Prompt | 1k~4k |
| 当前用户输入 | 0.5k~2k |
| 工具 schema | 2k~20k |
| 工作记忆 | 2k~8k |
| 检索记忆 | 1k~6k |
| 输出保留空间 | 1k~4k |

如果你做多工具 Agent，真正给历史对话的空间往往没有想象中大。

### 10.4.2 压缩技术

常见压缩手段：

1. **摘要（summarization）**：把旧对话压缩为关键点；
2. **选择性遗忘（selective forgetting）**：丢弃无关寒暄；
3. **字段抽取**：只保留结构化事实；
4. **结果裁剪**：工具返回只留前 N 条；
5. **分层存储**：热点信息在短期层，冷数据在长期层。

### 10.4.3 基于优先级的上下文选择

不是所有记忆都值得进入当前 prompt。可以按优先级排序：

| 优先级 | 内容 |
|---|---|
| P0 | 当前任务目标、最新错误、当前计划 |
| P1 | 与当前问题强相关的历史事实 |
| P2 | 用户长期偏好 |
| P3 | 较旧的背景信息 |

如果上下文空间不足，先删 P3，再删 P2，而不是随机截断。

## 10.5 生产级记忆架构

推荐三层架构：

```text
                    +-----------------------------+
                    |      Long-term Memory       |
                    | Vector DB + SQL / Graph DB  |
                    | user-scoped / org-scoped    |
                    +-------------^---------------+
                                  |
                                  |
                    +-------------+---------------+
                    |      Medium-term Memory     |
                    | Redis / Postgres            |
                    | session-scoped              |
                    +-------------^---------------+
                                  |
                                  |
                    +-------------+---------------+
                    | Short-term / Working Memory |
                    | in-process, current loop    |
                    +-----------------------------+
```

### 10.5.1 短期层：进程内、会话内

保存当前 loop 与最近对话，读写频繁、延迟要求低，通常直接存内存对象即可。

### 10.5.2 中期层：Redis / Database

保存 session-scoped 状态，例如：

- 当前计划；
- 已完成步骤；
- 当前草稿；
- tool cache；
- 会话摘要。

这层用于：

- Agent 重启恢复；
- 多 worker 协同；
- 长任务 checkpoint。

### 10.5.3 长期层：向量库 + 结构化库

向量库擅长语义召回，结构化库擅长事实与权限。实际生产中往往两者结合：

- 向量库：Chroma、pgvector、Weaviate、Milvus；
- 结构化库：Postgres、SQLite、Neo4j、RedisJSON。

## 10.6 多层记忆系统 Python 实现

下面实现一个简化版多层记忆系统：

- WorkingMemory：保存最近消息；
- SummaryMemory：压缩旧对话；
- VectorMemory：用简单词袋相似度模拟语义检索；
- EntityMemory：保存实体；
- MemoryManager：统一调度。

```python
from __future__ import annotations

import math
import re
from collections import Counter, deque
from dataclasses import dataclass, field
from typing import Deque, Dict, List, Tuple


@dataclass
class Message:
    role: str
    content: str


class WorkingMemory:
    def __init__(self, max_messages: int = 8) -> None:
        self.messages: Deque[Message] = deque(maxlen=max_messages)

    def add(self, role: str, content: str) -> None:
        self.messages.append(Message(role, content))

    def get_messages(self) -> List[Message]:
        return list(self.messages)


class SummaryMemory:
    def __init__(self) -> None:
        self.summary = ""

    def update(self, old_messages: List[Message]) -> None:
        joined = " ".join(m.content for m in old_messages)
        key_sentences = joined[:300]
        if self.summary:
            self.summary += "\n"
        self.summary += f"- 历史摘要: {key_sentences}"


def tokenize(text: str) -> List[str]:
    return re.findall(r"[a-zA-Z_]+|[\u4e00-\u9fff]{2,}", text.lower())


def cosine_similarity(a: Counter, b: Counter) -> float:
    common = set(a) & set(b)
    numerator = sum(a[x] * b[x] for x in common)
    sum1 = sum(v * v for v in a.values())
    sum2 = sum(v * v for v in b.values())
    if sum1 == 0 or sum2 == 0:
        return 0.0
    return numerator / (math.sqrt(sum1) * math.sqrt(sum2))


class VectorMemory:
    def __init__(self) -> None:
        self.items: List[Tuple[str, Counter]] = []

    def add(self, text: str) -> None:
        self.items.append((text, Counter(tokenize(text))))

    def search(self, query: str, top_k: int = 3) -> List[str]:
        q = Counter(tokenize(query))
        scored = [(text, cosine_similarity(q, vec)) for text, vec in self.items]
        scored.sort(key=lambda x: x[1], reverse=True)
        return [text for text, score in scored[:top_k] if score > 0]


class EntityMemory:
    def __init__(self) -> None:
        self.entities: Dict[str, Dict[str, str]] = {}

    def upsert(self, name: str, entity_type: str, **attrs: str) -> None:
        self.entities[name] = {"type": entity_type, **attrs}

    def get(self, name: str) -> Dict[str, str] | None:
        return self.entities.get(name)


@dataclass
class MemoryManager:
    working: WorkingMemory = field(default_factory=lambda: WorkingMemory(max_messages=6))
    summary: SummaryMemory = field(default_factory=SummaryMemory)
    vector: VectorMemory = field(default_factory=VectorMemory)
    entity: EntityMemory = field(default_factory=EntityMemory)

    def add_message(self, role: str, content: str) -> None:
        if len(self.working.get_messages()) == self.working.messages.maxlen:
            old = self.working.get_messages()[:2]
            self.summary.update(old)
        self.working.add(role, content)
        self.vector.add(content)

    def remember_entity(self, name: str, entity_type: str, **attrs: str) -> None:
        self.entity.upsert(name, entity_type, **attrs)

    def build_context(self, query: str) -> str:
        recent = "\n".join(f"{m.role}: {m.content}" for m in self.working.get_messages())
        retrieved = "\n".join(self.vector.search(query))
        entities = "\n".join(f"{k}: {v}" for k, v in self.entity.entities.items())
        return f"""
[Summary]
{self.summary.summary}

[Recent Messages]
{recent}

[Retrieved Memories]
{retrieved}

[Entities]
{entities}
""".strip()


if __name__ == "__main__":
    mm = MemoryManager()
    mm.add_message("user", "我在准备 AI Agent 面试，重点是多智能体与 MCP。")
    mm.add_message("assistant", "好的，我们先从 Agent 架构开始。")
    mm.add_message("user", "我当前项目叫 Atlas，负责人是 Alice，数据库是 PostgreSQL。")
    mm.remember_entity("Atlas", "project", owner="Alice", database="PostgreSQL")
    mm.add_message("assistant", "已记录 Atlas 项目背景。")
    mm.add_message("user", "之后请多给我代码示例。")
    mm.add_message("assistant", "收到，会尽量提供可运行代码。")

    context = mm.build_context("Atlas 项目使用什么数据库？")
    print(context)
```

### 10.6.1 这个实现还缺什么

距离生产环境，还缺：

- 真正的 tokenizer 计数；
- 真 embedding 模型；
- 向量数据库持久化；
- 权限与隐私过滤；
- TTL（过期时间）；
- 记忆重要度评分；
- 基于反馈的 procedural memory 更新。

## 10.7 记忆写入策略：不是所有东西都值得存

一个常见反模式是“所有对话全量入库”。结果是：

- 存储膨胀；
- 检索噪声增加；
- 隐私风险上升；
- 召回质量下降。

应当只存这些高价值信息：

| 值得存 | 不值得存 |
|---|---|
| 用户长期偏好 | 日常寒暄 |
| 可复用事实 | 一次性上下文 |
| 成功/失败经验 | 无信息量的客套话 |
| 关键实体关系 | 大段原始网页正文 |

可以给每条候选记忆打分：

`score = relevance * reuse_probability * durability`

当分数超过阈值才写长期层。

## 10.8 生产问题：隐私、删除、版本化

记忆系统一上线，立刻会遇到治理问题：

1. **用户要求删除记忆怎么办？**
2. **错误记忆如何修正？**
3. **组织级知识与用户级偏好如何隔离？**
4. **同一个事实新旧冲突时用哪个版本？**

推荐做法：

- 每条长期记忆带 `scope`、`source`、`created_at`、`updated_at`、`confidence`；
- 允许 soft delete；
- 重要记忆可版本化；
- 检索时做权限过滤。

## 10.9 面试答题模板

如果面试官问：“你会如何设计一个支持跨会话个性化的 Agent 记忆系统？”

可以按这套结构回答：

1. 短期层保存当前会话工作记忆；
2. 中期层保存 session state，支持恢复与 checkpoint；
3. 长期层分 episodic / semantic / procedural；
4. 使用向量检索 + 结构化过滤；
5. 加 token budgeting 和摘要压缩；
6. 写入前做价值评分，避免噪声；
7. 做权限、删除、版本治理。

这样的回答比“我会用 Redis + 向量数据库”更完整，因为它体现了数据模型与使用策略。

## 10.10 检索排序：什么记忆应该先被召回

记忆检索不是“相似度越高越好”。生产系统里，至少还要考虑时间、可信度、权限、重要性四个维度。一个实用打分公式可以写成：

`final_score = 0.45 * semantic_similarity + 0.2 * recency + 0.2 * importance + 0.15 * confidence`

这里：

- `semantic_similarity`：当前问题与记忆内容的语义相似度；
- `recency`：新近程度，通常可以做时间衰减；
- `importance`：写入时打的权重，比如“长期偏好”通常高于“临时任务背景”；
- `confidence`：事实可信度，来自来源质量或人工确认。

举个例子，用户今天问：“继续上次 Atlas 项目的数据库迁移方案。”  
系统可能检索到两条候选记忆：

1. 一周前的记录：Atlas 使用 PostgreSQL，负责人 Alice；
2. 一小时前的记录：用户当前更关心迁移窗口与回滚方案。

从语义上看，两条都相关；但若当前问题偏“继续上次讨论”，第二条应优先进入上下文。也就是说，记忆系统的关键不是存储，而是**排序策略**。

## 10.11 记忆写入、更新与遗忘

长期记忆如果只会增加，不会修正和遗忘，几个月后一定变脏。一个成熟系统通常会对每条记忆维护这些字段：

| 字段 | 说明 |
|---|---|
| memory_type | episodic / semantic / procedural |
| scope | user / session / org |
| confidence | 可信度 |
| source | 来自对话、工具、人工确认还是导入数据 |
| ttl | 是否有过期时间 |
| supersedes | 是否替代旧记忆 |

例如用户曾说“我主要写 Java”，三个月后又说“最近转 Python 为主”。这并不是简单新增，而应该：

- 将旧偏好降权；
- 新偏好写成更高优先级；
- 在冲突解析时优先使用新版本。

遗忘策略也很重要。常见做法包括：

1. **时间遗忘**：临时性上下文 7 天后自动过期；
2. **价值遗忘**：低重要度、低命中率记忆定期清理；
3. **冲突遗忘**：被新事实替代的旧事实进入 archived 状态；
4. **隐私删除**：用户要求删除时，连索引与缓存一起移除。

很多团队只实现“写入”，没有实现“修正”和“删除”，最后记忆系统会逐渐成为幻觉来源。

## 10.12 记忆系统的生产检查清单

上线前建议用下面这张表做自查：

| 问题 | 说明 |
|---|---|
| 有没有 token 预算器 | 防止无上限拼上下文 |
| 有没有写入门槛 | 避免垃圾记忆污染长期层 |
| 能否跨会话检索 | 支持连续体验 |
| 是否有权限过滤 | 不同用户不能召回彼此私有记忆 |
| 是否支持删除/更正 | 满足治理和隐私要求 |
| 是否记录来源 | 方便审计与冲突处理 |
| 是否有摘要与滑窗策略 | 避免短期层膨胀 |

从工程实现上，推荐把记忆系统拆成四个接口，而不是一团代码：

1. `write_memory(candidate)`：负责筛选和写入；
2. `retrieve_memory(query, budget)`：负责召回和排序；
3. `compress_context(messages, budget)`：负责压缩；
4. `forget_memory(policy)`：负责清理和过期。

这样做的好处，是你可以独立替换向量库、摘要模型、排序器，而不影响上层 Agent Loop。

## 10.13 一个典型故障案例

假设客服 Agent 记住了“用户喜欢英文回复”。这是三个月前写入的偏好；但最近三次会话里，用户都明确要求中文。若系统仍机械召回旧偏好，就会出现“记忆正确、行为错误”的情况。

这说明记忆系统不仅要问“有没有这条记忆”，还要问：

- 这条记忆是不是还有效？
- 有没有更新的冲突证据？
- 当前任务是否真的需要它？

所以，好的记忆系统从来不是“更大的数据库”，而是“更严格的选择机制”。

## 10.14 一个生产级记忆流水线

把记忆系统拆成流水线会更容易实现和调试。一个典型流程如下：

1. **ingest**：收到用户消息、工具输出或任务结果；
2. **classify**：判断它更像 episodic、semantic 还是 procedural；
3. **score**：计算重要度、可复用性、敏感度；
4. **store**：写入对应层级，附带 scope、source、ttl；
5. **index**：生成 embedding、实体索引或图关系；
6. **retrieve**：按当前 query 与预算召回；
7. **compress**：根据 token 上限压缩；
8. **inject**：把最终选中的上下文送回模型。

如果你把这些步骤混在一个函数里，很快就会失控；但一旦流水线化，就能分别优化。例如：

- 想提升召回质量，就改 `retrieve`；
- 想降低成本，就改 `compress`；
- 想减少脏数据，就改 `score` 和 `store`。

## 10.15 面试中的一个加分点：记忆不是数据库，而是决策系统

很多候选人会说“我会把对话存进向量数据库”。这句话不算错，但层次不够。更好的表达是：

> 记忆系统本质上是一个决策系统，它决定哪些信息值得持久化、哪些信息应该被忘记、哪些信息在当前时刻值得进入上下文。

这句话为什么加分？因为它体现了三个工程意识：

1. **写入有成本**：存得越多不一定越好；
2. **召回有噪声**：检索到不相关信息会伤害模型表现；
3. **上下文有预算**：进入 prompt 的每个 token 都要有价值。

如果面试官继续追问，你还可以补一句：在高价值场景下，我会把长期记忆拆成“事实层”和“证据层”，避免模型只看到结论却看不到来源。

## 10.16 三类最常见的记忆错误

### 一、记错

模型把“可能如此”写成“确实如此”，把猜测当事实沉淀。解决办法是记录 `confidence` 和 `source`，并限制低可信内容写入长期层。

### 二、记太多

无差别入库会让检索噪声迅速累积。解决办法是增加写入阈值，并定期清理低命中率、低重要度记忆。

### 三、取错

明明存了正确事实，但召回排序把无关内容排到前面。解决办法是混合排序：相似度只是一个因素，还要看时间、scope、重要性和权限。

记忆系统做得好的团队，通常都非常重视这三类错误的监控。

## 10.17 一个跨会话助理的记忆设计案例

假设你在做“面试辅导 Agent”。用户第一天告诉你：

- 目标岗位是 AI Agent 工程师；
- 当前薄弱点是系统设计；
- 希望回答尽量结构化；
- 已经掌握 Python、后端开发和数据库。

到了第三天，用户再问：“继续昨天的系统设计题，今天多讲讲协议层。”  
这时一个设计良好的记忆系统会这样工作：

1. 从长期语义记忆中取回用户画像：岗位目标、偏好、已有基础；
2. 从情景记忆中找到“昨天讨论的是多 Agent 平台设计”；
3. 从工作记忆中保留最近几轮上下文；
4. 根据今天的话题“协议层”检索与 MCP、A2A 相关的历史讲解；
5. 重新组装成本轮上下文。

如果没有这套分层机制，系统要么完全忘记昨天讲过什么，要么把前三天所有对话全塞进 prompt，既贵又乱。

这个案例说明，记忆系统真正创造的是**连续性体验**。用户感受到的不是“数据库命中了”，而是“这个 Agent 真的记得我在学什么、卡在哪里、上次讲到哪一步了”。

## 10.18 写入策略中的一个关键问题：谁有资格成为长期记忆

不是每条信息都值得跨会话保存。一个实用规则是，只把满足以下条件的内容写入长期层：

- 未来高概率复用；
- 至少在当前会话之外仍然有效；
- 对用户体验或任务完成有明显帮助；
- 不包含不必要的敏感原文。

比如“用户偏好简洁回答”值得存，“今天心情不错”通常不值得存；“项目 Atlas 使用 PostgreSQL”值得存，“刚刚贴过一段报错堆栈全文”通常更适合放临时层。

当你开始按“是否值得长期存在”来筛选时，记忆系统才真正从存储逻辑变成产品逻辑。

## 10.19 一个简短但重要的结论

很多团队前期把大量精力花在“选哪家向量数据库”，却忽略了真正决定效果的往往是更朴素的问题：写入标准是什么、召回排序怎么做、什么信息必须遗忘、冲突事实如何处理。  
换句话说，记忆系统的难点主要不在存储引擎，而在策略引擎。你当然需要一个可靠的数据库，但如果没有好的写入、召回、压缩和治理策略，再强的数据库也只是在帮你更快地保存噪声。

对于转行求职者来说，这也是一个很好的面试加分点：当别人都在比较 Chroma、pgvector、Milvus 时，你能把话题拉回“哪些内容值得记、何时取、如何纠错”，层次会立刻不一样。
记忆做得好的系统，往往不是记得最多，而是在最关键的时候记得最对。
这也是为什么真正成熟的记忆架构，总会把写入门槛、召回排序、过期策略和冲突修正放在同等重要的位置。
离开这些策略，所谓长期记忆很快就会退化成长期噪声。
再往前走一步，你会发现记忆系统和搜索引擎、推荐系统其实有很多共通点：都在解决信息写入、索引、排序、曝光和反馈修正的问题。只是 Agent 记忆的最终曝光位置不是搜索结果页，而是模型的上下文窗口。因此，谁能更稳地控制“哪些信息进入窗口”，谁就更容易做出稳定、个性化且可持续优化的 Agent。
从这个角度看，记忆系统不仅是模型能力补丁，更是整个 Agent 产品体验的地基。
用户是否愿意长期使用一个 Agent，很多时候就取决于它记忆的准不准、取回得稳不稳。
而这份“稳”，来自工程上的约束，而不是模型偶然发挥得好。
所以，记忆系统越到后期，越像一套关于信息生命周期的治理方案，而不只是一个检索模块。
谁能治理好生命周期，谁就更可能做出长期可用的 Agent。
这也是记忆工程最终会回到治理、选择和演化上的原因。
本质上，它管理的是信息价值，而不只是信息数量。

## 本章要点

- 记忆系统的目标不是“存更多”，而是“在正确时间取回正确信息”。
- 感觉记忆、工作记忆、长期记忆对应不同生命周期和存储介质。
- 长期记忆可分为情景记忆、语义记忆、程序性记忆，三者用途不同。
- 常用技术包括 buffer、summary、sliding window、vector store、entity memory、knowledge graph。
- 生产系统必须做 token 预算、上下文压缩、优先级选择和权限治理。
- 多层记忆架构通常是：短期 in-process，中期 Redis/DB，长期 vector DB + structured DB。

## 延伸阅读

1. LangChain / LangGraph Memory 相关设计文档
2. Redis 作为 session memory store 的最佳实践
3. pgvector、Weaviate、Milvus 等向量存储文档
4. MemoryBank、Generative Agents 等关于长期记忆的论文
5. Neo4j 与知识图谱在企业 Agent 中的应用案例
