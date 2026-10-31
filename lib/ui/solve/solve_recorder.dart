import '../../progress/progress_store.dart';
import '../achievements.dart';
import '../levels.dart';
import '../puzzle_library.dart';
import '../solve_controller.dart';
import '../unlocking.dart';

/// Keeps the progress store up to date with a solve in progress: saves the
/// game when it changes, and records the result once it is solved.
class SolveRecorder {
  SolveRecorder({
    required this.store,
    required this.controller,
    required this.puzzle,
    this.dailyKey,
  }) : _savedSignature = _signatureOf(controller);

  final ProgressStore store;
  final SolveController controller;
  final PuzzleEntry puzzle;

  /// Set for the daily puzzle: the solve counts towards the streak rather
  /// than towards unlocking.
  final String? dailyKey;

  /// Changes whenever the game needs saving again.
  String _savedSignature;
  bool _recorded = false;

  /// A level this solve just opened, to tell the player.
  int? newlyUnlockedLevel;

  static String _signatureOf(SolveController c) =>
      '${c.changeCount}/${c.mistakes}/${c.hintsUsed}/${c.movesShown}';

  /// Call after every change to the game. Returns the titles of achievements
  /// this change earned, usually none.
  List<String> update() {
    if (controller.solved) return _recordSolve();
    _recorded = false;
    newlyUnlockedLevel = null;
    _saveGameIfChanged();
    return const [];
  }

  void _saveGameIfChanged() {
    final signature = _signatureOf(controller);
    if (signature == _savedSignature) return;
    _savedSignature = signature;
    final untouched =
        controller.changeCount == 0 &&
        controller.mistakes == 0 &&
        controller.hintsUsed == 0;
    if (untouched) {
      store.clearGame(puzzle.id);
    } else {
      store.saveGame(puzzle.id, controller.toJson());
    }
  }

  List<String> _recordSolve() {
    if (_recorded) return const [];
    _recorded = true;
    final achievementsBefore = unlockedAchievementIds(store);

    // Techniques the player needed a hint for count as ones to revisit.
    for (final technique in controller.applied) {
      store.recordTechnique(technique.name, right: false);
    }
    final key = dailyKey;
    if (key != null) {
      store.recordDaily(
        key,
        mistakes: controller.mistakes,
        hints: controller.hintsUsed,
        seconds: controller.seconds.value,
      );
    } else {
      _recordPuzzleSolve();
    }
    return [
      for (final a in achievementsFor(store))
        if (a.unlocked && !achievementsBefore.contains(a.id)) a.title,
    ];
  }

  void _recordPuzzleSolve() {
    final next = puzzle.level + 1;
    final wasOpen = isLevelUnlocked(store, next);
    store.recordSolve(
      puzzle.id,
      mistakes: controller.mistakes,
      hints: controller.hintsUsed,
      seconds: controller.seconds.value,
    );
    if (!wasOpen &&
        isLevelUnlocked(store, next) &&
        levelNames.containsKey(next)) {
      newlyUnlockedLevel = next;
    }
  }
}
