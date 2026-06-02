<p align="center">
  <img src="assets/icon/netstats-icon.svg" width="96" alt="NetStats icon">
</p>

<h1 align="center">NetStats</h1>

<p align="center">
  <strong>macOS 原生菜单栏系统监控工具，快速查看 CPU、内存、网络速度、公网 IP 和 Clash Verge Dev 状态。</strong>
</p>

<p align="center">
  中文 | <a href="README.en.md">English</a>
</p>

<p align="center">
  如果 NetStats 对你有帮助，欢迎点一个 Star，让更多 macOS 用户看到它。
</p>

<p align="center">
  <a href="https://github.com/autumncry/netstats/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/autumncry/netstats/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://autumncry.github.io/netstats/"><img alt="Website" src="https://img.shields.io/badge/website-netstats-2f8f46"></a>
  <a href="https://github.com/autumncry/netstats/releases"><img alt="Release" src="https://img.shields.io/github/v/release/autumncry/netstats?label=release"></a>
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/autumncry/netstats"></a>
  <a href="https://github.com/autumncry/netstats/issues"><img alt="Issues" src="https://img.shields.io/github/issues/autumncry/netstats"></a>
  <a href="https://github.com/autumncry/netstats/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/autumncry/netstats?style=social"></a>
</p>

<p align="center">
  <a href="https://github.com/autumncry/netstats/releases/latest"><img src="assets/screenshots/menu-bar.png" width="360" alt="NetStats menu bar"></a>
</p>

<p align="center">
  <a href="https://github.com/autumncry/netstats/releases/latest"><img src="assets/screenshots/panel.png" width="430" alt="NetStats detail panel"></a>
</p>

## 目录

- [安装](#安装)
- [系统要求](#系统要求)
- [特性](#特性)
- [隐私](#隐私)
- [常见问题](#常见问题)
- [从源码构建](#从源码构建)
- [项目资料](#项目资料)
- [贡献](#贡献)
- [开源协议](#开源协议)

## 安装

### Homebrew

```bash
brew tap autumncry/tap
brew install --cask netstats
```

当前 Homebrew cask 使用同一个公开 GitHub Release DMG。第一版公开构建未签名，macOS 首次打开时可能仍会拦截。

### DMG

从 [GitHub Releases](https://github.com/autumncry/netstats/releases/latest) 下载最新的 `NetStats-*.dmg`，打开后将 `NetStats.app` 拖到 `/Applications`。

第一版公开构建未签名，macOS 首次打开时可能拦截。可以到 **系统设置 > 隐私与安全性** 中允许打开，或按住 Control 点击 App 后选择 **打开**。

### npm

`@autumncry/netstats` npm 包已经准备好，发布到 npm 后可使用：

```bash
npx @autumncry/netstats install
```

npm 安装器会下载匹配版本的 GitHub Release DMG 并打开它。它不会在 `postinstall` 阶段自动安装软件。

## 系统要求

- macOS 14.0 或更高版本
- Apple Silicon 和 Intel Mac 均可从源码构建
- Clash Verge Dev 状态展示需要本机已安装并运行 Clash Verge Dev

## 特性

- 菜单栏和详情面板显示 CPU 使用率
- 显示内存负载、已用内存、缓存内存、压缩内存
- 显示网络上传和下载速度
- 显示公网 IPv4、地理位置，并支持复制 IP
- 显示 Clash Verge Dev 状态：运行状态、系统代理、TUN、模式、订阅、代理组、当前节点
- 可配置哪些指标显示在菜单栏和悬停提示中
- AppKit + SwiftUI 原生 macOS 界面
- 支持中文和英文切换

## 隐私

NetStats 的系统指标、网络速度与 Clash Verge Dev 状态均在本机读取和处理，不会上传到 NetStats 的任何项目服务器。公网 IP 与地理位置功能需要请求 `ipinfo.io` 以解析当前公网出口；如果你不需要该信息，可以通过系统防火墙或网络过滤工具阻止该请求。

## 常见问题

### 为什么 macOS 提示无法验证开发者？

当前公开 DMG 未签名、未 notarize。你可以从 GitHub Release 下载源码自行构建，或在确认来源后通过 macOS 的隐私与安全性设置允许打开。

### Clash Verge Dev 信息从哪里读取？

NetStats 会读取本机 Clash Verge Dev 的配置文件、进程状态、系统代理状态，以及本机可访问的 Mihomo 控制接口。它不会把这些信息上传到 NetStats 服务器。

### 为什么 npm 命令暂时不能直接安装？

npm 包源码已经在仓库中准备好，但发布到 npm registry 需要完成 npm 登录后再执行 `npm publish --access public`。在此之前，请优先使用 GitHub Release DMG。

## 从源码构建

```bash
git clone https://github.com/autumncry/netstats.git
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

## 项目资料

- [Roadmap](docs/roadmap.md)：后续功能、分发方式和设计原则
- [Website](https://autumncry.github.io/netstats/)：NetStats 项目落地页
- [Changelog](CHANGELOG.md)：版本更新记录
- [Contributing](CONTRIBUTING.md)：开发环境、PR 要求和隐私注意事项
- [Security](SECURITY.md)：安全与隐私问题报告方式
- [Launch Kit](docs/launch-kit.md)：项目介绍和传播文案

## 贡献

Issue 和 Pull Request 都欢迎。适合贡献的方向包括：更多菜单栏指标、签名与 notarization、Homebrew tap 维护、更多代理客户端状态适配。

如果你愿意帮忙传播，可以参考 [Launch Kit](docs/launch-kit.md) 里的项目介绍和发帖文案。

如果 NetStats 对你有帮助，欢迎点一个 Star，让更多 macOS 用户看到它。

## 开源协议

MIT License，详见 [LICENSE](LICENSE)。
