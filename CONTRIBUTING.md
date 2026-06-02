# Contributing to NetStats

Thanks for helping improve NetStats. The project is a small native macOS app, so the best contributions are focused, easy to review, and respectful of the menu bar experience.

## Good First Contributions

- Fix UI spacing, text wrapping, or localization issues.
- Improve README, screenshots, release notes, or install instructions.
- Add small system metrics that fit the existing panel layout.
- Improve Clash Verge Dev status detection.
- Add packaging support such as Homebrew Cask, signing, or notarization.

## Development Setup

```bash
git clone https://github.com/autumncry/netstats.git
cd netstats
swift build
```

Run a release build:

```bash
swift build -c release
```

Package the app:

```bash
scripts/package_app.sh
open build/NetStats.app
```

Build the DMG:

```bash
scripts/package_dmg.sh
open dist
```

## Pull Request Guidelines

- Keep changes scoped to one behavior or one documentation update.
- Match the existing SwiftUI/AppKit style instead of introducing a new UI framework.
- Prefer native macOS APIs and local processing.
- Add screenshots for visible UI changes.
- Mention the macOS version you tested on.
- Do not include personal IP addresses, proxy node names, or private desktop screenshots in issues or PRs.

## Privacy Guidelines

NetStats should keep system metrics, network speed, and proxy status local whenever possible. If a change adds any network request or reads sensitive local state, document it clearly in the PR and README.
