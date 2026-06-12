# 第四章：大语言模型基础

如果你是一个后端、前端或者基础架构工程师，第一次接触大语言模型（Large Language Model, LLM）时，最容易踩进两个坑：第一，把它当成“更聪明的搜索引擎”；第二，把它当成“神秘黑盒”，觉得只有机器学习研究员才能理解。实际上，AI Agent 工程师不需要手推全部梯度，也不需要自己从头训练一个 700B 模型，但必须理解模型在**推理时到底做了什么、为什么会犯错、性能瓶颈在哪里、API 成本为什么会爆炸**。这一章的目标，就是用软件工程师熟悉的方式，把 LLM 的底层机制拆开。

你可以把 LLM 想象成一个“极大规模的条件概率程序”：输入一串 token，模型根据上下文预测下一个 token。所有复杂能力——问答、代码生成、规划、摘要、调用工具——本质上都来自这个过程的叠加。区别只在于：模型参数极多、训练数据极大、上下文窗口很长，而且 Transformer（转换器）结构让它能在一次前向传播里并行处理整段上下文。

---

## 4.1 Transformer 到底解决了什么问题

在 Transformer 出现之前，主流序列模型是循环神经网络（Recurrent Neural Network, RNN）和长短期记忆网络（Long Short-Term Memory, LSTM）。它们的问题对软件工程师来说很好理解：**串行依赖太强，无法高效并行，而且长距离依赖会衰减**。一句话里第 3 个词和第 300 个词的关系，RNN 理论上能学，工程上却很难稳定。

Transformer 的核心创新是：**不再按时间步串行传递隐藏状态，而是让每个 token 直接“看”其他 token**。这就是自注意力（Self-Attention）。

### 4.1.1 一个工程视角下的整体结构

下面是一个 GPT 类 Decoder-only（仅解码器）模型的简化结构：

```text
输入文本
   │
   ▼
[Tokenizer]
   │
   ▼
Token IDs
   │
   ▼
[Embedding Lookup] + [Positional Encoding]
   │
   ▼
┌─────────────────────────────────────────────┐
│ Transformer Block × N                       │
│  ┌───────────────────────────────────────┐  │
│  │ Masked Multi-Head Attention           │  │
│  │   ↓                                   │  │
│  │ Add & LayerNorm                       │  │
│  │   ↓                                   │  │
│  │ Feed-Forward Network                  │  │
│  │   ↓                                   │  │
│  │ Add & LayerNorm                       │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
   │
   ▼
[Linear LM Head]
   │
   ▼
下一个 token 的概率分布
```

软件工程里我们喜欢问：“数据结构是什么？”这里最重要的数据结构是矩阵。

- 设序列长度为 `n`
- 模型隐藏维度为 `d_model`
- 输入张量形状通常是 `batch_size x n x d_model`

你可以把整个 Transformer 看成一个高维矩阵变换流水线。理解这一点之后，很多后续问题都会自然很多，比如为什么上下文越长越贵，为什么 KV Cache 有效，为什么批处理（batching）会影响吞吐。

---

## 4.2 Input Embedding 与 Positional Encoding

模型不能直接吃字符串，它先看到的是 token id。每个 token id 会查表变成一个向量，这一步叫输入嵌入（Input Embedding）。

### 4.2.1 Embedding 是什么

假设词表（Vocabulary）大小是 100,000，隐藏维度是 4,096，那么嵌入矩阵就是：

`E ∈ R^(100000 x 4096)`

第 15234 个 token 对应第 15234 行向量。这个向量不是“解释性的规则”，而是训练出来的高维表示。和数据库里的主键查记录很像：token id 是 key，embedding matrix 是大表，lookup 之后得到 dense vector。

### 4.2.2 为什么还要位置编码

如果只有 embedding，模型看到的其实是一堆“无序集合”。“我打你”和“你打我”会包含相同 token，但语义完全不同。所以必须给 token 注入位置信息。

