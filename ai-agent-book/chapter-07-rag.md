# 第七章：RAG 检索增强生成

到了这一章，你已经具备了两块关键积木：一是 LLM 的工作原理，二是 embedding 与向量检索。把这两者拼起来，就是 RAG（Retrieval-Augmented Generation，检索增强生成）。在 2026 年，几乎所有“让模型接入企业私有知识”的系统，都离不开 RAG。面试时只要岗位描述里出现下面这些词中的任意两个，RAG 几乎必考：

- knowledge base
- enterprise search
- chatbot
- internal docs
- grounding
- hallucination reduction

但真正能落地的人并不多。因为大多数人停留在“检索几个 chunk 塞进 prompt”这一步，而没有意识到：**RAG 不是一个 API，而是一条数据处理、检索、排序、生成、评估的完整流水线**。

---

## 7.1 为什么需要 RAG：LLM 的三个天然限制

### 7.1.1 知识截止（Knowledge Cutoff）

无论模型多强，它的预训练数据总有时间边界。你问它“本公司上周发布的内部制度更新”，模型天然不知道。RAG 的第一价值，就是给模型补充**新知识**。

### 7.1.2 幻觉（Hallucination）

模型在缺少证据时，仍然倾向于给出“看起来合理”的答案。这对写作场景还勉强能忍，对客服、法务、医疗、运维则可能直接出事故。RAG 的第二价值，是让模型回答时“有证可依”。

### 7.1.3 无法直接访问私有数据

你公司的 Jira、Confluence、PDF 规范、代码仓库、数据库、工单系统，都不在通用模型的预训练集里。RAG 的第三价值，是让模型在不重新训练大模型的前提下访问私域信息。

简化理解：

```text
没有 RAG：模型 = 聪明但靠记忆作答
有 RAG：模型 = 聪明 + 会查资料再作答
```

---

## 7.2 RAG 架构的演进：从 Naive 到 Modular

### 7.2.1 Naive RAG

最基础的 RAG 流程如下：

```text
用户问题
   │
   ▼
Embedding 查询
   │
   ▼
检索 TopK 文档片段
   │
   ▼
拼接到 Prompt
   │
   ▼
LLM 生成答案
```

这就是“retrieve → stuff → generate”。它能用，但很容易遇到三类问题：

1. 检索到不相关片段
2. 片段相关但排序不佳
3. 文档里明明有答案，模型还是答错

### 7.2.2 Advanced RAG

进阶版 RAG 会在检索前后加入更多组件：

- Query Transformation（查询改写）
- Hybrid Search（稠密 + 稀疏混合）
- Reranking（重排序）
- Iterative Retrieval（迭代检索）
- Context Compression（上下文压缩）

一个典型的高级流水线：

```text
用户问题
   │
   ▼
[Query Rewrite]
   │
   ├─ 原始查询
   ├─ 改写查询
   └─ 多查询扩展
   ▼
[Dense + Sparse Retrieval]
   │
   ▼
[Reranker]
   │
   ▼
[Prompt Builder]
   │
   ▼
LLM Answer
```

### 7.2.3 Modular RAG

Modular RAG（模块化 RAG）强调：检索、排序、压缩、回答、评估都应可替换。它非常适合 Agent 平台，因为不同业务线可以共享骨架、替换组件。

例如：

- 法务知识库：更重视精确召回与引用
- 代码问答：更重视结构切块和仓库路径信息
- 客服 FAQ：更重视延迟和低成本

模块化设计的核心思想不是“用更多框架”，而是：**每个组件都可单独评估和升级**。

---

## 7.3 完整 RAG 流水线 ASCII 图

```text
                    ┌──────────────────────┐
                    │  Documents / Data    │
                    │ PDF / HTML / MD /代码 │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Loading & Cleaning   │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Chunking             │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Embedding            │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Vector / BM25 Index  │
                    └──────────┬───────────┘
                               │
      用户问题                 │
         │                     │
         ▼                     │
┌──────────────────────┐       │
│ Query Transform      │───────┘
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Dense / Sparse Search│
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Rerank / Compress    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Prompt Builder       │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ LLM Generate Answer  │
└──────────────────────┘
```

---

## 7.4 文档处理：加载、清洗、切块

RAG 效果一半来自模型，另一半来自文档处理。很多系统召回差，不是 embedding 模型不够强，而是前处理阶段已经把信息切碎了。

