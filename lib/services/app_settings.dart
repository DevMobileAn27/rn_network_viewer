import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this.preferences)
    : _languageCode = preferences?.getString('languageCode') == 'vi'
          ? 'vi'
          : 'en',
      _themeMode = preferences?.getString('themeMode') == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;

  final SharedPreferences? preferences;
  String _languageCode;
  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;
  Locale get locale => Locale(_languageCode);

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
