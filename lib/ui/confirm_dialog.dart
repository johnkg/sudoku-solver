import 'package:flutter/material.dart';

/// Asks the player to choose between two actions and returns whether they
/// picked [confirmLabel]. Dismissing the dialog counts as [cancelLabel].
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  String? message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
