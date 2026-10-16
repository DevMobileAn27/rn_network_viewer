# Changelog

## Unreleased — coordinated security upgrade

- Add independent, persisted switches for sensitive-data redaction and capture limits; include SDK options in copied setup.

- Default capture binding is localhost. LAN is opt-in with an assigned private IPv4 address and explicit source subnet.
- Require SDK pairing token; separate MCP token, rotation controls and authenticated setup snippets. MCP remains off by default and localhost-only.
- Add optional WSS using operator-provided PEM certificates; bound capture connections, rates and payload structure.
- Add security documentation, socket/TLS tests, dependency-update configuration and release download checksums.

Upgrade the React Native SDK at the same time and copy fresh setup from Settings → Security. Existing SDKs without token support cannot connect. Existing screenshots predate the new Security panel.
