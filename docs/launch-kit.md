# NetStats v2.00 Launch Kit

Reusable project copy for the v2.00 release and updated website. These are drafts for human review, not authorization to post or contact anyone.

## Links

- Repository: https://github.com/autumncry/netstats
- Website: https://autumncry.github.io/netstats/
- v2.00 release: https://github.com/autumncry/netstats/releases/tag/v2.00
- Universal DMG: https://github.com/autumncry/netstats/releases/download/v2.00/NetStats-2.0.0.dmg
- SHA-256 checksum: https://github.com/autumncry/netstats/releases/download/v2.00/NetStats-2.0.0.dmg.sha256
- Chinese README: https://github.com/autumncry/netstats/blob/main/README.md
- English README: https://github.com/autumncry/netstats/blob/main/README.en.md
- Weather setup: https://github.com/autumncry/netstats/blob/main/docs/weather-shortcut.md
- Privacy: https://github.com/autumncry/netstats/blob/main/docs/PRIVACY.md
- Permissions: https://github.com/autumncry/netstats/blob/main/docs/PERMISSIONS.md

## Positioning

### Chinese

NetStats v2.00 用一张 360 pt 原生玻璃卡片聚合网络、设备、日历、天气、剪切板与暂存架。点击菜单栏，或开启实体刘海悬停入口，再通过底部 Dock 切换功能。两个入口共用设置和本机数据；「详情」继续提供 Native / Terminal 完整监控与 Clash Verge Dev 状态。

通用 DMG 支持 macOS 14+、Apple Silicon 和 Intel。macOS 26+ 使用系统玻璃，macOS 14/15 使用原生模糊材质。刘海入口默认关闭；没有刘海的 Mac 也能通过菜单栏使用。

### English

NetStats v2.00 brings Network, Device, Calendar, Weather, Clipboard and Shelf into one 360 pt native glass hub. Open it from the menu bar or enable the physical-notch hover entrance, then click the bottom Dock to switch features. Both entrances share settings and local data. Details retains the Native / Terminal monitor and Clash Verge Dev status.

The universal DMG supports macOS 14+, Apple Silicon and Intel. It uses system glass on macOS 26+ and native blurred material on macOS 14/15. The notch entrance is optional and initially disabled; the menu-bar entrance works without a notch.

## Feature Copy

| Feature | Safe description |
| --- | --- |
| Network | Live upload/download rates, short history, session totals and active interfaces. |
| Device | CPU, GPU model and available load, memory and startup-volume capacity. Disk I/O is aggregated across devices; missing GPU load is unavailable, not 0%. |
| Calendar | Month/week browsing and selected-day events after an explicit system Full Access grant. NetStats queries events only; create/edit in Calendar. |
| Weather | Current Apple Weather through a user-configured, verified system shortcut. Cached for 15 minutes, with manual refresh. No forecast or automatic setup claim. |
| Clipboard | Local text/image history with search, preview, copy, pause, clear and app exclusions. Default retention is 30 days with unlimited counts; retention and separate text/image limits are configurable. |
| Shelf | Persistent file/folder references with drag in/out, open, remove and relink. Removing a reference does not delete its original. |

Network, Device and Shelf are initially enabled. Calendar, Weather and Clipboard are initially disabled and require explicit setup. The hub opens after a 1-second notch hover, with a 300 ms exit grace period; a valid file drag held for 500 ms opens Shelf. Existing detailed monitoring includes public IP, geolocation and Clash Verge Dev information.

## Privacy Message

### Chinese

NetStats 不需要账号、不包含遥测，也不向项目服务器上传系统指标、剪切板或日历内容。剪切板历史和文件引用保存在本机。日历系统授权为「完整访问」，产品只查询日程；剪切板需用户启用并按系统要求允许后台访问。天气依赖用户配置的快捷指令，可能使用 Apple 的网络和定位服务；公网 IP 查询使用 `ipinfo.io`，可在 App 设置中关闭。卡片不新增辅助功能、输入监控或录屏授权。

### English

NetStats requires no account, includes no telemetry, and does not upload system metrics, clipboard content or calendar events to project servers. Clipboard history and file references stay local. Calendar uses an explicit system Full Access grant but only queries events; clipboard capture requires user enabling and the applicable system background-access permission. Weather uses a shortcut configured by the user and may use Apple's network/location services. Optional public IP lookup uses `ipinfo.io` and can be turned off in the app. The card adds no Accessibility, Input Monitoring or Screen Recording grant.

