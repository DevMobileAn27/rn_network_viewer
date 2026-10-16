import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rn_network_viewer/l10n/app_localizations.dart';
import 'package:rn_network_viewer/services/capture_store.dart';
import 'package:rn_network_viewer/services/viewer_server.dart';
import 'package:rn_network_viewer/services/viewer_mcp_server.dart';
import 'package:rn_network_viewer/ui/connection_security_panel.dart';
import 'settings_test.dart' show TrackingServer;
import 'viewer_server_test.dart' show until;

void main() {
  test('unlimited retention keeps records and enabling limits trims them', () {
    final store = CaptureStore(
      maxRecords: 1,
      maxBytes: 1024,
      limitCapture: false,
    );
    addTearDown(store.dispose);
    final fixture = jsonDecode(
      File('test/fixtures/sdk_envelope.json').readAsStringSync(),
    );
    store.ingest(fixture);
    expect(store.network.length, 3);
    expect(store.logs.length, 1);
    expect(store.evicted, 0);
    store.limitCapture = true;
    expect(store.network.length + store.logs.length, lessThanOrEqualTo(1));
    expect(store.evicted, greaterThan(0));
  });

  test(
    'unlimited capture accepts large frames, batches and rates while authentication stays required',
    () async {
      final store = CaptureStore();
      final server = ViewerServer(store)..limitCapture = false;
      addTearDown(() async {
        await server.stop();
        server.dispose();
        store.dispose();
      });
      await server.start(port: 0);
      await expectLater(
        WebSocket.connect(server.localUrl),
        throwsA(isA<WebSocketException>()),
      );
      final socket = await WebSocket.connect(
        server.localUrl,
        headers: server.connectionHeaders,
      );
      socket.listen((_) {});
      addTearDown(socket.close);
      final text = 'x' * (ViewerServer.maxMessageBytes + 1);
      socket.add(
        jsonEncode({
          'sdk': {'schemaVersion': 1},
          'session': {'id': 'unlimited'},
          'events': [
            {'source': 'js.console', 'message': text},
          ],
        }),
      );
      await until(() => store.logs.isNotEmpty);
      expect(store.logs.first.message, text);
      final batch = jsonEncode({
        'sdk': {'schemaVersion': 1},
        'session': {'id': 'unlimited'},
        'events': List.generate(
          101,
          (i) => {'source': 'js.console', 'message': '$i'},
        ),
      });
      for (var i = 0; i < 40; i++) {
        socket.add(batch);
      }
      await until(() => store.logs.length == 4041);
      expect(server.connections, 1);
      expect(server.invalidMessages, 0);
    },
  );

  testWidgets(
    'capture choices default on, persist off and are copied into SDK setup',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = CaptureStore();
      final server = TrackingServer(store);
      final mcp = ViewerMcpServer(store, server);
      addTearDown(() {
        mcp.dispose();
        server.dispose();
        store.dispose();
      });
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConnectionSecurityPanel(
                server: server,
                mcp: mcp,
                preferences: preferences,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in ['redact-sensitive-data', 'limit-capture']) {
        final toggle = find.byKey(ValueKey(key));
        expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      }
      await tester.ensureVisible(find.text('Apply & restart'));
      await tester.tap(find.text('Apply & restart'));
      await tester.pumpAndSettle();
      expect(preferences.getBool('redactSensitiveData'), isFalse);
      expect(preferences.getBool('limitCapture'), isFalse);
      expect(server.redactSensitiveData, isFalse);
      expect(store.limitCapture, isFalse);
      await tester.ensureVisible(find.text('Copy SDK setup'));
      await tester.tap(find.text('Copy SDK setup'));
      await tester.pumpAndSettle();
      expect(copied, contains('REDACT_SENSITIVE_DATA: false'));
      expect(copied, contains('LIMIT_CAPTURE: false'));
      expect(copied, contains('VIEWER_TOKEN:'));
      // Reopening Settings reflects the active choices.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConnectionSecurityPanel(
                server: server,
                mcp: mcp,
                preferences: preferences,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('redact-sensitive-data')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const ValueKey('limit-capture')))
            .value,
        isFalse,
      );
    },
  );
}
