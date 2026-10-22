# Privacy

## 中文

NetStats 是本地优先的 macOS 菜单栏监控工具，不需要账号，不包含遥测，也不会把系统指标上传到 NetStats 的任何项目服务器。

NetStats 会在本机读取和处理 CPU、内存、硬盘、网络、电源、进程排行，以及 Clash Verge Dev 的本地进程、配置和控制接口状态。显示偏好保存在本机 `UserDefaults` 中。

公网 IP 与地理位置功能会请求 `https://ipinfo.io/json`，用于解析当前公网出口 IP。这个功能可以在 NetStats 设置中关闭；关闭后，NetStats 会清空公网 IP 展示，并且不会由 App 主动发起该查询。

NetStats 只展示 Clash Verge Dev 状态，不会退出、重启或控制 Clash Verge Dev。

公开截图时，请避免暴露真实 IP、位置、订阅名、代理组或节点名。

## 六功能卡片的本机数据

- 日历与剪切板默认关闭，首次访问由设置中的按钮主动发起。日历系统 Full Access 包含读写能力，NetStats 仅查询日程，创建和编辑交给 Calendar。
- 剪切板历史使用本机 SQLite 与图片文件，位于 `~/Library/Application Support/NetStats/Clipboard/`。默认保留30天、文字和图片数量不限，可分别设上限；关闭功能不立即删除历史，仍按期限清理。支持暂停、排除应用与清空。来源标记缺失时，前台应用判断只是辅助。
- 剪切板内容不会上传；数据库没有额外应用层加密。用户账户与系统磁盘保护仍适用。隐藏、临时、自动生成的剪切板类型会跳过。
- 暂存架在 UserDefaults 保存文件书签与名称/路径引用，移除引用不删除原文件。打开或拖出文件是用户主动操作。
- 天气由用户指定的系统快捷指令返回，最近成功结果保存在本机 `NetStats/weather-cache.json`。测试成功前不后台运行；快捷指令的天气/位置动作可能使用 Apple 的网络和定位服务。NetStats 不读取 Weather.app 私有缓存。
- 新卡片沿用已有系统采样。GPU负载只在驱动提供有效读数时显示，启动盘容量与全部磁盘 I/O 分别标注。

## English

NetStats is designed as a local-first macOS menu bar monitor. The app does not require an account, does not include telemetry, and does not upload system metrics to any NetStats-owned server.

## Local Data

The following data is read and processed locally on your Mac:

- CPU usage
- Memory pressure, used memory, cached memory, and compressed memory
- Disk capacity and aggregate disk read/write speed
- Network upload/download speed and session totals
- Battery or AC power state
- Top process samples collected through local macOS process listing
- Clash Verge Dev process state, local configuration, local Mihomo controller state, and macOS system proxy state

NetStats stores preferences and file-reference bookmarks in local `UserDefaults`. Optional Calendar access only queries events after an explicit Full Access grant. Clipboard history is local SQLite plus image files under `~/Library/Application Support/NetStats/Clipboard/`, with configurable1–30-day retention and separate unlimited-by-default counts; it has no additional app-level encryption. Pause, clear and application exclusions are available. Disabling capture retains history until normal cleanup. Shelf removes references without deleting originals.

Weather stores the last successful result locally and invokes only the configured, verified system shortcut. That shortcut may use Apple's weather/network/location services. NetStats does not inspect Weather.app private caches. No calendar, clipboard or file-reference contents are uploaded to a NetStats server.

## External Requests

Public IP and geolocation lookup uses `https://ipinfo.io/json` to resolve the current public egress IP address. This request is optional and can be disabled in NetStats settings by turning off the public IP location option.

When public IP lookup is disabled, NetStats clears the public IP display and does not start the lookup request from the app.

## Clash Verge Dev

NetStats only displays Clash Verge Dev status. It reads local files and local controller state to show whether Clash Verge Dev is running, whether system proxy and TUN appear enabled, the current mode, subscription traffic, proxy group, and selected node.

NetStats does not quit, restart, or control Clash Verge Dev.

## Screenshots

Public screenshots should avoid exposing real IP addresses, locations, subscription names, proxy groups, or node names. Use privacy-masked screenshots for README, website, and release pages.
