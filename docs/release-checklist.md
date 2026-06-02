# Release Checklist

Use this checklist before publishing a new NetStats release.

## Build

- [ ] Update `CHANGELOG.md`.
- [ ] Update `docs/release-notes/vX.Y.Z.md`.
- [ ] Run `swift build -c release`.
- [ ] Run `scripts/package_app.sh`.
- [ ] Run `scripts/package_dmg.sh`.
- [ ] Confirm `dist/NetStats-X.Y.Z.dmg` exists.

## Install Verification

- [ ] Mount the DMG and confirm `NetStats.app` can be copied to `/Applications`.
- [ ] Launch NetStats manually on macOS.
- [ ] Confirm the menu bar item appears.
- [ ] Confirm the detail panel opens.
- [ ] Confirm public IP copy still works.
- [ ] Confirm unsigned-build warning text is still accurate, or update it after signing/notarization.

## Homebrew Tap

- [ ] Update `autumncry/homebrew-tap` cask version.
- [ ] Update the cask `sha256`.
- [ ] Run `brew style --cask autumncry/tap/netstats`.
- [ ] Run `brew fetch --cask autumncry/tap/netstats`.
- [ ] Run `brew install --cask --dry-run autumncry/tap/netstats`.

## GitHub

- [ ] Create or update the GitHub Release.
- [ ] Upload the DMG asset.
- [ ] Use the release notes file as the release body.
- [ ] Confirm GitHub Pages still deploys successfully.
- [ ] Confirm CI passes on `main`.
- [ ] Confirm README badges render correctly.

## Promotion

- [ ] Update `docs/launch-kit.md` if install commands or screenshots changed.
- [ ] Share the website link first: `https://autumncry.github.io/netstats/`.
- [ ] Mention Homebrew and DMG install options.
- [ ] Ask for feedback first, then mention starring as a lightweight close.

