# 第六章：Embedding 与向量数据库

如果说大语言模型负责“生成”，那么 Embedding（嵌入）负责“理解相似性”。几乎所有像样的 AI Agent 系统，只要涉及知识库、检索、记忆、推荐、去重、聚类、日志语义分析，最后都会落到 embedding 和向量数据库（Vector Database）上。很多转行者对这一章内容感到陌生，不是因为概念难，而是因为它处在传统软件工程和机器学习之间：既有数学，又有存储系统，又有性能调优。

本章的目标是把这条链路完整讲清：**文本怎么变成向量、向量怎么比较、索引怎么加速、数据库怎么选型、检索系统怎么落地**。如果你能吃透这一章，面试里关于 RAG、知识库、语义搜索、长期记忆的题目会轻松很多。

---

## 6.1 什么是 Embedding：一个软件工程师可接受的解释

Embedding 的本质是：**把离散对象映射到连续向量空间，让“语义相近”在几何空间里也相近**。

你可以把传统数据库检索和 embedding 检索做个类比：

| 方式 | 输入 | 匹配依据 | 优点 | 缺点 |
|------|------|----------|------|------|
| 关键词检索 | 文本 | 字符串或倒排索引 | 精确、快 | 不理解语义 |
| Embedding 检索 | 文本/图片/代码 | 向量相似度 | 语义好 | 需要索引和模型 |

举个例子，以下三句话：

1. “订单支付失败”
2. “付款没有成功”
3. “我的信用卡扣款被拒绝”

关键词角度，这三句重合不多；但 embedding 模型会把它们映射到相近区域，因为语义上都和“支付失败”有关。

---

## 6.2 从文本到向量空间：模型到底做了什么

Embedding 模型通常是经过专门训练的 Transformer 编码器或双塔结构。输入一段文本后，模型输出一个固定长度向量，比如 768、1024、1536、3072 维。

### 6.2.1 一个直觉图

```text
"Redis 连接池耗尽"
        │
        ▼
[Tokenizer]
        │
        ▼
[Embedding Model]
        │
        ▼
[0.12, -0.87, 0.44, ..., 0.03]   # 1024 维向量
```

当你把很多文本都投影进去后，语义相近的文本在空间里更靠近。注意这里的“靠近”不是二维平面，而是高维空间。

### 6.2.2 为什么 embedding 能表达语义

模型在训练时通常会优化“相似文本更近、不相似文本更远”的目标。例如：

- 查询：“如何重置用户密码”
- 正样本：“忘记密码后，用户可通过邮箱验证码重置密码”
- 负样本：“如何查看订单物流”

通过大规模对比学习（contrastive learning），模型学会了把“重置密码”相关文本聚在一起。

---

## 6.3 常见 Embedding 模型对比（2026）

下面这张表是工程选型时很实用的一张速查表。MTEB（Massive Text Embedding Benchmark）成绩这里采用常见公开检索或平均表现区间，主要用于横向感觉，不要把 0.5 分差距神化。

| Model | Dimensions | Max Tokens | Performance (MTEB) | Cost |
|------|------------|------------|--------------------|------|
| text-embedding-3-large | 3072 | 8191 | 检索表现强，英文平均约 64+ | \$0.13 / 1M tokens |
| Cohere embed-v4 | 1024 | 512-4K（视接口） | 多语言检索强，常见约 65-66 | \$0.10 / 1M tokens |
| BGE-M3 | 1024 | 8192 | 开源多语言强，中文场景表现好 | 开源免费，自托管算力成本 |
| Jina Embeddings v3 | 1024 | 8192 | 性价比高，长文本友好，约 65+ | \$0.02 / 1M tokens 或自托管 |

如何选：

1. **想省事**：OpenAI / Cohere 这类托管 API 上手快。
2. **中文和多语言优先**：BGE-M3、Jina v3、Qwen Embedding 系列通常更有竞争力。
3. **要私有化**：优先开源模型。
4. **长文档多**：看 max tokens，不然你前处理会很痛苦。

---

## 6.4 相似度度量：Cosine、Dot Product、Euclidean

向量有了，下一步就是比较“谁更像谁”。最常见的三种度量：

### 6.4.1 Cosine Similarity（余弦相似度）

公式：

`cos(a, b) = (a · b) / (||a|| ||b||)`

它比较的是方向而非长度，所以在文本检索中最常见。只要两个向量朝向相近，即便长度不同，也会被认为相似。

### 6.4.2 Dot Product（点积）

