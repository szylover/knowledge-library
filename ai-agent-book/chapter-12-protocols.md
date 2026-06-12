# 第十二章：Agent 通信协议 — MCP 与 A2A

在 2023 年以前，几乎每个 Agent 系统都在做同一件低效的事：为每一个工具、每一个数据源、每一个协作 Agent 写一套自定义集成层。结果是：

- 工具接入方式不统一；
- 权限模型碎片化；
- 调试与可观测性割裂；
- 一个模型供应商切换就要重写大量胶水代码。

所以标准化协议的价值非常直接：**让 Agent 与工具、Agent 与 Agent 之间的接口，从“私有约定”变成“公开规范”**。这一章重点讲两个在 2025~2026 年最值得理解的协议：MCP 和 A2A。

## 12.1 为什么需要标准协议

没有协议时，一个“接天气工具 + 接搜索工具 + 接另一个 Agent”的系统，往往像这样：

```text
LLM
 |- custom HTTP wrapper for weather
 |- custom JSON parser for search
 |- custom websocket bridge for peer agent
 |- custom auth middleware
 |- custom logging format
```

这会造成至少四个问题：

1. **重复造轮子**：每接一个能力都要写 adapter；
2. **迁移成本高**：从一个框架切换到另一个框架几乎重来；
3. **安全难统一**：每个集成点自己做权限和审计；
4. **生态无法组合**：工具作者和 Agent 作者无法解耦。

MCP 解决的是“Agent 如何标准化连接工具和数据”；A2A 解决的是“Agent 之间如何标准化协作”。

## 12.2 MCP（Model Context Protocol）

### 12.2.1 背景

MCP（Model Context Protocol，模型上下文协议）最初由 Anthropic 推动，并在 2025 年捐赠给 Linux Foundation，目标是建立一种开放、供应商中立的 Agent ↔ Tool / Data 协议。

如果你熟悉浏览器世界，可以把 MCP 理解成“给 Agent 生态做的 USB-C 接口”：不同工具和数据源不再需要为每个 Agent 单独适配。

### 12.2.2 MCP 解决什么问题

MCP 面向的是 **vertical integration（纵向集成）**：

- Agent 访问本地文件；
- Agent 查询数据库；
- Agent 使用搜索服务；
- Agent 调用公司内部 API；
- Agent 读取 prompt 模板、资源文档。

也就是说，MCP 主要处理的是**Agent 与外部能力**之间的协议，而不是多个 Agent 之间的任务协作。

### 12.2.3 架构：Client-Server + JSON-RPC 2.0

MCP 的核心架构很清晰：

```text
 +------------------+          JSON-RPC 2.0           +-------------------+
 |  MCP Client      |  <--------------------------->  |  MCP Server       |
 |  (inside Agent)  |                                 |  tools/resources   |
 +------------------+                                 +-------------------+
```

Agent 侧通常内嵌一个 MCP Client；每个工具提供方实现一个 MCP Server。双方通过 JSON-RPC 2.0 通信，因此拥有：

- method
- params
- id
- result / error

这种设计的好处是通用、语言无关、可双向扩展。

### 12.2.4 MCP 的核心概念

MCP 里最重要的四类能力是：

| 概念 | 作用 | 例子 |
|---|---|---|
| Resources | 可读取资源 | 文件、文档、数据库记录 |
| Tools | 可执行动作 | 搜索、查询、写入、计算 |
| Prompts | 可复用提示模板 | 总结模板、代码审查模板 |
| Sampling | 由 server 反向请求模型能力 | 让 server 请求 client 进行模型推理 |

#### Resources

资源偏向“读”，可以理解为带 URI 的内容提供接口。比如：

- `file://docs/architecture.md`
- `db://orders/12345`

#### Tools

Tools 是动作入口。MCP server 会声明工具列表、参数 schema、描述信息，client 决定何时调用。

#### Prompts

Prompts 很适合做组织级模板沉淀。例如“生成周报”“复盘事故”“审查 Terraform 变更”等 prompt 可以集中托管在 server 上。

#### Sampling

Sampling 很有意思：它允许 server 反过来请求 client 触发一次模型推理。这让一些“工具增强型服务”可以在协议里和模型双向协作，而不只是被动执行命令。

### 12.2.5 传输方式

MCP 常见三种 transport（传输）：

