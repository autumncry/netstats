# NetStats Launch Kit

This document keeps reusable launch copy and outreach notes for growing NetStats to 100 GitHub stars through organic discovery.

## Links

- Repository: https://github.com/autumncry/netstats
- Latest release: https://github.com/autumncry/netstats/releases/latest
- Chinese README: https://github.com/autumncry/netstats/blob/main/README.md
- English README: https://github.com/autumncry/netstats/blob/main/README.en.md

## Positioning

### Chinese

NetStats 是一个 macOS 原生菜单栏系统监控工具，用来快速查看 CPU、内存、网络速度、公网 IP、地理位置和 Clash Verge Dev 状态。它适合希望状态栏保持简洁、但点击后能看到完整系统与网络信息的 macOS 用户。

### English

NetStats is a native macOS menu bar monitor for CPU, memory, network speed, public IP, geolocation, and Clash Verge Dev status. It is designed for users who want a clean menu bar with a detailed system and network panel one click away.

## Privacy Message

### Chinese

系统指标、网络速度与 Clash Verge Dev 状态均在本机读取和处理，不会上传到任何 NetStats 项目服务器。公网 IP 与地理位置查询会请求 `ipinfo.io` 来解析当前公网出口；如果不需要该信息，可以用防火墙或网络过滤工具阻止该请求。

### English

System metrics, network speed, and Clash Verge Dev status are read and processed locally on your Mac and are never sent to any NetStats-owned server. Public IP and geolocation lookup uses `ipinfo.io` to resolve the current public egress address; if you do not need it, you can block that request with a firewall or network filtering tool.

## Short Posts

### Chinese - V2EX / 即刻 / 小红书

我做了一个 macOS 原生菜单栏工具 NetStats，可以在状态栏查看 CPU、内存、网络速度，点击后显示公网 IP、地理位置和 Clash Verge Dev 状态。

我希望它保持轻量：菜单栏只显示你关心的数据，详情面板里再放完整信息。系统指标、网络速度、代理状态都在本机读取和处理；公网 IP/地理位置查询会请求 `ipinfo.io`。

目前提供 DMG 安装包，项目开源在 GitHub。如果你也需要这样的 macOS 小工具，欢迎试用、提 issue，觉得有用也欢迎点一个 Star：
https://github.com/autumncry/netstats

### English - Reddit / X / Hacker News

I built NetStats, a native macOS menu bar monitor for CPU, memory, network speed, public IP, geolocation, and Clash Verge Dev status.

The goal is to keep the menu bar clean while still making detailed system and network information available in one click. System metrics, network speed, and Clash Verge Dev status are processed locally; public IP/geolocation lookup uses `ipinfo.io`.

DMG builds are available from GitHub Releases. Feedback, issues, and stars are welcome:
https://github.com/autumncry/netstats

### English - Show HN

Show HN: NetStats - a native macOS menu bar system and network monitor

NetStats shows CPU, memory, network upload/download speed, public IP, geolocation, and Clash Verge Dev status from a compact macOS menu bar app.

I built it because I wanted a small native monitor that keeps the menu bar readable but still exposes useful network and proxy state in one click. System metrics and proxy status are processed locally. Public IP/geolocation lookup uses `ipinfo.io`.

GitHub: https://github.com/autumncry/netstats

## Channel Checklist

- GitHub repository topics and description
- V2EX macOS / Apple section
- 即刻 macOS / 独立开发 topic
- X with screenshots
- Reddit: `r/macapps`, `r/MacOS`
- Hacker News: `Show HN`
- Product Hunt, after the app has signed builds and a stronger release page
- Clash Verge Dev community channels, only if the post focuses on proxy status visibility

## Suggested Cadence

1. Day 1: Share the Chinese short post with the menu bar and panel screenshots.
2. Day 2: Share the English short post on Reddit and X.
3. Day 3: Post a short Show HN entry if the release page and screenshots are ready.
4. Day 4-7: Reply to comments, fix small issues quickly, and cut a follow-up release if needed.
5. Weekly: Update screenshots and README if the UI changes meaningfully.

## Posting Rules

- Do not ask for fake stars or run automated star campaigns.
- Do not post the same message repeatedly in the same community.
- Always include screenshots and the GitHub link.
- Ask for feedback first; mention starring only as a lightweight closing note.
- Be explicit that the current public DMG is unsigned until code signing and notarization are available.
