# 第二十章：学习资源与路线图

写到这里，你已经走完了本书的最后一章。前面十九章帮你搭起了从行业认知、基础知识、Agent 架构，到面试与实操的完整骨架；这一章的任务，是把“知道该学什么”进一步变成“明天就能开始执行的路线图”。如果说前面的章节是在帮你建立地图，那么这一章更像是为你准备背包、补给和里程碑。

先给你一个结论：**AI Agent 工程师不是只会调模型 API 的“提示词工程师”，而是能够把大语言模型（Large Language Model, LLM）、检索增强生成（Retrieval-Augmented Generation, RAG）、工具调用（Tool Calling）、工作流编排（Workflow Orchestration）、评估（Evaluation）与工程化部署真正落地的人。** 所以，你的学习策略不应该是“追爆款框架”，而应该是“打基础、做项目、进社区、持续输出”。

这一章我会给你四类最有价值的资源：**书、课、论文、开源项目**；再给你四类最能改变结果的方法：**路线图、作品集、简历、公开表达**。你不需要一口气吃掉所有内容，但你需要有一份清晰、可信、能执行的行动计划。

---

## 一、先建立资源使用原则：不要囤课，要形成闭环

很多工程师转行失败，不是因为不努力，而是因为“资源消费”代替了“能力增长”。收藏了 200 个链接，却没有一个项目上线；买了 10 门课，却说不清楚 ReAct、RAG、Toolformer 和 MCP 的区别。真正有效的学习闭环，建议固定为下表。

| 阶段 | 主要动作 | 产出物 | 判断标准 |
|------|----------|--------|----------|
| 输入 | 读书、上课、读论文 | 笔记、术语卡片、代码片段 | 能复述核心概念 |
| 模仿 | 跟教程复现 | Demo、Notebook、脚手架项目 | 能在本地跑通 |
| 变形 | 自己改需求 | Feature、评估报告、对比实验 | 能解释为什么这样设计 |
| 输出 | 写文章、做分享、开源贡献 | 博客、PR、Issue、演讲稿 | 别人能看懂并复用 |
| 证明 | 写进简历、做作品集 | GitHub 仓库、在线演示、README | 面试官愿意追问 |

建议你以后接触任何资源，都问自己三个问题：

1. **它帮我补的是基础、框架、还是项目经验？**
2. **我学完后，能产出什么可展示的成果？**
3. **它能否服务于 90 天内的求职目标？**

带着这三个问题看资源，你会自然筛掉大量“看起来很热闹、实际不长能力”的内容。

---

## 二、推荐书单：至少读 15 本，但不要平均用力

下面这份书单按照主题划分，并标注难度与适合阶段。我的建议是：**不要按顺序全读，而是围绕你当前短板组合阅读。** 如果你来自后端，可能更缺模型与 NLP；如果你来自算法岗，可能更缺系统设计与工程化；如果你是前端转行，Python 与数据处理的优先级会更高。

### 2.1 AI / ML 基础书单

| 书名 | 作者 | 难度 | 适合阶段 | 一句话推荐 |
|------|------|------|----------|------------|
| Hands-On Machine Learning with Scikit-Learn, Keras & TensorFlow（《动手学机器学习》） | Aurélien Géron | 中 | 入门-进阶 | 对工程师最友好的 ML 入门书，代码密度高，适合边学边跑。 |
| Deep Learning（《深度学习》） | Ian Goodfellow、Yoshua Bengio、Aaron Courville | 高 | 进阶 | 这是理论底座，想真正理解神经网络而不是“会调 API”，值得啃。 |
| 动手学深度学习（Dive into Deep Learning） | 李沐、Aston Zhang 等 | 中 | 入门-进阶 | 中文友好、数学解释清晰，配套代码和课程非常适合自学。 |
| Pattern Recognition and Machine Learning（《模式识别与机器学习》） | Christopher M. Bishop | 高 | 进阶 | 如果你希望把概率图模型、EM、贝叶斯方法补扎实，这是经典。 |
| Probabilistic Machine Learning: An Introduction | Kevin P. Murphy | 高 | 进阶 | 对“为什么这样建模”解释得很好，适合把直觉升级为系统认知。 |

### 2.2 NLP / LLM 方向书单

