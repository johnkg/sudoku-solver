import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'puzzle_library.dart';
import 'search_dialog.dart';
import 'solve_screen.dart';

/// Looks for a random puzzle built around [technique], then opens it. With [replace] the current screen is swapped for the new puzzle.
///
/// Like random puzzles, these are practice only: not saved, and they do not
/// count towards unlocking levels.
Future<void> playTechniquePuzzle(
  BuildContext context,
  Technique technique, {
  bool replace = false,
}) async {
  final navigator = Navigator.of(context);
  final found = await runSearchWithDialog<FoundPuzzle>(
    context,
    message: 'Looking for a puzzle that uses ${technique.label}…',
    notFound: 'Could not find one this time. Try again.',
    search: (isCancelled) =>
        findPuzzleRequiring(technique, Random(), isCancelled: isCancelled),
  );
  if (found == null) return;

  final entry = PuzzleEntry(
    id: 'technique',
    title: '${technique.label} puzzle',
    text: found.puzzle.toLine().replaceAll('.', '0'),
    technique: found.rating.required ?? technique,
  );
  final route = MaterialPageRoute<void>(
    builder: (context) => SolveScreen(
      puzzle: entry,
      recordProgress: false,
      onNewPuzzle: () => playTechniquePuzzle(context, technique, replace: true),
    ),
  );
  if (replace) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
}

/// A card on the Practice tab: pick a technique, get a puzzle built around it.
class TechniquePuzzleCard extends StatefulWidget {
  const TechniquePuzzleCard({super.key, required this.isUnlocked});

  /// Whether a level is open to the player.
  final bool Function(int level) isUnlocked;

  @override
  State<TechniquePuzzleCard> createState() => _TechniquePuzzleCardState();
}

class _TechniquePuzzleCardState extends State<TechniquePuzzleCard> {
  Technique? chosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Full House only ever finishes a unit, so no puzzle needs it.
    final options = [
      for (final t in Technique.values)
        if (t != Technique.fullHouse && widget.isUnlocked(t.level)) t,
    ];
    final selected = options.contains(chosen) ? chosen : options.first;

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Practise a technique', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'A fresh puzzle built around the technique you pick. Harder ones '
              'can take a little while to find.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButton<Technique>(
              key: const Key('technique-picker'),
              isExpanded: true,
              value: selected,
              items: [
                for (final t in options)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (t) => setState(() => chosen = t),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('technique-puzzle'),
              onPressed: () => playTechniquePuzzle(context, selected!),
              icon: const Icon(Icons.psychology_outlined),
              label: const Text('Play a puzzle with it'),
            ),
          ],
        ),
      ),
    );
  }
}
