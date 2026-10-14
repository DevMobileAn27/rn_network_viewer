import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/capture_store.dart';
import 'services/app_settings.dart';
import 'l10n/app_localizations.dart';
import 'services/viewer_server.dart';
import 'ui/viewer_shell.dart';
import 'ui/viewer_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final store = CaptureStore();
  final server = ViewerServer(store);
  runApp(ViewerApp(store: store, server: server, preferences: preferences));
  unawaited(server.start(port: preferences.getInt('viewerPort') ?? 38940));
}

class ViewerApp extends StatefulWidget {
  const ViewerApp({
    super.key,
    required this.store,
    required this.server,
    this.preferences,
  });
  final CaptureStore store;
  final ViewerServer server;
  final SharedPreferences? preferences;

  @override
  State<ViewerApp> createState() => _ViewerAppState();
}

class _ViewerAppState extends State<ViewerApp> {
  late final AppSettings _settings = AppSettings(widget.preferences);

  @override
  void dispose() {
    _settings.dispose();
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
      ),
    ),
  );
}