公式：

`a · b = Σ(a_i * b_i)`

点积既受方向影响，也受长度影响。如果 embedding 模型训练时就是按内积优化，点积通常效果很好。

### 6.4.3 Euclidean Distance（欧氏距离）

公式：

`||a - b||_2`

它表达“空间距离有多远”。在某些聚类或近邻场景中仍有用，但在文本语义检索里，余弦和点积更常见。

### 6.4.4 Python 示例：手算三种相似度

```python
from __future__ import annotations

import numpy as np

a = np.array([0.2, 0.8, -0.1, 0.5], dtype=np.float32)
b = np.array([0.1, 0.75, -0.05, 0.55], dtype=np.float32)
c = np.array([-0.6, 0.1, 0.7, -0.2], dtype=np.float32)


def cosine(x: np.ndarray, y: np.ndarray) -> float:
    return float(np.dot(x, y) / (np.linalg.norm(x) * np.linalg.norm(y)))


def dot_product(x: np.ndarray, y: np.ndarray) -> float:
    return float(np.dot(x, y))


def euclidean(x: np.ndarray, y: np.ndarray) -> float:
    return float(np.linalg.norm(x - y))


for name, x, y in [("a vs b", a, b), ("a vs c", a, c)]:
    print(name)
    print("cosine   =", cosine(x, y))
    print("dot      =", dot_product(x, y))
    print("euclidean=", euclidean(x, y))
    print("-" * 30)
```

在大多数 RAG 实战里，如果你看到“向量要先归一化”，通常就是为了让点积近似等价于余弦相似度。

---

## 6.5 向量数据库生态全景

向量数据库不是“有个 API 就能查最近邻”这么简单。它背后涉及索引、分片、过滤、持久化、多租户、混合检索和成本控制。

| Database | Type | Scalability | Special Features | Pricing |
|----------|------|-------------|------------------|---------|
| Pinecone | 托管云服务 | 十亿级 | 免运维、Hybrid Search、Namespace | 免费层 + 按量计费 |
| Weaviate | 开源 + 云 | 亿级到十亿级 | GraphQL、对象关联、混合检索 | 自托管免费，云版按资源 |
| Milvus | 开源 + 云 | 十亿级 | 多索引、高吞吐、企业级扩展 | 自托管免费，云版较高 |
| Qdrant | 开源 + 云 | 亿级 | Payload 过滤强、Rust 实现、量化支持 | 自托管免费，云版按节点 |
| Chroma | 嵌入式/轻服务 | 中小规模 | 上手简单、原型开发快 | OSS 免费 |
| FAISS | 本地库 | 单机百万到千万 | 速度快、研究友好 | 免费 |
| LanceDB | 嵌入式/分析型 | 中小到中大型 | 列式存储、适合多模态 | OSS 免费 |
| pgvector | PostgreSQL 扩展 | 单机千万级 | 与关系数据共存、SQL 友好 | 包含在 PG 成本内 |

### 6.5.1 怎么选

一个实用决策树：

- 只做原型、本地实验：**FAISS / Chroma**
- 已有 PostgreSQL，希望最少引入新组件：**pgvector**
- 需要托管、快速上线：**Pinecone / Weaviate Cloud / Qdrant Cloud**
- 强调开源可控和复杂过滤：**Qdrant / Weaviate / Milvus**

很多团队的真实路径是：

1. 第 1 周用 Chroma 验证效果  
2. 第 1 个月切 pgvector 或 Qdrant  
3. 规模上来后评估 Milvus / Pinecone / Weaviate  

---

## 6.6 向量索引算法：为什么能加速近似搜索

如果你有 1000 条向量，暴力遍历就够了；但如果你有 1 亿条，每次都全量算相似度会非常贵。于是就有 ANN（Approximate Nearest Neighbor，近似最近邻）索引。

### 6.6.1 Brute Force（暴力搜索）

```text
query
  │
  ├─ compare with vec1
  ├─ compare with vec2
  ├─ compare with vec3
  └─ ...
```

优点：准确率 100%。  
缺点：数据量大时慢。

### 6.6.2 IVF（Inverted File Index）

先把向量分成多个簇，查询时只搜索最可能相关的几个簇。

```text
全部向量
   │
   ├─ cluster A
   ├─ cluster B
   ├─ cluster C
   └─ cluster D

query -> 先找最近的簇 -> 只在部分簇内搜索
```

