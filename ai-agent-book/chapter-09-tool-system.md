# 第九章：工具系统设计

如果把 LLM 看作“大脑”，那么工具系统（tool system）就是 Agent 的手、脚、眼睛和神经末梢。没有工具，模型只能在参数记忆里生成文本；有了工具，它才能访问实时世界、操作外部系统、执行确定性计算、调用企业能力。生产级 Agent 的上限，往往不是模型本身，而是**工具系统设计是否规范、可控、可扩展、可观测**。

本章会从工具分类、注册表设计、输入输出规范、安全模型、错误恢复讲起，最后实现一套完整 Python 工具系统。

## 9.1 为什么工具对 Agent 至关重要

LLM 有三个先天限制：

1. **知识过期**：训练截止之后的新数据不知道；
2. **执行不确定**：数学、代码、数据库写入等任务不能只靠“猜”；
3. **无法直接改变外部世界**：不能自己发邮件、写文件、调用业务 API。

工具恰好补这三个洞：

| LLM 限制 | 对应工具能力 | 例子 |
|---|---|---|
| 不知道实时信息 | 信息检索工具 | Web Search、内部搜索、数据库查询 |
| 不能稳定做确定性计算 | 计算工具 | Calculator、Python Sandbox |
| 不能操作外部系统 | 动作工具 | 发消息、建工单、写文件、调用 CRM API |

所以，Agent 工程并不是“让模型更聪明”，而是“让模型在受控边界内调度正确工具”。

## 9.2 工具分类（Tool Taxonomy）

### 9.2.1 信息检索工具

Information Retrieval Tools（信息检索工具）负责把“外部事实”带入上下文。

常见类型：

- 搜索引擎查询；
- 企业知识库检索；
- SQL / NoSQL 数据库查询；
- 第三方 API 读取；
- 网页抓取。

例子：

| 工具 | 输入 | 输出 | 典型延迟 |
|---|---|---|---|
| `search_web` | query | 搜索摘要列表 | 300ms~2s |
| `query_orders` | order_id / user_id | 订单记录 | 20ms~200ms |
| `fetch_doc` | doc_id | 文档全文 | 50ms~500ms |

### 9.2.2 动作工具

Action Tools（动作工具）会改变外部系统状态，因此风险最高。

典型动作：

- 发送邮件；
- 创建 GitHub issue；
- 执行部署脚本；
- 写入数据库；
- 修改文件。

这类工具一定要加权限和审批，后面会详细展开。

### 9.2.3 计算工具

Computation Tools（计算工具）处理确定性逻辑，最典型的是：

- 计算器；
- Python 代码执行器；
- 数据分析脚本；
- 规则引擎。

一个经验法则：**凡是你希望结果 100% 可重复、可验证，就尽量让工具算，不要让模型猜。**

### 9.2.4 通信工具

Communication Tools（通信工具）常被初学者忽略，但在多 Agent 和企业自动化场景中非常关键。

例如：

- `notify_user`
- `send_slack_message`
- `delegate_to_research_agent`
- `request_human_approval`

当系统具备这些能力后，Agent 不再是孤立模型，而变成组织流程里的协作节点。

## 9.3 设计一套工具系统

一个成熟工具系统通常包含以下层次：

```text
+------------------------+
| Tool Selection by LLM  |
+------------------------+
           |
           v
+------------------------+
| Tool Registry          |
| - metadata             |
| - schema               |
| - permission           |
+------------------------+
           |
           v
+------------------------+
| Validation Layer       |
| Pydantic / Zod         |
+------------------------+
           |
           v
+------------------------+
| Runtime Executor       |
| retry / timeout / log  |
+------------------------+
           |
           v
+------------------------+
| Standardized Result    |
+------------------------+
```

### 9.3.1 Tool Registry Pattern（工具注册表模式）

注册表的作用，是把工具定义与执行逻辑统一管理。不要在代码里到处 `if tool_name == ...`，而是用中心注册：

```python
registry.register(tool)
tool = registry.get("search_web")
result = tool.execute(args)
```

注册表至少应保存：

- 名称；
- 描述；
- 参数 schema；
- 权限级别；
- 超时时间；
- 处理函数；
- 是否幂等；
- 是否允许并行。

### 9.3.2 OpenAI Function Format 与 Anthropic Tool Format

