import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rn_network_viewer/main.dart';
import 'package:rn_network_viewer/services/app_settings.dart';
import 'package:rn_network_viewer/services/capture_store.dart';
import 'package:rn_network_viewer/services/viewer_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrackingServer extends ViewerServer {
  TrackingServer(super.store);
  int restarts = 0;

  @override
  Future<void> start({int port = 38940}) async {
    restarts++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'language preference persists across settings instances; unknown locale falls back',
    () async {
      SharedPreferences.setMockInitialValues({'languageCode': 'fr'});
      final preferences = await SharedPreferences.getInstance();
      final settings = AppSettings(preferences);
      expect(settings.languageCode, 'en');
      await settings.setLanguage('vi');
      expect(preferences.getString('languageCode'), 'vi');
      final restored = AppSettings(preferences);
      expect(restored.languageCode, 'vi');
      await expectLater(settings.setLanguage('fr'), throwsArgumentError);
      expect(settings.languageCode, 'vi');
      settings.dispose();
      restored.dispose();
    },
  );

  test(
    'theme defaults to light and persists across settings instances',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settings = AppSettings(preferences);
      expect(settings.languageCode, 'en');
      expect(settings.themeMode, ThemeMode.light);
      await settings.setThemeMode(ThemeMode.dark);
      expect(AppSettings(preferences).themeMode, ThemeMode.dark);
      await settings.setThemeMode(ThemeMode.light);
      expect(AppSettings(preferences).themeMode, ThemeMode.light);
      await expectLater(
        settings.setThemeMode(ThemeMode.system),
        throwsArgumentError,
      );
      settings.dispose();
    },
  );

  for (final width in [860.0, 1360.0]) {
    testWidgets(
      'settings switches languages without resetting capture or filters at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final store = CaptureStore()
          ..ingest(
            jsonDecode(
              File('test/fixtures/sdk_envelope.json').readAsStringSync(),
            ),
          );
        final server = TrackingServer(store);
        await tester.pumpWidget(
          ViewerApp(store: store, server: server, preferences: preferences),
        );
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(Scaffold))).brightness,
          Brightness.light,
        );
        await tester.enterText(find.byType(TextField).first, 'orders');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('Language'), findsWidgets);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tiếng Việt').last);
        await tester.pumpAndSettle();
        expect(find.text('Cài đặt'), findsOneWidget);
        expect(find.text('Ngôn ngữ'), findsWidgets);
        expect(preferences.getString('languageCode'), 'vi');
        await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đêm').last);
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
          Brightness.dark,
        );
        expect(preferences.getString('themeMode'), 'dark');
        expect(server.restarts, 0);
        expect(store.network.length, 3);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Mạng'), findsOneWidget);
        expect(find.text('/orders?draft=true'), findsOneWidget);
        expect(find.text('/feed'), findsNothing);
        expect(
          Theme.of(tester.element(find.byType(Scaffold))).brightness,
          Brightness.dark,
        );
        await tester.tap(find.byTooltip('Cài đặt'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
        expect(preferences.getString('languageCode'), 'en');
        await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Light').last);
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
          Brightness.light,
        );
        await tester.enterText(find.byType(TextField), '70000');
        await tester.tap(find.text('Save & restart'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a port from 1 to 65535'), findsOneWidget);
        expect(server.restarts, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        server.dispose();
        store.dispose();
      },
    );
  }

  testWidgets('Vietnamese and dark theme are restored on application launch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'languageCode': 'vi',
      'themeMode': 'dark',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = CaptureStore();
    final server = ViewerServer(store);
    await tester.pumpWidget(
      ViewerApp(store: store, server: server, preferences: preferences),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    expect(find.text('Chưa có request'), findsOneWidget);
    await tester.tap(find.text('Kết nối ứng dụng'));
    await tester.pumpAndSettle();
    expect(find.text('Kết nối ứng dụng React Native'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    server.dispose();
    store.dispose();
  });
}
