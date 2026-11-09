# NetStats v2.01 native view renders

These images render the released `HubCardView` with synthetic example data. They are **native component renders**, not live desktop screenshots or AI-generated UI.

- `network-zh.png` / `network-en.png`: current aligned transfer rows, separate history charts and six-feature Dock (784 × 528).
- `device-zh.png` / `device-en.png`: CPU, GPU availability, memory, startup disk and all-disk I/O (784 × 528).

Each image uses the same 392 × 264 pt presentation canvas (784 × 528 pixels at 2×), with the unchanged 360 pt product card centered at its original height and a neutral presentation background. Side margins are 16 pt; the shorter Network card has more vertical breathing room. The product cards are not stretched. Recommended README display width: 360–392 px. Exact dimensions and checksums are in `manifest.json`.

## Provenance and privacy

Source: release tag `v2.01` (`011980254b4c2b87225e7d924ab7910807d3d82c`). A separate temporary SwiftPM renderer copies the product source and uses isolated UserDefaults, a named private pasteboard and temporary storage. No monitoring services are started. Only the Network and Device views are instantiated; the renderer does not read calendar events, real clipboard content, user files or weather shortcuts.

The temporary source copy selects the product's existing Reduce Transparency branch because that environment value is read-only, replaces the device hostname with `MacBook Pro`, and uses the generic GPU label `Apple GPU` with an unavailable-load reading. No repository product source or tests were changed. Device capacity, usage and transfer values are examples; unavailable GPU utilization is shown honestly as “—”.

## Capture limitation

AppKit captures the app's own view hierarchy offscreen. These images do not reproduce the live Liquid Glass desktop backdrop. The layout, typography, icons and controls come from the released views. All four images were visually checked for clipping, alignment and private information.

Suggested caption: **v2.01 native component render · Example data · Reduce Transparency**.
