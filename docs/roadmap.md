# NetStats Roadmap

This roadmap keeps the project direction visible for users and contributors. It is not a promise of delivery order, but it shows what would make NetStats more useful and easier to trust.

## Near Term

- Code signing and notarization for smoother first launch.
- Homebrew tap hardening and release automation.
- Clear public IP and geolocation enable/disable setting.
- Better empty and unavailable states for Clash Verge Dev.
- More polished screenshots for GitHub and release pages.

## Metrics

- Optional disk usage display.
- Optional battery and power display on MacBook devices.
- Optional GPU usage when reliable local sampling is available.
- Per-interface network breakdown in Advanced settings.

## Proxy Integrations

- More robust Clash Verge Dev detection.
- Clearer display of proxy mode, selected group, selected node, and TUN/system proxy state.
- Potential support for other local proxy clients if their state can be read safely.

## Distribution

- Signed and notarized DMG.
- Homebrew tap is available through `brew tap autumncry/tap`.
- Published npm installer.
- Automated release workflow after signing is available.

## Design Principles

- Keep the menu bar compact.
- Keep the detail panel readable and native to macOS.
- Prefer local processing and explicit privacy boundaries.
- Avoid showing sensitive values in public screenshots.