| Transport | 适合场景 | 特点 |
|---|---|---|
| stdio | 本地桌面应用、本地工具进程 | 简单、低延迟、部署轻 |
| HTTP + SSE | 远程服务、浏览器集成 | 易穿透网络、支持服务化 |
| WebSocket | 实时双向会话 | 适合长连接与事件流 |

工程上怎么选？

- 本地开发工具：stdio 最方便；
- 企业服务平台：HTTP+SSE 更容易接网关；
- 实时协作系统：WebSocket 更自然。

### 12.2.6 工具如何声明能力

一个 MCP tool 通常声明：

- name
- description
- inputSchema

本质与 OpenAI function calling 很像，但 MCP 把这个“工具声明 + 调用 + 返回”包装成标准协议流程，而不是某个模型厂商的私有 API 细节。

### 12.2.7 Agent 如何发现并调用工具

发现流程通常是：

1. client 连接 server；
2. 请求列出可用 tools / resources / prompts；
3. 将能力映射为 Agent 可用上下文；
4. 当模型需要时，由 client 发起 tool invocation。

这意味着一个 Agent 不需要预埋所有工具细节，只要能说“列出能力并按 schema 调用”即可。

### 12.2.8 安全模型

MCP 安全要点：

- server 只暴露必要能力；
- client 需要明确用户授权；
- 敏感资源必须做 ACL；
- 工具调用要记录审计日志；
- 对写操作增加审批或沙箱；
- transport 层做好认证和 TLS。

很多人误以为“标准协议 = 自动安全”。实际上协议只统一了接口，不会替你做权限建模。

## 12.3 Python：实现一个简单 MCP Server 与 Client

下面我们用最简化方式模拟一个 MCP 风格服务。重点不是复刻完整规范，而是理解 JSON-RPC 2.0 + capability discovery + tool invoke 的骨架。

### 12.3.1 服务器示例

```python
import json
from typing import Any, Dict


TOOLS = {
    "echo": {
        "description": "回显输入文本",
        "inputSchema": {
            "type": "object",
            "properties": {
                "text": {"type": "string"}
            },
            "required": ["text"]
        }
    },
    "add": {
        "description": "计算两个整数之和",
        "inputSchema": {
            "type": "object",
            "properties": {
                "a": {"type": "integer"},
                "b": {"type": "integer"}
            },
            "required": ["a", "b"]
        }
    }
}


def handle_request(req: Dict[str, Any]) -> Dict[str, Any]:
    method = req["method"]
    req_id = req.get("id")

    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "tools": [
                    {"name": name, **meta}
                    for name, meta in TOOLS.items()
                ]
            }
        }

    if method == "tools/call":
        name = req["params"]["name"]
        arguments = req["params"]["arguments"]

        if name == "echo":
            result = {"text": arguments["text"]}
        elif name == "add":
            result = {"sum": arguments["a"] + arguments["b"]}
        else:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32601, "message": f"Unknown tool: {name}"}
            }

        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {"content": result}
        }

    return {
        "jsonrpc": "2.0",
        "id": req_id,
        "error": {"code": -32601, "message": f"Unknown method: {method}"}
    }


if __name__ == "__main__":
    print("Enter JSON-RPC request, one line at a time:")
    while True:
        try:
            line = input().strip()
            if not line:
                continue
            req = json.loads(line)
            print(json.dumps(handle_request(req), ensure_ascii=False))
        except EOFError:
            break
```

### 12.3.2 客户端示例

```python
import json
import subprocess


def send(proc: subprocess.Popen, payload: dict) -> dict:
    proc.stdin.write(json.dumps(payload, ensure_ascii=False) + "\n")
    proc.stdin.flush()
    response = proc.stdout.readline()
    return json.loads(response)


if __name__ == "__main__":
    proc = subprocess.Popen(
        ["python", "mcp_server.py"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )

    tools = send(proc, {"jsonrpc": "2.0", "id": 1, "method": "tools/list"})
    print("TOOLS:", json.dumps(tools, ensure_ascii=False, indent=2))

    result = send(
        proc,
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "add",
                "arguments": {"a": 7, "b": 35}
            }
        }
    )
    print("CALL RESULT:", json.dumps(result, ensure_ascii=False, indent=2))

    proc.terminate()
```

虽然这个例子很小，但你已经能看到 MCP 的关键动作：

1. 发现能力：`tools/list`
2. 结构化调用：`tools/call`
3. JSON-RPC 标准化响应

## 12.4 A2A（Agent-to-Agent）Protocol

### 12.4.1 背景

