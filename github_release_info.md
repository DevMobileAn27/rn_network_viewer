---
tag: v0.1.3
title: RN Network Viewer v0.1.3
---

## What’s new

- Fixed macOS architecture verification in the release workflow so Apple Silicon and Intel builds can proceed to ZIP packaging.
- Desktop downloads include separate macOS Apple Silicon, macOS Intel, and Windows x64 ZIPs with SHA256 checksums.

## Downloads

- **macOS Apple Silicon (M-series):** `rn-network-viewer-0.1.3-macos-arm64.zip`
- **macOS Intel:** `rn-network-viewer-0.1.3-macos-x86_64.zip`
- **Windows x64:** `rn-network-viewer-0.1.3-windows-x64.zip`

On macOS, unzip and drag **RN Network Viewer.app** into **Applications**.
On Windows, unzip and run **rn_network_viewer.exe**. Keep the DLL files and `data` folder alongside the executable.

Use `SHA256SUMS.txt` to verify the downloaded ZIPs.

## Upgrading

Use React Native SDK **0.4.7 or later**. Open **Settings → Security → Copy SDK setup**, update your React Native configuration, then rebuild and run your development app.

MCP is disabled by default. Sensitive-data redaction and capture limits are enabled by default and can be changed separately in **Settings → Security**.
