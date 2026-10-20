import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/strings.dart';
import '../services/app_settings.dart';
import '../services/app_updater.dart';
import '../services/viewer_server.dart';
import '../services/viewer_mcp_server.dart';
import 'components.dart';
import 'connection_security_panel.dart';
import 'settings_feedback.dart';
import 'viewer_dropdown.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.server,
    required this.mcpServer,
    this.updater,
  });
  final AppSettings settings;
  final ViewerServer server;
  final ViewerMcpServer mcpServer;
  final AppUpdater? updater;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _port;
  late final TextEditingController _mcpPort;
  late final Future<String> _version;
  bool _savingLanguage = false;
  bool _savingTheme = false;
  bool _savingPort = false;
  bool _invalidPort = false;
  bool _savingMcp = false;
  bool _invalidMcpPort = false;
  McpSetupClient _mcpClient = McpSetupClient.codex;

  @override
  void initState() {
    super.initState();
    _version = PackageInfo.fromPlatform()
        .then((info) => info.version)
        .onError((_, _) => '—');
    _port = TextEditingController(
      text:
          '${widget.settings.preferences?.getInt('viewerPort') ?? widget.server.port}',
    );
    _mcpPort = TextEditingController(text: '${widget.settings.mcpPort}');
  }

  @override
  void dispose() {
    _port.dispose();
    _mcpPort.dispose();
    super.dispose();
  }

  Future<void> _changeLanguage(String? code) async {
    if (code == null) return;
    setState(() => _savingLanguage = true);
    try {
      await widget.settings.setLanguage(code);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) showSettingsFeedback(context, context.l10n.languageSaved);
    } catch (_) {
      if (mounted) _notice(context.l10n.settingsSaveFailed);
    } finally {
      if (mounted) setState(() => _savingLanguage = false);
    }
  }

  Future<void> _changeTheme(ThemeMode? mode) async {
    if (mode == null) return;
    setState(() => _savingTheme = true);
    try {
      await widget.settings.setThemeMode(mode);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) showSettingsFeedback(context, context.l10n.themeSaved);
    } catch (_) {
      if (mounted) _notice(context.l10n.settingsSaveFailed);
    } finally {
      if (mounted) setState(() => _savingTheme = false);
    }
  }

  Future<void> _savePort() async {
    final port = int.tryParse(_port.text.trim());
    setState(() => _invalidPort = port == null || port < 1 || port > 65535);
    if (_invalidPort) {
      showSettingsFeedback(
        context,
        context.l10n.invalidPortNotice,
        kind: SettingsFeedbackKind.warning,
      );
      return;
    }
    setState(() => _savingPort = true);
    try {
      final preferences = widget.settings.preferences;
      if (preferences != null &&
          !await preferences.setInt('viewerPort', port!)) {
        throw StateError('Could not persist port preference');
      }
      await widget.server.stop();
      await widget.server.start(port: port!);
      if (mounted) {
        if (widget.server.running) {
          showSettingsFeedback(context, context.l10n.portSaved);
        } else {
          _notice(context.l10n.serverStartFailed(widget.server.error ?? ''));
        }
      }
    } catch (_) {
      if (mounted) _notice(context.l10n.settingsSaveFailed);
    } finally {
      if (mounted) setState(() => _savingPort = false);
    }
  }

  void _notice(String text) =>
      showSettingsFeedback(context, text, kind: SettingsFeedbackKind.error);

  Future<void> _changeMcp(bool enabled) async {
    setState(() => _savingMcp = true);
    try {
      await widget.settings.setMcpEnabled(enabled);
      await widget.mcpServer.configure(
        enabled: enabled,
        port: widget.settings.mcpPort,
      );
      if (mounted) {
        if (widget.mcpServer.error != null ||
            (enabled && !widget.mcpServer.running)) {
          _notice(context.l10n.serverStartFailed(widget.mcpServer.error ?? ''));
        } else {
          showSettingsFeedback(
            context,
            enabled
                ? context.l10n.mcpEnabledNotice
                : context.l10n.mcpDisabledNotice,
          );
        }
      }
    } catch (_) {
      if (mounted) _notice(context.l10n.settingsSaveFailed);
    } finally {
      if (mounted) setState(() => _savingMcp = false);
    }
  }

  Future<void> _saveMcpPort() async {
    final port = int.tryParse(_mcpPort.text.trim());
    setState(() => _invalidMcpPort = port == null || port < 1 || port > 65535);
    if (_invalidMcpPort) {
      showSettingsFeedback(
        context,
        context.l10n.invalidPortNotice,
        kind: SettingsFeedbackKind.warning,
      );
      return;
    }
    setState(() => _savingMcp = true);
    try {
      final changed = widget.settings.mcpPort != port;
      await widget.settings.setMcpPort(port!);
      await widget.mcpServer.configure(
        enabled: widget.settings.mcpEnabled,
        port: port,
        restart: !changed,
      );
      if (mounted) {
        if (widget.mcpServer.error != null ||
            (widget.settings.mcpEnabled && !widget.mcpServer.running)) {
          _notice(context.l10n.serverStartFailed(widget.mcpServer.error ?? ''));
        } else if (widget.settings.mcpEnabled) {
          showSettingsFeedback(context, context.l10n.mcpPortSaved);
        } else {
          showSettingsFeedback(
            context,
            context.l10n.mcpPortSavedDisabled,
            kind: SettingsFeedbackKind.info,
          );
        }
      }
    } catch (_) {
      if (mounted) _notice(context.l10n.settingsSaveFailed);
    } finally {
      if (mounted) setState(() => _savingMcp = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.settings,
      widget.server,
      widget.mcpServer,
      if (widget.updater != null) widget.updater!,
    ]),
    builder: (context, child) => Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings),
        backgroundColor: context.palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > 820
              ? (constraints.maxWidth - 764) / 2
              : 28.0;
          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 28,
            ),
            children: [
              _section(Icons.tune, context.l10n.appearance, [
                _field(
                  context.l10n.theme,
                  ViewerDropdown<ThemeMode>(
                    value: widget.settings.themeMode,
                    options: [
                      DropdownOption(ThemeMode.light, context.l10n.lightTheme),
                      DropdownOption(ThemeMode.dark, context.l10n.darkTheme),
                    ],
                    onChanged: _savingTheme ? null : _changeTheme,
                  ),
                ),
                const SizedBox(height: 20),
                _field(
                  context.l10n.language,
                  ViewerDropdown<String>(
                    value: widget.settings.languageCode,
                    options: const [
                      DropdownOption('vi', 'Tiếng Việt'),
                      DropdownOption('en', 'English'),
                    ],
                    onChanged: _savingLanguage ? null : _changeLanguage,
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _section(Icons.lan_outlined, context.l10n.connection, [
                _field(
                  context.l10n.webSocketPort,
                  TextField(
                    key: const ValueKey('viewer-port'),
                    controller: _port,
                    keyboardType: TextInputType.number,
                    enabled: !_savingPort && !widget.server.busy,
                    decoration: InputDecoration(
                      errorText: _invalidPort
                          ? context.l10n.portValidation
                          : null,
                    ),
                    onChanged: (_) {
                      if (_invalidPort) setState(() => _invalidPort = false);
                    },
                    onSubmitted: (_) {
                      if (!_savingPort && !widget.server.busy) _savePort();
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _savingPort || widget.server.busy
                        ? null
                        : _savePort,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _savingPort
                          ? context.l10n.saving
                          : context.l10n.saveRestart,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _mcpSection(),
              const SizedBox(height: 20),
              _section(Icons.security, context.l10n.security, [
                ConnectionSecurityPanel(
                  server: widget.server,
                  mcp: widget.mcpServer,
                  preferences: widget.settings.preferences,
                ),
              ]),
              if (widget.updater case final updater?) ...[
                const SizedBox(height: 20),
                _section(Icons.system_update_alt, context.l10n.appUpdates, [
                  FutureBuilder<String>(
                    future: _version,
                    builder: (context, snapshot) => Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Version ${snapshot.data ?? '…'}'),
                          if (updater.status == UpdateStatus.current ||
                              updater.status == UpdateStatus.available)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Tooltip(
                                  message:
                                      updater.status == UpdateStatus.current
                                      ? context.l10n.updateCurrent
                                      : context.l10n.updateAvailable,
                                  child: Icon(
                                    updater.status == UpdateStatus.current
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.update_rounded,
                                    key: const ValueKey(
                                      'version-update-status',
                                    ),
                                    size: 18,
                                    color:
                                        updater.status == UpdateStatus.current
                                        ? const Color(0xff22c55e)
                                        : context.palette.accent,
                                    semanticLabel:
                                        updater.status == UpdateStatus.current
                                        ? context.l10n.updateCurrent
                                        : context.l10n.updateAvailable,
                                  ),
                                ),
                              ),
                            ),
                          const TextSpan(text: ' - Nguyễn Quốc An'),
                        ],
                      ),
                      key: const ValueKey('app-version'),
                      style: TextStyle(color: context.palette.muted),
                    ),
                  ),
                  if (updater.status != UpdateStatus.current &&
                      updater.status != UpdateStatus.available) ...[
                    const SizedBox(height: 12),
                    Text(
                      switch (updater.status) {
                        UpdateStatus.idle => context.l10n.updateReady,
                        UpdateStatus.checking => context.l10n.updateChecking,
                        UpdateStatus.available => context.l10n.updateAvailable,
                        UpdateStatus.current => context.l10n.updateCurrent,
                        UpdateStatus.failed => context.l10n.updateFailed,
                        UpdateStatus.installing =>
                          context.l10n.updateInstalling,
                      },
                      style: TextStyle(
                        color: switch (updater.status) {
                          UpdateStatus.idle => context.palette.muted,
                          UpdateStatus.failed => context.palette.danger,
                          UpdateStatus.available || UpdateStatus.current =>
                            context.palette.methodColor('POST'),
                          UpdateStatus.checking ||
                          UpdateStatus.installing => context.palette.info,
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: const ValueKey('check-app-updates'),
                      onPressed: updater.supported && !updater.busy
                          ? () => updater.check()
                          : null,
                      icon: Icon(
                        updater.status == UpdateStatus.available
                            ? Icons.update_rounded
                            : Icons.refresh,
                        size: 18,
                      ),
                      label: Text(
                        updater.status == UpdateStatus.available
                            ? context.l10n.updateNewVersion
                            : context.l10n.checkForUpdates,
                      ),
                    ),
                  ),
                ]),
              ],
            ],
          );
        },
      ),
    ),
  );

  Widget _mcpSection() {
    final mcp = widget.mcpServer;
    final busy = _savingMcp || mcp.busy;
    final status = StatusChip(
      mcp.busy
          ? context.l10n.starting
          : mcp.running
          ? context.l10n.mcpListening
          : widget.settings.mcpEnabled
          ? context.l10n.serverStopped
          : context.l10n.mcpDisabled,
      color:
          (mcp.error != null
                  ? SettingsFeedbackKind.error
                  : mcp.running
                  ? SettingsFeedbackKind.success
                  : SettingsFeedbackKind.info)
              .color(context.palette),
    );
    final port = _field(
      context.l10n.mcpPort,
      TextField(
        key: const ValueKey('mcp-port'),
        controller: _mcpPort,
        keyboardType: TextInputType.number,
        enabled: !busy,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          errorText: _invalidMcpPort ? context.l10n.portValidation : null,
          errorMaxLines: 4,
        ),
        onChanged: (_) {
          if (_invalidMcpPort) setState(() => _invalidMcpPort = false);
        },
        onSubmitted: (_) {
          if (!busy) _saveMcpPort();
        },
      ),
    );
    final endpoint = _field(
      context.l10n.mcpEndpoint,
      Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.palette.input,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: SelectableText(mcp.endpoint, style: mono),
        ),
      ),
    );
    return _section(
      Icons.hub_outlined,
      'MCP',
      [
        if (mcp.error != null) ...[
          Text(
            context.l10n.serverStartFailed(mcp.error!),
            key: const ValueKey('mcp-error'),
            style: TextStyle(color: context.palette.danger),
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 680
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 160, child: port),
                    const SizedBox(width: 20),
                    Expanded(child: endpoint),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [port, const SizedBox(height: 16), endpoint],
                ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('save-mcp-port'),
                onPressed: busy ? null : _saveMcpPort,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  visualDensity: VisualDensity.standard,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _savingMcp ? context.l10n.saving : context.l10n.saveRestart,
                ),
              ),
              _mcpCopyButton(),
            ],
          ),
        ),
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          status,
          const SizedBox(width: 12),
          Tooltip(
            message: context.l10n.enableMcp,
            child: Semantics(
              label: context.l10n.enableMcp,
              child: Switch(
                key: const ValueKey('mcp-enabled'),
                value: widget.settings.mcpEnabled,
                onChanged: busy ? null : _changeMcp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mcpCopyButton() {
    final mcp = widget.mcpServer;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: context.palette.primaryFill,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: FilledButton.icon(
                key: const ValueKey('copy-mcp-setup'),
                onPressed: () {
                  copySettingsText(
                    context,
                    mcp.setupCommand(_mcpClient),
                    message: context.l10n.mcpCopySuccess,
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  visualDensity: VisualDensity.standard,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  overlayColor: Colors.white,
                  shape: const RoundedRectangleBorder(),
                ),
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: Text(context.l10n.copyMcpSetup),
              ),
            ),
            Container(
              width: 1,
              height: 24,
              color: Colors.white.withValues(alpha: .3),
            ),
            _mcpClientMenu(),
          ],
        ),
      ),
    );
  }

  Widget _mcpClientMenu() {
    return MenuAnchor(
      consumeOutsideTap: true,
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomStart,
        backgroundColor: WidgetStatePropertyAll(context.palette.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.palette.line),
          ),
        ),
      ),
      menuChildren: [
        for (final client in McpSetupClient.values)
          MenuItemButton(
            key: ValueKey('copy-mcp-${client.name}'),
            onPressed: () => setState(() => _mcpClient = client),
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(0, 44)),
            ),
            leadingIcon: _mcpClient == client
                ? Icon(Icons.check, size: 18, color: context.palette.accent)
                : const SizedBox(width: 18),
            child: Text(client.label),
          ),
      ],
      builder: (context, controller, child) => Semantics(
        expanded: controller.isOpen,
        child: TextButton.icon(
          key: const ValueKey('copy-mcp-formats'),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: Colors.white,
            overlayColor: Colors.white,
            shape: const RoundedRectangleBorder(),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          iconAlignment: IconAlignment.end,
          label: Text(_mcpClient.label),
        ),
      ),
    );
  }

  Widget _field(String title, Widget input) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: TextStyle(color: context.palette.muted, fontSize: 12)),
      const SizedBox(height: 8),
      Semantics(label: title, child: input),
    ],
  );

  Widget _section(
    IconData icon,
    String title,
    List<Widget> children, {
    Widget? trailing,
  }) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: context.palette.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    ),
  );
}