| 书名 | 作者 | 难度 | 适合阶段 | 一句话推荐 |
|------|------|------|----------|------------|
| Speech and Language Processing | Daniel Jurafsky、James H. Martin | 高 | 进阶 | NLP 领域百科全书，Transformer 之前与之后的脉络都能补齐。 |
| Natural Language Processing with Transformers | Lewis Tunstall、Leandro von Werra、Thomas Wolf | 中 | 入门-进阶 | Hugging Face 生态的最佳实践入口，适合工程师快速落地。 |
| Transformers for Natural Language Processing | Denis Rothman | 中 | 入门 | 结构清晰，适合快速建立 Transformer 与下游任务概念。 |
| Generative Deep Learning（第 2 版） | David Foster | 中 | 入门-进阶 | 对生成式模型演进讲得通俗，适合建立大模型前史。 |
| Build a Large Language Model (From Scratch) | Sebastian Raschka | 中高 | 进阶 | 想知道 LLM 内部是怎么“搭起来”的，这本书非常值得。 |

### 2.3 Agent / 应用构建方向书单

| 书名 | 作者 | 难度 | 适合阶段 | 一句话推荐 |
|------|------|------|----------|------------|
| AI Engineering: Building Applications with Foundation Models | Chip Huyen | 中 | 入门-进阶 | 面向应用层最实用的一本，覆盖评估、提示、RAG、生产化。 |
| Designing Large Language Model Applications | Chip Huyen（课程/讲义体系延伸） | 中 | 入门-进阶 | 帮你建立“LLM 应用不是聊天框，而是系统”的工程视角。 |
| Building LLM Apps for Production | 多位作者，O’Reilly 2025-2026 系列 | 中 | 进阶 | 重点看可观测性、评估、安全与上线，特别适合求职前补全短板。 |
| Practical AI Agents | Noah Gift 等 | 中 | 入门-进阶 | 对 Agent 工作流、工具集成和企业落地很有帮助。 |
| Generative AI on AWS / Azure OpenAI Service 实战类书籍 | 各云厂商作者 | 中 | 进阶 | 如果你目标是企业岗位，云上集成、权限、成本与部署非常关键。 |

### 2.4 系统设计与工程化书单

| 书名 | 作者 | 难度 | 适合阶段 | 一句话推荐 |
|------|------|------|----------|------------|
| Designing Machine Learning Systems | Chip Huyen | 中高 | 进阶 | 把模型训练、数据、部署、监控串起来，是 ML/Agent 工程化必修。 |
| Machine Learning System Design Interview | Ali Aminian、Alex Xu | 中 | 面试冲刺 | 面试表达框架清晰，能帮你把“会做”变成“会讲”。 |
| Designing Data-Intensive Applications（《数据密集型应用系统设计》） | Martin Kleppmann | 高 | 进阶 | 任何做 RAG、向量检索、异步任务编排的人都应该反复读。 |
| System Design Interview | Alex Xu | 中 | 面试冲刺 | 即使不是纯后端岗，也要具备吞吐、缓存、队列和一致性表达能力。 |

### 2.5 Python 与数学书单

| 书名 | 作者 | 难度 | 适合阶段 | 一句话推荐 |
|------|------|------|----------|------------|
| Fluent Python（《流畅的 Python》） | Luciano Ramalho | 中高 | 入门-进阶 | 想把 Python 从“能写”升级到“写得像工程师”，这本书很关键。 |
| Effective Python | Brett Slatkin | 中 | 入门 | 短小高效，适合快速补常见坑与最佳实践。 |
| Python for Data Analysis | Wes McKinney | 中 | 入门-进阶 | 数据清洗、分析、CSV/Parquet 处理都离不开它。 |
| Mathematics for Machine Learning | Marc Peter Deisenroth、A. Aldo Faisal、Cheng Soon Ong | 中高 | 入门-进阶 | 用最贴近 ML 的方式讲线代、概率、微积分。 |
| Introduction to Linear Algebra | Gilbert Strang | 中 | 入门 | 向量、矩阵、特征值这些概念想建立长期稳定直觉，首选。 |

### 2.6 不同背景的阅读优先级

