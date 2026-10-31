import 'package:flutter/material.dart' hide Step;

import '../../engine/engine.dart';
import '../layout.dart';
import '../solve_controller.dart';

/// One line of feedback for the player's last move.
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.controller});

  final SolveController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.solved) return const SizedBox.shrink();

    final armed = controller.armed;
    final text =
        controller.message ??
        (armed != null
            ? 'Tap cells to fill in $armed. Tap $armed again to stop.'
            : controller.selected == null
            ? 'Tap a cell, then pick a digit.'
            : controller.board.values[controller.selected!] != 0
            ? 'Tap an empty cell to continue.'
            : controller.mode == EntryMode.place
            ? 'Pick the digit that goes in '
                  '${Board.cellName(controller.selected!)}.'
            : 'Tap digits to add or remove notes in '
                  '${Board.cellName(controller.selected!)}.');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.snug,
        Space.lg,
        Space.xs,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: controller.messageIsError
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(keyRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: controller.messageIsError
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
