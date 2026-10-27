import 'package:flutter/material.dart';

import 'layout.dart';

/// Says what the colours on a worked-example board mean.
class BoardLegend extends StatelessWidget {
  const BoardLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: Space.lg,
      runSpacing: Space.xs,
      children: [
        _Swatch(color: scheme.primaryContainer, label: 'Look here'),
        _Swatch(color: scheme.tertiaryContainer, label: 'Answer'),
        _Swatch(color: scheme.errorContainer, label: 'Ruled out'),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSmall - Space.sm,
          height: iconSmall - Space.sm,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(barRadius),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(width: Space.sm),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
