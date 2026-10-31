import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../progress/progress_scope.dart';
import '../progress/progress_store.dart';
import '../util/text.dart';
import 'layout.dart';
import 'levels.dart';
import 'navigation.dart';
import 'puzzle_library.dart';
import 'search_dialog.dart';
import 'solve_screen.dart';
import 'stars.dart';

/// Ring of a week dot for a day other than today: thinner and fainter.
const _otherDayRingWidth = 1.0;
const _otherDayRingAlpha = 0.4;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// `Sat, Oct 10`.
String dailyDateLabel(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${shortMonthName(date)} ${date.day}';

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
    text = found.text;
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
  openScreen(navigator, (_) => SolveScreen(puzzle: entry, dailyKey: key));
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
                          plural(streak, 'day'),
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
            _WeekDots(store: store),
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

/// The days of the week [today] falls in, Monday first.
List<DateTime> weekOf(DateTime today) {
  final monday = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - 1),
  );
  return [
    for (var i = 0; i < 7; i++)
      DateTime(monday.year, monday.month, monday.day + i),
  ];
}

/// One dot per day of this week: filled when that day's puzzle is solved,
/// ringed for today.
class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    final today = store.today;
    final todayDate = DateTime(today.year, today.month, today.day);

    return Row(
      key: const Key('week-dots'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final day in weekOf(today))
          Semantics(
            label:
                '${_weekdays[day.weekday - 1]}: '
                '${store.dailyRecord(ProgressStore.dayKey(day)) != null ? 'solved' : 'not solved'}',
            excludeSemantics: true,
            child: Column(
              children: [
                Text(
                  _weekdays[day.weekday - 1][0],
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
                const SizedBox(height: Space.xs),
                Container(
                  width: weekDotSize,
                  height: weekDotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: store.dailyRecord(ProgressStore.dayKey(day)) != null
                        ? color
                        : null,
                    border: Border.all(
                      color: color.withValues(
                        alpha: day == todayDate ? 1 : _otherDayRingAlpha,
                      ),
                      width: day == todayDate
                          ? todayRingWidth
                          : _otherDayRingWidth,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
