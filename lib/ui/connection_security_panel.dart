import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/strings.dart';
import '../services/connection_security.dart';
import '../services/viewer_server.dart';
import '../services/viewer_mcp_server.dart';
import 'settings_feedback.dart';
import 'viewer_dropdown.dart';
import 'viewer_theme.dart';

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
  late final _token = TextEditingController(text: widget.server.accessToken);
  bool _showToken = false;
  bool _tokensExpanded = false;
  bool _invalidToken = false;
  List<String> _addresses = [];
  bool _busy = false;
  String? _error;

  bool get _pendingChanges =>
      _token.text.trim() != widget.server.accessToken ||
      _lan != widget.server.lanEnabled ||
      _redact != widget.server.redactSensitiveData ||
      _limit != widget.server.limitCapture ||
      (_lan &&
          (_address != widget.server.bindAddress ||
              _cidr.text.trim() != widget.server.lanCidr));

  void _pendingNotice() => showSettingsFeedback(
    context,
    _pendingChanges
        ? context.l10n.settingsPendingApply
        : context.l10n.settingsNoPendingChanges,
    kind: SettingsFeedbackKind.info,
  );
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
      final token = _token.text.trim();
      if (!validAccessToken(token)) {
        setState(() {
          _invalidToken = true;
          _tokensExpanded = true;
        });
        throw FormatException(context.l10n.pairingTokenInvalid);
      }
      if (_lan) {
        try {
          if (_address.isEmpty ||
              !LanSubnet(_cidr.text).contains(InternetAddress(_address))) {
            throw const FormatException();
          }
        } on FormatException {
          throw FormatException(context.l10n.lanSubnetInvalid);
        }
      }
      final prefs = widget.preferences;
      if (prefs != null) {
        // Persist enabled last so interrupted saves cannot enable an incomplete configuration.
        if (!await prefs.setBool('redactSensitiveData', _redact) ||
            !await prefs.setBool('limitCapture', _limit) ||
            !await prefs.setString('captureToken', token) ||
            !await prefs.setString('lanAddress', _address) ||
            !await prefs.setString('lanCidr', _cidr.text.trim()) ||
            !await prefs.setBool('lanEnabled', _lan)) {
          throw StateError('Could not save connection settings');
        }
      }
      await widget.server.stop();
      widget.server.accessToken = token;
      widget.server.redactSensitiveData = _redact;
      widget.server.limitCapture = _limit;
      widget.server.bindAddress = _lan ? _address : '127.0.0.1';
      widget.server.lanCidr = _cidr.text.trim();
      await widget.server.start(port: widget.server.port);
      if (mounted) {
        final error = widget.server.error;
        if (error != null || !widget.server.running) {
          final message = error == null
              ? context.l10n.settingsSaveFailed
              : context.l10n.serverStartFailed(error);
          setState(() => _error = message);
          showSettingsFeedback(
            context,
            message,
            kind: SettingsFeedbackKind.error,
          );
        } else {
          showSettingsFeedback(context, context.l10n.securityApplied);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : context.l10n.settingsSaveFailed,
        );
        showSettingsFeedback(
          context,
          _error!,
          kind: e is FormatException
              ? SettingsFeedbackKind.warning
              : SettingsFeedbackKind.error,
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
      var restartFailed = false;
      String? restartError;
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
        restartFailed =
            widget.mcp.error != null ||
            ((widget.preferences?.getBool('mcpEnabled') ?? false) &&
                !widget.mcp.running);
        restartError = widget.mcp.error;
      } else {
        final running = widget.server.running;
        await widget.server.stop();
        widget.server.accessToken = token;
        _token.text = token;
        _invalidToken = false;
        if (running) {
          await widget.server.start(port: widget.server.port);
          restartFailed = !widget.server.running || widget.server.error != null;
          restartError = widget.server.error;
        }
      }
      if (mounted) {
        if (restartFailed) {
          final message = context.l10n.tokenResetRestartFailed(
            restartError ?? context.l10n.settingsSaveFailed,
          );
          setState(() => _error = message);
          showSettingsFeedback(
            context,
            message,
            kind: SettingsFeedbackKind.warning,
          );
        } else {
          showSettingsFeedback(
            context,
            mcp ? context.l10n.mcpTokenReset : context.l10n.pairingTokenReset,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.settingsSaveFailed);
        showSettingsFeedback(
          context,
          _error!,
          kind: SettingsFeedbackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _cidr.dispose();
    _token.dispose();
    super.dispose();
  }

  Widget _optionTitle(String title, String hint) => Row(
    children: [
      Flexible(child: Text(title)),
      const SizedBox(width: 6),
      Tooltip(
        message: hint,
        triggerMode: TooltipTriggerMode.tap,
        child: Icon(Icons.info_outline, size: 16, color: context.palette.muted),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.server, widget.mcp]),
    builder: (context, _) {
      final busy = _busy || widget.server.busy || widget.mcp.busy;
      final buttonShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      );
      final outlinedButtonStyle = OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: buttonShape,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: _optionTitle(
              context.l10n.allowLan,
              context.l10n.connectionSecurityHint,
            ),
            value: _lan,
            onChanged: busy
                ? null
                : (v) {
                    setState(() => _lan = v);
                    _pendingNotice();
                  },
          ),
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
                  : (v) {
                      setState(() => _address = v);
                      _pendingNotice();
                    },
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
          SwitchListTile(
            key: const ValueKey('redact-sensitive-data'),
            contentPadding: EdgeInsets.zero,
            title: _optionTitle(
              context.l10n.redactSensitiveData,
              context.l10n.redactionTooltip,
            ),
            value: _redact,
            onChanged: busy
                ? null
                : (value) {
                    setState(() => _redact = value);
                    _pendingNotice();
                  },
          ),
          SwitchListTile(
            key: const ValueKey('limit-capture'),
            contentPadding: EdgeInsets.zero,
            title: _optionTitle(
              context.l10n.limitCapture,
              context.l10n.captureLimitTooltip,
            ),
            value: _limit,
            onChanged: busy
                ? null
                : (value) {
                    setState(() => _limit = value);
                    _pendingNotice();
                  },
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ListTile(
            key: const ValueKey('security-tokens-toggle'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.securityTokens),
            trailing: Icon(
              _tokensExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
            ),
            onTap: () => setState(() {
              _tokensExpanded = !_tokensExpanded;
              if (!_tokensExpanded) _showToken = false;
            }),
          ),
          if (_tokensExpanded) ...[
            _optionTitle(
              context.l10n.pairingToken,
              context.l10n.pairingTokenHint,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('capture-token'),
              controller: _token,
              enabled: !busy,
              obscureText: !_showToken,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) {
                if (_invalidToken) setState(() => _invalidToken = false);
              },
              decoration: InputDecoration(
                errorText: _invalidToken
                    ? context.l10n.pairingTokenInvalid
                    : null,
                errorMaxLines: 3,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _showToken
                          ? context.l10n.hidePairingToken
                          : context.l10n.showPairingToken,
                      onPressed: busy
                          ? null
                          : () => setState(() => _showToken = !_showToken),
                      icon: Icon(
                        _showToken ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('default-capture-token'),
                      tooltip: context.l10n.useDefaultToken,
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                _token.text = defaultViewerToken;
                                _invalidToken = false;
                              });
                              _pendingNotice();
                            },
                      icon: const Icon(Icons.settings_backup_restore, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : _apply,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    visualDensity: VisualDensity.standard,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: context.palette.primaryFill,
                    foregroundColor: Colors.white,
                    overlayColor: Colors.white,
                    shape: buttonShape,
                  ),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(context.l10n.applyConnection),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => copySettingsText(
                          context,
                          widget.server.setupCode,
                          message: _pendingChanges
                              ? context.l10n.sdkSetupCopiedPending
                              : context.l10n.sdkSetupCopied,
                          kind: _pendingChanges
                              ? SettingsFeedbackKind.warning
                              : SettingsFeedbackKind.success,
                        ),
                  style: outlinedButtonStyle,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: Text(context.l10n.copySdkSetup),
                ),
                PopupMenuButton<bool>(
                  key: const ValueKey('security-more-actions'),
                  tooltip: context.l10n.securityMoreActions,
                  enabled: !busy,
                  onSelected: _rotate,
                  color: context.palette.surface,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: false,
                      child: Text(context.l10n.rotatePairingToken),
                    ),
                    PopupMenuItem(
                      value: true,
                      child: Text(context.l10n.rotateMcpToken),
                    ),
                  ],
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
