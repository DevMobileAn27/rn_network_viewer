import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rn_network_viewer/l10n/app_localizations.dart';
import 'package:rn_network_viewer/services/app_settings.dart';
import 'package:rn_network_viewer/services/capture_store.dart';
import 'package:rn_network_viewer/services/viewer_server.dart';
import 'package:rn_network_viewer/ui/settings_screen.dart';
import 'package:rn_network_viewer/ui/viewer_dropdown.dart';
import 'package:rn_network_viewer/ui/viewer_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_test.dart' show TrackingMcpServer;

class FeedbackServer extends ViewerServer {
  FeedbackServer(super.store);
  bool started = true;
  bool failStart = false;
  int starts = 0;
  @override
  bool get running => started;
  @override
  Future<void> start({int port = 38940}) async {
    starts++;
    this.port = port;
    started = !failStart;
    error = failStart ? 'Port already in use' : null;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    started = false;
    notifyListeners();
  }
}

class FeedbackSettings extends AppSettings {
  FeedbackSettings(super.preferences);
  bool failSave = false;
  @override
  Future<void> setLanguage(String code) async {
    if (failSave) throw StateError('Preference write failed');
    await super.setLanguage(code);
  }
}

class FeedbackHarness {
  FeedbackHarness(this.preferences)
    : store = CaptureStore(),
      settings = FeedbackSettings(preferences) {
    viewer = FeedbackServer(store);
    mcp = TrackingMcpServer(store, viewer);
  }
  final SharedPreferences preferences;
  final CaptureStore store;
  final FeedbackSettings settings;
  late final FeedbackServer viewer;
  late final TrackingMcpServer mcp;