### 7.4.1 Loading：数据源不是只有 PDF

常见数据源包括：

- PDF：制度文件、白皮书、投标资料
- HTML：帮助中心、官网、Wiki
- Markdown：技术文档、README、设计文档
- Code Files：`.py`、`.ts`、`.go` 等源码
- Structured Data：CSV、数据库记录、工单、聊天记录

不同类型文档的处理重点不同：

| 数据类型 | 关键挑战 | 建议 |
|----------|----------|------|
| PDF | 版面噪声、换行乱 | OCR 后做段落重建 |
| HTML | 导航栏、脚注、广告 | 只保留正文 DOM |
| Markdown | 标题层级重要 | 保留 heading 路径 |
| 代码 | 结构边界关键 | 按函数、类、文件树切块 |

### 7.4.2 Chunking 为什么是灵魂

切块（Chunking）决定了检索单元。RAG 不是检索整篇文档，而是检索 chunk。chunk 过大，噪声多；过小，信息断裂。

#### 固定长度切块

最简单：每 500 tokens 一块，重叠 50 tokens。优点是实现简单；缺点是经常把一个完整定义切成两半。

#### 递归切块（Recursive Chunking）

按标题、段落、句子、字符逐层退化，尽量保留自然边界。这是技术文档里非常常见的实用方案。

#### 语义切块（Semantic Chunking）

根据句向量或主题变化来决定边界。效果往往更自然，但计算成本更高。

#### Agentic Chunking

让模型参与切块，比如“根据问题回答需要的最小语义单元重组文档”。这适合高价值场景，但成本高，不适合海量基础索引。

### 7.4.3 Chunk 大小与 overlap 的取舍

下面是一组对技术知识库的常见实验结论（示意但贴近真实工程）：

| Chunk Size | Overlap | Recall@5 | Answer Faithfulness | 平均输入成本 |
|------------|---------|----------|---------------------|--------------|
| 128 tokens | 20 | 0.68 | 0.72 | 低 |
| 256 tokens | 30 | 0.79 | 0.81 | 中 |
| 512 tokens | 50 | 0.83 | 0.84 | 中高 |
| 1024 tokens | 80 | 0.84 | 0.76 | 高 |

可以看到：更大的 chunk 不一定更好。因为虽然召回率略增，但上下文噪声也增加，生成阶段更容易“看花眼”。

经验规则：

- FAQ / 短知识：150-300 tokens
- 技术设计文档：300-600 tokens
- 法务/制度文件：500-800 tokens，保留章节标题
- 代码：按函数/类/文件边界，不要强行固定长度

---

## 7.5 Retrieval 策略：Dense、Sparse、Hybrid 与更多变体

### 7.5.1 Dense Retrieval

Dense retrieval（稠密检索）就是 embedding 检索。优点是语义强，缺点是对精确关键词、编号、错误码不够敏感。

适合：

- 用户表达多样
- 同义改写多
- 中文语义问答

### 7.5.2 Sparse Retrieval

Sparse retrieval（稀疏检索）代表方法是 BM25、TF-IDF。它对关键字、精确术语、变量名、报错码特别敏感。

适合：

- 日志检索
- API 名称、报错码定位
- 法律条文编号

### 7.5.3 Hybrid Retrieval

Hybrid retrieval 是生产系统里的主流方案：把 dense 和 sparse 的结果合并。原因非常简单：

- dense 擅长“意思相近”
- sparse 擅长“字面精确”

一个很常见的融合公式：

`score = α * dense_score + (1 - α) * sparse_score`

实际项目里 `α` 常在 `0.5-0.8` 区间调优。

### 7.5.4 Multi-query Retrieval

用户原问题往往表达不稳定。例如：

> “为什么我的订单创建接口有时会超时？”

可以自动扩展成：

- 订单创建接口超时原因
- 数据库写入导致订单超时
- 下游支付服务慢导致订单接口超时

多查询检索常能提高召回，但会增加成本和噪声，所以通常需要 rerank。

### 7.5.5 Parent-child Retrieval

做法是把大文档切成小块建立索引，但返回时附带其“父文档”或更大上下文。它特别适合：

- 长技术设计文档
- 法规条文
- 多级标题文档

你既能用细粒度 chunk 提高召回，又能在回答阶段给模型更完整上下文。

---

