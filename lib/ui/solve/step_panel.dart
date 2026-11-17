import 'package:flutter/material.dart' hide Step;

import '../../engine/engine.dart';
import '../../lessons/lessons.dart';
import '../../util/text.dart';
import '../hint_ladder.dart';
import '../layout.dart';
import '../learn_tab.dart';
import '../levels.dart';
import '../solve_controller.dart';
import 'summary.dart';

class StepPanel extends StatelessWidget {
  const StepPanel({
    super.key,
    required this.controller,
    required this.focus,
    required this.newlyUnlockedLevel,
    required this.onNewPuzzle,
    required this.dailyStreak,
    required this.onShare,
  });

  final SolveController controller;

  /// The hardest technique the puzzle needs.
  final Technique focus;

  /// A level this solve just opened, if any.
  final int? newlyUnlockedLevel;

  final VoidCallback? onNewPuzzle;

  /// The daily-puzzle streak, or null when this is not the daily puzzle.
  final int? dailyStreak;

  /// Copies the daily result to share, or null when this is not the daily.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = controller.pending;

    final Widget content;
    if (controller.solved) {
      content = Summary(
        controller: controller,
        newlyUnlockedLevel: newlyUnlockedLevel,
        onNewPuzzle: onNewPuzzle,
        dailyStreak: dailyStreak,
        onShare: onShare,
      );
    } else if (step != null) {
      content = switch (controller.hintLevel) {
        SolveController.hintNudge ||
        SolveController.hintTechnique ||
        SolveController.hintPattern => _hintStage(context, step, controller),
        _ => _fullMove(context, step, controller),
      };
    } else if (controller.stuck) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No technique applies', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          Text(
            'This puzzle needs something beyond the techniques the solver '
            'knows. Try undoing a step or starting over.',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      );
    } else {
      final count = controller.moveCount;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 0
                ? 'Ready when you are'
                : '${plural(count, 'move')} so far',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Stuck? Tap Hint: first where to look, then the technique, '
            'then its cells, then the move. Hardest technique here: '
            '${focus.label}.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    return Card(
      child: Padding(padding: const EdgeInsets.all(Space.lg), child: content),
    );
  }
}

/// Hint stages 1 to 3: where to look, which technique, then its cells.
Widget _hintStage(BuildContext context, Step step, SolveController controller) {
  final theme = Theme.of(context);
  final level = controller.hintLevel;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Hint $level of ${SolveController.hintMove}',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      const SizedBox(height: Space.sm),
      if (level == SolveController.hintNudge)
        Text(nudgeText(step), style: theme.textTheme.bodyLarge)
      else ...[
        Wrap(
          spacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text(step.technique.label)),
            Text(
              'Level ${step.technique.level} · ${levelNames[step.technique.level]}',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          level == SolveController.hintTechnique
              ? '${_whereToUse(step)} Tap Another hint to see its cells.'
              : lessonFor(step.technique).tagline,
          style: theme.textTheme.bodyLarge,
        ),
      ],
      const SizedBox(height: Space.lg),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (level != SolveController.hintPattern)
            FilledButton.tonal(
              onPressed: controller.moreHelp,
              child: const Text('Another hint'),
            ),
          if (level != SolveController.hintPattern)
            TextButton(
              onPressed: controller.showMove,
              child: const Text('Show the move'),
            )
          else
            FilledButton.tonal(
              onPressed: controller.showMove,
              child: const Text('Show the move'),
            ),
          if (level != SolveController.hintNudge)
            TextButton(
              onPressed: () => openLesson(context, lessonFor(step.technique)),
              child: const Text('How it works'),
            ),
          TextButton(
            onPressed: controller.dismissPending,
            child: const Text('Hide'),
          ),
        ],
      ),
    ],
  );
}

/// Stage 2 text: where the named technique applies, without its cells.
String _whereToUse(Step step) {
  final unit = hintUnit(step);
  return unit == null
      ? 'Look for it across the board.'
      : 'Look for it in ${unit.name}.';
}

/// Hint stage 4: the full move, ready to apply.
Widget _fullMove(BuildContext context, Step step, SolveController controller) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: Space.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(label: Text(step.technique.label)),
          Text(
            'Level ${step.technique.level} · ${levelNames[step.technique.level]}',
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
      const SizedBox(height: Space.sm),
      Text(step.explanation, style: theme.textTheme.bodyLarge),
      const SizedBox(height: Space.lg),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: controller.applyPending,
            icon: const Icon(Icons.check),
            label: const Text('Apply'),
          ),
          TextButton(
            onPressed: controller.dismissPending,
            child: const Text('Hide'),
          ),
          TextButton(
            onPressed: () => openLesson(context, lessonFor(step.technique)),
            child: const Text('How it works'),
          ),
        ],
      ),
    ],
  );
}