适合大规模数据，但需要调 `nlist`、`nprobe` 等参数，在速度和召回率之间平衡。

### 6.6.3 HNSW（Hierarchical Navigable Small World）

HNSW 是近几年非常流行的图索引。核心思路是构建多层小世界图，查询时像“导航”一样逐步逼近最近邻。

```text
Layer 3:   o ---- o
            \    /
Layer 2:   o -- o -- o
           |    |    |
Layer 1: o -- o -- o -- o -- o
```

特点：

- 查询快
- 召回率高
- 内存占用相对大

Qdrant、pgvector、FAISS 等都支持 HNSW 变体。

### 6.6.4 PQ（Product Quantization）

PQ（乘积量化）把高维向量拆成多个子空间，每个子空间用码本压缩。优点是节省内存、适合超大规模；缺点是会损失精度，调优复杂。

### 6.6.5 一个简单对比

| 算法 | 速度 | 召回率 | 内存占用 | 适用场景 |
|------|------|--------|----------|----------|
| Brute Force | 慢 | 最高 | 高 | 小数据集、评测基线 |
| IVF | 中到快 | 中到高 | 中 | 大规模向量 |
| HNSW | 快 | 高 | 中到高 | 在线检索主流选择 |
| PQ | 快 | 中 | 低 | 超大规模、内存敏感 |

---

## 6.7 从零构建一个语义搜索系统

下面我们做一个完整但尽量简单的系统：读取文档、生成 embedding、建立 FAISS 索引、接受查询并返回相似文本。

### 6.7.1 安装依赖

```bash
pip install sentence-transformers faiss-cpu numpy
```

### 6.7.2 完整代码

```python
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import List

import faiss
import numpy as np
from sentence_transformers import SentenceTransformer


@dataclass
class Document:
    doc_id: str
    text: str
    source: str


docs: List[Document] = [
    Document("1", "Redis 连接池耗尽会导致请求超时和重试风暴。", "ops.md"),
    Document("2", "使用指数退避可以降低下游故障时的重试压力。", "ops.md"),
    Document("3", "RAG 系统的 chunk 大小会影响召回率与上下文噪声。", "rag.md"),
    Document("4", "HNSW 适合在线向量检索，速度快且召回率较高。", "vector.md"),
]


model = SentenceTransformer("BAAI/bge-m3")

texts = [doc.text for doc in docs]
embeddings = model.encode(texts, normalize_embeddings=True)
embeddings = np.asarray(embeddings, dtype="float32")

dimension = embeddings.shape[1]
index = faiss.IndexFlatIP(dimension)  # 使用内积，配合归一化等价于 cosine
index.add(embeddings)


def search(query: str, top_k: int = 3) -> list[dict]:
    q = model.encode([query], normalize_embeddings=True)
    q = np.asarray(q, dtype="float32")
    scores, indices = index.search(q, top_k)

    results = []
    for score, idx in zip(scores[0], indices[0]):
        doc = docs[idx]
        results.append(
            {
                "doc_id": doc.doc_id,
                "score": float(score),
                "source": doc.source,
                "text": doc.text,
            }
        )
    return results


if __name__ == "__main__":
    for item in search("如何降低超时重试带来的系统压力？", top_k=2):
        print(item)
```

### 6.7.3 这段代码做对了什么

1. 使用同一个 embedding 模型编码文档和查询  
2. 做了向量归一化  
3. 用内积索引近似 cosine similarity  
4. 保留了 metadata（`source`）以便后续过滤和展示  

### 6.7.4 实际生产还需要什么

- 文档持久化
- 增量更新
- 删除和版本控制
- 多租户隔离
- metadata filter
- rerank
- 评估集

这就是为什么“只会调用向量库 SDK”还不算真正掌握这一章内容。

---

## 6.8 用 Chroma 做一个更像应用的版本

如果你不想自己管理索引，Chroma 是一个很好的入门工具。

```bash
pip install chromadb sentence-transformers
```

```python
from __future__ import annotations

import chromadb
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction

client = chromadb.PersistentClient(path="./chroma_demo")
embedding_fn = SentenceTransformerEmbeddingFunction(model_name="BAAI/bge-m3")

collection = client.get_or_create_collection(
    name="knowledge_base",
    embedding_function=embedding_fn,
)

collection.upsert(
    ids=["1", "2", "3"],
    documents=[
        "Prompt injection 是 Agent 系统的重要安全风险。",
        "Parent-child retrieval 适合保留文档层级结构。",
        "KV Cache 可以显著降低长对话生成成本。",
    ],
    metadatas=[
        {"topic": "security"},
        {"topic": "rag"},
        {"topic": "llm"},
    ],
)

result = collection.query(
    query_texts=["如何防御提示注入攻击？"],
    n_results=2,
    where={"topic": "security"},
)

print(result)
```