两家格式不同，但本质一样：都要求把工具描述为结构化 schema。

OpenAI 风格：

```json
{
  "type": "function",
  "function": {
    "name": "query_weather",
    "description": "查询天气",
    "parameters": {
      "type": "object",
      "properties": {
        "city": {"type": "string"}
      },
      "required": ["city"]
    }
  }
}
```

Anthropic 风格更接近：

```json
{
  "name": "query_weather",
  "description": "查询天气",
  "input_schema": {
    "type": "object",
    "properties": {
      "city": {"type": "string"}
    },
    "required": ["city"]
  }
}
```

工程上建议内部维护**统一中间表示**，再映射到不同模型厂商格式，避免业务代码直接依赖某一家 SDK。

### 9.3.3 输入校验：Pydantic / Zod

Python 里优先推荐 Pydantic，TypeScript 里常用 Zod。原因很简单：自然语言输入并不可靠，模型生成的 JSON 也不总是可靠。

一个常见错误：

```json
{"days": "tomorrow"}
```

而 schema 明明要求 integer。没有校验层，错误会直接传到下游 API。

### 9.3.4 输出标准化

工具输出必须统一，不然上层 Agent 很难做通用错误处理。推荐结构：

```python
{
    "ok": True,
    "data": {...},
    "error": None,
    "meta": {
        "latency_ms": 182,
        "tool_name": "query_weather"
    }
}
```

若失败：

```python
{
    "ok": False,
    "data": None,
    "error": {
        "type": "validation_error",
        "message": "field 'city' is required",
        "retryable": True
    },
    "meta": {...}
}
```

## 9.4 安全设计：别让 Agent 拿着 root 权限到处跑

工具系统的第一原则不是“强大”，而是“可控”。

### 9.4.1 代码执行工具必须沙箱化

Code Interpreter（代码解释器）类工具风险极高。最低要求包括：

- CPU / memory 限制；
- 执行超时；
- 文件系统隔离；
- 网络白名单；
- 禁止访问宿主机敏感路径；
- 进程级审计日志。

即使你只是给“数据分析 Agent”一个 Python 执行器，也不要默认它安全。

### 9.4.2 权限级别

推荐至少分三级：

| 级别 | 说明 | 示例 |
|---|---|---|
| Read-only | 只能读 | 搜索、查库、读文件 |
| Read-write | 可改数据但范围受限 | 写工作目录、创建草稿邮件 |
| Admin | 高风险操作 | 删除资源、生产发布、转账 |

在生产环境里，Agent 默认应该只有 read-only 权限；升级到 read-write 需要显式授权；admin 必须 human approval（人工批准）。

### 9.4.3 危险动作的人类审批

Human-in-the-Loop（人类在环）通常在以下场景强制插入：

- 删除文件超过 10 个；
- 发送邮件给外部客户；
- 创建生产环境变更；
- 批量数据库更新；
- 单次成本超过设定阈值，比如 50 元人民币或 10 美元。

审批消息要包含：

- Agent 想做什么；
- 影响对象；
- 回滚方式；
- 成本和风险。

### 9.4.4 速率限制与成本控制

工具层一定要做 rate limiting（速率限制）和 budget control（预算控制）。

示例策略：

- 单用户每分钟最多 20 次搜索；
- 单会话最多 5 次网页抓取；
- 单日第三方 API 成本封顶 200 元；
- 单次 Agent Loop 最多 12 个工具调用。

## 9.5 错误处理：要让模型“有机会自救”

好的错误处理，不只是 try/except，而是要把错误信息变成对模型有帮助的反馈。

### 9.5.1 指数退避重试

Exponential Backoff（指数退避）适合处理临时失败：

- 第 1 次失败后等待 0.5 秒；
- 第 2 次等待 1 秒；
- 第 3 次等待 2 秒；
- 最多 3~5 次。

适用于：

- 429 Too Many Requests
- 网络抖动
- 短暂 5xx

不适用于：

- 401 未授权
- 参数错误
- 权限拒绝

### 9.5.2 优雅降级

如果网页抓取失败，不代表整个任务失败。可以：

1. 改用搜索摘要；
2. 缩小返回结果；
3. 告诉用户“基于可访问数据给出近似结论”。