早期 Transformer 用的是正弦位置编码（Sinusoidal Positional Encoding），后来的 GPT 类模型更常用可学习位置编码、RoPE（Rotary Position Embedding，旋转位置编码）等方法。工程上你不必推导公式，但要记住三件事：

1. **位置必须参与注意力计算**，否则模型没有顺序概念。
2. **长上下文能力与位置编码方案直接相关**，这也是很多模型扩展到 128K、200K、1M context 的关键工程点。
3. **位置编码不是外挂功能，而是基础能力**。如果位置表示外推不好，模型在超长上下文时会变笨、定位不准、引用错段落。

---

## 4.3 Self-Attention：真正的核心

### 4.3.1 先说直觉

当模型生成一个 token 时，它会问：**当前这个位置，应该重点参考前面哪些位置？**

例如句子：

> “The database connection was closed because it exceeded the idle timeout.”

当模型处理 `it` 时，它要判断 `it` 指代 `connection` 而不是 `database`。这就是注意力机制擅长的地方：建立远距离依赖。

### 4.3.2 矩阵乘法走一遍

设输入矩阵为：

`X ∈ R^(n x d_model)`

通过三组线性层得到：

- Query（查询）矩阵：`Q = XW_Q`
- Key（键）矩阵：`K = XW_K`
- Value（值）矩阵：`V = XW_V`

其中：

- `W_Q ∈ R^(d_model x d_k)`
- `W_K ∈ R^(d_model x d_k)`
- `W_V ∈ R^(d_model x d_v)`

接下来做最关键的一步：

`Attention(Q, K, V) = softmax(QK^T / sqrt(d_k))V`

对软件工程师，最需要理解的是这个公式的**数据流**：

1. `QK^T`：得到一个 `n x n` 的相关性分数矩阵。
2. `sqrt(d_k)`：做缩放，避免数值过大导致 softmax 过于尖锐。
3. `softmax`：把每一行变成概率分布，表示“当前位置应该关注哪些历史 token”。
4. 再乘 `V`：按注意力权重对信息做加权汇总。

### 4.3.3 一个小型例子

假设序列长度 `n=4`，分别是：

```text
["用户", "提交", "订单", "失败"]
```

经过线性变换后，我们得到一个 `4x4` 的 score 矩阵（这里只是示意，不是训练值）：

```text
         用户   提交   订单   失败
用户     1.2   0.1   0.0   0.0
提交     0.3   1.5   0.8   0.0
订单     0.1   0.9   1.6   0.2
失败     0.0   0.4   1.7   1.3
```

最后一行意味着：当模型处理“失败”时，它最关注“订单”和自己，其次关注“提交”。这非常符合直觉，因为“失败”的语义通常和具体动作对象强相关。

### 4.3.4 为什么上下文长会越来越贵

注意力的核心瓶颈是 `QK^T`，它的复杂度近似是：

`O(n^2 * d)`

这意味着：

- 4K token 到 8K token，长度翻倍，注意力计算量接近 4 倍
- 8K 到 32K，不是“多一点”，而是明显爆炸

这就是为什么长上下文模型虽然好用，但你在生产环境里不能无脑把所有聊天历史全塞进去。

---

## 4.4 Multi-Head Attention：为什么要多头

如果只有一个注意力头（head），模型就像只有一个观察角度。多头注意力（Multi-Head Attention）本质上是：**并行学习多种相关性模式**。

可以把不同 head 粗略理解为：

- 某些 head 更关注语法依赖
- 某些 head 更关注实体引用
- 某些 head 更关注代码缩进、括号匹配、变量名复用
- 某些 head 更关注局部邻近信息

形式上，假设有 `h` 个头：

```text
head_1 = Attention(Q1, K1, V1)
head_2 = Attention(Q2, K2, V2)
...
head_h = Attention(Qh, Kh, Vh)

MultiHead(Q, K, V) = Concat(head_1, ..., head_h)W_O
```

工程意义非常直接：

1. **表达力更强**：不同头可以捕获不同关系。
2. **训练更稳定**：把大问题拆成多个低维子空间。
3. **对代码任务特别有利**：代码不是自然语言那种单一局部依赖，符号、作用域、调用链、注释都可能形成不同模式。