## 7.6 Reranking：为什么 TopK 之后还要再排一次

检索系统的一个现实问题是：初步召回的前 20 条里，通常只有 3 到 8 条真正最相关。于是我们引入 reranker（重排序器）。

### 7.6.1 Cross-Encoder Reranker

Cross-encoder 会把“query + candidate chunk”一起送入模型评分。相比双塔 embedding，它计算更贵，但排序更准。

### 7.6.2 常见 reranker 选择

| Reranker | 特点 | 适用场景 |
|----------|------|----------|
| Cohere Rerank | API 易用、英文强 | 快速上线 |
| BGE-Reranker | 开源可自部署，中文不错 | 私有化、中文系统 |
| Jina Reranker | 多语言可选 | 国际化系统 |

### 7.6.3 一个实战经验

对 50 万 chunk 的企业文档库，常见配置是：

1. dense 检索 30 条  
2. sparse 检索 30 条  
3. 合并去重后得到 40-50 条  
4. rerank 前 10 条  
5. 最终送给 LLM 4-6 条  

这通常比“直接送 Top3”更稳，也比“直接送 Top20”更省 token。

---

## 7.7 RAG 评估：不评估，系统就只能靠感觉调

RAG 的难点在于，错误可能发生在多个环节：

- 文档没加载进来
- chunk 切坏了
- 检索没召回
- rerank 排错了
- prompt 没约束好
- 模型看到了正确上下文却答错

因此必须分层评估。

### 7.7.1 Retrieval Metrics

#### Recall@K

正确文档是否出现在前 K 个结果中。最基础、最重要。

#### MRR（Mean Reciprocal Rank）

正确结果排名越靠前，分数越高。适合看排序质量。

#### nDCG

考虑多级相关性，不只是“对/错”，更适合复杂检索评估。

### 7.7.2 Generation Metrics

#### Faithfulness

答案是否忠于给定上下文，而不是自己瞎编。

#### Answer Relevancy

答案是否真正回答了问题，而不是泛泛而谈。

#### Context Precision

提供给模型的上下文中，有多少内容是真正相关的。这个指标能帮助你发现“检索很多，但噪声更大”的问题。

### 7.7.3 RAGAS

RAGAS 是一个很常见的 RAG 评估框架，可以对 retrieval 和 generation 做自动化评测。它不是万能的，但非常适合建立第一版离线评估基线。

工程建议：

- 建立 100-300 条高质量问答评测集
- 每次调整 chunk、embedding、retriever、prompt 后都跑一遍
- 把 Recall@K、Faithfulness、人工胜率一起看

---

## 7.8 常见失败模式与解决方案

### 7.8.1 检索到了不相关文档

典型表现：模型回答有理有据，但完全答偏。

排查顺序：

1. chunk 是否过大或过小  
2. embedding 模型是否不适合该语言/领域  
3. 是否缺少 metadata filter  
4. TopK 是否太大导致噪声多  

### 7.8.2 检索到了正确文档，但答案仍然错

说明错误更可能在生成阶段：

- prompt 没有要求“仅依据上下文”
- 上下文排序不佳
- 没做 rerank
- chunk 太碎，模型无法拼出完整答案

解决思路：

- 加强 grounded prompt
- 引入 reranker
- 做 parent-child retrieval
- 让模型给出引用片段

### 7.8.3 明明有资料，但系统总说找不到

这往往不是模型问题，而是覆盖率问题：

- 文档根本没入库
- OCR 失败
- 代码文件被排除
- 查询改写不够好

解决：

- 加入多源数据
- 做 ingestion 监控
- 对空召回做 fallback（BM25、站内搜索、人工 FAQ）

---

## 7.9 一个完整的 Python 端到端 RAG 示例（LangChain）

下面是一个最小但完整的 RAG 示例：加载 Markdown 文档、切块、embedding、存入 Chroma、检索并回答。

### 7.9.1 安装依赖

```bash
pip install langchain langchain-openai langchain-community chromadb tiktoken
```

### 7.9.2 准备文档

假设 `./docs` 目录下有若干 `.md` 文件。

### 7.9.3 完整代码

