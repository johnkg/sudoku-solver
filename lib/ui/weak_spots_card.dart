import 'package:flutter/material.dart';

import '../progress/progress_scope.dart';
import 'layout.dart';
import 'technique_puzzle.dart';
import 'weak_spots.dart';

/// A card on the Practice tab: the techniques the player keeps missing, each
/// with its accuracy and a button that opens a puzzle built around it. Shows
/// nothing until there is a weak spot.
class WeakSpotsCard extends StatelessWidget {
  const WeakSpotsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ProgressScope.of(context);
    final spots = weakSpots(store);
    if (spots.isEmpty) return const SizedBox.shrink();

    return Card(
      key: const Key('weak-spots'),
      margin: const EdgeInsets.only(top: Space.lg),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weak spots', style: theme.textTheme.titleMedium),
            const SizedBox(height: Space.xs),
            Text(
              'Techniques you often miss. Drill one with a fresh puzzle.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.sm),
            for (final t in spots)
              _WeakSpotRow(
                key: Key('weak-${t.name}'),
                label: t.label,
                accuracy: store.techniqueStats[t.name]!.accuracy,
                onDrill: () => playTechniquePuzzle(context, t),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeakSpotRow extends StatelessWidget {
  const _WeakSpotRow({
    super.key,
    required this.label,
    required this.accuracy,
    required this.onDrill,
  });

  final String label;
  final double accuracy;
  final VoidCallback onDrill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (accuracy * 100).round();

    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                const SizedBox(height: Space.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(barRadius),
                  child: LinearProgressIndicator(
                    value: accuracy,
                    minHeight: Space.tight,
                    color: theme.colorScheme.error,
                    backgroundColor: theme.colorScheme.surfaceContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          SizedBox(
            width: scoreColumnWidth,
            child: Text(
              '$percent% right',
              textAlign: TextAlign.end,
              style: theme.textTheme.labelMedium,
            ),
          ),
          IconButton(
            tooltip: 'Drill $label',
            onPressed: onDrill,
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}