生产级系统不追求“所有情况下都完美成功”，而追求“在失败时仍然可用”。

### 9.5.3 让错误信息帮助模型自修正

差的错误信息：

```text
error
```

好的错误信息：

```text
ValidationError: field 'days' must be integer between 1 and 7. Received value: "tomorrow".
```

模型看到这种错误，就有机会在下一轮修正参数。你会发现，**错误消息本身也是 Prompt 设计的一部分**。

## 9.6 逐步构建自定义工具

下面我们设计 4 个常见工具。

### 9.6.1 天气 API 工具

适用场景：天气查询、出行建议、日程提醒。

设计要点：

- 输入：城市、天数；
- 校验：天数 1~7；
- 输出：标准化天气列表；
- 错误：城市不存在、API 超时。

### 9.6.2 数据库查询工具

适用场景：查询订单、工单、用户信息。

关键原则：

- 默认只允许 `SELECT`；
- 参数化查询；
- 限制返回行数，如最多 100；
- 禁止模型直接拼接原始 SQL 写入生产库。

### 9.6.3 网页抓取工具

抓取工具常见坑：

- 页面 JS 渲染拿不到内容；
- robots.txt 限制；
- 反爬与验证码；
- 页面太长导致上下文爆炸。

所以输出最好做：

- 标题；
- 主体文本前 3000 字；
- 关键链接；
- 抓取状态码；
- 抽取时间戳。

### 9.6.4 带安全护栏的文件系统工具

文件系统工具是最容易“伤到自己”的一类工具。

安全护栏至少包括：

- 只能访问指定工作目录；
- 禁止 `..` 路径逃逸；
- 删除必须二次确认；
- 单次写入大小限制；
- 二进制文件默认拒绝。

## 9.7 完整 Python 工具系统实现

下面实现一套可运行的 Python 工具系统。它包含：

- 工具注册表；
- Pydantic 参数校验；
- 权限控制；
- 标准化结果；
- 重试机制；
- 4 个示例工具。

