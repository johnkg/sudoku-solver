import 'package:flutter/material.dart' hide Step;
import 'package:flutter/foundation.dart' show ValueListenable;

import '../../util/text.dart';
import '../layout.dart';
import '../levels.dart';

/// Level, mistakes, hints and time at a glance above the board.
class StatsRow extends StatelessWidget {
  const StatsRow({
    super.key,
    required this.level,
    required this.mistakes,
    required this.hints,
    required this.seconds,
    required this.limit,
    required this.showClock,
  });

  final int level;
  final int mistakes;
  final int hints;
  final ValueListenable<int> seconds;

  /// The mistake limit, or 0 for none.
  final int limit;
  final bool showClock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget stat(String label, String value, {Key? valueKey}) => Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.hair),
            Text(
              value,
              key: valueKey,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.xs,
        Space.md,
        Space.md,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm,
          ),
          child: Row(
            children: [
              stat('Level $level', levelNames[level] ?? ''),
              stat(
                'Mistakes',
                limit == 0 ? '$mistakes' : '$mistakes/$limit',
                valueKey: const Key('mistakes-value'),
              ),
              stat('Hints', '$hints', valueKey: const Key('hints-value')),
              if (showClock)
                ValueListenableBuilder<int>(
                  valueListenable: seconds,
                  builder: (context, value, _) => stat(
                    'Time',
                    formatClock(value),
                    valueKey: const Key('time-value'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
