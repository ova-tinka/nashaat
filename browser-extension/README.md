# Bloom Focus Browser Extension

Manifest V3 extension that enforces Bloom's macOS website rules inside Chromium browsers (Brave, Google Chrome, Microsoft Edge, Arc) via `declarativeNetRequest` and native messaging (`BloomBrowserBridge`), showing a branded block page (`blocked.html`) with an **Open Bloom to unlock** action and automatically redirecting already-open blocked tabs.

## Local Installation (Brave / Chrome / Edge / Arc)

1. Open `/Applications/Bloom.app`, go to **Focus → Websites to block**, and click **Register browser bridge** (or **Save and start website blocking**).
2. Open `brave://extensions` (or `chrome://extensions`).
3. Enable **Developer mode** (top right).
4. Click **Load unpacked** and select this `browser-extension` directory.

The shared domain matcher in `lib/domain-policy.mjs` is adapted from Focuser commit `14cbfdb3d55d3bc669bc9a39a6eddb9915e61844` (MIT license in `FOCUSER-LICENSE`) and shares the exact same test vectors (`tests/fixtures/macos-domain-policy.json`) as the native macOS `WebsiteRules.swift`.
