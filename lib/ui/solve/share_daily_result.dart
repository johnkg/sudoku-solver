import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../progress/progress_store.dart';
import '../levels.dart';
import '../puzzle_library.dart';
import '../share_result.dart';
import '../solve_controller.dart';

/// Copies a short summary of today's daily result to the clipboard, to share.
/// [shareBase] is the page address the link is built from.
Future<void> copyDailyResult(
  BuildContext context, {
  required String dailyKey,
  required PuzzleEntry puzzle,
  required SolveController controller,
  required ProgressStore store,
  required Uri shareBase,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final text = dailyShareText(
    date: DateTime.parse(dailyKey),
    level: puzzle.level,
    levelName: levelNames[puzzle.level] ?? '',
    stars: PuzzleRecord(
      mistakes: controller.mistakes,
      hints: controller.hintsUsed,
    ).stars,
    seconds: controller.seconds.value,
    mistakes: controller.mistakes,
    hints: controller.hintsUsed,
    streak: store.dailyStreak,
    link: appHome(shareBase),
  );
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Result copied. Paste it anywhere.')),
    );
}