```python
from __future__ import annotations

import json
import sqlite3
import time
from pathlib import Path
from typing import Any, Callable, Dict, Literal, Optional, Type

import requests
from pydantic import BaseModel, Field, ValidationError


PermissionLevel = Literal["read_only", "read_write", "admin"]


class ToolResult(BaseModel):
    ok: bool
    data: Optional[Any] = None
    error: Optional[Dict[str, Any]] = None
    meta: Dict[str, Any] = Field(default_factory=dict)


class ToolSpec(BaseModel):
    name: str
    description: str
    permission: PermissionLevel = "read_only"
    timeout_seconds: int = 10
    allow_parallel: bool = True


class RegisteredTool:
    def __init__(
        self,
        spec: ToolSpec,
        input_model: Type[BaseModel],
        handler: Callable[[BaseModel], Any],
    ) -> None:
        self.spec = spec
        self.input_model = input_model
        self.handler = handler

    def openai_schema(self) -> Dict[str, Any]:
        return {
            "type": "function",
            "function": {
                "name": self.spec.name,
                "description": self.spec.description,
                "parameters": self.input_model.model_json_schema(),
            },
        }


class ToolRegistry:
    def __init__(self) -> None:
        self._tools: Dict[str, RegisteredTool] = {}

    def register(self, tool: RegisteredTool) -> None:
        self._tools[tool.spec.name] = tool

    def get(self, name: str) -> RegisteredTool:
        if name not in self._tools:
            raise KeyError(f"Unknown tool: {name}")
        return self._tools[name]

    def list_openai_tools(self) -> list[Dict[str, Any]]:
        return [tool.openai_schema() for tool in self._tools.values()]


def execute_with_retry(func: Callable[[], Any], retries: int = 3, base_delay: float = 0.5) -> Any:
    for attempt in range(retries):
        try:
            return func()
        except requests.RequestException:
            if attempt == retries - 1:
                raise
            time.sleep(base_delay * (2 ** attempt))


class WeatherInput(BaseModel):
    city: str = Field(min_length=1, description="城市名称")
    days: int = Field(ge=1, le=7, description="预测天数，1到7")


class DbQueryInput(BaseModel):
    sql: str = Field(description="只允许 SELECT 查询")
    limit: int = Field(default=20, ge=1, le=100)


class WebScrapeInput(BaseModel):
    url: str


class FileWriteInput(BaseModel):
    relative_path: str
    content: str


def weather_handler(inp: WeatherInput) -> Dict[str, Any]:
    # 示例中用模拟数据代替真实 API
    data = [
        {"day": 1, "temp_c": 28, "rain_prob": 0.1},
        {"day": 2, "temp_c": 30, "rain_prob": 0.3},
        {"day": 3, "temp_c": 27, "rain_prob": 0.6},
    ][: inp.days]
    return {"city": inp.city, "forecast": data}


def db_handler(inp: DbQueryInput) -> Dict[str, Any]:
    sql_upper = inp.sql.strip().upper()
    if not sql_upper.startswith("SELECT"):
        raise ValueError("Only SELECT statements are allowed")

    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE orders(id INTEGER, user TEXT, amount REAL)")
    conn.executemany(
        "INSERT INTO orders VALUES(?, ?, ?)",
        [(1, "alice", 199.0), (2, "bob", 88.5), (3, "alice", 299.9)],
    )
    rows = conn.execute(f"{inp.sql} LIMIT {inp.limit}").fetchall()
    return {"rows": rows, "count": len(rows)}


def scrape_handler(inp: WebScrapeInput) -> Dict[str, Any]:
    response = execute_with_retry(lambda: requests.get(inp.url, timeout=8))
    text = response.text[:3000]
    return {
        "status_code": response.status_code,
        "content_preview": text,
        "content_length": len(response.text),
    }


SAFE_ROOT = Path("workspace").resolve()
SAFE_ROOT.mkdir(exist_ok=True)


def file_write_handler(inp: FileWriteInput) -> Dict[str, Any]:
    target = (SAFE_ROOT / inp.relative_path).resolve()
    if SAFE_ROOT not in target.parents and target != SAFE_ROOT:
        raise ValueError("Path escapes safe root")
    if len(inp.content.encode("utf-8")) > 100_000:
        raise ValueError("Content too large")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(inp.content, encoding="utf-8")
    return {"written_to": str(target), "size": len(inp.content)}


class ToolRuntime:
    def __init__(self, registry: ToolRegistry, granted_permission: PermissionLevel = "read_only") -> None:
        self.registry = registry
        self.granted_permission = granted_permission
        self.order = {"read_only": 1, "read_write": 2, "admin": 3}

    def execute(self, tool_name: str, arguments: Dict[str, Any]) -> ToolResult:
        started = time.perf_counter()
        try:
            tool = self.registry.get(tool_name)

            if self.order[self.granted_permission] < self.order[tool.spec.permission]:
                return ToolResult(
                    ok=False,
                    error={
                        "type": "permission_denied",
                        "message": f"{tool_name} requires {tool.spec.permission}",
                        "retryable": False,
                    },
                    meta={"tool_name": tool_name},
                )

            validated = tool.input_model(**arguments)
            data = tool.handler(validated)
            return ToolResult(
                ok=True,
                data=data,
                meta={
                    "tool_name": tool_name,
                    "latency_ms": round((time.perf_counter() - started) * 1000, 2),
                },
            )
        except ValidationError as exc:
            return ToolResult(
                ok=False,
                error={
                    "type": "validation_error",
                    "message": exc.errors(),
                    "retryable": True,
                },
                meta={"tool_name": tool_name},
            )
        except Exception as exc:
            return ToolResult(
                ok=False,
                error={
                    "type": exc.__class__.__name__,
                    "message": str(exc),
                    "retryable": False,
                },
                meta={"tool_name": tool_name},
            )


def build_registry() -> ToolRegistry:
    registry = ToolRegistry()
    registry.register(
        RegisteredTool(
            ToolSpec(name="weather_api", description="查询城市未来7天天气", permission="read_only"),
            WeatherInput,
            weather_handler,
        )
    )
    registry.register(
        RegisteredTool(
            ToolSpec(name="db_query", description="执行只读 SQL 查询", permission="read_only"),
            DbQueryInput,
            db_handler,
        )
    )
    registry.register(
        RegisteredTool(
            ToolSpec(name="web_scrape", description="抓取网页内容摘要", permission="read_only"),
            WebScrapeInput,
            scrape_handler,
        )
    )
    registry.register(
        RegisteredTool(
            ToolSpec(name="safe_file_write", description="在安全目录下写文件", permission="read_write"),
            FileWriteInput,
            file_write_handler,
        )
    )
    return registry


if __name__ == "__main__":
    registry = build_registry()
    runtime = ToolRuntime(registry, granted_permission="read_write")

    print(json.dumps(runtime.execute("weather_api", {"city": "Shanghai", "days": 3}).model_dump(), ensure_ascii=False, indent=2))
    print(json.dumps(runtime.execute("db_query", {"sql": "SELECT * FROM orders WHERE user = 'alice'"}).model_dump(), ensure_ascii=False, indent=2))
    print(json.dumps(runtime.execute("safe_file_write", {"relative_path": "notes/todo.txt", "content": "hello agent"}).model_dump(), ensure_ascii=False, indent=2))
```

