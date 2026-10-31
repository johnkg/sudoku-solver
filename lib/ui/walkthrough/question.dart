import 'package:flutter/material.dart' hide Step;

import '../../engine/engine.dart';
import '../digit_keys.dart';
import '../layout.dart';
import '../technique_choices.dart';

/// Asks the player to find the move of [step] on [board]: pick a cell and a
/// digit when the move places one, otherwise pick the technique.
class WalkthroughQuestion extends StatelessWidget {
  const WalkthroughQuestion({
    super.key,
    required this.step,
    required this.number,
    required this.of,
    required this.board,
    required this.selected,
    required this.message,
    required this.wrongChoices,
    required this.onDigit,
    required this.onChoose,
    required this.onShowMe,
  });

  final Step step;
  final int number;
  final int of;
  final Board board;
  final int? selected;
  final String? message;
  final Set<Technique> wrongChoices;
  final ValueChanged<int> onDigit;
  final ValueChanged<Technique> onChoose;
  final VoidCallback onShowMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final places = step.placements.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $number of $of · your turn',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          places
              ? 'Find a digit you can place for certain. Tap its cell, then '
                    'choose the digit.'
              : 'No digit can be placed yet, but a technique lets you remove '
                    'candidates. Which one finds a move on this board?',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: Space.md),
        if (places)
          DigitKeyRow(
            keyPrefix: 'play-digit-',
            onDigit: selected == null ? null : onDigit,
          )
        else
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              for (final t in techniqueChoices(board, step.technique))
                ChoiceChip(
                  key: Key('choice-${t.name}'),
                  label: Text(t.label),
                  selected: false,
                  onSelected: wrongChoices.contains(t)
                      ? null
                      : (_) => onChoose(t),
                ),
            ],
          ),
        if (message != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            message!,
            key: const Key('feedback'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: Space.sm),
        TextButton(
          key: const Key('show-me'),
          onPressed: onShowMe,
          child: const Text('Show me'),
        ),
      ],
    );
  }
}