| 你的背景 | 先读什么 | 后读什么 | 暂时可放后 |
|----------|----------|----------|--------------|
| 后端工程师 | Hands-On ML、AI Engineering、Designing ML Systems | NLP with Transformers、Machine Learning System Design Interview | PRML、PML |
| 前端工程师 | Fluent Python、动手学深度学习、AI Engineering | LangChain/LangGraph 官方文档配套书 | Bishop、Murphy 的重理论书 |
| 测试 / QA 工程师 | Effective Python、RAG/评估相关资料、AI Engineering | 系统设计与 Agent 评估框架 | 过深的训练理论 |
| 算法 / 数据岗 | Designing Data-Intensive Applications、Agent 应用构建类书 | Resume/portfolio 相关资源 | 纯入门型 Python 书 |

---

## 三、在线课程推荐：用课程搭框架，用项目补深度

高质量课程最大的价值，不是替你省时间，而是帮你避免学习顺序混乱。下面的课程我尽量选择**官方、长期可访问、社区认可度高**的资源。

| 课程名 | 平台 | 讲师 | 时长 | 难度 | 链接 |
|--------|------|------|------|------|------|
| Machine Learning Specialization | Coursera / DeepLearning.AI | Andrew Ng | 约 60 小时 | 入门 | https://www.coursera.org/specializations/machine-learning-introduction |
| Deep Learning Specialization | Coursera / DeepLearning.AI | Andrew Ng | 约 80 小时 | 入门-进阶 | https://www.coursera.org/specializations/deep-learning |
| AI Agentic Design Patterns with AutoGen | DeepLearning.AI | Andrew Ng 团队 | 4-6 小时 | 入门 | https://www.deeplearning.ai/short-courses/ |
| Practical Deep Learning for Coders | fast.ai | Jeremy Howard | 约 25 小时 | 入门-进阶 | https://course.fast.ai/ |
| Hugging Face NLP Course | Hugging Face | Lewis Tunstall 等 | 自定进度 | 入门-进阶 | https://huggingface.co/learn/nlp-course |
| LangChain Academy / Official Tutorials | LangChain | 官方团队 | 自定进度 | 入门-进阶 | https://academy.langchain.com/ 与 https://python.langchain.com/docs/tutorials/ |
| LangGraph Tutorials | LangChain | 官方团队 | 自定进度 | 进阶 | https://langchain-ai.github.io/langgraph/ |
| CS229 Machine Learning | Stanford Online | Andrew Ng / Stanford | 学期制 | 中高 | https://cs229.stanford.edu/ |
| CS224N Natural Language Processing with Deep Learning | Stanford Online | Christopher Manning 团队 | 学期制 | 中高 | https://web.stanford.edu/class/cs224n/ |
| Full Stack Deep Learning | FSDL | Berkeley/社区讲师 | 学期制 | 中高 | https://fullstackdeeplearning.com/ |
| 李宏毅机器学习 | B 站 / YouTube | 李宏毅 | 系列课程 | 入门-进阶 | https://space.bilibili.com/17720593 |
| 吴恩达 Generative AI / Agent 系列短课 | DeepLearning.AI | Andrew Ng 团队 | 1-6 小时 | 入门 | https://www.deeplearning.ai/short-courses/ |

### 3.1 课程选择建议

| 目标 | 优先课程 | 为什么 |
|------|----------|--------|
| 0 到 1 入门 | 吴恩达 ML + 李宏毅机器学习 | 一个偏结构化英文体系，一个偏中文讲解友好 |
| 想快速做项目 | fast.ai + Hugging Face Course | 理论不过载，工程实践直接、反馈快 |
| 想冲 Agent 岗 | LangChain / LangGraph + Agentic Design Patterns | 能直接补工作流、工具调用、多 Agent 设计 |
| 想冲中高级岗位 | CS229 + CS224N + FSDL | 帮你把理论深度和系统视角补齐 |

一个实用原则是：**主课只保留 1 门，副课最多 2 门。** 主课负责连续性，副课负责针对性补洞。否则很容易陷入今天看 Stanford、明天跳 B 站、后天刷短视频，最后什么都懂一点、什么都说不深。

---

## 四、必读论文：10 篇足够帮你建立 Agent 核心世界观

你不需要把所有论文都精读到公式级别，但下面 10 篇建议至少完成“问题是什么、方法是什么、为什么重要、今天还如何影响工程实践”四件事。

