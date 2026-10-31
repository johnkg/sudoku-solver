import 'package:flutter/material.dart' hide Step;

import '../layout.dart';

/// Stands in for the board while paused, so the puzzle cannot be studied with
/// the clock stopped.
class PausedBoard extends StatelessWidget {
  const PausedBoard({super.key, required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        child: InkWell(
          onTap: onResume,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_circle_outline,
                size: iconHero,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: Space.sm),
              Text('Paused', style: theme.textTheme.titleLarge),
              Text('Tap to resume', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
