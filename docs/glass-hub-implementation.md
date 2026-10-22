# NetStats glass hub implementation

Approved 2026-10-22: native translucent material, 360pt shared card, click-to-switch six-feature Dock; existing detailed Native/Terminal monitor retained.

The approved visual direction uses a translucent native surface, clear download/upload hierarchy, a notch-centered attachment, and an integrated feature Dock.

## Work ledger

- Shared settings/GPU tests: red confirmed missing types before implementation.
- Root: shared feature selection/settings, glass shell/Dock, network/device views, application lifecycle, integration verification.
- hub_persistence: clipboard SQLite/image persistence, file-reference shelf, feature/settings views and tests.
- hub_integrations: EventKit/calendar, configurable Shortcuts weather bridge, views/setup docs and tests.
- hub_presentation: shared status/notch routing, input focus/interaction holds, real file drag destination.

## Constraints

No automatic calendar/clipboard permission prompts. Weather background refresh only after successful explicit setup. Clipboard unlimited counts by default and up to30 days, stored locally. Shelf persists references and never deletes source files. Unavailable GPU utilization must stay unavailable. Both entrances share feature switches/data; old monitor settings remain accessible.

## Implementation and validation

- Shared360pt adaptive glass shell, click Dock, six switches and settings are connected to both entrances. Existing detailed monitoring remains reachable.
- Calendar/Weather, clipboard/shelf, presentation and root selection tests implemented. Final `swift test`:67 passed,0 failures. Existing `swift run NetStatsLogicTests`: passed.
- Debug and Release builds passed. Release bundle packaged and ad-hoc signed; `codesign --verify --strict` passed. Built app launched and its process remained running.
- Both languages, light/dark, six feature sizes, settings and six-row month layout have offscreen render fixtures. ImageRenderer cannot reproduce live desktop material or every native control; native bitmap fixtures also omit compositor/vibrancy. These fixtures validate size/layout only, not actual desktop glass.
- Fresh review found paused clipboard backfill, old TIFF conversion surviving Clear, and failed image unlink blocking retention. All reproduced with behavioral RED tests, fixed, and verified GREEN. Manual weather refresh was also added, with verified/enabled gating. Scoped re-review marked all four findings ADDRESSED and found no new important issue in the fixes.
- Final root verification:67 tests passed,0 failures; strict signature and packaged Info.plist valid; running Release process confirmed. Release source is prepared for the `v2.00` tag; app and npm versions use `2.0.0`.

## Runtime acceptance

Calendar grants, newer macOS clipboard access and weather shortcut setup intentionally remain user initiated. No personal clipboard content or calendar entries were accessed during tests, and no real user shortcut was run. The running app contains the setup/test controls and weather instructions.

Physical-notch drag delivery, first-click input, popover/sheet Escape, actual translucent material over desktop, fullscreen/external-display changes, lock and sleep/wake require hands-on acceptance. Automated tests and app launch do not establish those results.