A2A（Agent-to-Agent）协议主要由 Google 推动，后续与 IBM 的 ACP（Agent Communication Protocol）方向融合，目标是建立**Agent ↔ Agent** 的标准协作方式。

如果 MCP 解决的是“怎么连工具”，那 A2A 解决的是“怎么找别的 Agent 帮忙、怎么描述能力、怎么跟踪任务生命周期、怎么做认证”。

### 12.4.2 A2A 的定位

A2A 面向的是 **horizontal integration（横向集成）**：

- Research Agent 委托 Coding Agent 做实现；
- Customer Support Agent 请求 Billing Agent 查询账单；
- Orchestrator 找到一个具备“法律摘要”能力的外部 Agent 并下发任务。

### 12.4.3 Agent Card：能力广告

Agent Card 可以理解为 Agent 的自我介绍卡片，通常是 JSON 格式，描述：

- agent name
- description
- supported skills
- input/output formats
- auth requirements
- endpoint
- version

示意：

```json
{
  "name": "research-agent",
  "description": "擅长技术资料检索与事实整理",
  "skills": ["web_search", "fact_extraction", "source_citation"],
  "input_format": "task",
  "output_format": "report",
  "auth": {
    "type": "oauth2.1",
    "scopes": ["tasks.read", "tasks.write"]
  },
  "endpoint": "https://agents.example.com/research",
  "version": "1.0.0"
}
```

有了 Agent Card，别的 Agent 不需要事先硬编码“research-agent 能做什么”，而可以动态发现。

### 12.4.4 任务生命周期

A2A 中很关键的是 task lifecycle（任务生命周期）：

```text
create -> assign -> in_progress -> needs_input? -> complete / failed / cancelled
```

这和工具调用最大的不同在于：A2A 任务通常是**长时、异步、可跟踪**的。

例如：

1. Supervisor 创建任务；
2. 指派给 Research Agent；
3. Research Agent 每 10 秒回报进度；
4. 完成后上传结果与证据链接；
5. 若失败，附错误码与建议。

### 12.4.5 认证：OAuth 2.1

因为 Agent 调 Agent 往往跨服务、跨团队、甚至跨组织，因此 A2A 常依赖 OAuth 2.1 做认证授权：

- 谁在代表谁发请求；
- 拥有哪些 scope；
- token 多久过期；
- 是否允许委托链。

这比“内网默认信任”安全得多，也更符合未来 Agent 服务化部署的方向。

### 12.4.6 发现机制

发现（discovery）可以来自：

- 固定注册中心；
- Agent Catalog；
- 通过 URL 获取 Agent Card；
- 企业服务目录。

一个成熟 A2A 生态，应该允许：

1. 先找到某类能力的 Agent；
2. 判断其认证要求；
3. 创建任务；
4. 跟踪任务状态；
5. 拿到最终结果。

## 12.5 MCP vs A2A：两者不是竞争，而是互补

### 12.5.1 核心区别

| 维度 | MCP | A2A |
|---|---|---|
| 方向 | 垂直（Agent 到工具/数据） | 水平（Agent 到 Agent） |
| 目标对象 | Tools / Resources / Prompts | Peer Agents |
| 调用粒度 | 通常较细，单次工具调用 | 通常较粗，任务级协作 |
| 时长 | 可短可中 | 更偏长时异步 |
| 认证重点 | 工具与资源访问控制 | 服务间身份与任务授权 |

一句话总结：

- **MCP = 我怎么用工具**
- **A2A = 我怎么找同伴**

### 12.5.2 现代 Agent 技术栈中的位置

```text
                    +------------------------------------+
                    |            User / App              |
                    +----------------+-------------------+
                                     |
                                     v
                    +----------------+-------------------+
                    |        Orchestrator Agent          |
                    +-----------+------------+-----------+
                                |            |
                        A2A     |            |    A2A
                                v            v
                     +----------+--+      +--+-----------+
                     | Research    |      | Coding Agent |
                     | Agent       |      | / Reviewer   |
                     +------+------+\     +------+-------+
                            |             |
                            | MCP         | MCP
                            v             v
                 +----------+---+   +-----+-----------+
                 | Search Server |   | File / DB Tool |
                 | Docs Resource |   | Internal APIs  |
                 +-------------- +   +----------------+
```

你会发现，在生产系统中它们完全可以同时存在：

- 上层 Agent 之间用 A2A；
- 每个 Agent 内部访问工具和数据源用 MCP。

