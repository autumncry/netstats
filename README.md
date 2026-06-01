# NetStats

A native macOS menu bar monitor for CPU, memory, network speed, public IP, and Clash Verge Dev status.

NetStats is intentionally small: it lives in the menu bar, updates live, and opens a compact native panel when clicked.

> macOS only. NetStats is unsigned in the first public builds.

## Install

### Download the DMG

Download the latest `NetStats-*.dmg` from [GitHub Releases](https://github.com/RonnyCao0816/netstats/releases), open it, then drag `NetStats.app` to `/Applications`.

Because the first builds are unsigned, macOS may block the first launch. Open **System Settings > Privacy & Security** and allow NetStats, or Control-click the app and choose **Open**.

### npm

The npm package is prepared as `@ronnycao/netstats` and will be available after the package is published to npm:

```bash
npx @ronnycao/netstats install
```

The npm installer downloads the matching GitHub Release DMG and opens it. It does not install anything during `postinstall`.

## Features

- CPU usage in the menu bar and detail panel
- Memory load, used memory, cached memory, and compressed memory
- Network upload and download speed
- Public IPv4 address, geolocation, and one-click copy
- Clash Verge Dev status: running state, system proxy, TUN, mode, subscription, proxy group, and selected node
- Configurable menu bar and hover metrics
- Native macOS AppKit + SwiftUI UI
- English and Chinese interface

## Build from Source

```bash
git clone https://github.com/RonnyCao0816/netstats.git
cd netstats
swift build -c release
```

Package the menu bar app:

```bash
scripts/package_app.sh
open build/NetStats.app
```

Build a DMG:

```bash
scripts/package_dmg.sh
open dist
```

## Support

If NetStats saves you time, you can support ongoing development:

- Buy Me a Coffee: `https://www.buymeacoffee.com/YOUR_BMC_NAME`
- Alipay and WeChat Pay QR codes will be added under `assets/sponsor/` after the images are provided.

## License

MIT License. See [LICENSE](LICENSE).

---

# NetStats 中文说明

NetStats 是一个 macOS 原生菜单栏系统监控工具，用来显示 CPU、内存、网络速度、公网 IP 和 Clash Verge Dev 状态。

它常驻菜单栏，点击后打开原生风格的信息面板，适合日常快速查看系统与代理状态。

> 仅支持 macOS。第一版公开构建未签名。

## 安装

### 下载 DMG

从 [GitHub Releases](https://github.com/RonnyCao0816/netstats/releases) 下载最新的 `NetStats-*.dmg`，打开后将 `NetStats.app` 拖到 `/Applications`。

由于第一版安装包未签名，macOS 首次打开时可能拦截。可以到 **系统设置 > 隐私与安全性** 中允许打开，或按住 Control 点击 App 后选择 **打开**。

### npm

`@ronnycao/netstats` npm 包已经准备好，发布到 npm 后可使用：

```bash
npx @ronnycao/netstats install
```

npm 安装器会下载匹配版本的 GitHub Release DMG 并打开它。它不会在 `postinstall` 阶段自动安装软件。

## 功能

- 菜单栏和详情面板显示 CPU 使用率
- 显示内存负载、已用内存、缓存内存、压缩内存
- 显示网络上传和下载速度
- 显示公网 IPv4、地理位置，并支持复制 IP
- 显示 Clash Verge Dev 状态：运行状态、系统代理、TUN、模式、订阅、代理组、当前节点
- 可配置哪些指标显示在菜单栏和悬停提示中
- AppKit + SwiftUI 原生 macOS 界面
- 支持中文和英文切换

## 从源码构建

```bash
git clone https://github.com/RonnyCao0816/netstats.git
cd netstats
swift build -c release
```

打包菜单栏 App：

```bash
scripts/package_app.sh
open build/NetStats.app
```

生成 DMG：

```bash
scripts/package_dmg.sh
open dist
```

## 赞助

如果 NetStats 对你有帮助，可以赞助后续开发：

- Buy Me a Coffee: `https://www.buymeacoffee.com/YOUR_BMC_NAME`
- 支付宝和微信收款码会在你提供图片后放到 `assets/sponsor/`。

## 开源协议

MIT License，详见 [LICENSE](LICENSE)。
