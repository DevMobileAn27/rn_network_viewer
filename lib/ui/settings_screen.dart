import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/app_settings.dart';
import '../services/viewer_server.dart';
import 'components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.server,
  });
  final AppSettings settings;
  final ViewerServer server;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _port;
  bool _savingLanguage = false;
  bool _savingTheme = false;
  bool _savingPort = false;
  bool _invalidPort = false;

  @override
  void initState() {
    super.initState();
    _port = TextEditingController(
      text:
          '${widget.settings.preferences?.getInt('viewerPort') ?? widget.server.port}',
    );
  }

  @override
  void dispose() {
    _port.dispose();
    super.dispose();
  }

  Future<void> _changeLanguage(String? code) async {
    if (code == null) return;
    setState(() => _savingLanguage = true);
    try {
      await widget.settings.setLanguage(code);
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
    } catch (_) {
      if (mounted) _notice(context.l10n.settingsSaveFailed);
    } finally {
      if (mounted) setState(() => _savingTheme = false);
    }
  }

  Future<void> _savePort() async {
    final port = int.tryParse(_port.text.trim());
    setState(() => _invalidPort = port == null || port < 1 || port > 65535);
    if (_invalidPort) return;
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
        _notice(
          widget.server.running
              ? context.l10n.portSaved
              : context.l10n.serverStartFailed(widget.server.error ?? ''),
        );
      }
    } catch (_) {
      if (mounted) _notice(context.l10n.settingsSaveFailed);
    } finally {
      if (mounted) setState(() => _savingPort = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.settings, widget.server]),
    builder: (context, child) => Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings),
        backgroundColor: context.palette.surface,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              _section(Icons.tune, context.l10n.appearance, [
                _field(
                  context.l10n.theme,
                  DropdownButtonFormField<ThemeMode>(
                    key: ValueKey(widget.settings.themeMode),
                    initialValue: widget.settings.themeMode,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(context.l10n.lightTheme),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(context.l10n.darkTheme),
                      ),
                    ],
                    onChanged: _savingTheme ? null : _changeTheme,
                  ),
                ),
                const SizedBox(height: 20),
                _field(
                  context.l10n.language,
                  DropdownButtonFormField<String>(
                    key: ValueKey(widget.settings.languageCode),
                    initialValue: widget.settings.languageCode,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
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
                  alignment: Alignment.centerLeft,
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
            ],
          ),
        ),
      ),
    ),
  );

  Widget _field(String title, Widget input) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: TextStyle(color: context.palette.muted, fontSize: 12)),
      const SizedBox(height: 8),
      Semantics(label: title, child: input),
    ],
  );

  Widget _section(IconData icon, String title, List<Widget> children) => Card(
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    ),
  );
}