但多头并不是“越多越好”。头数增加会带来更多参数和显存占用。在部署时，你最终关心的是**每秒 token 数（TPS）、首 token 延迟（TTFT）和总成本**。

---

## 4.5 Feed-Forward Network、LayerNorm 与残差连接

注意力层负责“信息交换”，前馈网络（Feed-Forward Network, FFN）负责“信息变换”。

### 4.5.1 FFN 做了什么

经典形式是两层线性层加激活函数：

```text
FFN(x) = W2 * GELU(W1 * x + b1) + b2
```

通常第一层会升维，比如从 4096 提到 11008，再降回 4096。你可以把它想象成一个逐 token 的非线性特征变换器。注意：FFN 不在 token 之间交互，它是对每个位置独立执行的；token 间交互发生在 attention。

### 4.5.2 为什么需要残差连接

残差连接（Residual Connection）就是：

`y = x + F(x)`

这在深层网络里几乎是必备的。对软件工程师来说，可以把它类比为“保留原始信息的旁路通道”。这样即便某一层学得一般，原始信号仍能往后传，梯度也更容易回流。

### 4.5.3 LayerNorm 为什么重要

Layer Normalization（层归一化）会对每个样本的特征做归一化，稳定数值范围。没有它，几十层甚至上百层堆叠后，训练会非常不稳定。它不像 BatchNorm 那样依赖 batch 统计，因此更适合序列模型和变长输入。

实际的 Transformer Block 可以近似理解为：

```text
x = x + Attention(LN(x))
x = x + FFN(LN(x))
```

现代实现细节会有 Pre-LN、Post-LN 差异，但从工程理解角度，上面的心智模型已经足够支撑你做大部分 Agent 系统设计。

---

## 4.6 Decoder-only 与 Encoder-Decoder

很多工程师第一次接触模型架构时会问：为什么 ChatGPT、Claude、Qwen 这类主流对话模型大多是 Decoder-only？那 Encoder-Decoder（编码器-解码器）又去哪了？

### 4.6.1 两类架构的区别

| 架构 | 代表模型 | 适合任务 | 特点 |
|------|----------|----------|------|
| Decoder-only | GPT、Llama、Qwen、DeepSeek | 对话、代码生成、Agent、补全 | 自回归生成强，统一训练目标简单 |
| Encoder-Decoder | T5、BART、Flan-T5 | 翻译、摘要、结构化转换 | 输入编码和输出生成分离，seq2seq 任务自然 |

Decoder-only 的优势在于统一：无论是聊天、写代码还是工具调用，本质都可以转化为“给定上下文，预测下一个 token”。这让训练语料组织和推理接口都更简单，也更适合当前 API 生态。

### 4.6.2 为什么 Agent 更偏爱 Decoder-only

Agent 的核心是“看上下文 → 推理 → 生成动作或回复”。它天然适合自回归流程。比如 ReAct 提示里：

```text
Thought: ...
Action: search_docs
Observation: ...
Thought: ...
Final Answer: ...
```

整个过程都能作为单一序列建模，因此 Decoder-only 模型几乎是 Agent 时代的默认选择。

---

## 4.7 Tokenizer 深入：BPE、SentencePiece、tiktoken

### 4.7.1 为什么 tokenizer 很重要

很多人把 tokenizer 当成边角料，这是典型误区。实际工程里，tokenizer 会直接影响：

- API 成本：按 token 计费
- 上下文利用率：同一句中文和英文 token 数可能差很多
- 截断行为：过长输入会被截掉
- 检索与 chunk 策略：RAG 切块必须按 token 预算设计

### 4.7.2 BPE（Byte Pair Encoding）

BPE（字节对编码）最早来自文本压缩思想：不断合并高频相邻子串。比如：

```text
l o w
l o w e r
n e w e s t
```

经过多轮合并后，可能得到 `low`、`est`、`er` 等子词。优点是词表可控，对未登录词（OOV）更鲁棒。很多代码模型也喜欢 BPE，因为标识符、路径、函数名天然适合拆成子词。