| 论文 | 作者 / 时间 | 链接 | 为什么必读 | 建议关注点 |
|------|-------------|------|------------|------------|
| Attention Is All You Need | Vaswani et al., 2017 | https://arxiv.org/abs/1706.03762 | Transformer 是今天 LLM 的根基 | Self-Attention、位置编码、并行训练优势 |
| ReAct: Synergizing Reasoning and Acting in Language Models | Yao et al., 2022 | https://arxiv.org/abs/2210.03629 | 奠定了“思考 + 行动”式 Agent 模式 | Thought/Action/Observation 循环 |
| Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks | Lewis et al., 2020 | https://arxiv.org/abs/2005.11401 | RAG 体系的源头之一 | 参数知识与外部知识的结合 |
| LoRA: Low-Rank Adaptation of Large Language Models | Hu et al., 2021 | https://arxiv.org/abs/2106.09685 | 微调（Fine-tuning）成本革命的关键工作 | 低秩分解、参数高效微调 |
| Constitutional AI: Harmlessness from AI Feedback | Bai et al., 2022 | https://arxiv.org/abs/2212.08073 | 安全对齐（Alignment）与规则化输出的重要里程碑 | 原则驱动监督、RLAIF 思路 |
| Toolformer: Language Models Can Teach Themselves to Use Tools | Schick et al., 2023 | https://arxiv.org/abs/2302.04761 | 模型学习工具调用的代表作 | API 选择、调用时机、自监督数据构造 |
| Chain-of-Thought Prompting Elicits Reasoning in Large Language Models | Wei et al., 2022 | https://arxiv.org/abs/2201.11903 | 解释了为什么“让模型展示推理过程”能提升效果 | Prompt 结构与复杂任务表现 |
| Tree of Thoughts: Deliberate Problem Solving with Large Language Models | Yao et al., 2023 | https://arxiv.org/abs/2305.10601 | 从线性推理走向树状搜索 | 分支探索、状态评估、搜索策略 |
| RAPTOR: Recursive Abstractive Processing for Tree-Organized Retrieval | Sarthi et al., 2024 | https://arxiv.org/abs/2401.18059 | 提醒你 RAG 不只有 chunk + top-k | 分层摘要、树状检索组织 |
| The Landscape of Emerging AI Agent Architectures for Reasoning, Planning, and Tool Calling | 2024 综述类论文 | https://arxiv.org/abs/2404.11584 | 帮你从个例跳到全局理解 Agent 架构谱系 | Planner、Executor、Memory、Tool Use 的组合 |

### 4.1 论文阅读顺序建议

| 顺序 | 论文 | 目标 |
|------|------|------|
| 1 | Attention Is All You Need | 建立 LLM 起点认知 |
| 2 | Chain-of-Thought | 理解提示对推理质量的影响 |
| 3 | ReAct | 进入 Agent 核心模式 |
| 4 | RAG | 理解外部知识接入 |
| 5 | Toolformer | 理解工具调用的自动化方向 |
| 6 | Tree of Thoughts | 理解复杂任务搜索策略 |
| 7 | Constitutional AI | 理解安全与对齐 |
| 8 | LoRA | 理解个性化与成本优化 |
| 9 | RAPTOR | 理解高级检索组织 |
| 10 | Agent 架构综述 | 建立全景图，准备系统设计表达 |

论文不要只读摘要。建议你至少写一页自己的总结，模板如下：**问题定义、核心方法、和已有方案的区别、可落地到什么工程场景、我在面试时如何用一句话讲清楚。** 这会极大提升你面试中的“理论理解深度”。

---

## 五、开源项目推荐：最好的老师往往是源码与 Issue

如果说课程是“带扶手的楼梯”，那么开源项目就是“真实世界的施工现场”。AI Agent 岗位非常看重工程感，而工程感很多时候来自你读过多少真实代码、踩过多少真实坑。

| 项目 | Stars（约） | 用途 | 学习价值 |
|------|-------------|------|----------|
| LangChain | 100k+ | LLM 应用与工具编排框架 | 学组件抽象、Prompt 链、工具调用、生态整合 |
| LangGraph | 15k+ | 状态机式 Agent 工作流 | 学可控性、持久化状态、复杂流程编排 |
| LlamaIndex | 40k+ | RAG 数据接入与索引框架 | 学数据连接器、索引策略、查询管线 |
| CrewAI | 30k+ | 多 Agent 协作框架 | 学角色分工、任务分解、协作模式 |
| AutoGen | 40k+ | 多智能体对话与任务执行 | 学会话式协作、自动化任务流、Agent Chat |
| Dify | 90k+ | 可视化 LLM / Agent 应用平台 | 学产品化、工作流编排、运营后台思路 |
| FastGPT | 20k+ | 中文社区常用知识库 / Agent 平台 | 学中文场景落地、SaaS 交互和部署方式 |
| RAGFlow | 50k+ | 面向生产的 RAG 系统 | 学文档解析、检索链路、企业知识库工程 |
| QAnything | 15k+ | 本地知识库问答系统 | 学私有化部署、中文文档问答、离线方案 |

