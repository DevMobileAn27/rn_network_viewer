---
tag: v0.1.2
title: RN Network Viewer v0.1.2
---

## What’s new

- Settings feedback popups in English and Vietnamese.
- JSON search, image body previews, and saved inspector tabs and panel sizes.
- Improved request inspection and desktop controls.
- Pairing-token authentication, optional LAN access, and separate MCP authentication.
- Sensitive-data redaction and capture limits, each with its own setting.
- Separate downloads for macOS Apple Silicon, macOS Intel, and Windows x64.

## Downloads

- **macOS Apple Silicon (M-series):** `rn-network-viewer-0.1.2-macos-arm64.zip`
- **macOS Intel:** `rn-network-viewer-0.1.2-macos-x86_64.zip`
- **Windows x64:** `rn-network-viewer-0.1.2-windows-x64.zip`

On macOS, unzip and drag **RN Network Viewer.app** into **Applications**.
On Windows, unzip and run **rn_network_viewer.exe**. Keep the DLL files and `data` folder alongside the executable.

Use `SHA256SUMS.txt` to verify the downloaded ZIPs.

## Upgrading

Use React Native SDK **0.4.7 or later**. Open **Settings → Security → Copy SDK setup**, update your React Native configuration, then rebuild and run your development app.

MCP is disabled by default. Sensitive-data redaction and capture limits are enabled by default and can be changed separately in **Settings → Security**.