## Short Posts

### Chinese — V2EX / 即刻 / 小红书

NetStats 更新到 v2.00：点击菜单栏，或者在 MacBook 实体刘海悬停 1 秒，打开一张原生玻璃卡片。底部 Dock 可切换网络、设备、日历、天气、剪切板与文件暂存架；原来的完整监控和 Clash Verge Dev 状态也保留在「详情」中。

日历、天气和剪切板默认关闭，需要自己在设置中启用和配置。天气通过系统快捷指令获取当前天气；剪切板历史保存在本机，默认 30 天、数量不限；暂存架只保存文件引用，不移动原件。

v2.00 提供 macOS 14+ 通用 DMG，支持 Apple Silicon 与 Intel。当前安装包使用临时签名，尚未经过 Apple 公证，首次打开请按官方发布页说明操作。欢迎试用、提 Issue，分享体验：
https://autumncry.github.io/netstats/

### English — Reddit / X

NetStats v2.00 is out: a native glass hub for Network, Device, Calendar, Weather, Clipboard and Shelf. Open it from the menu bar or an optional 1-second physical-notch hover, then click the Dock to switch features. The detailed monitor and Clash Verge Dev status are still available through Details.

Calendar, Weather and Clipboard start disabled. Calendar needs explicit access, Weather uses a shortcut you configure, and clipboard history stays local. Shelf keeps file references without moving originals.

A universal DMG is available for macOS 14+, Apple Silicon and Intel. It is ad-hoc signed and not Apple notarized; see the release page for first-launch instructions. Feedback is welcome:
https://autumncry.github.io/netstats/

### English — Show HN

Show HN: NetStats v2 — a six-feature macOS menu-bar and notch hub

NetStats v2.00 is a Swift, AppKit and SwiftUI utility with one 360 pt card shared by menu-bar clicks and an optional physical-notch hover entrance. Its Dock switches Network, Device, Calendar, Weather, Clipboard and Shelf. Details retains the system/network monitor and local Clash Verge Dev status.

The new features are opt-in where setup is required: Calendar only queries events after a system Full Access grant; current weather comes from a verified system shortcut; text/image clipboard history is local. Shelf stores file references, so removing an item does not delete the original. Optional public IP lookup uses ipinfo.io and can be disabled.

The project is MIT licensed. The universal DMG supports macOS 14+, Apple Silicon and Intel; it is ad-hoc signed and not Apple notarized.

GitHub: https://github.com/autumncry/netstats
Website: https://autumncry.github.io/netstats/

## Visual Assets

The website and README use v2 native SwiftUI fixture renders under `assets/screenshots/v2/`: Network, Device, Calendar, Weather, Clipboard, Shelf and shared Settings. They are marked **Native UI · example data**. Values and list entries are examples, not private user data or proof of a live weather/calendar connection. Captions should explain that actual material appearance varies with the system and accessibility settings.

Use these previews for sharing the shipping interface. Do not present the earlier GPT-generated design concept as a product screenshot. Real screenshots must mask IPs, locations, hostnames, calendar entries, clipboard contents, subscriptions, nodes and private paths as appropriate.

## Distribution Notes

- Prefer the exact v2.00 DMG and release links above.
- The separate Homebrew tap has not yet been updated to v2.00. Do not advertise its command as an installer for this version.
- The npm package source exists but has not been published. Do not advertise `npx` installation as available.
- The public DMG is **ad-hoc signed**, without Developer ID signing or Apple notarization. Avoid the inaccurate blanket description “unsigned.”
- Do not claim measured battery savings, universal GPU-load support, Apple Weather setup completed for every user, cloud sync, encrypted clipboard storage or validation of every hardware/permission workflow.

## Channel Checklist

- GitHub repository description and topics
- V2EX macOS / Apple section
- 即刻 macOS / 独立开发 topic
- X with the v2 native previews
- Reddit: `r/macapps`, `r/MacOS`
- Hacker News: `Show HN`
- Product Hunt after Developer ID signing, notarization and release presentation are ready
- Clash Verge Dev communities when the post specifically explains retained proxy-status visibility

## Posting Rules

- Have a human review and explicitly authorize each post; this document does not send anything.
- Do not ask for fake stars or run automated star campaigns.
- Do not repeatedly post the same message in a community.
- Link the repository or website, use accurate v2 previews and ask for feedback.
- Keep setup, permission and distribution limitations clear. Never label example fixture data as a live account connection.
