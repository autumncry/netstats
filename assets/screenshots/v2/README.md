# NetStats v2.00 native view renders

These seven images render the actual released SwiftUI components (`HubCardView` and `HubSettingsView`) with synthetic example data. They are **native view renders**, not live desktop screenshots or AI-generated UI images.

The product's existing **Reduce Transparency** branch is selected in the isolated renderer so the native surface can be rendered accurately offscreen. These images do not represent the live Liquid Glass backdrop effect. The rendered card layout, typography, icons and controls match the released views. The pale blue/purple presentation background is part of the isolated render scene, not the user's desktop.

Suggested website caption: **Native view render · Example data · Reduce Transparency**.

- `network.png`: throughput, history, session totals and the six-function Dock.
- `device.png`: CPU, GPU name with honest unavailable utilization, memory, startup capacity, all-disk I/O.
- `calendar.png`: week navigation and synthetic selected-day events.
- `weather.png`: synthetic connected-shortcut weather result; setup is required in the real app.
- `clipboard.png`: synthetic text history, search and actions.
- `shelf.png`: references to disposable example files/folder.
- `settings.png`: shared feature switches, notch/display options and calendar authorization entry.

All feature cards are 1280×880 pixels (2× backing scale); Settings is 1280×1320. Exact sizes and hashes are recorded in `manifest.json`.

## Provenance and privacy

Product source is taken from commit `c47df4af3732700c8d4e5956b2c63f453cf35505`. `git diff v2.00 HEAD -- Sources/NetStats` was empty at production time. A separate temporary SwiftPM app provides the fixtures, a separate UserDefaults suite, private pasteboard and `/tmp` storage. It does not start monitoring services, request calendar/clipboard grants or run a user shortcut. Calendar, clipboard-history reload and shelf refresh are no-ops in the temporary source copies, and `MacBook Pro` replaces the device hostname.

The temporary fixture harness is separate from the product. No product source was edited for these renders.

## Capture limitation

The images render the app's own view hierarchy offscreen through AppKit. They do not capture the live desktop compositor. All seven were visually inspected.
