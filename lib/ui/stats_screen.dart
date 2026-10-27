import 'package:flutter/material.dart';

import '../engine/engine.dart' show Technique;
import '../progress/progress_scope.dart';
import '../progress/progress_store.dart' show ProgressStore, PuzzleRecord;
import 'achievements.dart';
import 'daily_calendar.dart';
import 'layout.dart';
import 'levels.dart';
import 'puzzle_library.dart';
import 'section.dart';
import 'solve_screen.dart' show formatClock;
import 'weak_spots.dart';

/// What the player has achieved: puzzles solved, stars, streak, and the
/// fastest solve per level.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ProgressScope.of(context);
    final records = store.records;

    final stars = records.values.fold<int>(0, (sum, r) => sum + r.stars);
    final mostStars = puzzleLibrary.length * PuzzleRecord.maxStars;

    int? fastest(Iterable<int?> times) {
      final known = times.whereType<int>();
      return known.isEmpty ? null : known.reduce((a, b) => a < b ? a : b);
    }

    Widget tile(
      String label,
      String value,
      IconData icon, {
      bool highlight = false,
    }) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Space.lg,
            horizontal: Space.sm,
          ),
          child: Column(
            children: [
              IconChip(icon, highlight: highlight),
              const SizedBox(height: Space.sm),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              Space.xxl,
            ),
            children: [
              Row(
                children: [
                  tile(
                    'Puzzles solved',
                    '${store.solvedCount}/${puzzleLibrary.length}',
                    Icons.grid_on,
                  ),
                  tile(
                    'Stars',
                    '$stars/$mostStars',
                    Icons.star_outline,
                    highlight: true,
                  ),
                ],
              ),
              Row(
                children: [
                  tile(
                    'Daily streak',
                    '${store.dailyStreak}',
                    Icons.local_fire_department_outlined,
                  ),
                  tile(
                    'Dailies solved',
                    '${store.dailySolvedCount}',
                    Icons.calendar_today_outlined,
                  ),
                ],
              ),
              ..._techniqueSection(context, store),
              const SectionTitle('Daily puzzles'),
              Card(
                key: const Key('daily-calendar'),
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    children: [
                      DailyCalendar(
                        solved: store.dailyRecords.keys.toSet(),
                        today: store.today,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        'Current streak ${store.dailyStreak} · '
                        'Best ${store.bestDailyStreak}',
                        key: const Key('streak-line'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              ..._achievementSection(context, store),
              const SectionTitle('By level'),
              for (final level in levelNames.keys)
                Builder(
                  builder: (context) {
                    final puzzles = puzzleLibrary.where(
                      (p) => p.level == level,
                    );
                    final solved = puzzles
                        .where((p) => records.containsKey(p.id))
                        .length;
                    final best = fastest(
                      puzzles.map((p) => records[p.id]?.seconds),
                    );
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Level $level · ${levelNames[level]}',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                Text(
                                  best == null
                                      ? 'No time yet'
                                      : 'Best ${formatClock(best)}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(barRadius),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: puzzles.isEmpty
                                    ? 0
                                    : solved / puzzles.length,
                              ),
                            ),
                            const SizedBox(height: Space.xs),
                            Text(
                              '$solved of ${puzzles.length} solved',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How the player is doing at each technique they have been asked about, with
/// the ones to revisit first.
List<Widget> _techniqueSection(BuildContext context, ProgressStore store) {
  final theme = Theme.of(context);
  final stats = store.techniqueStats;
  final asked = [
    for (final t in Technique.values)
      if (stats.containsKey(t.name)) t,
  ];
  if (asked.isEmpty) return const [];
  final weak = weakSpots(store);

  return [
    const SectionTitle('Techniques'),
    if (weak.isNotEmpty)
      Card(
        key: const Key('weak-spots'),
        color: theme.colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Text(
            'Worth revisiting: ${weak.map((t) => t.label).join(', ')}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ),
      ),
    for (final t in asked)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(t.label, style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(barRadius),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: stats[t.name]!.accuracy,
                ),
              ),
            ),
            SizedBox(
              width: scoreColumnWidth,
              child: Text(
                '${stats[t.name]!.right}/${stats[t.name]!.attempts}',
                key: Key('stat-${t.name}'),
                textAlign: TextAlign.end,
                style: theme.textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
  ];
}

/// Everything there is to earn, with how far along the player is.
List<Widget> _achievementSection(BuildContext context, ProgressStore store) {
  final theme = Theme.of(context);
  final all = achievementsFor(store);
  final earned = all.where((a) => a.unlocked).length;

  return [
    SectionTitle(
      'Achievements · $earned of ${all.length}',
      key: const Key('achievements-title'),
    ),
    for (final a in all)
      Card(
        key: Key('achievement-${a.id}'),
        child: ListTile(
          leading: IconChip(
            a.unlocked ? Icons.emoji_events : a.icon,
            highlight: a.unlocked,
            muted: !a.unlocked,
          ),
          title: Text(a.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.description),
              if (!a.unlocked && a.goal > 1) ...[
                const SizedBox(height: Space.tight),
                LinearProgressIndicator(value: a.progress / a.goal),
                const SizedBox(height: Space.hair),
                Text(
                  '${a.progress} of ${a.goal}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ],
          ),
          trailing: a.unlocked
              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
              : null,
        ),
      ),
  ];
}
