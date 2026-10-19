---
tag: v0.1.4
title: RN Network Viewer v0.1.4
---

## What’s new

- Added macOS installation instructions for opening trusted downloads when macOS blocks the app.

## Downloads

- **macOS Apple Silicon (M-series):** `rn-network-viewer-0.1.4-macos-arm64.zip`
- **macOS Intel:** `rn-network-viewer-0.1.4-macos-x86_64.zip`
- **Windows x64:** `rn-network-viewer-0.1.4-windows-x64.zip`

On macOS, unzip and drag **RN Network Viewer.app** into **Applications**.
On Windows, unzip and run **rn_network_viewer.exe**. Keep the DLL files and `data` folder alongside the executable.

Use `SHA256SUMS.txt` to verify the downloaded ZIPs.

### If macOS blocks the app

After moving the app into **Applications**, if macOS reports an unverified developer or a damaged app, run in **Terminal**:

```sh
xattr -dr com.apple.quarantine "/Applications/RN Network Viewer.app"
open "/Applications/RN Network Viewer.app"
```

This removes the app’s quarantine attribute. Only use it for a trusted download from this repository’s official GitHub Releases.

## Upgrading

Use React Native SDK **0.4.7 or later**. Open **Settings → Security → Copy SDK setup**, update your React Native configuration, then rebuild and run your development app.

MCP is disabled by default. Sensitive-data redaction and capture limits are enabled by default and can be changed separately in **Settings → Security**.