```python
from __future__ import annotations

from pathlib import Path

from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.document_loaders import TextLoader
from langchain_community.vectorstores import Chroma
from langchain_openai import ChatOpenAI, OpenAIEmbeddings


DOC_DIR = Path("./docs")


def load_documents():
    docs = []
    for path in DOC_DIR.glob("*.md"):
        loader = TextLoader(str(path), encoding="utf-8")
        docs.extend(loader.load())
    return docs


def build_vectorstore():
    docs = load_documents()
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=500,
        chunk_overlap=80,
        separators=["\n## ", "\n### ", "\n", "。", " ", ""],
    )
    chunks = splitter.split_documents(docs)

    vectorstore = Chroma.from_documents(
        documents=chunks,
        embedding=OpenAIEmbeddings(model="text-embedding-3-large"),
        persist_directory="./rag_chroma",
    )
    return vectorstore


def answer_question(question: str) -> str:
    vectorstore = build_vectorstore()
    retriever = vectorstore.as_retriever(search_kwargs={"k": 4})
    retrieved_docs = retriever.invoke(question)

    context = "\n\n".join(doc.page_content for doc in retrieved_docs)

    llm = ChatOpenAI(model="gpt-4o", temperature=0)
    prompt = f"""
你是一名企业知识库问答助手。
你只能依据给定上下文回答问题。
如果上下文中没有答案，请明确回答“根据当前知识库无法确定”。

上下文：
{context}

问题：
{question}
""".strip()

    resp = llm.invoke(prompt)
    return resp.content


if __name__ == "__main__":
    print(answer_question("系统为什么要使用 KV Cache？"))
```

### 7.9.4 这段代码缺了什么

它能跑，但离生产还很远。你还需要：

- 文档增量更新
- 检索缓存
- rerank
- 引用来源
- 失败重试
- 评估集
- prompt injection 防护
- 监控：空召回率、引用命中率、回答满意度

---

## 7.10 一个更接近生产的 RAG 设计建议

如果你要设计企业级 RAG，建议按下面的结构拆分模块：

| 模块 | 建议职责 |
|------|----------|
| Ingestion Service | 拉取 PDF/HTML/代码/数据库内容并清洗 |
| Chunking Service | 负责分块、标题路径、版本号记录 |
| Embedding Service | 统一 embedding 模型与缓存 |
| Retrieval Service | dense/sparse/hybrid 检索与 metadata filter |
| Rerank Service | 重排候选结果 |
| Prompt Builder | 组装 system prompt、context、citations |
| Answering Service | 调用 LLM 并输出结构化答案 |
| Evaluation Pipeline | 离线评测、A/B 实验、回归检查 |

这套分层的好处在于：你以后换 embedding 模型、换向量库、换 reranker 时，不需要重写整个应用。

---

## 7.11 面试高频问法：如何回答更像工程师

### 问：为什么不能直接把所有文档塞进长上下文？

答法要点：

- 成本高、延迟高
- 上下文噪声会污染答案
- 1M context 并不意味着 1M token 都同样可用
- 检索本质是在做“信息压缩和定位”

### 问：RAG 效果差时你先查什么？

优秀回答：

1. 先区分是 retrieval 问题还是 generation 问题  
2. 看评测集上的 Recall@K  
3. 抽样查看 chunk 和召回结果  
4. 再决定改 embedding、chunking、rerank 还是 prompt  

### 问：Hybrid retrieval 为什么常优于纯向量检索？

因为企业数据里大量关键信息是编号、函数名、报错码、表名、SKU 之类的精确 token，纯 dense 检索对这些信号未必敏感。

---

## 7.12 Query Transformation、引用与线上监控

很多 RAG 新手会直接拿“用户原话”去检索，但真实业务里的问题经常包含口语、省略、缩写和上下文依赖。比如：

> “昨天那个退款接口又慢了，会不会还是 MQ 堆积？”

如果直接检索，这句话里真正有用的关键信号其实很散。于是我们需要 query transformation（查询改写）。

### 7.12.1 常见改写方式

1. Rewrite：把口语改成完整技术问题  
2. Expand：补充同义词、英文术语、缩写全称  
3. Decompose：拆成多个子问题  
4. Normalize：抽取时间、服务名、错误码等结构化条件  

一个更可检索的改写结果可能是：

- 退款接口超时原因
- MQ backlog 导致 refund API latency
- payment-service refund timeout queue congestion

成熟系统通常不会只用改写后的 query，而是“原 query + 改写 query 并行检索，再合并去重”。这样既保留原始关键词，又提高语义覆盖率。

### 7.12.2 为什么引用很重要