### 4.7.3 SentencePiece

SentencePiece 的重要思想是：**直接对原始文本做子词训练，不强依赖空格分词**。这对中文、日文等无显式空格语言非常友好。它支持 BPE 和 Unigram 等算法，是多语言模型里极常见的 tokenizer 工具。

### 4.7.4 tiktoken

tiktoken 是 OpenAI 常用的高性能 tokenizer 库。实际开发时，如果你调用 OpenAI API，最好用它做预估 token 数，而不是拍脑袋。

### 4.7.5 Python 示例：查看不同 tokenizer 的行为

```python
from __future__ import annotations

sample = "请帮我分析 Python 函数 foo_bar(x=42) 为什么在 GPU 服务器上超时。"

# 1) OpenAI tiktoken
import tiktoken

enc = tiktoken.get_encoding("cl100k_base")
ids = enc.encode(sample)
print("tiktoken token 数:", len(ids))
print(ids[:20])
print([enc.decode([i]) for i in ids[:20]])

# 2) Hugging Face tokenizer（很多开源模型都能这样看）
from transformers import AutoTokenizer

tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-7B-Instruct")
hf_ids = tokenizer.encode(sample, add_special_tokens=False)
print("HF token 数:", len(hf_ids))
print(hf_ids[:20])
print(tokenizer.convert_ids_to_tokens(hf_ids[:20]))
```

如果你在中文 RAG 项目里看到“400 字一块”的经验值，先不要照抄。应该先测：

- 400 中文字符是多少 token？
- 如果夹杂英文代码和日志，会不会变成 700 token？
- 你预留给 system prompt、history、tool output 的 token 预算是多少？

这就是工程化思维。

---

## 4.8 训练流水线：Pre-training、Fine-tuning、RLHF、DPO

### 4.8.1 预训练（Pre-training）

预训练阶段，模型在海量语料上学习“下一个 token 预测”。数据可能包括网页、书籍、代码、论文、问答、论坛。这个阶段学到的是广义世界知识、语言模式、代码模式和基本推理能力。

你可以把预训练理解为：先把一个大脑“灌满统计规律”。

### 4.8.2 微调（Fine-tuning / SFT）

监督微调（Supervised Fine-Tuning, SFT）使用更高质量、带示范答案的数据，让模型学会“像助手一样回答”。例如：

- 用户问问题，模型给结构化答案
- 用户贴代码，模型先分析再修复
- 工具调用时输出 JSON

SFT 的目标不是增加世界知识，而是**让能力更可用、行为更对齐**。

### 4.8.3 RLHF

RLHF（Reinforcement Learning from Human Feedback，基于人类反馈的强化学习）通常分三步：

1. 让标注员比较多个回答哪个好
2. 训练奖励模型（Reward Model）
3. 用 PPO 等算法优化主模型

它的价值在于：把“人更喜欢什么样的回答”编码进模型。但 RLHF 成本高、稳定性差、工程链路长。

### 4.8.4 DPO

DPO（Direct Preference Optimization，直接偏好优化）是近几年非常实用的替代方案。它不再显式训练奖励模型再跑 RL，而是直接用“偏好对”（chosen vs rejected）优化模型。对很多团队来说，DPO 更简单、更稳定、更容易落地。

### 4.8.5 训练阶段的工程心智图

```text
海量原始语料
   │
   ▼
Pre-training
   │  学到语言/知识/代码模式
   ▼
SFT / Fine-tuning
   │  学到助手风格、输出格式、任务习惯
   ▼
Preference Alignment
   ├─ RLHF：奖励模型 + 强化学习
   └─ DPO：直接偏好优化
   ▼
可上线的对齐模型
```

做 Agent 时你通常不会碰训练本身，但要知道：**模型今天表现成什么样，不只是因为参数量大，更是因为后训练（post-training）阶段做了大量行为塑形**。

---

## 4.9 2026 主流模型对比

