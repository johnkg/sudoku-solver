import 'package:flutter/material.dart';

import 'layout.dart';
import 'navigation.dart';
import 'puzzle_library.dart';
import 'solve_screen.dart';

/// Opens [entry] as a practice puzzle: not saved, and it does not count
/// towards unlocking levels. [playAnother] runs from the solve screen's "new
/// puzzle" button and gets that screen's context.
void openPracticePuzzle(
  NavigatorState navigator,
  PuzzleEntry entry, {
  required void Function(BuildContext context) playAnother,
  required bool replace,
}) => openScreen(
  navigator,
  (context) => SolveScreen(
    puzzle: entry,
    recordProgress: false,
    onNewPuzzle: () => playAnother(context),
  ),
  replace: replace,
);

/// A card on the Practice tab: a title, a line saying what it does, and the
/// controls to choose and start.
class PracticeCard extends StatelessWidget {
  const PracticeCard({
    super.key,
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(top: Space.lg),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: Space.xs),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.md),
            ...children,
          ],
        ),
      ),
    );
  }
}
