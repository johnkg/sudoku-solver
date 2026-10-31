import 'package:flutter/material.dart' hide Step;

import '../../engine/engine.dart';
import '../layout.dart';
import '../link_legend.dart';
import '../step_text.dart';
import 'technique_link.dart';

/// The explanation of one solver step, shown while watching.
class WalkthroughStepPanel extends StatelessWidget {
  const WalkthroughStepPanel({
    super.key,
    required this.step,
    required this.number,
    required this.of,
  });

  final Step step;
  final int number;
  final int of;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $number of $of',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: Space.sm),
        TechniqueLink(technique: step.technique),
        const SizedBox(height: Space.md),
        Text(step.explanation, style: theme.textTheme.bodyLarge),
        LinkLegend(step: step),
        const SizedBox(height: Space.md),
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Text(
              describeResult(step),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
