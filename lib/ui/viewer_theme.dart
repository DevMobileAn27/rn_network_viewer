import 'package:flutter/material.dart';

extension ViewerThemeContext on BuildContext {
  ViewerPalette get palette =>
      ViewerPalette(Theme.of(this).brightness == Brightness.dark);
}

class ViewerPalette {
  const ViewerPalette(this.dark);
  final bool dark;

  Color get background =>
      dark ? const Color(0xff101317) : const Color(0xfff6f8fa);
  Color get surface => dark ? const Color(0xff171b21) : Colors.white;
  Color get sidebar => dark ? const Color(0xff14181d) : const Color(0xfff0f3f6);
  Color get input => dark ? const Color(0xff20252c) : const Color(0xffedf1f5);
  Color get muted => dark ? const Color(0xff8d98a7) : const Color(0xff596778);
  Color get accent => dark ? const Color(0xff63ddbb) : const Color(0xff08785d);
  Color get danger => dark ? const Color(0xffff848a) : const Color(0xffbd293a);
  Color get line => dark ? const Color(0xff2a3038) : const Color(0xffd6dde5);
  Color get warning => dark ? const Color(0xffe4bc87) : const Color(0xff8c560b);
  Color get info => dark ? const Color(0xff91b9f1) : const Color(0xff285da8);
  Color get method => dark ? const Color(0xffb6a3ed) : const Color(0xff7150ad);
  Color get string => dark ? const Color(0xffb2d9a0) : const Color(0xff39712a);
}

ThemeData viewerTheme(Brightness brightness) {
  final colors = ViewerPalette(brightness == Brightness.dark);
  return ThemeData(
    fontFamily: 'JetBrains Mono',
    brightness: brightness,
    scaffoldBackgroundColor: colors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
      primary: colors.accent,
      surface: colors.surface,
      error: colors.danger,
    ),
    dividerColor: colors.line,
    cardTheme: CardThemeData(color: colors.surface),
    appBarTheme: AppBarTheme(backgroundColor: colors.surface),
    textTheme: TextTheme(
      bodyMedium: const TextStyle(fontSize: 13),
      bodySmall: TextStyle(fontSize: 11, color: colors.muted),
      titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.input,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
    useMaterial3: true,
  );
}
