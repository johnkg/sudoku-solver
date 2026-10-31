import 'package:flutter/material.dart' hide Step;

import '../../engine/engine.dart';
import '../layout.dart';
import 'technique_link.dart';

/// What the walkthrough shows after its last step: how it ended, how the
/// player did in "your turn" mode, and the techniques it used.
class WalkthroughEndPanel extends StatelessWidget {
  const WalkthroughEndPanel({
    super.key,
    required this.solved,
    required this.revealed,
    required this.steps,
    required this.onReveal,
    this.score,
  });

  final bool solved;

  /// Whether the rest of the board was filled in by trial and error.
  final bool revealed;
  final List<Step> steps;
  final VoidCallback onReveal;
  final String? score;

  String get _headline => solved
      ? 'Solved in ${steps.length} steps.'
      : revealed
      ? 'The rest was filled in by trial and error.'
      : 'The solver is stuck.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <Technique, int>{};
    for (final step in steps) {
      counts[step.technique] = (counts[step.technique] ?? 0) + 1;
    }
    final used = Technique.values.where(counts.containsKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_headline, style: theme.textTheme.headlineSmall),
        if (score != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            score!,
            key: const Key('score'),
            style: theme.textTheme.titleMedium,
          ),
        ],
        const SizedBox(height: Space.sm),
        if (!solved && !revealed) ...[
          Text(
            'None of the techniques in this app finds another move. The rest '
            'needs something harder, or trial and error.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: Space.sm),
          OutlinedButton(
            key: const Key('reveal'),
            onPressed: onReveal,
            child: const Text('Show the answer'),
          ),
        ],
        if (used.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text('Techniques used', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final t in used)
                TechniqueLink(technique: t, count: counts[t]),
            ],
          ),
        ],
      ],
    );
  }
}