  static Future<FeedbackHarness> pump(
    WidgetTester tester, {
    double width = 1000,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final h = FeedbackHarness(await SharedPreferences.getInstance());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      h.mcp.dispose();
      h.viewer.dispose();
      h.settings.dispose();
      h.store.dispose();
    });
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: h.settings,
        builder: (context, _) => MaterialApp(
          locale: h.settings.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: viewerTheme(Brightness.light),
          darkTheme: viewerTheme(Brightness.dark),
          themeMode: h.settings.themeMode,
          home: SettingsScreen(
            settings: h.settings,
            server: h.viewer,
            mcpServer: h.mcp,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return h;
  }
}

Finder feedback(String kind) => find.byKey(ValueKey('settings-feedback-$kind'));

Future<void> tapAction(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'language and theme success use the selected locale and replace notices',
    (tester) async {
      final h = await FeedbackHarness.pump(tester);
      await tapAction(tester, find.byType(ViewerDropdown<String>).first);
      await tapAction(tester, find.text('Tiếng Việt').last);
      expect(find.text('Đã đổi ngôn ngữ.'), findsOneWidget);
      expect(feedback('success'), findsOneWidget);
      await tapAction(tester, find.byType(ViewerDropdown<ThemeMode>));
      await tapAction(tester, find.text('Đêm').last);
      expect(h.settings.themeMode, ThemeMode.dark);
      expect(find.text('Đã đổi giao diện.'), findsOneWidget);
      expect(find.text('Đã đổi ngôn ngữ.'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets('preference failure reports an error without claiming success', (
    tester,
  ) async {
    final h = await FeedbackHarness.pump(tester);
    h.settings.failSave = true;
    await tapAction(tester, find.byType(ViewerDropdown<String>).first);
    await tapAction(tester, find.text('Tiếng Việt').last);
    expect(h.settings.languageCode, 'en');
    expect(feedback('error'), findsOneWidget);
    expect(
      find.text('Could not save settings. Please try again.'),
      findsOneWidget,
    );
    expect(feedback('success'), findsNothing);
  });

  testWidgets(
    'viewer port distinguishes validation, restart success and failure',
    (tester) async {
      final h = await FeedbackHarness.pump(tester);
      final port = find.byKey(const ValueKey('viewer-port'));
      final save = find.text('Save & restart').first;
      await tester.enterText(port, '0');
      await tapAction(tester, save);
      expect(feedback('warning'), findsOneWidget);
      expect(h.viewer.starts, 0);
      await tester.enterText(port, '39940');
      await tapAction(tester, save);
      expect(feedback('success'), findsOneWidget);
      expect(find.text('Port saved. Server restarted.'), findsOneWidget);
      h.viewer.failStart = true;
      await tapAction(tester, save);
      expect(feedback('error'), findsOneWidget);
      expect(find.textContaining('Port already in use'), findsOneWidget);
      expect(feedback('success'), findsNothing);
    },
  );

  testWidgets(
    'MCP reports disabled saves, failed enable, retry and disable accurately',
    (tester) async {
      final h = await FeedbackHarness.pump(tester);
      final save = find.byKey(const ValueKey('save-mcp-port'));
      await tapAction(tester, save);
      expect(feedback('info'), findsOneWidget);
      expect(
        find.text('MCP port saved. MCP is still disabled.'),
        findsOneWidget,
      );
      expect(h.mcp.starts, 0);
      h.mcp.failStart = true;
      await tapAction(tester, find.byKey(const ValueKey('mcp-enabled')));
      expect(feedback('error'), findsOneWidget);
      expect(feedback('success'), findsNothing);
      h.mcp.failStart = false;
      await tapAction(tester, save);
      expect(feedback('success'), findsOneWidget);
      expect(
        find.text('MCP port saved. MCP server restarted.'),
        findsOneWidget,
      );
      await tapAction(tester, find.byKey(const ValueKey('mcp-enabled')));
      expect(find.text('MCP disabled.'), findsOneWidget);
      expect(h.mcp.running, isFalse);
    },
  );

  testWidgets(
    'security drafts and copies are distinguished from applied settings',
    (tester) async {
      final h = await FeedbackHarness.pump(tester);
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
      await tapAction(
        tester,
        find.byKey(const ValueKey('redact-sensitive-data')),
      );
      expect(feedback('info'), findsOneWidget);
      expect(h.viewer.redactSensitiveData, isTrue);
      await tapAction(tester, find.text('Copy SDK setup'));
      expect(feedback('warning'), findsOneWidget);
      expect(copied, contains('REDACT_SENSITIVE_DATA: true'));
      await tapAction(tester, find.text('Apply & restart'));
      expect(feedback('success'), findsOneWidget);
      expect(h.viewer.redactSensitiveData, isFalse);
      await tapAction(tester, find.text('Copy SDK setup'));
      expect(find.text('SDK setup copied.'), findsOneWidget);
      expect(feedback('success'), findsOneWidget);
      expect(copied, contains('REDACT_SENSITIVE_DATA: false'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('token resets report success and warn when restart fails', (
    tester,
  ) async {
    final h = await FeedbackHarness.pump(tester);
    final originalToken = h.viewer.accessToken;
    await tapAction(tester, find.text('Reset pairing token'));
    expect(h.viewer.accessToken, isNot(originalToken));
    expect(h.preferences.getString('captureToken'), h.viewer.accessToken);
    expect(feedback('success'), findsOneWidget);
    expect(find.textContaining(h.viewer.accessToken), findsNothing);
    await tapAction(tester, find.text('Reset MCP token'));
    expect(h.preferences.getString('mcpToken'), h.mcp.accessToken);
    expect(find.textContaining('MCP token reset.'), findsOneWidget);
    h.viewer.failStart = true;
    await tapAction(tester, find.text('Reset pairing token'));
    expect(feedback('warning'), findsOneWidget);
    expect(feedback('success'), findsNothing);
    expect(
      find.descendant(
        of: feedback('warning'),
        matching: find.textContaining(
          'Token reset, but the server could not restart',
        ),
      ),
      findsOneWidget,
    );
  });

  for (final width in [560.0, 1360.0]) {
    testWidgets(
      'clipboard failures show dismissible error feedback at width $width',
      (tester) async {
        await FeedbackHarness.pump(tester, width: width);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              throw PlatformException(code: 'clipboard-unavailable');
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
        for (final target in [
          find.byKey(const ValueKey('copy-mcp-setup')),
          find.text('Copy SDK setup'),
        ]) {
          await tapAction(tester, target);
          expect(feedback('error'), findsOneWidget);
          expect(
            find.text('Could not copy to clipboard. Please try again.'),
            findsOneWidget,
          );
          expect(feedback('success'), findsNothing);
          await tapAction(tester, find.byTooltip('Close'));
          expect(find.byType(SnackBar), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
