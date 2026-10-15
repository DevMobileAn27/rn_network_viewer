import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this.preferences)
    : _languageCode = preferences?.getString('languageCode') == 'vi'
          ? 'vi'
          : 'en',
      _themeMode = preferences?.getString('themeMode') == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light,
      _mcpEnabled = preferences?.getBool('mcpEnabled') ?? false,
      _mcpPort = _restoreMcpPort(preferences?.getInt('mcpPort'));

  final SharedPreferences? preferences;
  String _languageCode;
  ThemeMode _themeMode;
  bool _mcpEnabled;
  int _mcpPort;
  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;
  Locale get locale => Locale(_languageCode);
  bool get mcpEnabled => _mcpEnabled;
  int get mcpPort => _mcpPort;

  static int _restoreMcpPort(int? value) =>
      value != null && value >= 1 && value <= 65535 ? value : 38941;

  Future<void> setMcpEnabled(bool enabled) async {
    if (_mcpEnabled == enabled) return;
    if (preferences != null &&
        !await preferences!.setBool('mcpEnabled', enabled)) {
      throw StateError('Could not persist MCP preference');
    }
    _mcpEnabled = enabled;
    notifyListeners();
  }

  Future<void> setMcpPort(int port) async {
    if (port < 1 || port > 65535) throw ArgumentError.value(port, 'port');
    if (_mcpPort == port) return;
    if (preferences != null && !await preferences!.setInt('mcpPort', port)) {
      throw StateError('Could not persist MCP port');
    }
    _mcpPort = port;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == ThemeMode.system) {
      throw ArgumentError.value(mode, 'mode', 'Unsupported theme');
    }
    if (_themeMode == mode) return;
    if (preferences != null &&
        !await preferences!.setString('themeMode', mode.name)) {
      throw StateError('Could not persist theme preference');
    }
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (!['vi', 'en'].contains(code)) {
      throw ArgumentError.value(code, 'code', 'Unsupported language');
    }
    if (_languageCode == code) return;
    if (preferences != null &&
        !await preferences!.setString('languageCode', code)) {
      throw StateError('Could not persist language preference');
    }
    _languageCode = code;
    notifyListeners();
  }
}
