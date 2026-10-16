# Security and upgrade guide

These changes are in the working source / next release. Previously published SDK versions without `VIEWER_TOKEN` cannot connect to the secured Viewer. Upgrade both components, rebuild the native app, and copy fresh setup from **Settings → Security**. Port-only initialization now also needs a token in its overrides.

## Connection policy

- Default capture endpoint: `ws://127.0.0.1:38940/rnv/network`.
- LAN is opt-in. Bind only the selected, currently assigned RFC1918 IPv4 address. Require an explicit private CIDR and reject source addresses outside it. IPv6 LAN, wildcard and public binds are unsupported.
- Require a random 256-bit pairing token in the Authorization header before upgrading to WebSocket. Browser Origin headers and unexpected Host headers are rejected. The Android emulator host alias `10.0.2.2` is accepted in localhost mode.
- Discovery is not authorization: a machine on the same LAN still needs the token. A port may remain discoverable by a network scan; these checks restrict access to the service, not visibility of the computer.
- Source IP checks cannot identify physical LAN membership behind a NAT, VPN, reverse proxy or tunnel. Do not expose or forward these endpoints. Use OS firewall rules for the selected interface as defense in depth.
- Reset pairing token disconnects SDK sockets. Reset MCP token restarts MCP and invalidates old client credentials. Tokens are separate; sharing an SDK token does not grant MCP read access.
- Tokens persist in local application preferences (not an encrypted vault). Anyone with access to this OS account/preferences, clipboard, SDK config or client config may obtain them. Keep local config out of Git and rotate after sharing it accidentally.

## WSS

Optional TLS is supported for the capture endpoint. Provision a PEM certificate/key whose IP SAN matches the selected Viewer IP and whose CA is trusted by the device's **native** networking stack. Do not disable certificate verification or install a development CA into a production app.

Launch the executable directly with both environment variables set (Finder does not inherit shell exports):

```sh
RNV_TLS_CERT=/absolute/path/viewer-cert.pem \
RNV_TLS_KEY=/absolute/path/viewer-key.pem \
'/Applications/RN Network Viewer.app/Contents/MacOS/RN Network Viewer'
```

On Windows set the same variables before launching the `.exe`. Protect the private key with OS file permissions. Restart after changing certificates. The Viewer advertises `wss://` and **Copy SDK setup** includes that URL. Missing/invalid certificate configuration fails startup instead of silently falling back to plaintext. A self-signed certificate alone is insufficient: the device must trust it, and Android debug trust configuration may be required.

Without these variables, LAN uses plaintext `ws://`: token authentication does not prevent interception. Prefer localhost/USB on shared or untrusted networks. Certificate provisioning, rotation and OS trust installation are operator responsibilities. The application does not implement certificate pinning or automatic PKI.

## MCP and sensitive data

MCP stays off by default, always binds `127.0.0.1`, requires a separate bearer token, rejects browser origins and offers five read-only tools. Use the configuration copied from Settings. The Codex CLI environment-variable example must be available whenever Codex starts, not just during installation.

The Viewer has no built-in cloud upload or analytics. Enabling MCP lets an authorized AI client read captured data; that client may send it to its model provider. Redaction is best effort, not a guarantee that arbitrary log text or personal data is safe. Disable body/console capture or add redaction keys in the SDK when appropriate. Review exports before sharing them. Captured text must be treated as untrusted data, never agent instructions.

## Capture preferences

**Settings → Security** provides independent **Redact sensitive data** and **Limit capture** switches, both on by default and remembered across launches. Apply/restart the Viewer, copy updated SDK setup and reload the React Native app. Setup includes `REDACT_SENSITIVE_DATA` and `LIMIT_CAPTURE`. SDK-side changes require that updated setup; changing a Viewer switch alone cannot reveal previously redacted data. Only new captures use the new SDK options.

Disabling redaction preserves credential headers, URL values and bodies/logs. Disabling capture limits removes body/text/collection truncation, pending capture queue caps, Viewer message/rate/batch/structure limits and automatic history eviction. The store applies its retention limits again when the switch is re-enabled; old records can then be evicted immediately. This can increase memory use without bound until available memory is exhausted. Platform networking limits still apply (including OkHttp send-queue constraints).

Authentication, source subnet and Host/Origin checks, the connection count limit, protocol validation and handling malformed messages remain active. MCP tool pagination and UI previews affect presentation, not captured body contents.

## Resource limits and boundaries

The capture service permits 8 simultaneous sockets. With **Limit capture** enabled it enforces 1 MiB per assembled message, 100 events per envelope, bounded JSON depth/node count and session metadata, 30 messages/second and 4 MiB/second per socket. Repeated malformed messages disconnect. A socket cannot switch session IDs. With limits enabled, the store retains up to 5,000 records and approximately 64 MiB of event data.

Dart assembles WebSocket messages before the application checks their size; this is not a hard pre-allocation memory cap. MCP request/session resource management is supplied by `mcp_dart`; capture limits do not apply to MCP. Pairing credentials are trusted local credentials, not protection against a malicious authorized OS user or denial of service. Do not deploy this app as an Internet-facing service.

## Evidence and remaining release work

`flutter analyze` and `flutter test` cover authenticated capture, MCP, token rotation, subnet validation, malformed/large payloads and TLS certificate validation. The desktop CI builds macOS/Windows; check the actual run for the commit being installed. Test certificates are generated temporarily; Windows skips the OpenSSL test.

Release automation emits SHA-256 checksums. Checksums detect changed downloads when obtained from a trusted source; they do not establish publisher identity. macOS Developer ID signing/notarization and Windows Authenticode signing still require maintainer certificates and CI secret configuration. Current unsigned/ad-hoc builds must not be advertised as signed or audited.
