# NetStats Product and Growth Plan

This document focuses on product improvements and organic discovery work that can help NetStats grow toward 100 GitHub stars.

## Product Priorities

### 1. Trust and Privacy Controls

NetStats already documents that system metrics, network speed, and Clash Verge Dev status are local, while public IP and geolocation use `ipinfo.io`. The next product step is to make that boundary configurable inside the app:

- Add a setting to disable public IP and geolocation lookup.
- Add a visible "local-only mode" indicator when the external lookup is disabled.
- Add a one-click "refresh public IP" action instead of always treating it as background data.
- Show the external lookup provider in settings.

Why it matters: users who install system monitors care about privacy. A real switch is stronger than README text.

### 2. Distribution Quality

The largest current trust gap is the unsigned DMG. Improve the install experience before broader promotion:

- Code sign `NetStats.app`.
- Notarize the DMG.
- Update README, release notes, Homebrew cask, and landing page once the build is signed.
- Add an auto-update path after signing is available.

Why it matters: unsigned apps create friction exactly when a user is deciding whether the project is safe enough to try.

### 3. Better First-Run Experience

Add a compact first-run settings sheet:

- Choose menu bar metrics.
- Choose language.
- Choose whether public IP/geolocation is enabled.
- Explain Clash Verge Dev detection only when Clash data is unavailable.

Why it matters: users should understand the app within the first minute without opening the README.

### 4. Proxy Status Reliability

Clash Verge Dev support is a differentiator. Make it reliable and easy to debug:

- Add a "last updated" timestamp.
- Show a clear unavailable state when Clash Verge Dev is not running.
- Add a diagnostics view for detected config path, controller availability, and proxy mode.
- Avoid exposing sensitive node names in screenshots by offering a privacy display mode.

Why it matters: this is the feature that makes NetStats different from generic menu bar monitors.

### 5. Useful Alerts Without Becoming Noisy

Consider optional lightweight alerts:

- High memory pressure.
- Network throughput spike.
- Proxy mode changed.
- TUN/system proxy disabled unexpectedly.

Why it matters: passive metrics become more valuable when they catch state changes that users miss.

## SEO Plan

### Technical SEO

- Keep the landing page title focused on the product and macOS menu bar monitoring.
- Use a canonical URL: `https://autumncry.github.io/netstats/`.
- Add Open Graph and Twitter Card metadata for link previews.
- Add a 1200 x 630 social preview image.
- Add `robots.txt` and `sitemap.xml`.
- Add SoftwareApplication JSON-LD structured data.

### Content SEO

Create short pages or sections targeting real search intents:

- "macOS menu bar system monitor"
- "macOS network speed menu bar"
- "Clash Verge Dev status menu bar"
- "macOS public IP menu bar"
- "iStats alternative for macOS menu bar"

Each page should be honest and useful: screenshots, install command, privacy behavior, and a link to GitHub.

### Community SEO

Use the website link as the primary share target and GitHub as the final action:

- V2EX macOS / Apple.
- Reddit `r/macapps` and `r/MacOS`.
- Hacker News `Show HN`.
- X with screenshots and the website link.
- Clash Verge Dev communities, focused on proxy status visibility.

Avoid repeated posting. Reply to feedback and ship small improvements quickly.

## Near-Term Growth Moves

- Publish one signed/notarized release.
- Add a short GIF or video showing menu bar customization.
- Add a privacy toggle for public IP/geolocation.
- Add a "Works with Clash Verge Dev" section on the landing page.
- Create a comparison section against generic system monitors without attacking other projects.
