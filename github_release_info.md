---
tag: v0.1.7
title: RN Network Viewer v0.1.7
---

## What’s new

- Simplified Security settings with advanced token controls collapsed by default and reset actions grouped in a menu.
- Save connection and security changes from the streamlined Settings controls.
- Success and information notifications auto-hide after 3 seconds by default. Warnings, errors and confirmations stay open until dismissed.
- Per-notification overrides for auto-hide and display duration.

## Downloads

- **macOS Apple Silicon (M-series):** `rn-network-viewer-0.1.7-macos-arm64.zip`
- **macOS Intel:** `rn-network-viewer-0.1.7-macos-x86_64.zip`
- **Windows x64 installer:** `rn-network-viewer-0.1.7-windows-x64-setup.exe`
- **Windows x64 portable:** `rn-network-viewer-0.1.7-windows-x64.zip`

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