## 12.6 实践集成示例

假设你要做一个“投研助理”系统：

1. Supervisor Agent 接收“分析某公司最新财报”；
2. 通过 A2A 找到 Financial Research Agent；
3. Research Agent 再通过 MCP 调用：
   - 财报文档资源；
   - 股票价格 API 工具；
   - 财务指标计算工具；
4. 结果交给 Report Agent；
5. Report Agent 输出报告，再通过 MCP 写入内部文档系统。

这个例子很能体现两类协议的分工：

- A2A 负责**找谁做事**；
- MCP 负责**怎么访问能力**。

## 12.7 面试中如何讲协议

如果面试官问：“MCP 和 A2A 有什么区别？为什么需要两个协议？”

一个高质量回答可以是：

> MCP 面向 Agent 到工具/数据的标准化接入，解决 capability discovery、schema-based invocation 和资源访问问题；A2A 面向 Agent 之间的任务级协作，解决能力广告、任务生命周期、认证授权与进度跟踪问题。一个偏垂直集成，一个偏水平协作，生产系统里通常会同时使用。

如果再追问“你会如何落地？”

可以补充：

- 工具与知识库统一接 MCP；
- 多角色 Agent 通过 A2A 编排；
- 敏感工具走审批；
- 所有调用带 trace id；
- 会话状态和任务状态分层存储。

## 12.8 一个更细的 MCP 交互流程

如果把 MCP 放到工程实现里，可以把一次典型交互拆成下面 6 步：

1. **连接（connect）**：client 通过 stdio、HTTP+SSE 或 WebSocket 连上 server；
2. **初始化（initialize）**：双方交换版本、能力、会话信息；
3. **能力发现（discover）**：client 请求 tools/resources/prompts 列表；
4. **选择与调用（select & invoke）**：Agent 根据当前任务选择某个 tool；
5. **结果归约（reduce）**：tool 返回结构化结果，client 摘要后写入上下文；
6. **审计与关闭（audit & close）**：记录日志，必要时断开连接。

把这个流程画成 ASCII：

```text
Agent
  |
  | 1. connect
  v
MCP Client ----------------------> MCP Server
  |                                   |
  | 2. initialize                     |
  |<--------------------------------->|
  | 3. tools/list                     |
  |---------------------------------->|
  |<----------- tools metadata -------|
  | 4. tools/call                     |
  |---------------------------------->|
  |<----------- tool result ----------|
  | 5. context reduce                 |
  v
Next reasoning step
```

这里面最容易被忽视的是第 5 步。如果不做 result reduce，MCP 工具越多、返回越大，模型上下文越容易失控。所以协议标准化只是第一步，**上下文治理仍然是 Agent 自己的责任**。

## 12.9 A2A 任务对象应该长什么样

A2A 真正落地时，不能只说“把任务发给另一个 Agent”，而要有足够明确的任务对象。一个实用 JSON 可以包含：

```json
{
  "task_id": "task-001",
  "goal": "分析某公司财报并输出风险摘要",
  "input": {
    "ticker": "XYZ",
    "report_url": "https://example.com/report.pdf"
  },
  "constraints": {
    "deadline_seconds": 60,
    "max_cost_usd": 0.8,
    "need_citations": true
  },
  "callback": {
    "progress_url": "https://orchestrator.example.com/progress/task-001"
  }
}
```

这样设计的意义在于：

- goal 告诉对方最终目标；
- input 告诉它起始材料；
- constraints 告诉它时间、成本、质量边界；
- callback 告诉它如何汇报。

任务状态更新也最好结构化，例如：

| 状态 | 含义 |
|---|---|
| created | 任务已创建但未开始 |
| accepted | 目标 Agent 已接单 |
| in_progress | 正在执行 |
| blocked | 缺输入、缺权限或等待外部资源 |
| completed | 正常完成 |
| failed | 失败并附错误 |
| cancelled | 被上游取消 |

注意 `blocked` 非常重要。没有这个状态，很多系统只能在“还没完成”和“已经失败”之间摇摆，导致编排器无法做正确超时策略。

## 12.10 从自定义集成迁移到协议化架构

很多团队已经有一套“能跑”的 Agent 系统，如何迁到 MCP / A2A？最稳妥的路线通常不是推倒重来，而是三步走：

### 第一步：抽象内部能力描述

先把已有工具统一成：

- 名称；
- 描述；
- schema；
- 权限；
- owner。