下面这张表从工程选型角度整理了常见模型。注意，闭源模型参数量大多未公开，价格也会随区域、缓存命中、批量接口发生变化，因此这里给出的是 2026 年上半年常见公开区间，足够用于面试和方案评估。

| Model | Company | Parameters | Context Window | Strengths | API Price |
|------|---------|------------|----------------|-----------|-----------|
| GPT-4o | OpenAI | 未公开 | 128K | 多模态、延迟低、生态完整 | 约 \$5 / \$15（输入/输出，每 1M tokens） |
| GPT-4.5 | OpenAI | 未公开 | 128K | 推理稳定、写作和代码均衡 | 约 \$2.5 / \$15 |
| Claude Opus | Anthropic | 未公开 | 200K-1M（按版本） | 长上下文、代码质量高、安全性强 | 约 \$5 / \$25 |
| Claude Sonnet | Anthropic | 未公开 | 200K-1M（按版本） | 性价比高、日常 Agent 默认选项 | 约 \$3 / \$15 |
| Claude Haiku | Anthropic | 未公开 | 200K | 速度快、轻量任务便宜 | 约 \$1 / \$5 |
| Gemini 2.5 Pro | Google | 未公开 | 1M | 超长上下文、多模态、Google 生态 | 约 \$2 / \$12 |
| Llama 4 Maverick | Meta | 约 400B MoE / 17B active | 128K | 开源权重、自部署、可微调 | 官方 API 不固定，自建成本视 GPU 而定 |
| Qwen 3 Max | 阿里云 | 公开版本差异较大，旗舰级常见为百亿到数百亿级 | 128K-1M | 中文、代码、多语言均衡 | 约 \$1.2-\$4 / 1M tokens |
| DeepSeek V3 | DeepSeek | 671B MoE / 37B active | 128K | 代码强、性价比高、推理便宜 | 约 \$0.3-\$1.5 / 1M tokens |

几个非常实用的选型结论：

1. **做原型**：优先看生态、SDK、稳定性，而不是盯着排行榜第一名。
2. **做代码 Agent**：Claude Sonnet / Opus、GPT-4.5、DeepSeek V3、Qwen 3 都是高频选项。
3. **做私有化部署**：Llama 4、Qwen 系列、DeepSeek 系列比闭源模型更现实。
4. **做长文档分析**：上下文窗口和检索架构同样重要，不能只看“1M context”宣传页。

---

## 4.10 推理优化：真正决定成本的地方

训练很贵，但大多数公司更常见的问题其实是**推理成本**。Agent 系统上线后，钱是按调用次数、输出 token、延迟和显存烧掉的。

### 4.10.1 量化（Quantization）

量化（Quantization）是把 FP16 / BF16 权重压缩到 INT8、INT4 等更低精度格式。

| 方案 | 优点 | 代价 | 常见场景 |
|------|------|------|----------|
| INT8 | 精度损失较小 | 压缩率一般 | 在线推理基础方案 |
| INT4 | 显存下降明显 | 复杂任务可能掉点 | 本地部署、边缘部署 |
| GPTQ/AWQ | 开源社区常见 | 需要校准数据 | 7B/14B/32B 模型压缩 |

经验上，一个 7B 模型用 4-bit 量化后，单卡部署难度会显著下降。对中小团队，这是“能不能上线”的分水岭。

### 4.10.2 KV Cache

KV Cache（键值缓存）是所有 Agent 工程师都必须理解的优化。因为自回归生成时，前面 token 的 K/V 不需要每一步重算，只需要缓存起来。

没有 KV Cache 时：

- 第 1 个 token 算一次前缀
- 第 2 个 token 又把前缀重算一遍
- 第 1000 个 token 还在重复算前 999 个

有了 KV Cache，新增 token 只计算自己，然后和已有缓存拼接。它极大降低了长对话生成成本，也是 streaming 输出能流畅工作的基础。

### 4.10.3 Speculative Decoding