### 9.7.1 这套实现为什么重要

它体现了生产工具系统的几个关键实践：

- **schema-first**：输入先校验，再执行；
- **permission-aware**：权限不足在工具层就拒绝；
- **safe-by-default**：文件写入受根目录约束；
- **portable**：注册表可导出成 OpenAI 工具格式；
- **LLM-friendly**：错误结果结构化，便于模型下一轮修正。

## 9.8 设计面试常见问题

### 问：为什么不能把所有工具都暴露给模型？

因为工具越多，选择歧义越大，错误面越广，安全风险越高。通常应该按场景分组，只暴露完成当前任务所需的最小工具集。

### 问：工具错误应该返回自然语言还是结构化 JSON？

优先结构化 JSON。自然语言适合给人读，结构化结果适合 Agent 逻辑分支和重试策略。

### 问：什么时候需要 human approval？

凡是高成本、高风险、不可逆、跨边界的操作，都值得审批，比如删数据、发邮件、外部支付、生产变更。

## 9.9 工具系统的契约、版本化与兼容性

工具系统一开始看起来只是几个函数，真正上线后你会发现它更像内部 API 平台。只要有多个 Agent、多个调用方、多个环境，就一定会遇到版本兼容问题。

首先要区分两类变化：

| 变化类型 | 示例 | 是否兼容 |
|---|---|---|
| 非破坏性变更 | 新增可选字段 `locale` | 通常兼容 |
| 破坏性变更 | 把 `city` 改名为 `location_name` | 不兼容 |

因此建议每个工具都带版本号，例如：

- `search_web@v1`
- `search_web@v2`

或在元数据里声明 `schema_version`。不要在没有兼容层的情况下，直接改掉已上线工具的字段名。否则旧 Prompt、旧 Agent、旧缓存都会失效。

另一个实践是把**工具契约测试**纳入 CI。最少要验证：

1. schema 是否合法；
2. 示例输入能否通过校验；
3. 返回结构是否满足统一格式；
4. 错误时是否返回 `retryable`；
5. 权限要求是否符合预期。

如果你在团队里负责平台层，甚至可以做一个“工具目录页”，列出：

- 工具名称；
- 所有者；
- 权限级别；
- 平均延迟；
- 成功率；
- 近 7 天调用量；
- 当前版本。

这会让 Agent 工程从“脚本堆积”升级成“平台化治理”。

## 9.10 观测与治理：上线后看什么

生产工具系统必须可观测。推荐至少记录以下字段：

| 字段 | 说明 |
|---|---|
| request_id | 单次 Agent 任务 ID |
| tool_name | 工具名 |
| tool_version | 版本 |
| arguments_hash | 参数哈希，避免日志泄露原文 |
| permission_level | 调用时权限 |
| latency_ms | 延迟 |
| success | 是否成功 |
| error_type | 错误分类 |
| token_context_size | 触发调用时的上下文大小 |

有了这些字段，你就能回答很多管理问题：

- 哪个工具最慢？
- 哪个工具最容易被模型误用？
- 哪些错误是参数错，哪些是网络错？
- 哪个 Agent 最依赖高权限工具？

在治理层面，推荐做三条预算线：

1. **成本预算**：例如单用户每天第三方 API 花费不超过 30 元；
2. **风险预算**：例如每个任务最多 1 次写操作；
3. **延迟预算**：例如 95 分位响应时间不超过 8 秒。

当任意预算越界时，系统应该自动降级，比如关闭网页抓取、减少并行数、只返回摘要而不是全文。

