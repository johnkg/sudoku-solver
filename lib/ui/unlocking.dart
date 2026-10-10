import '../engine/engine.dart';
import '../progress/progress_store.dart';
import 'puzzle_library.dart';

/// Level 1 is always open. A higher level opens once the player has solved a
/// practice puzzle for every technique of the level below, or when they chose
/// to unlock everything. A technique with no practice puzzle does not hold the
/// next level back.
bool isLevelUnlocked(ProgressStore store, int level) {
  if (level <= 1 || store.unlockedAll) return true;
  return Technique.values.where((t) => t.level == level - 1).every((t) {
    final puzzles = puzzleLibrary.where((p) => p.technique == t);
    return puzzles.isEmpty || puzzles.any((p) => store.isSolved(p.id));
  });
}

/// What the player must do to open [level].
String unlockHint(int level) =>
    'Solve a practice puzzle for every Level ${level - 1} technique to unlock '
    'this level.';