哪怕暂时还没上 MCP，这一步也会立刻提升治理质量。

### 第二步：先协议化高复用能力

优先把最常用、最稳定、最有复用价值的能力包装成 MCP server，例如：

- 文档检索；
- 数据库只读查询；
- 文件读取；
- 搜索服务。

不要一开始就拿最危险的“生产发布工具”做试点。

### 第三步：再引入 A2A 做服务化协作

当团队里已经有多个独立 Agent 服务，例如研究 Agent、报告 Agent、代码修复 Agent，这时再用 A2A 统一发现、认证和任务管理，会比一开始就上更自然。

迁移时常见坑包括：

1. **把协议当成框架替代品**：协议解决互通，不解决你的业务状态机；
2. **工具 schema 写得过于宽泛**：模型仍然会乱传参数；
3. **没有 trace id**：跨 Agent、跨 MCP server 后无法排查链路；
4. **忽略权限继承问题**：上游 Agent 代用户调用下游时，必须明确用谁的身份、带哪些 scope。

## 12.11 一个现代 Agent 平台的最小落地建议

如果你所在团队在 2026 年要从零做平台，我建议的最小组合是：

- Agent 内部工具接入优先采用 MCP；
- 长任务和专业角色协作采用 A2A；
- 所有调用都带 trace id 与 task id；
- 只读能力先开放，写能力后开放；
- 每条任务都要有超时、成本预算和取消机制；
- 结果统一沉淀到可审计日志与共享状态层。

这样做的好处是，你可以先获得“标准接口”的收益，而不必一次性解决所有复杂问题。

## 12.12 协议之外仍需自己解决的问题

理解协议很重要，但也要知道协议不能替你解决什么。无论 MCP 还是 A2A，都不会自动帮你处理：

1. 业务状态机；
2. 成本控制；
3. 结果质量评估；
4. Prompt 设计；
5. 人类审批链路；
6. 组织内部权限模型映射。

这也是很多团队常见误区：以为“接上协议”就等于“系统工程化完成”。实际上，协议只统一通信接口，真正决定上线质量的仍然是你的状态管理、治理策略和监控体系。

## 12.13 面试中怎么讲一个完整方案

如果面试官问：“请设计一个支持工具调用和多 Agent 协作的企业 Agent 平台。”  
你可以这样回答：

第一层是用户接入与编排层，由 Supervisor Agent 接收任务、分配预算、维护 trace id 和 task id。  
第二层是协作层，多个专业 Agent 之间通过 A2A 交换 Agent Card、创建任务、同步进度。  
第三层是能力层，每个 Agent 内部通过 MCP 接入文件、数据库、搜索和内部 API。  
第四层是治理层，统一做认证、审计、成本统计、审批与可观测性。  
第五层是状态层，保存会话状态、任务状态、长期记忆和证据链。

这样的答案之所以有效，是因为它把协议放回了整体系统，而不是孤立背概念。

## 12.14 三个高频踩坑点

### 一、把工具调用和任务委托混为一谈

有些团队让一个 Agent 调另一个 Agent 时，仍然沿用工具式同步调用接口。结果长任务、进度跟踪、取消控制都做不出来。工具调用和任务委托在粒度上就是两件事。

### 二、忽略身份传递

当上游 Agent 代表用户去调用下游 Agent 或 MCP server 时，必须明确：

- 当前是谁发起；
- 代表哪个用户；
- 拥有哪些 scope；
- 审计日志记到谁头上。

如果这层没做好，后面几乎无法合规。

### 三、没有统一可观测性

一个任务可能跨：

- 1 个 Orchestrator；
- 3 个协作 Agent；
- 5 个 MCP 工具服务。

如果没有统一 trace id，就无法把这条链路串起来。协议标准化后，链路追踪反而比以前更重要，而不是更不重要。

## 12.15 一个组合案例：企业代码助手平台

设想你在公司内部做一个代码助手平台，目标是：

- 开发者提问时能读取仓库文件、搜索文档、运行测试；
- 复杂任务时能委托给“测试 Agent”“文档 Agent”“重构 Agent”；
- 所有动作都有权限控制和审计。

这时最自然的架构就是：

1. 主对话 Agent 通过 MCP 连接代码搜索、文件读取、测试运行等工具；
2. 当任务复杂到需要分工时，主 Agent 通过 A2A 委托给其他专业 Agent；
3. 每个专业 Agent 内部仍然通过 MCP 获取自己所需工具；
4. 统一治理层负责 OAuth、审计日志、成本看板和人工审批。

