# NetStats

<!-- impeccable:product-schema 1 -->

## Platform

Native macOS application (SwiftUI + AppKit), macOS 14 and later.

## Users and purpose

Mac users inspect system and network activity from the menu bar or a screen-top card, and use calendar, weather, clipboard and file-shelf tools without opening a large dashboard.

## Confirmed constraints

- Native and Terminal are two styles of the detailed monitor. The six-feature hub is a separate surface.
- Chinese and English are supported. Public-facing project documentation defaults to Chinese.
- System samples, process lists, permission states and proxy status must remain truthful. Missing data is unavailable, not zero or an invented score.
- Calendar/clipboard require user-controlled setup or permissions. Weather uses a configured Shortcut. No account or new remote backend is part of this work.
- The existing NetStats name, icon, MIT license and Ronny Cao copyright are retained.
- This design task changes only Terminal detail styling and its presentation. Sampling, Native layout, hub paging and login behavior remain in scope for regression protection.

## Current approved direction

For Terminal details, the user requested modern CLI styling inspired by Claude Code or Codex and explicitly selected deep charcoal with warm orange accents. It must remain a usable monitoring surface, not a simulated interactive shell.