这种方式的优势是：

- API 简单
- 默认带持久化
- 适合小型知识库原型

但如果文档量、并发和过滤复杂度上来，Chroma 往往不是最终形态。

---

## 6.9 性能调优：真正影响检索质量的不是“库名”

很多团队会争论“Pinecone 和 Qdrant 谁更强”，但对中小规模系统来说，真正决定效果的往往不是数据库名字，而是下面这些参数。

### 6.9.1 Chunk 策略

即使这一章还没进入 RAG，也必须先理解：你存进去的不是“全文”，而是切块后的文本。切得太大：

- 单块语义太杂
- 召回不精确
- 成本高

切得太小：

- 上下文碎片化
- 关键条件被拆散
- 回答容易断章取义

经验上，面向中文技术文档：

- FAQ：150-300 tokens
- API 文档：300-500 tokens
- 代码片段：按函数/类边界切，优先结构化而非固定长度

### 6.9.2 索引选择

| 数据规模 | 推荐索引 |
|----------|----------|
| 1 万以内 | Brute Force / Flat |
| 1 万 - 100 万 | HNSW |
| 100 万以上 | IVF + PQ / 分片 HNSW |

不要过早优化。很多团队只有 5 万条文档，却上来就堆复杂 ANN 配置，最后调试时间比收益还大。

### 6.9.3 Metadata Filtering

过滤条件往往比向量相似度还重要。例如：

- 只检索当前租户
- 只检索 `language=zh`
- 只检索最近 30 天日志
- 只检索 `product=payment`

如果没有 metadata filter，你的“语义搜索”很可能只是噪声制造机。

### 6.9.4 召回与延迟的权衡

在一个内部知识库实验中（50 万 chunk，HNSW，1024 维向量），常见现象可能是：

| TopK | Recall@10 | 平均检索延迟 |
|------|-----------|--------------|
| 5 | 0.71 | 18ms |
| 10 | 0.82 | 24ms |
| 20 | 0.88 | 37ms |
| 50 | 0.91 | 72ms |

结论往往不是“越多越好”，而是先召回 20 条，再 rerank 前 5-10 条。

---

## 6.10 面试与实战：你应该能说清什么

如果面试官问你“embedding 和向量数据库怎么设计”，一个成熟回答至少应覆盖：

1. 业务对象是什么：FAQ、日志、代码、邮件还是多模态内容？
2. 向量模型怎么选：中文、多语言、成本、私有化要求
3. 向量维度与相似度度量
4. 索引类型：HNSW、IVF、PQ 的适用边界
5. metadata 过滤如何做
6. 如何评估：Recall@K、人工标注集、误召回分析
7. 如何与 RAG 结合：chunk、rerank、缓存、版本控制

真正的工程能力，不在于你会背多少名词，而在于你能解释：**为什么这套设计适合当前数据规模、延迟目标和预算。**

---

## 6.11 数据入库、增量更新与去重

很多教程到“向量搜出来了”就停了，但真实生产系统往往先死在入库链路上。因为知识库不是静态文件夹，而是持续变化的数据源：文档会更新、FAQ 会修改、代码会重构、工单会关闭。你必须回答四个问题：

1. 文档更新后，何时重新切块？  
2. 旧版本 chunk 如何失效？  
3. 重复内容如何去重？  
4. 不同租户如何隔离？  

一个比较稳的入库流水线通常是：

```text
原始文档
  -> 抽取正文
  -> 清洗噪声
  -> 按规则切块
  -> 计算 chunk hash
  -> 命中去重则跳过
  -> 生成 embedding
  -> 写入向量索引 + metadata
  -> 记录 version / updated_at
```

### 6.11.1 为什么 chunk hash 很重要

如果一份 200 页 PDF 只改了一个段落，你没必要把所有 chunk 都重新 embedding。实际工程里很常见的优化是：

- 对每个 chunk 文本计算 hash
- 新 hash 不存在时才调用 embedding 模型
- 文档级别再维护一份 manifest，记录 chunk 列表

对于高频更新的知识库，这会直接决定月度成本。

### 6.11.2 逻辑删除优于物理删除

