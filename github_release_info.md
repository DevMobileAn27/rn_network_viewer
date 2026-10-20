---
tag: v0.1.6
title: RN Network Viewer v0.1.6
---

## What’s new

- Compact Network table with resizable columns and saved widths. The request list and detail panel start evenly split; panel sizes and the selected detail tab are remembered.
- Scroll hints on the request detail tabs, separate header/body views and fewer repeated titles.
- Preview color values and automatically display base64 image responses.
- New bottom-left notifications with information, success, error and warning states.
- MCP setup with a Codex/Claude selector, plus right-aligned Settings actions and clearer app-update status.
- English/Vietnamese usage guide and a link to GitHub Discussions.
- Updated README with short GIF guides for each feature.
- More reliable macOS update status and UTF-8 release metadata on Windows.

## Downloads

- **macOS Apple Silicon (M-series):** `rn-network-viewer-0.1.6-macos-arm64.zip`
- **macOS Intel:** `rn-network-viewer-0.1.6-macos-x86_64.zip`
- **Windows x64 installer:** `rn-network-viewer-0.1.6-windows-x64-setup.exe`
- **Windows x64 portable:** `rn-network-viewer-0.1.6-windows-x64.zip`

On macOS, unzip and drag **RN Network Viewer.app** into **Applications**.
On Windows, run the installer. For the portable ZIP, unzip and run **rn_network_viewer.exe**. Keep the DLL files and `data` folder alongside the executable.

Use `SHA256SUMS.txt` to verify your downloads. The `appcast-*.xml` files are used by the app updater.

### If macOS blocks the app

After moving the app into **Applications**, if macOS reports an unverified developer or a damaged app, run in **Terminal**:

```sh
xattr -dr com.apple.quarantine "/Applications/RN Network Viewer.app"
open "/Applications/RN Network Viewer.app"
```

This removes the app’s quarantine attribute. Only use it for a trusted download from this repository’s official GitHub Releases.

## Upgrading

Versions without the updater need to install **0.1.6** manually once. This version can receive future published updates from within the app. Export any captures you want to keep before updating.

Use React Native SDK **0.4.7 or later**. Open **Settings → Security → Copy SDK setup**, update your React Native configuration, then rebuild and run your development app.

MCP is disabled by default. Sensitive-data redaction and capture limits are enabled by default and can be changed separately in **Settings → Security**.
