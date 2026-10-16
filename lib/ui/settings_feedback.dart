import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import 'viewer_theme.dart';

enum SettingsFeedbackKind { success, error, info, warning }

void showSettingsFeedback(
  BuildContext context,
  String message, {
  SettingsFeedbackKind kind = SettingsFeedbackKind.success,
}) {
  final palette = context.palette;
  final (icon, color, title) = switch (kind) {
    SettingsFeedbackKind.success => (
      Icons.check_circle_outline,
      palette.methodColor('POST'),
      context.l10n.success,
    ),
    SettingsFeedbackKind.error => (
      Icons.error_outline,
      palette.danger,
      context.l10n.error,
    ),
    SettingsFeedbackKind.info => (
      Icons.info_outline,
      palette.info,
      context.l10n.settingsNotice,
    ),
    SettingsFeedbackKind.warning => (
      Icons.warning_amber_rounded,
      palette.warning,
      context.l10n.settingsNotice,
    ),
  };
  final messenger = ScaffoldMessenger.of(context);
  // Show the latest result immediately, instead of queuing stale messages.
  messenger.clearSnackBars();
  messenger.removeCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      key: ValueKey('settings-feedback-${kind.name}'),
      behavior: SnackBarBehavior.floating,
      width: MediaQuery.sizeOf(context).width > 560 ? 520 : null,
      duration: Duration(seconds: kind == SettingsFeedbackKind.success ? 3 : 6),
      backgroundColor: palette.surface,
      showCloseIcon: true,
      closeIconColor: palette.muted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: .5)),
      ),
      content: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
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
