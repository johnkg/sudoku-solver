import 'package:flutter/material.dart';

import '../progress/progress_scope.dart';
import 'daily_puzzle.dart';
import 'layout.dart';
import 'level_header.dart';
import 'levels.dart';
import 'puzzle_library.dart';
import 'random_puzzle.dart';
import 'solve_screen.dart';
import 'stars.dart';
import 'technique_puzzle.dart';
import 'unlocking.dart';

/// The list of practice puzzles, grouped by level. A level opens once the one
/// below is solved.
class PracticeTab extends StatelessWidget {
  const PracticeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ProgressScope.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Pick a puzzle. Place digits yourself, and ask for a hint when '
              'you are stuck.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${store.solvedCount} of ${puzzleLibrary.length} puzzles solved',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const DailyPuzzleCard(),
            RandomPuzzleCard(
              isUnlocked: (level) => isLevelUnlocked(store, level),
            ),
            TechniquePuzzleCard(
              isUnlocked: (level) => isLevelUnlocked(store, level),
            ),
            for (final level in levelNames.keys) ...[
              Builder(
                builder: (context) {
                  final unlocked = isLevelUnlocked(store, level);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LevelHeader(
                        level: level,
                        unlocked: unlocked,
                        blurb: unlocked
                            ? levelBlurbs[level]!
                            : unlockHint(level),
                      ),
                      for (final puzzle in puzzleLibrary.where(
                        (p) => p.level == level,
                      ))
                        _PuzzleTile(puzzle: puzzle, unlocked: unlocked),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({required this.puzzle, required this.unlocked});

  final PuzzleEntry puzzle;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final record = store.recordFor(puzzle.id);

    final String subtitle;
    Widget? trailing;
    if (!unlocked) {
      subtitle = 'Locked';
      trailing = const Icon(Icons.lock_outline);
    } else if (store.hasSavedGame(puzzle.id)) {
      subtitle = 'Needs: ${puzzle.technique.label} · In progress';
      trailing = const Icon(Icons.play_circle_outline);
    } else if (record != null) {
      subtitle = 'Needs: ${puzzle.technique.label}';
      trailing = Stars(count: record.stars);
    } else {
      subtitle = 'Needs: ${puzzle.technique.label}';
      trailing = const Icon(Icons.chevron_right);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: unlocked,
        title: Text(puzzle.title),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SolveScreen(puzzle: puzzle)),
        ),
      ),
    );
  }
}