这个案例能很好说明两类协议的互补：  
MCP 让“能力接入”标准化，A2A 让“协作编排”标准化。缺任何一个，系统都能做，但都会更碎、更难维护。

## 12.16 2026 年你该如何学习这两类协议

建议顺序不是先背规范，而是先做三个层次的实践：

### 第一层：本地玩具项目

自己写一个最简单的 MCP server，暴露两个工具；再写一个 client 去发现并调用它。目的不是做产品，而是把 JSON-RPC、schema 和调用流程真正跑通。

### 第二层：把现有工具协议化

选你最熟悉的工具场景，比如文件读取、数据库查询、内部搜索，把原来散落在 Agent 代码里的函数抽出来，用统一元数据定义。到这一步，你就会真正理解“标准接口”为什么重要。

### 第三层：尝试任务级协作

再做一个两 Agent 或三 Agent 的小系统，让主 Agent 把任务发给副 Agent，并追踪状态、处理超时、汇总结果。做到这里，你基本就能分清 MCP 与 A2A 的职责边界了。

很多候选人死记概念，但没有亲手跑过一次 discovery、一次 task lifecycle。面试时一追问就露馅。你只要做过这三个层次的小实验，理解会扎实很多。

## 12.17 一个面试中的总结句式

如果你只能用一句话概括这章内容，可以这样说：  
**MCP 负责把 Agent 和能力世界连起来，A2A 负责把 Agent 和 Agent 的协作世界连起来；前者解决“怎么用”，后者解决“找谁做”，二者叠加后才构成现代 Agent 平台的通信底座。**  
这句话短，但非常适合在面试回答结尾收束全章逻辑。

如果面试时间允许，再补一句更工程化的话：协议让互操作成为可能，但真正的竞争力仍然来自你如何设计工具边界、任务状态、权限继承和可观测性。这句补充能帮助你把“懂规范”提升到“懂系统”。
标准协议提供共同语言，但系统质量仍然取决于你如何把这门语言说清楚、管起来、跑稳定。
因此，学习协议的最好方式永远不是背术语，而是亲手完成一次能力发现、一次任务委托、一次失败回溯和一次链路追踪。
只有真正跑通过链路，你才会理解协议设计背后的工程取舍。
再强调一次，协议化最重要的价值不是“看起来先进”，而是把原本隐含在代码里的假设显式化：能力如何发现、参数如何约束、身份如何传递、任务如何结束、错误如何表达、日志如何串联。当这些问题有了共同语言，团队协作、平台演进和跨供应商迁移才真正有了工程基础。
因此，真正懂协议的人，关注的从来不只是字段格式，而是字段背后的系统边界与组织协作方式。
只有把协议放回系统上下文里理解，它才真正有价值。
否则，协议知识就会退化成一堆记不住、也用不起来的名词表。
而当你能把协议与身份、权限、任务状态、日志链路和平台演进联系起来时，它们就会从“知识点”变成真正可落地的系统设计工具。
这也是协议章节在面试里特别容易区分候选人深度的原因。
因为会背名词很容易，但能说清协议如何支撑真实协作、真实权限和真实运维的人并不多。
这也是为什么你在学习 MCP 与 A2A 时，最好始终把它们放在“平台演进”和“系统协作”的大图里理解。

## 本章要点

- 在协议出现之前，Agent 生态的主要问题是集成碎片化、迁移困难和安全模型不统一。
- MCP 主要解决 Agent 到工具/数据的标准化连接，底层常用 JSON-RPC 2.0。
- MCP 的核心概念包括 Resources、Tools、Prompts 和 Sampling，常见传输是 stdio、HTTP+SSE、WebSocket。
- A2A 主要解决 Agent 到 Agent 的协作，强调 Agent Card、任务生命周期、发现机制和 OAuth 2.1 认证。
- MCP 与 A2A 是互补关系：前者偏垂直能力接入，后者偏水平协同编排。
- 面试中解释这两个协议时，重点不是背定义，而是讲清楚“谁和谁通信、通信粒度、生命周期、认证模型”。

## 延伸阅读

1. Model Context Protocol 官方规范与 SDK 文档
2. Linux Foundation 关于 MCP 治理与生态材料
3. Google A2A / IBM ACP 相关公开资料
4. JSON-RPC 2.0 规范
5. OAuth 2.1 与 service-to-service authorization 最佳实践
