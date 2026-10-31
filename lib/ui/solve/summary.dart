import 'package:flutter/material.dart' hide Step;

import '../../engine/engine.dart';
import '../../progress/progress_store.dart';
import '../../util/text.dart';
import '../layout.dart';
import '../levels.dart';
import '../solve_controller.dart';
import '../stars.dart';

class Summary extends StatelessWidget {
  const Summary({
    super.key,
    required this.controller,
    required this.newlyUnlockedLevel,
    required this.onNewPuzzle,
    required this.dailyStreak,
    required this.onShare,
  });

  final SolveController controller;
  final int? newlyUnlockedLevel;
  final VoidCallback? onNewPuzzle;
  final int? dailyStreak;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <Technique, int>{};
    for (final technique in controller.applied) {
      counts[technique] = (counts[technique] ?? 0) + 1;
    }
    final techniques = counts.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Solved!', style: theme.textTheme.titleLarge),
        const SizedBox(height: Space.sm),
        Stars(
          count: PuzzleRecord(
            mistakes: controller.mistakes,
            hints: controller.hintsUsed,
          ).stars,
          size: iconMedium,
        ),
        const SizedBox(height: Space.sm),
        Text(
          '${formatClock(controller.seconds.value)} · '
          '${controller.moveCount} moves · ${controller.mistakes} mistakes · '
          '${controller.hintsUsed} hints (${controller.movesShown} showed the '
          'full move)',
          style: theme.textTheme.bodyMedium,
        ),
        if (newlyUnlockedLevel != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            'Level $newlyUnlockedLevel · ${levelNames[newlyUnlockedLevel]} '
            'unlocked!',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        if (dailyStreak != null && dailyStreak! > 0) ...[
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: Space.xs),
              Text(
                '${plural(dailyStreak!, 'day')} in a row',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
        if (onShare != null) ...[
          const SizedBox(height: Space.md),
          OutlinedButton.icon(
            key: const Key('share-result'),
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Copy my result'),
          ),
        ],
        if (onNewPuzzle != null) ...[
          const SizedBox(height: Space.lg),
          FilledButton.icon(
            onPressed: onNewPuzzle,
            icon: const Icon(Icons.shuffle),
            label: const Text('New random puzzle'),
          ),
        ],
        if (techniques.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Text('Solver steps you applied:', style: theme.textTheme.bodyMedium),
          const SizedBox(height: Space.xs),
          for (final t in techniques)
            Text(
              '• ${t.label} × ${counts[t]}',
              style: theme.textTheme.bodyLarge,
            ),
        ],
      ],
    );
  }
}