企业用户不只想知道答案，还想知道“依据是什么”。因此好的 RAG 回答通常包含：

- 最终答案
- 引用来源
- 关键片段
- 不确定性说明

例如：

```text
答案：支付超时更可能与队列堆积有关。
依据：
1. 《退款服务故障复盘》2026-05-18
2. payment-service dashboard 周报第 3 节
不确定性：若你们已切换到 v2 队列配置，需要进一步核对最新部署单。
```

这不仅降低幻觉风险，也方便用户人工复核。

### 7.12.3 RAG 上线后的核心监控指标

一套最低可用的 RAG 监控面板，建议至少有：

| 指标 | 说明 |
|------|------|
| empty_retrieval_rate | 空召回比例 |
| avg_context_tokens | 平均送入模型的上下文长度 |
| citation_hit_rate | 带有效引用的回答比例 |
| fallback_rate | “无法确定”或转人工比例 |
| index_freshness_lag | 文档更新到索引生效的延迟 |

离线 Recall@K 很高，不代表线上体验就好。因为线上还会受到多轮上下文、文档新鲜度、缓存命中和用户提问风格的影响。

---

## 7.13 Agentic RAG 与多跳检索

简单 RAG 通常只检索一次，但复杂问题常常需要多跳（multi-hop）推理。例如：

> “为什么上海区用户昨天支付失败率上升，而退款成功率没有同步下降？”

这个问题可能需要依次检索：

1. 支付服务告警记录  
2. 上海区流量变更公告  
3. 退款服务错误率报表  
4. 最近一次配置变更单  

Agentic RAG 的含义是：让 Agent 决定是否继续检索、检索哪些子问题、何时停止。它比固定单次检索更强，但也更贵、更难控。所以通常需要：

- 工具调用次数上限
- 检索回路检测
- 每轮检索后的摘要压缩
- 成本与延迟预算

如果你在面试里能把“单次检索 RAG”和“多跳 Agentic RAG”区别清楚，基本就超过了只会搭 demo 的候选人。

---

## 7.14 RAG 安全、权限与数据新鲜度

很多团队以为 RAG 的主要风险是“答错”，实际上企业环境里还有三个更现实的问题：越权、脏数据和过期数据。

### 7.14.1 检索越权

如果你的知识库面向多个角色，例如普通员工、主管、管理员，那么“是否能检索到某段内容”本身就是权限问题。不要指望模型在回答时再自己判断哪些内容不能说，正确做法是：

- 在检索前做 ACL / role filter
- metadata 中明确 `access_level`
- 高敏感内容默认不入通用索引

### 7.14.2 脏数据污染

如果源文档本身过时、矛盾或内容复制粘贴错误，RAG 会把这些问题忠实放大。因此 ingestion 阶段最好有：

- 文档版本字段
- 生效时间和失效时间
- 来源可信度等级
- 重复文档检测

### 7.14.3 数据新鲜度

很多产品投诉“AI 总回答旧流程”，本质不是模型落后，而是索引刷新慢。一个成熟系统会对以下延迟做监控：

1. 文档变更时间到抓取时间  
2. 抓取时间到切块完成时间  
3. 切块完成时间到索引可查询时间  

如果这条链路总延迟是 6 小时，那么你就不能对业务方承诺“分钟级更新”。

---

## 7.15 一套实用的 RAG 调优顺序

RAG 系统效果不好时，很多团队第一反应是换模型。其实更高效的调优顺序通常是：

1. 先检查文档是否真的入库了  
2. 再检查 chunk 是否保留了结构边界  
3. 再看 Recall@K 是否足够  
4. 然后引入 hybrid retrieval  
5. 再尝试 rerank  
6. 最后再调 prompt 和生成模型  

原因很简单：如果召回阶段就把正确证据漏掉了，后面的模型再强也救不回来。

### 7.15.1 一个典型案例

某内部技术知识库最初方案：

- chunk size 1000
- 纯 dense 检索
- 无 rerank
- 直接将 top 8 chunk 塞给模型

问题表现：

- Recall@5 只有 0.63
- 回答常引用不相关段落
- 平均上下文 4200 tokens，成本高

优化后方案：

- chunk size 改为 350 + 50 overlap
- 增加 BM25 混合检索
- 先召回 20 条，再 rerank 取前 5
- 回答时强制引用来源

结果往往会变成：

