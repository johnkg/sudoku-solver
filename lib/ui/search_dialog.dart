import 'package:flutter/material.dart';

/// Runs [search] while a progress dialog is up. Returns what it found, or
/// null if the player cancelled or nothing was found (in which case a message
/// is shown). The dialog is closed before this returns.
///
/// [search] is given a function to poll; it should stop when that returns true.
Future<T?> runSearchWithDialog<T>(
  BuildContext context, {
  required String message,
  required Future<T?> Function(bool Function() isCancelled) search,
  String notFound = 'Could not find a puzzle. Try again.',
}) async {
  var cancelled = false;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);

  // Not awaited: the dialog stays up while the search runs.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            cancelled = true;
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  final found = await search(() => cancelled);
  if (cancelled) return null;
  navigator.pop(); // close the dialog

  if (found == null) {
    messenger?.showSnackBar(SnackBar(content: Text(notFound)));
  }
  return found;
}