### 5.1 推荐仓库入口

| 项目 | GitHub URL | 建议学习方式 |
|------|------------|--------------|
| LangChain | https://github.com/langchain-ai/langchain | 先看 docs，再读核心接口与 examples |
| LangGraph | https://github.com/langchain-ai/langgraph | 找一个官方 tutorial 手敲一遍，再改成自己的业务流 |
| LlamaIndex | https://github.com/run-llama/llama_index | 从 ingestion、index、query engine 三层看结构 |
| CrewAI | https://github.com/crewAIInc/crewAI | 重点看 role / task / process 抽象 |
| AutoGen | https://github.com/microsoft/autogen | 看多 Agent 对话样例与工具执行链路 |
| Dify | https://github.com/langgenius/dify | 适合看全栈产品化与后端服务划分 |
| FastGPT | https://github.com/labring/FastGPT | 适合看中文社区如何做知识库产品 |
| RAGFlow | https://github.com/infiniflow/ragflow | 适合看解析、切块、检索、工作流一体化 |
| QAnything | https://github.com/netease-youdao/QAnything | 适合看本地化企业知识库方案 |

### 5.2 开源学习顺序

| 阶段 | 要做什么 | 不要做什么 |
|------|----------|------------|
| 第一步 | 跑通官方 quickstart | 一上来就试图读完整个仓库 |
| 第二步 | 找 1 个核心链路，从入口追到出口 | 迷失在配置文件和脚手架细节里 |
| 第三步 | 改一个小功能或替换一个组件 | 没理解架构就大改代码 |
| 第四步 | 提 Issue、修文档、补测试、提 PR | 只 star 不动手 |

对转行者来说，**一次高质量开源贡献，往往比十个“照着教程做出来的 Demo”更能证明能力。** 因为开源贡献体现的是阅读陌生代码、理解上下文、遵守规范、和维护者沟通、完成交付的综合能力。

---

## 六、社区与论坛：别一个人埋头学，建立信息雷达

AI Agent 变化快，这是事实；但“变化快”不等于“只能靠运气跟上”。真正有效的方法，是建立一套稳定的信息雷达，让你知道哪里看官方发布、哪里看实战案例、哪里看社区争议。

### 6.1 值得长期关注的社区

| 社区 / 平台 | 网址 | 适合看什么 | 使用建议 |
|-------------|------|------------|----------|
| Hugging Face Community | https://huggingface.co/ 与 https://discuss.huggingface.co/ | 模型、数据集、课程、论坛讨论 | 适合查模型卡（Model Card）与最新实践 |
| Reddit r/LocalLLaMA | https://www.reddit.com/r/LocalLLaMA/ | 本地模型、推理部署、硬件讨论 | 看趋势很快，但注意信息噪声 |
| Reddit r/MachineLearning | https://www.reddit.com/r/MachineLearning/ | 论文讨论、研究动态 | 用来发现值得读的论文与综述 |
| Reddit r/LangChain | https://www.reddit.com/r/LangChain/ | LangChain/LangGraph 使用经验 | 查坑点与版本迁移经验很实用 |
| LangChain Discord | 官方社区入口页可达 | 工作流、bug、教程、生态整合 | 遇到版本问题时很高效 |
| OpenAI Developer Community | https://community.openai.com/ | API、Agents、Responses、实践案例 | 关注官方示例与变更公告 |
| Anthropic Discord / Docs 社区 | https://docs.anthropic.com/ | Claude、tool use、安全实践 | 看 tool use 和安全设计很有启发 |
| 掘金 AI 专区 | https://juejin.cn/ | 中文工程实战文章 | 适合找国内开发者的落地经验 |
| 知乎 AI 话题 | https://www.zhihu.com/topic/19559424 | 行业观察、学习经验 | 注意辨别营销内容 |
| B 站 AI 技术区 | https://www.bilibili.com/ | 中文课程、项目拆解、论文解读 | 适合碎片时间补充理解 |

