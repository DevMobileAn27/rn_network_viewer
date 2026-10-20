import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import 'viewer_theme.dart';
import 'viewer_notification.dart';

enum SettingsFeedbackKind {
  success,
  error,
  info,
  warning;

  Color color(ViewerPalette palette) => switch (this) {
    success => palette.methodColor('POST'),
    error => palette.danger,
    info ||
    warning => palette.dark ? const Color(0xfffacc15) : const Color(0xff8a6500),
  };
}

void showSettingsFeedback(
  BuildContext context,
  String message, {
  SettingsFeedbackKind kind = SettingsFeedbackKind.success,
}) {
  showViewerNotification(
    context,
    description: message,
    type: switch (kind) {
      SettingsFeedbackKind.success => ViewerNotificationType.success,
      SettingsFeedbackKind.error => ViewerNotificationType.danger,
      SettingsFeedbackKind.info => ViewerNotificationType.info,
      SettingsFeedbackKind.warning => ViewerNotificationType.warning,
    },
  );
}

Future<void> copySettingsText(
  BuildContext context,
  String text, {
  required String message,
  SettingsFeedbackKind kind = SettingsFeedbackKind.success,
}) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
  } catch (_) {
    if (context.mounted) {
      showSettingsFeedback(
        context,
        context.l10n.clipboardFailed,
        kind: SettingsFeedbackKind.error,
      );
    }
    return;
  }
  if (context.mounted) showSettingsFeedback(context, message, kind: kind);
}
