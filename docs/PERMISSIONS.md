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

## Features That Are Intentionally Limited

Per-process GPU, disk, and network usage are not fully available through stable public macOS APIs without heavier tracing, extra permissions, or privileged helpers. NetStats shows a clear unavailable state for those categories instead of silently requesting broad access.

## Future Permissions

If a future feature needs additional permissions, NetStats should document:

- what permission is needed
- which feature uses it
- whether the feature works without it
- how to revoke the permission
