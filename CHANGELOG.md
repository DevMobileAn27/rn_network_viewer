# Changelog

## 0.1.3 — 2026-10-16

- Fix lipo argument order in macOS architecture verification before release packaging.
- Update release metadata and download names for 0.1.3.

## 0.1.2 — 2026-10-16

- Create a draft GitHub Release when the app version increases on main, using the tag, title and description in github_release_info.md.
- Build and attach separate macOS Apple Silicon, macOS Intel and Windows x64 ZIPs with SHA256 checksums.
- Separate pull request checks from release builds, and retain workflow artifacts for 7 days.
- Validate release metadata and reject tags pointing to a different commit.

## 0.1.1 — 2026-10-16

- Add success, error, warning and informational popups for Settings actions in English and Vietnamese.
- Add JSON search, image body previews and persisted inspector tabs and panel sizes.
- Improve request inspection, desktop controls and architecture-specific macOS builds.

- Add independent, persisted switches for sensitive-data redaction and capture limits; include SDK options in copied setup.

- Default capture binding is localhost. LAN is opt-in with an assigned private IPv4 address and explicit source subnet.
- Require SDK pairing token; separate MCP token, rotation controls and authenticated setup snippets. MCP remains off by default and localhost-only.
- Add optional WSS using operator-provided PEM certificates; bound capture connections, rates and payload structure.
- Add security documentation, socket/TLS tests, dependency-update configuration and release download checksums.

Upgrade the React Native SDK at the same time and copy fresh setup from Settings → Security. Existing SDKs without token support cannot connect. Existing screenshots predate the new Security panel.
