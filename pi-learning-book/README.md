# 系统理解 Pi：从终端 Coding Agent 到 Agent Harness

Pi Agent Harness 的中文系统学习教材。首版以 `earendil-works/pi` 的
`dcfe36c79702ec240b146c45f167ab75ecddd205` 为源码基线，覆盖架构、Agent loop、
工具、安全、会话、上下文压缩、Provider prompt cache 与 KV cache 边界、扩展、TUI、
测试和学习路线。

编译：

```powershell
& D:\projects\tools\tectonic\tectonic.exe -X compile --outdir ..\pdf book.tex
Rename-Item ..\pdf\book.pdf pi-learning-book.pdf
```

发布产物统一位于仓库根目录的 `pdf/pi-learning-book.pdf`。