## 9.11 从“函数集合”到“工具平台”的演进路径

很多团队的演进路径都很相似：

### 阶段一：脚本期

- 几个 Python 函数；
- 没有统一 schema；
- 没有权限控制；
- 只有开发者自己会用。

### 阶段二：注册表期

- 引入工具注册表；
- 开始做参数校验；
- 有统一返回格式；
- 支持多个 Agent 复用。

### 阶段三：平台期

- 工具目录、观测面板、版本管理；
- 权限体系、审批流、配额系统；
- 工具 owner 机制；
- 测试与发布流程独立。

### 阶段四：协议化期

- 工具对外以 MCP 或内部标准协议暴露；
- Agent 与工具解耦；
- 跨团队共享能力。

你在面试中如果能把工具系统讲成“平台演化”，会明显强于只谈某个 Python decorator 的候选人。

## 9.12 四个常见反模式

1. **一个工具做太多事**：例如 `general_api_tool` 既查用户、又查订单、又写工单。模型很难稳定使用，日志也无法治理。
2. **把自然语言直接传给数据库**：没有参数化和只读限制，风险极高。
3. **默认给写权限**：为了“演示方便”把文件写、消息发送、数据库更新都开放，后面几乎必出事故。
4. **把原始 HTML/超大 JSON 全量喂回模型**：上下文污染严重，成本和噪声同时上升。

真正优秀的工具系统，追求的是**小而清晰、强约束、易监控、可替换**。

## 9.13 一个企业级工具平台的落地蓝图

如果你未来进入的是中大型公司，而不是个人项目，那么工具系统通常要按平台思路建设。一个最小平台可以分成五层：

1. **Tool SDK 层**：供业务团队定义工具、schema、权限和示例；
2. **Registry 层**：统一注册与发现；
3. **Gateway 层**：负责鉴权、限流、审计、超时和重试；
4. **Execution 层**：真正调用数据库、HTTP 服务、文件系统或沙箱；
5. **Observability 层**：日志、指标、追踪、成本统计。

平台化之后，业务团队新增一个工具的流程应该像“发布内部 API”，而不是“往 Agent 代码里再塞一个函数”。理想流程是：

- 开发者提交工具定义；
- 自动跑 schema 测试与安全检查；
- 平台分配版本号；
- 审批通过后上线到 registry；
- Agent 侧按场景订阅需要的工具集合。

为什么这很重要？因为当工具数量从 5 个增加到 50 个后，真正的复杂度不在调用，而在治理。没有 owner、没有版本、没有统计的工具系统，几周后就会变成“谁都不敢删、谁也说不清还能不能用”的遗留资产。

## 9.14 面试高频追问：如何让模型更稳定地用对工具

这是非常高频的问题。可以从四个层面回答：

### 一、减少歧义

不要同时暴露三个相似工具。若必须同时存在，就在描述里明确边界，例如“内部知识库搜索”和“公网搜索”必须分别写清使用条件。

### 二、提供反例和边界

工具描述不只写“什么时候用”，还要写“什么时候不要用”。例如数据库查询工具可以注明：不适用于模糊常识问答，不适用于写操作。

### 三、缩小工具集合

按任务动态裁剪，只把当前任务真正可能用到的 5~10 个工具发给模型，而不是把平台里的全部工具都暴露出去。

### 四、把错误变成训练信号

如果模型连续三次把 `city` 传成 `cities`，那就说明不是一次偶发错误，而是工具描述、字段命名或 few-shot 示例存在问题。成熟团队会把这些误用日志回流，修 schema、修描述、修路由规则，而不是只怪模型“不聪明”。

## 9.15 一个最小上线清单

在把工具系统接到真实用户前，建议逐项确认：

- 是否有参数校验；
- 是否有只读/读写权限区分；
- 是否有每个工具的超时；
- 是否有 429 与 5xx 重试；
- 是否有 trace id；
- 是否能统计单工具成本；
- 是否有危险写操作审批；
- 是否能在工具失败时优雅降级；
- 是否能屏蔽敏感字段进入模型上下文；
- 是否能按环境隔离测试、预发和生产资源。

如果这 10 条里做不到一半，那你的系统更像“能跑 demo”，而不是“可交付平台”。

