import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/capture_store.dart';
import 'services/connection_security.dart';
import 'services/app_settings.dart';
import 'l10n/app_localizations.dart';
import 'services/viewer_server.dart';
import 'services/viewer_mcp_server.dart';
import 'ui/viewer_shell.dart';
import 'ui/viewer_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  for (final key in ['captureToken', 'mcpToken']) {
    if (!validAccessToken(preferences.getString(key) ?? '')) {
      if (!await preferences.setString(key, createAccessToken())) {
        throw StateError('Cannot persist access token');
      }
    }
  }
  final store = CaptureStore();
  final server =
      ViewerServer(store, token: preferences.getString('captureToken'))
        ..redactSensitiveData =
            preferences.getBool('redactSensitiveData') ?? true
        ..limitCapture = preferences.getBool('limitCapture') ?? true;
  final cert = Platform.environment['RNV_TLS_CERT'];
  final key = Platform.environment['RNV_TLS_KEY'];
  if (cert != null || key != null) {
    if (cert == null || key == null) {
      throw StateError('Set both RNV_TLS_CERT and RNV_TLS_KEY');
    }
    server.tlsContext = SecurityContext()
      ..useCertificateChain(cert)
      ..usePrivateKey(key);
  }
  if (preferences.getBool('lanEnabled') == true) {
    server.bindAddress = preferences.getString('lanAddress') ?? '';
    server.lanCidr = preferences.getString('lanCidr') ?? '';
  }
  runApp(ViewerApp(store: store, server: server, preferences: preferences));
  unawaited(server.start(port: preferences.getInt('viewerPort') ?? 38940));
}

class ViewerApp extends StatefulWidget {
  const ViewerApp({
    super.key,
    required this.store,
    required this.server,
    this.preferences,
    this.mcpServer,
  });
  final CaptureStore store;
  final ViewerServer server;
  final SharedPreferences? preferences;
  final ViewerMcpServer? mcpServer;

  @override
  State<ViewerApp> createState() => _ViewerAppState();
}

class _ViewerAppState extends State<ViewerApp> {
  late final AppSettings _settings = AppSettings(widget.preferences);
  late final ViewerMcpServer _mcp =
      widget.mcpServer ??
      ViewerMcpServer(
        widget.store,
        widget.server,
        token: widget.preferences?.getString('mcpToken'),
      );

  @override
  void initState() {
    super.initState();
    _settings.addListener(_syncMcp);
    _syncMcp();
  }

  void _syncMcp() => unawaited(
    _mcp.configure(enabled: _settings.mcpEnabled, port: _settings.mcpPort),
  );

  @override
  void dispose() {
    _settings.removeListener(_syncMcp);
    _settings.dispose();
    if (widget.mcpServer == null) _mcp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _settings,
    builder: (context, child) => MaterialApp(
      title: 'RN Network Viewer',
      locale: _settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
      theme: viewerTheme(Brightness.light),
      darkTheme: viewerTheme(Brightness.dark),
      themeMode: _settings.themeMode,
      home: ViewerShell(
        store: widget.store,
        server: widget.server,
        settings: _settings,
        mcpServer: _mcp,
      ),
    ),
  );
}
