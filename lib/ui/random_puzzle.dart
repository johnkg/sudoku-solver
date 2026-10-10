import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'levels.dart';
import 'puzzle_library.dart';
import 'search_dialog.dart';
import 'solve_screen.dart';

/// Looks for a random puzzle at [level] while a dialog shows progress, then
/// opens it. With [replace] the current screen is swapped for the new puzzle,
/// which is what "new random puzzle" does.
///
/// Random puzzles are for practice only: they are not saved, and they do not
/// count towards unlocking levels.
Future<void> playRandomPuzzle(
  BuildContext context,
  int level, {
  bool replace = false,
}) async {
  final navigator = Navigator.of(context);
  final found = await runSearchWithDialog(
    context,
    message: 'Looking for a Level $level puzzle…',
    search: (isCancelled) =>
        findPuzzleOfLevel(level, Random(), isCancelled: isCancelled),
  );
  if (found == null) return;

  final entry = PuzzleEntry(
    id: 'random',
    title: 'Random · Level $level',
    text: found.puzzle.toLine().replaceAll('.', '0'),
    technique: found.rating.required!,
  );
  final route = MaterialPageRoute<void>(
    builder: (context) => SolveScreen(
      puzzle: entry,
      recordProgress: false,
      onNewPuzzle: () => playRandomPuzzle(context, level, replace: true),
    ),
  );
  if (replace) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
}

/// A card on the Practice tab: pick a level, get a fresh puzzle.
class RandomPuzzleCard extends StatefulWidget {
  const RandomPuzzleCard({super.key, required this.isUnlocked});

  /// Whether a level is open to the player.
  final bool Function(int level) isUnlocked;

  @override
  State<RandomPuzzleCard> createState() => _RandomPuzzleCardState();
}

class _RandomPuzzleCardState extends State<RandomPuzzleCard> {
  int level = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Random puzzle', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'A fresh puzzle at the level you choose. Practice only: it does '
              'not count towards unlocking.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in levelNames.keys)
                  ChoiceChip(
                    label: Text('Level $l'),
                    tooltip: levelNames[l],
                    selected: level == l,
                    onSelected: widget.isUnlocked(l)
                        ? (_) => setState(() => level = l)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => playRandomPuzzle(context, level),
              icon: const Icon(Icons.shuffle),
              label: const Text('Play random puzzle'),
            ),
          ],
        ),
      ),
    );
  }
}