投机解码（Speculative Decoding）通常会让一个小模型先猜多个 token，再让大模型验证。猜对就批量接受，猜错就回退。它像编译器里的 branch prediction：不是改变结果，而是提高吞吐。

适用场景：

- 高并发聊天
- 大量结构化输出
- 相似请求多

不适用场景：

- 每一步都需要复杂推理
- 输出分布高度发散

### 4.10.4 Batching 策略

批处理（Batching）不是简单把请求堆一起。你要平衡三件事：

1. **吞吐**：batch 大，GPU 利用率高
2. **延迟**：batch 大，单请求排队更久
3. **形状差异**：输入长度差太大，会浪费 padding 和显存

工程实践里常见做法是：

- 按 prompt 长度分桶（bucketing）
- 把 embedding 请求和 generation 请求分开
- 高频短请求独立服务，长上下文请求单独队列

---

## 4.11 Python 示例：同时调用 OpenAI、Anthropic 和本地 Ollama

下面这个示例展示一个统一封装。只要你准备好对应的 API Key，本代码可以直接运行。

```python
from __future__ import annotations

import os
from openai import OpenAI
import anthropic
import requests


def call_openai(prompt: str) -> str:
    client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    resp = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": "你是一名资深 AI Agent 工程师。"},
            {"role": "user", "content": prompt},
        ],
        temperature=0.2,
    )
    return resp.choices[0].message.content


def call_anthropic(prompt: str) -> str:
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    resp = client.messages.create(
        model="claude-sonnet-4-0",
        max_tokens=800,
        temperature=0.2,
        system="你是一名资深 AI Agent 工程师。",
        messages=[{"role": "user", "content": prompt}],
    )
    return "".join(block.text for block in resp.content if block.type == "text")


def call_ollama(prompt: str) -> str:
    resp = requests.post(
        "http://localhost:11434/api/generate",
        json={
            "model": "qwen2.5:7b-instruct",
            "prompt": prompt,
            "stream": False,
        },
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()["response"]


if __name__ == "__main__":
    prompt = "请用 5 条要点解释为什么 RAG 能降低 AI Agent 的幻觉率。"
    print("OpenAI =>", call_openai(prompt))
    print("Anthropic =>", call_anthropic(prompt))
    print("Ollama =>", call_ollama(prompt))
```

这段代码传达了一个关键事实：**模型调用层应该被你封装成可替换组件**。真正成熟的 Agent 系统不会把供应商 SDK 直接散落在业务代码里，而是做统一接口、超时控制、重试、熔断、token 计费统计和模型回退（fallback）。

---

## 4.12 面试高频问题：你应该怎么回答

### 问题 1：为什么 Transformer 比 RNN 更适合 LLM？

推荐答法：

- Self-Attention 能直接建模任意位置依赖
- 训练时能并行处理整个序列
- 更适合大规模数据和 GPU/TPU 矩阵计算
- 缺点是长上下文复杂度高，为此才衍生出 FlashAttention、稀疏注意力、线性注意力等工程优化

### 问题 2：上下文窗口越大越好吗？

不。上下文越大，成本越高、延迟越高，而且有效利用率不一定线性提升。很多任务用 8K + 好的 RAG，比“把所有文档塞进 1M context”更稳。

### 问题 3：Tokenizer 为什么会影响 RAG？

因为 chunk 切分、召回长度、prompt 预算、API 费用都按 token 计算。字符数只是近似指标，真正上线必须看 tokenizer 的实际编码结果。

---

## 4.13 从 Logits 到最终输出：采样策略为什么会影响 Agent 稳定性

理解 Transformer 结构后，还差最后一块拼图：模型是怎样把内部计算结果变成文本的。模型前向传播真正直接输出的是 logits，也就是“每个候选 token 的未归一化分数”。接下来还要经过 softmax、温度缩放、top-k 或 top-p 采样，最后才会确定输出什么 token。

### 4.13.1 Temperature

Temperature（温度）越低，分布越尖锐，模型越倾向选最高概率 token；温度越高，模型越愿意探索次优 token。工程上可以粗略记忆为：