很多系统会先给旧 chunk 打 `is_active=false` 或切换 `version`，异步清理底层索引。这样做的原因是：

- 在线删除大批量向量会影响查询性能
- 回滚更容易
- 审计和复盘更方便

---

## 6.12 代码、日志和结构化数据并不等于普通文本

向量检索最容易被误解的一点是：大家总拿自然语言段落做示例，但企业系统里经常检索的其实是代码、日志、报错、工单和数据库记录。

### 6.12.1 代码 Embedding

代码检索至少要注意三点：

1. 尽量按函数、类、文件边界切块  
2. 把路径、符号名、语言类型放进 metadata  
3. 代码与注释是否混合编码，要根据场景决定  

如果你把一个 800 行文件粗暴按固定 500 tokens 切开，检索效果通常会非常差。因为函数签名、实现和注释会被切散，模型看到的是碎片而不是结构。

### 6.12.2 日志检索更适合 Hybrid

日志里的强信号通常是：

- 错误码
- 服务名
- trace id
- 接口路径
- 时间范围

这些特征对 sparse retrieval 非常友好，对纯 dense 检索则未必。因此日志知识库、运维诊断、告警问答系统，几乎总是更适合 hybrid retrieval，而不是纯向量。

### 6.12.3 结构化数据的伪文本化

对工单、CRM 记录、数据库行数据，一个常见技巧是把字段展开成模板文本：

```text
ticket_id=T-1023; product=payment; severity=high;
summary=用户重复扣费；resolution=退款并修复幂等键校验
```

这样能快速接入统一检索接口，但不要忘记：结构化过滤仍应走 metadata 或 SQL。否则你会把本可以精确过滤的问题，错误地交给相似度去猜。

---

## 6.13 多租户、冷热分层与缓存

一旦服务多个业务线或多个客户，向量系统的挑战就不只是“搜得准”，还包括“资源管得住、数据不串租户”。

### 6.13.1 多租户

必须有强制 `tenant_id` 过滤，最好做到：

- 写入时记录租户
- 查询时默认注入租户 filter
- 回归测试里加入跨租户攻击样本

### 6.13.2 冷热分层

热门数据可以放在高性能 HNSW 索引中，冷数据放压缩索引或低成本节点。很多企业知识库里，80% 查询都落在 20% 文档上，冷热分层可以显著节省成本。

### 6.13.3 查询缓存

query embedding、检索结果甚至 rerank 结果都可以缓存，但必须带上：

- embedding 模型版本
- 索引版本
- 过滤条件摘要

否则系统一升级，就会出现“缓存命中但答案来自旧索引”的隐性错误。

---

## 6.14 评估集、误召回分析与线上回放

向量检索的一个典型问题是：系统总体看着“还行”，但某些高价值问题永远搜不对。解决它不能只盯着平均指标，还要做误召回分析。

### 6.14.1 建立问句-标准答案-标准文档三元组

最小评测集建议至少包含：

- query：用户真实提问
- positive_docs：应该被召回的文档或 chunk
- hard_negatives：容易混淆但不该被召回的文档

有了这套数据，你才能真正衡量：

- Recall@K 是否够高
- 哪些 query 依赖 sparse 信号
- 哪些 query 需要 query rewrite

### 6.14.2 误召回常见类型

1. **主题相关但答案不在其中**：例如支付问题召回了退款文档  
2. **关键词命中但语义错位**：例如“超时”召回了完全不同服务的超时说明  
3. **跨租户或跨产品线污染**：metadata filter 缺失  
4. **版本错误**：召回了已废弃文档  

把错误按类型归类后，你才知道应该去改模型、改切块还是改过滤器。

### 6.14.3 线上回放为什么重要

离线评测集无法覆盖所有真实提问。一个很实用的方法是：

- 记录线上匿名化 query
- 抽样回放到测试环境
- 对比新旧 embedding 模型或新旧索引配置

这样做能在升级前发现很多“平均分没变，但关键业务变差”的问题。

---

## 6.15 一个简化的 metadata 设计示例

下面是一个对技术知识库比较实用的 metadata 结构：

```json
{
  "chunk_id": "kb-2026-001-003",
  "document_id": "kb-2026-001",
  "tenant_id": "tenant-a",
  "source_type": "markdown",
  "language": "zh",
  "product": "payment",
  "title_path": "支付系统 > 故障处理 > 超时",
  "version": 3,
  "is_active": true,
  "updated_at": "2026-06-12T09:00:00Z"
}
```

