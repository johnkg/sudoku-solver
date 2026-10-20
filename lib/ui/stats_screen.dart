import 'package:flutter/material.dart';

import '../progress/progress_scope.dart';
import '../progress/progress_store.dart' show ProgressStore;
import 'achievements.dart';
import 'daily_calendar.dart';
import 'levels.dart';
import 'puzzle_library.dart';
import 'solve_screen.dart' show formatClock;

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
    final mostStars = puzzleLibrary.length * 3;

    int? fastest(Iterable<int?> times) {
      final known = times.whereType<int>();
      return known.isEmpty ? null : known.reduce((a, b) => a < b ? a : b);
    }

    Widget tile(String label, String value, IconData icon) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
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
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  tile(
                    'Puzzles solved',
                    '${store.solvedCount}/${puzzleLibrary.length}',
                    Icons.grid_on,
                  ),
                  tile('Stars', '$stars/$mostStars', Icons.star_outline),
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
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  'Daily puzzles',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Card(
                key: const Key('daily-calendar'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      DailyCalendar(
                        solved: store.dailyRecords.keys.toSet(),
                        today: store.today,
                      ),
                      const SizedBox(height: 4),
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
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  'By level',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
                        padding: const EdgeInsets.all(16),
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
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: puzzles.isEmpty
                                    ? 0
                                    : solved / puzzles.length,
                              ),
                            ),
                            const SizedBox(height: 4),
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

/// Everything there is to earn, with how far along the player is.
List<Widget> _achievementSection(BuildContext context, ProgressStore store) {
  final theme = Theme.of(context);
  final all = achievementsFor(store);
  final earned = all.where((a) => a.unlocked).length;

  return [
    Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        'Achievements · $earned of ${all.length}',
        key: const Key('achievements-title'),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    for (final a in all)
      Card(
        key: Key('achievement-${a.id}'),
        color: a.unlocked ? theme.colorScheme.primaryContainer : null,
        child: ListTile(
          leading: Icon(
            a.unlocked ? Icons.emoji_events : a.icon,
            color: a.unlocked
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.outline,
          ),
          title: Text(a.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.description),
              if (!a.unlocked && a.goal > 1) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(value: a.progress / a.goal),
                const SizedBox(height: 2),
                Text(
                  '${a.progress} of ${a.goal}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ],
          ),
          trailing: a.unlocked ? const Icon(Icons.check_circle) : null,
        ),
      ),
  ];
}
