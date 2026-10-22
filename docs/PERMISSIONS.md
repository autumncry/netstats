# Permissions

## 中文

NetStats 会尽量保持较小的权限范围。大多数系统指标通过 macOS API 或本地命令读取，不需要额外授权。

| 范围 | 是否需要权限 | 说明 |
| --- | --- | --- |
| CPU 和内存 | 不需要 | 通过 macOS host statistics API 读取。 |
| 硬盘容量 | 不需要 | 通过卷资源信息读取。 |
| 硬盘读写速度 | 不需要 | 通过 IOKit 读取聚合块存储计数器。 |
| 网络速度 | 不需要 | 读取聚合网络接口计数器。 |
| 电池和电源 | 不需要 | 读取 macOS power source 信息。 |
| 进程排行 | 不需要 | CPU 和内存排行来自本机进程列表。 |
| 公网 IP 和地理位置 | 需要网络访问 | 可选请求 `ipinfo.io`，可在设置中关闭。 |
| Clash Verge Dev 状态 | 不需要 | 读取同一台 Mac 上的本地进程、配置和控制接口状态。 |
| 日历 | 系统日历完整访问 | 设置页主动请求；产品只读取日程，拒绝时仍可看日期。可在系统隐私设置撤销。 |
| 剪切板历史 | 新版 macOS 的剪切板访问 | 设置页主动测试；15.4+ 仅在 Always Allow 时后台收集，其他状态暂停。旧版在用户启用后收集。 |
| 天气 | 快捷指令使用的权限 | 用户先在 Shortcuts 内配置并授权，测试成功后刷新；固定城市可避免定位。 |
| 文件暂存架 | 用户选择/拖入的文件访问 | 保存书签引用，支持离线与重新关联，不请求全盘访问。 |

悬停和 Dock 不触发上述首次授权。不新增辅助功能、输入监控、录屏权限或全局键盘监听；只有主动编辑输入时面板取得键盘焦点。

进程级 GPU、硬盘、网络占用并不都能通过稳定公开 API 可靠获取。NetStats 会显示明确的不可用原因，而不是静默请求更宽的权限或安装特权 helper。

## English

NetStats keeps its permission footprint intentionally small. Most system metrics are collected through macOS APIs or local command-line tools that do not require additional user-granted permissions.

## Current Permission Model

| Area | Permission Required | Why |
| --- | --- | --- |
| CPU and memory | None | Read through macOS host statistics APIs. |
| Disk capacity | None | Read through volume resource values. |
| Disk read/write speed | None | Read aggregate block storage counters through IOKit. |
| Network speed | None | Read aggregate network interface counters. |
| Battery and power | None | Read macOS power source information. |
| Process ranking | None | Uses local process listing for CPU and memory. |
| Public IP and geolocation | Network access | Optional request to `ipinfo.io`; can be disabled in settings. |
| Clash Verge Dev status | None | Reads local process/config/controller state on the same Mac. |
| Calendar | Explicit Full Access | Product queries events only. Revoke in system privacy settings. |
| Clipboard history | System pasteboard access on newer macOS | Explicit test in Settings; automatic capture requires Always Allow on15.4+. |
| Weather | Permissions used by the configured shortcut | Configure/authorize in Shortcuts, then verify the bridge in NetStats. |
| Shelf | User-selected/dropped file access | Persists bookmarks; no Full Disk Access request. |

## Features That Are Intentionally Limited

Per-process GPU, disk, and network usage are not fully available through stable public macOS APIs without heavier tracing, extra permissions, or privileged helpers. NetStats shows a clear unavailable state for those categories instead of silently requesting broad access.

## Future Permissions

If a future feature needs additional permissions, NetStats should document:

- what permission is needed
- which feature uses it
- whether the feature works without it
- how to revoke the permission