## 9.16 一个真实工作流示例：销售助理 Agent 的工具路由

假设你在做一个销售助理 Agent，用户问：“帮我查一下客户 ACME 最近三个月订单、是否有逾期发票，并草拟一封跟进邮件。”  
这个请求看起来只有一句话，但背后至少涉及四类工具：

1. CRM 查询工具：拿客户基本信息；
2. 订单数据库工具：查最近三个月订单；
3. 财务工具：查发票与逾期状态；
4. 邮件草稿工具：生成草稿但不直接发送。

一个成熟的工具系统不会让模型自由发挥，而是会做显式路由：

- 先调用只读 CRM；
- 再调用只读订单与财务工具；
- 最后只允许调用“创建邮件草稿”，不允许直接发送。

此时审批边界就非常清楚：查数据是 read-only，生成草稿是 read-write，但真正发送邮件仍需人工确认。  
这个例子特别适合面试，因为它能同时体现你对工具分类、权限边界、调用顺序和风险控制的理解。

如果进一步优化，还可以加入：

- 对 CRM 和订单查询结果做字段裁剪，只保留客户名、金额、日期、逾期标志；
- 对草稿邮件做模板化生成，减少模型自由发挥带来的措辞风险；
- 对同一客户 5 分钟内的重复查询做缓存，避免重复打数据库。

这说明工具系统设计并不只是“接 API”，而是把外部能力纳入一套可治理的执行模型。

## 9.17 为什么很多工具系统在第二个月开始失控

原因通常不是模型变差，而是系统复杂度开始堆积：

- 工具越来越多，但命名不统一；
- 描述由不同人编写，风格和边界不一致；
- 没有 owner，坏掉后没人修；
- 测试只覆盖 happy path，不覆盖异常参数与权限拒绝；
- 日志只记录成功，不记录误用模式。

所以工具系统真正的挑战，从来不只是“第一天能接通”，而是“第六十天还能稳定维护”。如果你能在面试里讲出这一层，通常就已经超越只会写 demo 的候选人。

## 9.18 最后一个经验：把工具当作产品来运营

成熟团队会把高价值工具当作内部产品，而不是一次性脚本。所谓“产品化”，至少包含三件事：

第一，有清晰文档。开发者和 Agent 都要知道这个工具的边界、示例、错误码和限制。  
第二，有用户反馈闭环。这里的“用户”既包括人类开发者，也包括模型本身的误用日志。  
第三，有生命周期管理。工具可能会下线、替换、升级，不能永远靠口口相传。

一旦你接受“工具也是产品”这个视角，就会自然重视命名、文档、可观测性、版本和权限，而这些恰恰是生产系统最难补的基础设施。

再补一句很实战的话：很多 Agent 项目的瓶颈不是模型效果，而是“关键工具没人维护”。因此工具 owner 机制、SLA、值班与告警，并不是大公司官僚流程，而是让 Agent 真正可依赖的必要条件。
当你把工具视为长期服务而不是临时脚本时，系统稳定性才会真正提升。
而一旦系统进入多团队协作阶段，工具目录、所有者、版本说明和调用统计，都会像接口文档一样成为日常工作的一部分。
没有这些基础治理，工具越多，Agent 越难稳定使用。
归根结底，工具系统的成熟度，决定了 Agent 能否从实验玩具变成真实生产力。
这也是工具工程为什么值得单独成为一门能力的原因。
没有稳定工具，就没有稳定 Agent。
两者是同一件事的两面。

## 本章要点

- 工具系统决定 Agent 能否真正连接现实世界，而不只是生成文本。
- 工具可分为信息检索、动作、计算、通信四大类。
- 生产系统要围绕工具注册表、schema 校验、标准化输出、权限控制来设计。
- 代码执行、文件系统、外部写操作必须默认不可信，必须加沙箱与安全护栏。
- 错误消息要能帮助模型自修正，而不仅仅是“失败了”。
- 工具应最小暴露、边界清晰、可观测、可限流、可审计。

## 延伸阅读

1. OpenAI Responses / Function Calling 官方文档
2. Anthropic Tool Use 与 JSON Schema 设计建议
3. Pydantic v2 官方文档
4. OWASP 关于安全自动化与最小权限原则
5. Python Tenacity / Backoff 库的重试模式设计