### 6.2 建议关注的 X（Twitter）账号类型

| 类型 | 代表账号 / 组织 | 你能获得什么 |
|------|-----------------|--------------|
| 模型公司官方 | @OpenAI、@AnthropicAI、@GoogleDeepMind | 第一时间获取能力更新与 API 变化 |
| 框架官方 | @LangChainAI、@llama_index | 文档更新、教程、breaking changes |
| 教学型创作者 | @jeremyphoward、@rasbt | 更适合工程师理解的拆解内容 |
| 系统设计 / AI 工程作者 | @chipro | 对应用架构、评估与产品化很有帮助 |
| 中文技术创作者 | 关注你认可的 B 站 / 掘金作者同步账号 | 更贴近本地求职与部署语境 |

社区的正确打开方式不是“每天刷到停不下来”，而是：

- 每周固定 2 次，每次 30-45 分钟
- 优先看官方 changelog、release note、issue 热点
- 看到好内容，马上转成自己的实验或笔记
- 只保留少量高价值订阅源，拒绝信息过载

---

## 七、30 / 60 / 90 天学习计划：把焦虑变成可执行进度

接下来这份 90 天路线图，适合**已经具备软件开发经验，但对 AI Agent 还不系统**的读者。它不是唯一答案，但它足够实用，尤其适合准备在 3 个月内完成转型和求职启动的人。

### 7.1 第一阶段：基础筑基（第 1-30 天）

| 周次 | 主题 | 本周任务 | 必做产出 | 验收标准 |
|------|------|----------|----------|----------|
| Week 1 | Python 复习 + LLM API 初体验 | 补 Python 基础、requests/httpx、JSON、环境变量、调用 OpenAI / Anthropic / Gemini 任一 API | 一个最小问答脚本 + README | 能独立完成 API 调用、异常处理、配置管理 |
| Week 2 | Prompt 工程（Prompt Engineering） | 学习 zero-shot、few-shot、role prompt、结构化输出；完成 3 个 prompt 练习 | 3 份 prompt 实验记录 | 能解释 prompt 失效原因与改进思路 |
| Week 3 | Embedding + 向量数据库（Vector Database） | 学文本切块、embedding、相似度检索；接入 FAISS / Chroma / pgvector 之一 | 一个语义搜索 Demo | 能展示 top-k 检索结果与误召回案例 |
| Week 4 | RAG 基础 | 做一个本地文档问答系统，加入 chunking、retriever、answer synthesis | 第一个 RAG 项目 | 能说明 chunk 大小、召回策略、失败样本 |

### 7.2 第二阶段：Agent 核心（第 31-60 天）

| 周次 | 主题 | 本周任务 | 必做产出 | 验收标准 |
|------|------|----------|----------|----------|
| Week 5 | Agent 架构 | 从零实现一个 ReAct Agent：思考、选择工具、读取观察、继续执行 | ReAct 原型仓库 | 不依赖重框架，能跑通 2-3 个工具任务 |
| Week 6 | LangChain / LangGraph 实战 | 用框架重构 Week 5 项目，加入状态管理、节点编排与错误恢复 | LangGraph 版 Agent | 能比较“手写 Agent”和“框架 Agent”的优缺点 |
| Week 7 | 工具系统 + 记忆系统 | 增加搜索、计算器、文件读取、SQL 查询等工具；加入短期记忆 / 长期记忆 | Tool + Memory 增强版 Agent | 能解释工具 schema、上下文裁剪、记忆更新策略 |
| Week 8 | 多 Agent 系统 + MCP 协议（Model Context Protocol, MCP） | 设计一个 researcher / planner / executor 协作系统；接入一个 MCP server | 多 Agent Demo + 架构图 | 能说明任务拆分、通信、权限边界与失败处理 |

### 7.3 第三阶段：面试冲刺（第 61-90 天）

| 周次 | 主题 | 本周任务 | 必做产出 | 验收标准 |
|------|------|----------|----------|----------|
| Week 9 | 完整 portfolio 项目 | 把前面项目升级为“能演示、能部署、能评估”的作品集项目 | 在线 Demo / 录屏 / README / 架构图 | 面试官打开仓库 3 分钟内能看懂价值 |
| Week 10 | 理论面试题 | 系统刷本书第 17 章的理论题，整理自己的答案模板 | 一份问答手册 | 能在 2-3 分钟内讲清 RAG、Agent、评估、安全 |
| Week 11 | 系统设计 | 按本书第 18 章练 5 套系统设计题 | 5 份设计草图 + 录音复盘 | 能结构化讲容量、延迟、缓存、评估与监控 |
| Week 12 | 模拟面试 + 简历优化 + 投递 | 修改简历、做 3 次模拟面试、开始投递 | 最终简历、投递清单、复盘表 | 能流畅讲项目、回答追问、定位短板 |

