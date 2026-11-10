# Terminal 详情样式

当前开发版的 Terminal 详情使用深炭灰、暖白和暖橙的现代终端设计语言，参考 Claude Code 的文字层级及简洁分隔方式。通过设置 → 显示与监控 → 详情样式选择“终端”。

- 固定顶部显示应用、主机与采样时间，保留设置按钮；底部显示本机采样与只读说明。
- 正文可滚动，按系统、磁盘、网络、Clash 分节。模块、历史趋势、进程排行开关与设置一致。
- 等宽数值对齐，内存使用量与压力分开标注；进程 CPU 可超过100%。缺失读数显示不可用，不用无依据的 Health 评分或网络“负载”表示未知量。
- 公网 IP 复制保留反馈；查询关闭、加载失败、模块全关均有明确状态。
- 配色不受系统浅色模式影响；Native 详情和六功能玻璃卡片保持原有样式。

实现：`Sources/NetStats/TerminalMonitorView.swift`。独立值输入便于使用合成数据做本地渲染验证，测试不启动采样服务或发起公网请求。

参考：[Claude Code 官方演示](https://github.com/anthropics/claude-code#readme)。这是 NetStats 的独立界面实现，不提供 Claude Code/Codex 的命令行能力。
