<p align="center">
  <img src="assets/icon/netstats-icon.svg" width="96" alt="NetStats icon">
</p>

<h1 align="center">NetStats v2.00</h1>

<p align="center">
  <strong>A 360 pt native glass hub for Network, Device, Calendar, Weather, Clipboard and Shelf. Open it from the menu bar or an optional physical-notch hover entrance, with shared features and settings.</strong>
</p>

<p align="center">
  <a href="README.md">中文</a> | English
</p>

<p align="center">
  <a href="https://github.com/autumncry/netstats/releases/download/v2.00/NetStats-2.0.0.dmg">Download v2.00 universal DMG</a> ·
  <a href="https://github.com/autumncry/netstats/releases/tag/v2.00">Release notes</a> ·
  <a href="https://autumncry.github.io/netstats/">Explore features and previews</a>
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
  <img src="assets/screenshots/v2/network.png" width="360" alt="NetStats v2.00 Network card with download/upload rates, trend and six-feature Dock, using example data">
  <img src="assets/screenshots/v2/device.png" width="360" alt="NetStats v2.00 Device card with CPU, GPU, memory and startup-volume capacity, using example data">
</p>

<p align="center">
  Native v2.00 SwiftUI view renders in English, with all features enabled, example data and Reduce Transparency. These are not live desktop screenshots. Actual glass varies with macOS, appearance, wallpaper and accessibility settings.
</p>

## Contents

