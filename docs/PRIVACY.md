# Privacy

## 中文

NetStats 是本地优先的 macOS 菜单栏监控工具，不需要账号，不包含遥测，也不会把系统指标上传到 NetStats 的任何项目服务器。

NetStats 会在本机读取和处理 CPU、内存、硬盘、网络、电源、进程排行，以及 Clash Verge Dev 的本地进程、配置和控制接口状态。显示偏好保存在本机 `UserDefaults` 中。

公网 IP 与地理位置功能会请求 `https://ipinfo.io/json`，用于解析当前公网出口 IP。这个功能可以在 NetStats 设置中关闭；关闭后，NetStats 会清空公网 IP 展示，并且不会由 App 主动发起该查询。

NetStats 只展示 Clash Verge Dev 状态，不会退出、重启或控制 Clash Verge Dev。

公开截图时，请避免暴露真实 IP、位置、订阅名、代理组或节点名。

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

NetStats stores display preferences in local `UserDefaults`.

## External Requests

Public IP and geolocation lookup uses `https://ipinfo.io/json` to resolve the current public egress IP address. This request is optional and can be disabled in NetStats settings by turning off the public IP location option.

When public IP lookup is disabled, NetStats clears the public IP display and does not start the lookup request from the app.

## Clash Verge Dev

NetStats only displays Clash Verge Dev status. It reads local files and local controller state to show whether Clash Verge Dev is running, whether system proxy and TUN appear enabled, the current mode, subscription traffic, proxy group, and selected node.

NetStats does not quit, restart, or control Clash Verge Dev.

## Screenshots

Public screenshots should avoid exposing real IP addresses, locations, subscription names, proxy groups, or node names. Use privacy-masked screenshots for README, website, and release pages.
