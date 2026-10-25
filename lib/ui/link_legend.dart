import 'package:flutter/material.dart' hide Step;

import 'layout.dart';

import '../engine/engine.dart';

/// A line under a board explaining the lines drawn on it, if [step] has any.
class LinkLegend extends StatelessWidget {
  const LinkLegend({super.key, required this.step});

  final Step? step;

  @override
  Widget build(BuildContext context) {
    final links = step?.links ?? const <ChainLink>[];
    if (links.isEmpty) return const SizedBox.shrink();
    final strong = links.any((l) => l.strong);
    final weak = links.any((l) => !l.strong);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Text(
        [
          if (strong)
            'Solid line: a strong link, exactly one of the two cells holds '
                'the digit.',
          if (weak)
            'Dashed line: a weak link, the cells cannot both hold the digit.',
        ].join(' '),
        key: const Key('link-legend'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
