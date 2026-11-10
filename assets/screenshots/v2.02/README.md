# v2.02 Terminal native previews

`terminal-zh.png` and `terminal-en.png` show the pending v2.02 Terminal redesign at 760 × 700 pt (1520 × 1400 pixels).

These are native SwiftUI/AppKit view renders from `TerminalMonitorRenderingTests`, with synthetic metrics, process names, the documentation-only IP address `203.0.113.42`, and example location/proxy labels. They are not live desktop screenshots and do not contain real clipboard, calendar, IP or proxy data.

The source is the v2.02 pull-request working tree. The render uses `TerminalMonitorView`, `TerminalTheme`, and AppKit's `NSHostingView.cacheDisplay(in:to:)`. Both previews use the chosen charcoal/warm-orange appearance. The new app version is 2.0.2, build 29; no release artifact is implied by these previews.

To regenerate the fixtures:

```sh
NETSTATS_TERMINAL_RENDER_OUTPUT=/tmp/netstats-terminal-renders swift test --filter TerminalMonitorRenderingTests
```

Copy `demo-simplifiedChinese.png` and `demo-english.png` from that output directory. Do not substitute the integration captures, whose host name can reflect the machine running the tests. Image dimensions, hashes and source hashes are recorded in `manifest.json`.
