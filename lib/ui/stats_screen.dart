import 'package:flutter/material.dart';

import '../engine/engine.dart' show Technique;
import '../progress/progress_scope.dart';
import '../progress/progress_store.dart' show ProgressStore;
import 'levels.dart';
import 'puzzle_library.dart';
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
              ..._techniqueSection(context, store),
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
    Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        'Techniques',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    if (weak.isNotEmpty)
      Card(
        key: const Key('weak-spots'),
        color: theme.colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(t.label, style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: stats[t.name]!.accuracy,
                ),
              ),
            ),
            SizedBox(
              width: 56,
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