- [Install](#install)
- [Requirements](#requirements)
- [Features](#features)
- [Privacy](#privacy)
- [FAQ](#faq)
- [Build from Source](#build-from-source)
- [Project Docs](#project-docs)
- [Contributing](#contributing)
- [License](#license)

## Install

### v2.00 DMG (recommended)

Download [NetStats-2.0.0.dmg](https://github.com/autumncry/netstats/releases/download/v2.00/NetStats-2.0.0.dmg), open it, and drag `NetStats.app` to `/Applications`. The universal app contains Apple Silicon (arm64) and Intel (x86_64) builds.

[GitHub Release](https://github.com/autumncry/netstats/releases/tag/v2.00) · [SHA-256 checksum](https://github.com/autumncry/netstats/releases/download/v2.00/NetStats-2.0.0.dmg.sha256)

v2.00 uses an ad-hoc signature. It is not Developer ID signed or notarized by Apple. macOS may block the first launch; after confirming the download source, allow it in **System Settings > Privacy & Security**. See the release page for instructions.

### Homebrew and npm

The separate [Homebrew tap](https://github.com/autumncry/homebrew-tap) has not been updated to v2.00, and `@autumncry/netstats` has not been published to npm. Use the DMG above for this version, or build from source.

## Requirements

- macOS 14.0 or later; the universal DMG supports Apple Silicon and Intel Macs
- The menu-bar entrance works on supported Macs; the optional notch entrance requires a built-in physical notch and is initially disabled
- Native system glass on macOS 26+, with native blurred material on macOS 14/15; follows appearance, Reduce Transparency and Reduce Motion settings
- Calendar, Weather and Clipboard require explicit enabling and their respective permission or setup steps
- Clash Verge Dev status requires Clash Verge Dev to be installed and running locally

## Features

### Six-feature Dock

| Feature | What it provides |
| --- | --- |
| Network | Live upload/download rates, short history, session totals and active interfaces. |
| Device | CPU, GPU model and available load, used/total memory and startup-volume capacity. Disk I/O is aggregated across block devices; unavailable GPU readings show “—”. |
| Calendar | Month/week browsing, selected-day events and calendar selection after an explicit Full Access grant. Create and edit in the system Calendar app. |
| Weather | Current Apple Weather through a shortcut you configure and verify, with a 15-minute cache, manual refresh and last successful data retained on failure. See [setup](docs/weather-shortcut.md). |
| Clipboard | Local text/image history, search, paging, preview, copy, pause, clear and app exclusions. Defaults to 30 days with unlimited counts; separate text/image limits and 1–30-day retention are configurable. |
| Shelf | Persistent file/folder references with drag in/out, open, remove and relink. Originals stay in place, and removing a reference never deletes the file. |

### Two entrances, one card

Click the menu-bar item to open the hub; click again to close it. Enable the notch entrance in Settings for a 1-second hover trigger and 300 ms exit grace. A valid file held over the notch for 500 ms opens Shelf; references are added only when dropped.

Click the bottom Dock to switch features and the gear to open shared Settings. Network, Device and Shelf start enabled; Calendar, Weather and Clipboard start disabled. Passive browsing and Dock clicks do not take focus. Editing, owned popovers and file dragging keep the card open. See the [glass hub guide](docs/notch-hover.md).

### Detailed monitoring remains available

Choose **Details** for the Native / Terminal monitor, including system load, memory details, disk, power, short history, process ranking, public IPv4, geolocation and Clash Verge Dev status. Process categories unavailable through stable public APIs show a reason.

Clash information includes running state, system proxy, TUN, mode, subscription traffic, proxy group and selected node. NetStats only displays this state; it does not quit, restart or control Clash Verge Dev. Menu-bar metrics, hover text, detailed-monitor modules and public IP lookup are configurable. English and Chinese interfaces are available.

## Privacy

System metrics, network speed, process ranking and Clash Verge Dev status are read and processed locally. No NetStats account is required, no telemetry is included, and this data is not uploaded to NetStats-owned servers.

- **Calendar:** the system Full Access grant permits reading and writing; NetStats only queries events. The first request is made explicitly from Settings.
- **Clipboard:** local SQLite and image files, with no additional app-level encryption. Supports pause, clear, app exclusions and retention; disabling capture retains history until normal cleanup. Newer macOS versions require background access before automatic capture. Hovering never asks for permission.
- **Shelf:** local file bookmarks only. Moved files or offline disks may require relinking.
- **Weather:** a system shortcut you choose returns current conditions. No background runs occur before a successful explicit test. The shortcut may use Apple's network/location services; NetStats does not read Weather.app private caches.
- **Public IP:** optional requests to `ipinfo.io` resolve the public address and location. Turn this off directly in Settings.

The card adds no Accessibility, Input Monitoring or Screen Recording grant. See [Privacy](docs/PRIVACY.md) and [Permissions](docs/PERMISSIONS.md).

## FAQ

### Can I use it without a notch?

Yes. The menu-bar entrance opens the same six-feature hub. Only the optional notch-hover entrance requires a built-in physical notch.

### Why does macOS say the developer cannot be verified?

The v2.00 DMG is ad-hoc signed, without Developer ID signing or Apple notarization. Download from the [official release](https://github.com/autumncry/netstats/releases/tag/v2.00), check the checksum and follow its first-launch instructions. Building from source is also available.

### Why is Weather not connected automatically?

Weather starts disabled. Configure a dedicated system shortcut, then test the connection in NetStats Settings. It displays current conditions, not forecasts. See [Weather setup](docs/weather-shortcut.md).

### Why does GPU load show “—”?

The GPU model is available, but load depends on valid data exposed by the driver. Missing readings are shown as unavailable rather than 0%.

### Where does the Clash Verge Dev information come from?

NetStats reads configuration, processes, system proxy state and the local Mihomo controller on the same Mac. It does not upload that information to project servers or control/restart Clash Verge Dev.

### Can Homebrew or npm install v2.00?

Use this page's v2.00 DMG for now. The separate Homebrew tap has not been updated to this version, and the npm package has not been published.

## Build from Source

Requires Swift 6 and a toolchain containing the macOS 26 SDK or later. macOS 14 is the app's deployment target, not a promise that older SDKs can build the current source.

```bash
git clone https://github.com/autumncry/netstats.git
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

## Project Docs

- [Website](https://autumncry.github.io/netstats/): six features, previews and downloads
- [Release Notes](docs/release-notes/v2.00.md): v2.00 notes
- [Glass Hub](docs/notch-hover.md): entrances, interactions and persistence
- [Weather Setup](docs/weather-shortcut.md): Apple Weather shortcut configuration
- [Roadmap](docs/roadmap.md): upcoming features, distribution plans and design principles
- [Changelog](CHANGELOG.md): release history
- [Release Checklist](docs/release-checklist.md): future release checks
- [Privacy](docs/PRIVACY.md): data boundaries, external requests and local-first behavior
- [Permissions](docs/PERMISSIONS.md): permission model and intentionally limited metrics
- [Product Growth](docs/product-growth.md): product improvements and SEO growth plan
- [Contributing](CONTRIBUTING.md): development setup, PR expectations and privacy notes
- [Security](SECURITY.md): security and privacy reporting
- [Launch Kit](docs/launch-kit.md): reusable project copy and post drafts

## Contributing

Issues and pull requests are welcome. Areas to improve include native card interactions, feature compatibility, Developer ID signing and notarization, Homebrew tap maintenance and more proxy client integrations.

The [Launch Kit](docs/launch-kit.md) has reusable copy for sharing the project. If NetStats helps, please star the repository.

## License

MIT License. See [LICENSE](LICENSE).
