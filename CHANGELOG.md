# Changelog

All notable changes to NetStats will be documented in this file.

## v2.02 (2.0.2) — Unreleased

- Redesigned Terminal details with a charcoal/warm-orange palette, compact monospaced sections and scrollable content; removed the synthetic Health score and made display switches apply consistently.
- Fixed the Device card clipping disk details and I/O above the feature bar by reserving enough height for its full content.
- Added two-finger horizontal paging across enabled features, with vertical scrolling, editing and drag interactions protected.
- Added directional page transitions and coordinated panel resizing, with reduced-motion fades and isolated outgoing-page interactions.
- Added automatic notch detection with a top-bar fallback for displays without a physical notch, plus manual mode selection.
- Added system-backed launch-at-login settings and an About page with version, copyright and GitHub support links.

## v2.01 (2.0.1) — 2026-11-09

- Fixed clipboard thumbnails overlapping titles and timestamps; wide and tall images now fit inside a fixed thumbnail cell.
- Fixed notch hover being disabled while the independent Settings window remained open.
- Simplified weather setup to a four-line text output and explicit Stop and Output action, with explicit missing-shortcut/no-output guidance and backwards-compatible JSON parsing.

- Grouped network download/upload into aligned rows with equal typography and paired history charts; moved interface identifiers out of the quick card.
- Standardized Dock icon boxes and label baselines, including Shelf.
- Moved all preferences into one reusable standalone Settings window, shared by the menu bar, notch and detailed monitor.

## v2.00 (2.0.0) — 2026-10-22

- Added an opt-in physical-notch hover card with a 1-second dwell and 0.3-second dismissal grace period.
- Replaced the original summary with a 360pt adaptive glass hub shared by the menu bar and notch, with a click-to-switch feature Dock.
- Added network trends, compact device information, EventKit calendar browsing, verified Shortcuts weather, persistent clipboard history, and a bookmark-based file shelf.
- Added shared switches, explicit permission/setup flows, clipboard retention/counts, local search/paging, copy-only file drags, and input/popover interaction holds.
- Preserved menu-bar toggling and coordinated the two surfaces so they do not overlap.
- Added deterministic hover/geometry/layout tests and a local build-and-run action.

## 1.0.0

- Added a native macOS menu bar monitor for CPU, memory, and network speed.
- Added a detail panel with hardware and network sections.
- Added public IPv4 and geolocation display with copy support.
- Added Clash Verge Dev status display.
- Added Chinese and English UI support.
- Added DMG packaging scripts.
- Added npm installer package source.