这个结构的价值在于：

- 检索前可以先按租户、语言、产品线过滤
- 展示答案时可以直接显示标题路径
- 回溯问题时可以定位到具体版本

很多“向量检索效果差”的系统，问题不是相似度，而是 metadata 根本设计得不够完整。

---

## 6.16 什么时候不该上向量数据库

向量数据库很火，但不是所有问题都应该用它。以下场景优先考虑传统方案：

1. 数据量很小，几百条 FAQ，关键词检索已足够  
2. 查询条件高度结构化，例如“查 2026 年 6 月华东区退款订单”  
3. 业务必须绝对精确匹配编号、SKU、身份证号、合同号  

这时，SQL、Elasticsearch、BM25 或规则引擎往往更合适。一个成熟工程师不是“看到文本就上 embedding”，而是知道什么时候该用向量，什么时候不该用。

### 6.16.1 一个实用混合策略

很多优秀系统最终都会采用：

- 结构化过滤：数据库 / 搜索引擎
- 精确关键词召回：BM25
- 语义扩展召回：embedding
- 最终融合：rerank 或业务规则

这也是为什么向量数据库常常不是替代搜索，而是补充搜索。

### 6.16.2 一个非常现实的成本判断

如果你的数据只有几千条，而每月查询量也只有几千次，那么托管向量数据库的工程复杂度和费用，很可能不如直接：

- PostgreSQL + pgvector
- SQLite + 本地 FAISS
- Elasticsearch + 少量 embedding 扩展

技术选型最怕“为了先进而先进”。对面试官来说，知道什么时候不上复杂系统，往往比会背更多名词更有说服力。

### 6.16.3 向量库上线前的检查清单

1. 是否有稳定的数据入库任务  
2. 是否有 metadata 过滤方案  
3. 是否能支持文档删除与版本回滚  
4. 是否有离线评测集  
5. 是否能观测查询延迟和召回质量  

只要这五项里有两三项答不上来，说明系统大概率还停留在 demo 阶段。

### 6.16.4 一个团队协作层面的建议

向量检索往往横跨算法、后端、数据平台和业务团队，因此非常容易出现“谁都改了一点，但没人负责整体质量”的情况。比较好的做法是：

- 由平台层统一 embedding 模型和索引规范
- 由业务团队维护文档质量和 metadata 标签
- 由评测负责人维护 query 集和误召回样本

这样，系统才能从“某个工程师的个人实验”演进成真正可维护的检索基础设施。
同时，这也能避免最常见的扯皮：算法怪数据差，业务怪检索差，平台怪调用方式不规范。职责边界一旦清晰，优化效率会高很多。
对转行面试来说，这类“跨团队协作如何落地”的回答也很加分，因为它说明你理解的不是玩具 demo，而是企业级系统。
再补一句实战经验：当系统进入百万级 chunk 规模后，真正决定幸福感的往往不是检索 API，而是入库监控、版本管理、评测回放和元数据治理。
这部分工作做不好，模型再强也很难稳定。
工程细节，最终决定上线成败。
别忽视这些脏活累活。
它们最值钱。
别小看基础设施。
真的。
很关键。

## 本章要点

1. Embedding 是把文本映射到向量空间，使语义相似性可计算。
2. 文本检索里最常见的相似度度量是 cosine similarity 和 dot product。
3. 向量数据库的核心价值不只是存向量，而是提供可扩展索引、过滤、持久化和查询能力。
4. HNSW 是在线检索的主流 ANN 方案，IVF/PQ 更适合超大规模场景。
5. 模型选型要综合考虑语言覆盖、维度、长度限制、成本和部署方式。
6. 构建语义搜索系统并不复杂，但做成生产系统需要处理增量更新、过滤、评估和性能调优。
7. 在很多项目里，chunk 策略和 metadata 过滤比“选哪家向量库”更影响效果。

## 延伸阅读

1. FAISS 官方文档：理解 Flat、IVF、PQ、HNSW 的真实 API 和参数。
2. Qdrant、Weaviate、Milvus 官方文档：重点看 filter、payload、hybrid search。
3. MTEB Leaderboard：不要只看总分，要看与你任务相近的子榜单。
4. BGE-M3、Jina Embeddings、Cohere Embeddings 官方说明：理解多语言与长文本支持差异。
5. 练习建议：选一组自己的技术博客或项目文档，分别用 FAISS、Chroma、pgvector 做三版语义搜索，对比开发复杂度和效果。