- `temperature=0`：结构化输出、工具调用、分类、SQL 生成
- `temperature=0.2~0.4`：企业问答、RAG 回答
- `temperature=0.7+`：创意写作、头脑风暴

如果你的 Agent 需要输出严格 JSON，却把温度设得很高，那么偶发字段漂移、附加说明文字、枚举值不稳定，其实都不是怪事。

### 4.13.2 Top-k 与 Top-p

Top-k 表示只在概率最高的前 K 个 token 中选择；Top-p（nucleus sampling，核采样）则表示在累计概率达到阈值 `p` 的候选集合中采样。Top-p 的工程价值在于，它能随着分布变化自动调整候选集大小，因此在很多通用生成场景更常见。

### 4.13.3 为什么代码 Agent 通常用低温度

代码修复、工具路由、参数填充，本质上都属于高约束任务。你追求的是可重复、可验证，而不是“有创造力”。因此代码 Agent 往往倾向于：

1. 低温度  
2. 明确 schema  
3. 少量 few-shot  
4. 必要时配合 deterministic post-check  

### 4.13.4 成本估算的工程习惯

假设一个知识库 Agent 每次请求包含：

- system prompt：600 tokens
- 检索上下文：1200 tokens
- 历史对话：800 tokens
- 用户问题：120 tokens
- 输出答案：280 tokens

则单次请求输入约 2720 tokens，输出约 280 tokens。如果日请求量 30,000 次，模型价格为输入 \$5 / 1M tokens、输出 \$15 / 1M tokens，那么日成本近似为：

- 输入成本：`30000 * 2720 / 1,000,000 * 5 ≈ $408`
- 输出成本：`30000 * 280 / 1,000,000 * 15 ≈ $126`
- 总成本：约 `$534/天`

这说明一个现实问题：Prompt 压缩、RAG 召回控制、缓存命中率和模型路由，经常比“换一个更便宜的模型”更能决定最终账单。

### 4.13.5 一个常见误区：把模型能力和系统能力混为一谈

很多候选人在面试里会说“某某模型有 1M 上下文，所以不需要 RAG 了”或者“某某模型参数更大，所以一定更适合 Agent”。这类说法都过于粗糙。模型能力只是系统能力的一部分，真正上线时还要同时考虑：

- 首 token 延迟是否可接受
- 工具调用是否稳定
- JSON 输出是否可靠
- 价格能否承受
- 合规和部署方式是否满足要求

所以一个成熟的 AI Agent 工程师不会只比较模型榜单，而会把模型放进完整的软件系统约束里评估。

---

## 本章要点

1. 大语言模型本质上是基于 Transformer 的下一个 token 预测系统。
2. Self-Attention 是核心，复杂度约为 `O(n^2)`，这决定了长上下文成本。
3. Multi-Head Attention 通过多个子空间并行建模不同关系，对代码与推理任务尤其重要。
4. FFN、LayerNorm、Residual Connection 让深层网络可训练、可稳定收敛。
5. 当前主流 Agent 模型大多是 Decoder-only 架构，因为它天然适合自回归生成和工具调用。
6. Tokenizer 不是边角料，而是影响成本、上下文预算与 RAG 切块质量的关键因素。
7. 模型能力不仅来自预训练，还来自 SFT、RLHF、DPO 等后训练流程。
8. 生产环境里真正决定体验和成本的，往往是量化、KV Cache、批处理、模型路由等推理优化。

## 延伸阅读

1. 《Attention Is All You Need》—— Transformer 原始论文，建议至少读摘要、架构图和 attention 公式。
2. OpenAI、Anthropic、Google 官方 API 文档——重点关注 context window、rate limit、structured output。
3. Hugging Face Transformers 文档——理解 tokenizer、模型加载、量化与推理接口。
4. vLLM、TensorRT-LLM、llama.cpp 项目文档——学习真实部署中的吞吐优化手段。
5. 如果你准备 Agent 面试，建议把本章所有概念用“系统设计语言”再复述一遍：它们如何影响延迟、成本、稳定性和召回质量。
