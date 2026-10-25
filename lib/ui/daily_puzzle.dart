import 'package:flutter/material.dart';

import 'layout.dart';

import '../engine/engine.dart';
import '../progress/progress_scope.dart';
import '../progress/progress_store.dart';
import 'levels.dart';
import 'puzzle_library.dart';
import 'search_dialog.dart';
import 'solve_screen.dart';
import 'stars.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

/// `Sat, Oct 10`.
String dailyDateLabel(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';

/// Opens today's daily puzzle, finding it first if this is the first time
/// today. Everyone gets the same puzzle on the same day.
Future<void> playDailyPuzzle(BuildContext context) async {
  final store = ProgressScope.read(context);
  final navigator = Navigator.of(context);
  final today = store.today;
  final key = store.todayKey;

  var text = store.dailyPuzzleText(key);
  Technique? technique;
  if (text == null) {
    final found = await runSearchWithDialog(
      context,
      message: 'Preparing today\'s puzzle…',
      search: (isCancelled) => findDailyPuzzle(today, isCancelled: isCancelled),
    );
    if (found == null) return;
    text = found.puzzle.toLine().replaceAll('.', '0');
    technique = found.rating.required;
    store.saveDailyPuzzle(key, text);
  }
  technique ??= ratePuzzle(Board.parse(text)).required;

  final entry = PuzzleEntry(
    id: ProgressStore.dailyGameId(key),
    title: 'Daily · ${dailyDateLabel(today)}',
    text: text,
    technique: technique!,
  );
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => SolveScreen(puzzle: entry, dailyKey: key),
    ),
  );
}

/// A card on the Practice tab: today's puzzle, its level, and the streak.
class DailyPuzzleCard extends StatelessWidget {
  const DailyPuzzleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ProgressScope.of(context);
    final today = store.today;
    final key = store.todayKey;
    final level = dailyLevel(today);
    final record = store.dailyRecord(key);
    final inProgress = store.hasSavedGame(ProgressStore.dailyGameId(key));
    final streak = store.dailyStreak;

    return Card(
      margin: const EdgeInsets.only(top: Space.lg),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Daily puzzle · ${dailyDateLabel(today)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                if (streak > 0)
                  Tooltip(
                    message: 'Days in a row',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: Space.xs),
                        Text(
                          '$streak ${streak == 1 ? 'day' : 'days'}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Level $level · ${levelNames[level]}. The same puzzle for '
              'everyone today.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.md,
              runSpacing: Space.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => playDailyPuzzle(context),
                  icon: Icon(record != null ? Icons.replay : Icons.play_arrow),
                  label: Text(
                    record != null
                        ? 'Play again'
                        : inProgress
                        ? 'Continue'
                        : 'Play today\'s puzzle',
                  ),
                ),
                if (record != null) Stars(count: record.stars),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