### 7.4 每周固定节奏建议

| 时间块 | 建议安排 |
|--------|----------|
| 工作日 1 小时 | 看课 / 读书 / 写少量代码 |
| 工作日 30 分钟 | 复盘当天知识点，写卡片或 issue |
| 周末半天 | 集中做项目或重构 |
| 周末 1-2 小时 | 读论文、写总结、准备公开输出 |

如果你只能保证每周 8-10 小时，那也没关系。关键不是理想计划，而是**连续性**。AI Agent 方向非常奖励“持续迭代的人”，而不是“偶尔爆发一下的人”。

---

## 八、简历与作品集打造指南：让学习成果可见、可问、可信

很多人能力并不差，但输在表达方式。AI Agent 招聘常见问题是：简历上写了很多名词，却看不出你是否真的做过工程。你需要把自己的经历改写成“有业务目标、有技术方案、有指标结果”的形式。

### 8.1 AI 导向简历结构建议

| 模块 | 应写什么 | 常见错误 | 更好的写法 |
|------|----------|----------|------------|
| 个人简介 | 1-2 句话概括背景、技术栈、转型方向 | 写成空泛口号 | 写清“X 年后端经验 + 正在构建 RAG / Agent 系统” |
| 核心技能 | Python、LLM API、RAG、LangChain/LangGraph、向量数据库、Docker、云平台 | 列太多 buzzword | 只写自己能在面试中展开的技能 |
| 项目经历 | 问题背景、职责、架构、结果、指标 | 只写“负责开发” | 用动词 + 技术 + 结果，例如“设计并实现多 Agent 研究助手，将检索响应时间降至 1.2s” |
| 开源贡献 | PR、Issue、文档、插件、适配器 | 只贴仓库链接 | 说明你贡献了什么、为什么重要 |
| 技术输出 | 博客、演讲、课程笔记 | 没有上下文 | 标明主题与链接，让面试官可快速查看 |

### 8.2 最能打动面试官的作品集项目

| 项目点子 | 你需要实现什么 | 为什么加分 |
|----------|------------------|------------|
| 企业级 RAG 系统 + 评估面板 | 文档接入、切块、检索、答案生成、引用展示、离线评估 dashboard | 体现你不是只会“聊天”，而是在做知识系统 |
| 多 Agent 研究助手 | planner / researcher / writer 多角色协作，支持网页检索、总结和报告输出 | 体现 Agent 架构、工具调用和任务编排能力 |
| 自定义 MCP Server + Agent 集成 | 自己实现一个 MCP server，让 Agent 能读取内部系统或数据库 | 体现协议理解、工具抽象与工程整合能力 |
| 参与主流 AI 框架开源贡献 | 给 LangChain、LlamaIndex、Dify 等提交 PR 或修文档 | 直接证明代码阅读、协作与社区参与能力 |

### 8.3 GitHub 主页优化清单

| 项目 | 建议 |
|------|------|
| Profile README | 写清你的方向、代表项目、联系方式、技术博客 |
| Pin 仓库 | 固定 4-6 个最能代表 AI Agent 能力的仓库 |
| 每个项目 README | 至少包含问题背景、架构图、运行方式、截图、评估结果、未来计划 |
| Commit 历史 | 保持连续输出，避免全是“一次性上传” |
| Issue / PR 痕迹 | 让别人看到你不仅会写代码，也会协作 |

### 8.4 技术博客写作建议

| 写作题材 | 示例标题 | 目的 |
|----------|----------|------|
| 踩坑复盘 | 《我把一个 RAG Demo 做成可评估系统时踩过的 7 个坑》 | 显示工程深度 |
| 源码拆解 | 《从源码看 LangGraph 的状态流转设计》 | 显示阅读能力 |
| 方案对比 | 《FAISS、Chroma、pgvector 在小型知识库场景下怎么选》 | 显示决策能力 |
| 面试总结 | 《AI Agent 面试里，面试官最爱追问的 12 个问题》 | 显示求职相关度 |

