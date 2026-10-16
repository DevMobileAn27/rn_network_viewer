import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/strings.dart';
import '../services/connection_security.dart';
import '../services/viewer_server.dart';
import '../services/viewer_mcp_server.dart';
import 'components.dart';
import 'viewer_dropdown.dart';

class ConnectionSecurityPanel extends StatefulWidget {
  const ConnectionSecurityPanel({
    super.key,
    required this.server,
    required this.mcp,
    this.preferences,
  });
  final ViewerServer server;
  final ViewerMcpServer mcp;
  final SharedPreferences? preferences;
  @override
  State<ConnectionSecurityPanel> createState() =>
      _ConnectionSecurityPanelState();
}

class _ConnectionSecurityPanelState extends State<ConnectionSecurityPanel> {
  late bool _lan = widget.server.lanEnabled;
  late bool _redact = widget.server.redactSensitiveData;
  late bool _limit = widget.server.limitCapture;
  late String _address = _lan ? widget.server.bindAddress : '';
  late final _cidr = TextEditingController(text: widget.server.lanCidr);
  List<String> _addresses = [];
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _discover();
  }

  Future<void> _discover() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      if (!mounted) return;
      setState(() {
        _addresses = interfaces
            .expand((i) => i.addresses)
            .where(privateIPv4)
            .map((a) => a.address)
            .toSet()
            .toList();
        if (!_addresses.contains(_address)) {
          _address = _addresses.firstOrNull ?? '';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _addresses = []);
    }
  }

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_lan &&
          (_address.isEmpty ||
              !LanSubnet(_cidr.text).contains(InternetAddress(_address)))) {
        throw FormatException(context.l10n.lanSubnetInvalid);
      }
      final prefs = widget.preferences;
      if (prefs != null) {
        // Persist enabled last so interrupted saves cannot enable an incomplete configuration.
        if (!await prefs.setBool('redactSensitiveData', _redact) ||
            !await prefs.setBool('limitCapture', _limit) ||
            !await prefs.setString('lanAddress', _address) ||
            !await prefs.setString('lanCidr', _cidr.text.trim()) ||
            !await prefs.setBool('lanEnabled', _lan)) {
          throw StateError('Could not save connection settings');
        }
      }
      await widget.server.stop();
      widget.server.redactSensitiveData = _redact;
      widget.server.limitCapture = _limit;
      widget.server.bindAddress = _lan ? _address : '127.0.0.1';
      widget.server.lanCidr = _cidr.text.trim();
      await widget.server.start(port: widget.server.port);
      if (mounted) setState(() => _error = widget.server.error);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : context.l10n.settingsSaveFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rotate(bool mcp) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = createAccessToken();
      if (widget.preferences != null &&
          !await widget.preferences!.setString(
            mcp ? 'mcpToken' : 'captureToken',
            token,
          )) {
        throw StateError('Could not save token');
      }
      if (mcp) {
        widget.mcp.accessToken = token;
        await widget.mcp.configure(
          enabled:
              widget.preferences?.getBool('mcpEnabled') ?? widget.mcp.running,
          port: widget.mcp.port,
          restart: true,
        );
      } else {
        final running = widget.server.running;
        await widget.server.stop();
        widget.server.accessToken = token;
        if (running) await widget.server.start(port: widget.server.port);
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.settingsSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _cidr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.server, widget.mcp]),
    builder: (context, _) {
      final busy = _busy || widget.server.busy || widget.mcp.busy;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.allowLan),
            value: _lan,
            onChanged: busy ? null : (v) => setState(() => _lan = v),
          ),
          Text(context.l10n.connectionSecurityHint),
          if (_lan) ...[
            const SizedBox(height: 16),
            Text(context.l10n.lanAddress),
            const SizedBox(height: 8),
            ViewerDropdown<String>(
              value: _address,
              options: _addresses.isEmpty
                  ? const [DropdownOption('', '—')]
                  : _addresses.map((a) => DropdownOption(a, a)).toList(),
              onChanged: busy || _addresses.isEmpty
                  ? null
                  : (v) => setState(() => _address = v),
            ),
            const SizedBox(height: 16),
            Text(context.l10n.lanSubnet),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('lan-subnet'),
              controller: _cidr,
              enabled: !busy,
              decoration: const InputDecoration(hintText: '192.168.1.0/24'),
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            key: const ValueKey('redact-sensitive-data'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.redactSensitiveData),
            value: _redact,
            onChanged: busy ? null : (value) => setState(() => _redact = value),
          ),
          SwitchListTile.adaptive(
            key: const ValueKey('limit-capture'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.limitCapture),
            value: _limit,
            onChanged: busy ? null : (value) => setState(() => _limit = value),
          ),
          Text(context.l10n.captureOptionsHint),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: busy ? null : _apply,
                child: Text(context.l10n.applyConnection),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => copyText(context, widget.server.setupCode),
                icon: const Icon(Icons.copy, size: 18),
                label: Text(context.l10n.copySdkSetup),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => _rotate(false),
                child: Text(context.l10n.rotatePairingToken),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => _rotate(true),
                child: Text(context.l10n.rotateMcpToken),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(context.l10n.tokenRotationHint),
        ],
      );
    },
  );
}