- Recall@5 提升到 0.81
- Faithfulness 明显改善
- 平均上下文降到 1900 tokens

这类案例最能体现 RAG 是系统工程，而不是单点技巧。

### 7.15.2 什么时候不该用 RAG

不是所有 AI 问答都要上 RAG。以下场景就不一定合适：

1. 纯结构化查询，数据库直接答更准  
2. 实时性极强且数据秒级变化，用 API/工具调用比索引检索更靠谱  
3. 问题高度固定，FAQ 模板和规则引擎已经足够  

RAG 的优势是把“非结构化知识”接入生成系统，而不是替代所有数据访问方式。很多成熟 Agent 实际采用的是“RAG + Tool Use”的混合架构：知识类问题走 RAG，事务类问题走 API，分析类问题再由模型汇总。

### 7.15.3 一个上线前检查清单

在真正把 RAG 发布给用户之前，建议至少确认：

1. 有一套可复现的离线评测集  
2. 空召回时有明确 fallback 策略  
3. 回答能附带引用来源  
4. 高权限文档不会被普通用户检索到  
5. 文档更新到索引生效的延迟可监控  

RAG 最怕的不是“效果一般”，而是你根本不知道它什么时候开始失效。能监控、能回放、能回滚，才叫可运营的 RAG。

### 7.15.4 让产品、算法和后端说同一种语言

RAG 项目很容易失败在协作上：产品说“回答不准”，算法说“召回没问题”，后端说“接口都通了”。为了避免这种各说各话，建议团队统一使用以下三层诊断语言：

1. 检索层：有没有把正确证据找回来  
2. 排序层：找回来的证据是否排在前面  
3. 生成层：模型是否忠于证据作答  

一旦团队能按这三层拆问题，RAG 的迭代速度会明显提升。
进一步说，RAG 项目的成功标准也应该分层定义：如果目标是降低人工客服转接率，就不能只看 Recall@K；还要看最终回答是否真的解决了用户问题，以及引用是否让用户敢于相信答案。
这也是为什么成熟团队会同时维护检索指标、生成指标和业务指标，而不是把所有责任都推给模型排行榜。
对转行面试者来说，如果你能把 RAG 讲成“数据处理 + 检索排序 + 生成约束 + 评估运营”的完整闭环，而不是只会说“向量数据库 + 大模型”，基本就已经具备了明显的竞争优势。
更进一步，如果你还能说出空召回、错误引用、版本过期、权限串漏这些真实故障模式，面试官通常会直接判断你做过真正的 RAG 项目。
而这，正是 AI Agent 岗位和普通“会调接口”岗位之间最关键的差别。
真正难的不是把 demo 跑通，而是让它在真实用户、真实数据和真实组织协作中持续稳定工作。
这才是工程化的核心。
也是企业愿意为你付薪水的原因。
而不是只奖励会写 demo 的人。
长期主义更重要。
确实。

---

## 本章要点

1. RAG 的核心价值是补充新知识、接入私有数据、降低幻觉。
2. Naive RAG 只是起点，生产系统通常需要 query rewrite、hybrid retrieval、rerank 和评估。
3. 文档加载与 chunking 对效果影响极大，很多问题在进入模型前就已经埋下。
4. Dense 检索擅长语义，Sparse 检索擅长精确术语，Hybrid 往往是企业系统的默认选择。
5. Reranker 是把“能召回”变成“能排对”的关键步骤。
6. RAG 必须分层评估：Recall@K、MRR、nDCG、Faithfulness、Context Precision 缺一不可。
7. 诊断 RAG 系统时，首先要区分问题发生在检索阶段还是生成阶段。
8. 真正可维护的 RAG 架构应模块化，让 ingestion、retrieval、rerank、generation、evaluation 各自可替换。

## 延伸阅读

1. LangChain、LlamaIndex 官方文档：重点看 retriever、reranker、evaluation 相关模块。
2. RAGAS 项目文档：理解自动评估指标的适用边界。
3. BM25、HNSW、Cross-Encoder reranker 相关资料：帮助你把“检索”从黑盒变成可调系统。
4. 各大向量数据库的 hybrid search 与 metadata filter 文档：这是企业落地中最容易产生差异的部分。
5. 实战练习：拿一套自己的项目文档，分别做 naive RAG 和 hybrid + rerank 版本，对比 Recall@K、回答准确率和 token 成本。