你不需要成为“大 V”才配写博客。相反，**越早公开记录，越容易积累复利。** 当你把学习过程变成公开资产，机会往往会主动来找你。

---

## 九、一个可直接照抄的资源搭配方案

如果你不想自己组合资源，我给你一套“低纠结版本”：

| 目标 | 资源组合 |
|------|----------|
| 理论基础 | 《动手学深度学习》 + CS224N 前几讲 + Attention / CoT / ReAct 三篇论文 |
| 应用开发 | AI Engineering + Hugging Face Course + LangChain / LangGraph 官方教程 |
| RAG 能力 | LlamaIndex 文档 + RAG 论文 + RAGFlow / QAnything 源码观摩 |
| 系统设计 | Designing ML Systems + 本书第 18 章 + 5 套设计题复盘 |
| 面试冲刺 | 本书第 17-19 章 + 作品集项目 + 模拟面试录音 |

如果你预算有限，就优先使用：

- Stanford、fast.ai、Hugging Face、LangChain 官方等免费资源
- 开源项目源码与社区讨论
- 自己动手做项目，替代“继续买更多课程”

转行最贵的从来不是课程费，而是**拖延成本**。

---

## 十、结语：别等“准备好了”，先开始建立你的新身份

AI Agent 领域仍然非常早期，这意味着规则还没有完全固化、岗位能力模型还在快速演进、优秀工程师仍然稀缺。对转行者来说，这不是坏消息，反而是非常珍贵的窗口期。越是早期赛道，越奖励那些肯补基础、能做项目、愿意公开表达、能把技术变成可交付结果的人。

你不需要一开始就掌握所有框架，也不需要在第一周就读懂所有论文。你真正需要的是：

- 先把基础打牢，因为基础变化最慢
- 先做出作品，因为作品最能证明能力
- 先加入社区，因为信息流会改变你的速度
- 先开始输出，因为公开表达会倒逼成长

请记住，框架会变、API 会变、热门词汇会变，但以下能力会长期保值：

1. 把模糊问题拆成可执行系统的能力
2. 把模型能力接到真实数据与真实工具上的能力
3. 评估一个 Agent 是否真的“有用、可靠、可控”的能力
4. 用工程方式交付、监控、迭代 AI 系统的能力

如果你已经读到这里，我想真诚地恭喜你：你不是在“随便看看 AI 热点”，你是在认真塑造自己的下一阶段职业身份。也许你还没有百分之百自信，也许你会担心自己起步晚、数学不够强、项目还不够亮眼——这些担心都很正常。但请相信，**持续 90 天的高质量投入，足以让一个成熟的软件工程师完成一次非常有竞争力的转身。**

去读书，去写代码，去提 PR，去做 Demo，去投出第一份简历，去和这个新世界发生真实连接。很多时候，职业转折点并不是“某一天突然准备好了”，而是“你决定从今天开始按路线图行动”。

愿你在下一个面试里，不只是回答问题的人，而是那个能让面试官感受到“这个人真的能把 AI Agent 做出来”的候选人。

---

## 本章要点

- 学习资源要围绕“输入—模仿—变形—输出—证明”形成闭环，而不是无止境囤课。
- 书单建议按短板组合阅读：ML/LLM 打底，Agent 应用、系统设计与 Python 工程能力并行推进。
- 在线课程优先选择官方与高质量免费资源，如 DeepLearning.AI、fast.ai、Hugging Face、Stanford、LangChain 官方教程。
- 必读论文至少掌握 Transformer、CoT、ReAct、RAG、Toolformer、LoRA、Constitutional AI、ToT、RAPTOR 与 Agent 架构综述。
- 开源项目是建立工程感的关键，重点关注 LangChain、LangGraph、LlamaIndex、AutoGen、CrewAI、Dify、RAGFlow 等。
- 建议建立长期信息雷达：官方文档、社区论坛、Discord、Reddit、中文技术社区和高质量创作者。
- 30/60/90 天路线图的核心是连续产出：第一个 RAG、可运行 Agent、完整作品集、模拟面试与简历投递。
- 简历与作品集要强调问题背景、技术方案、评估指标与实际结果，避免只堆名词。
- AI Agent 仍处早期窗口期，最重要的不是追最新框架，而是夯实基础、做出项目、持续公开输出。
