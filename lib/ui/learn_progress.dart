import '../lessons/lessons.dart';
import '../progress/progress_store.dart';
import 'levels.dart';
import 'puzzle_library.dart';
import 'unlocking.dart';

/// Whether the player has solved a practice puzzle for [lesson]'s technique.
bool isPractised(ProgressStore store, Lesson lesson) => puzzleLibrary.any(
  (p) => p.technique == lesson.technique && store.isSolved(p.id),
);

/// How many of a level's lessons are practised, and how many there are.
({int done, int total}) levelProgress(ProgressStore store, int level) {
  final inLevel = lessons.where((l) => l.level == level).toList();
  return (
    done: inLevel.where((l) => isPractised(store, l)).length,
    total: inLevel.length,
  );
}

/// How many of all lessons are practised, and how many there are.
({int done, int total}) overallProgress(ProgressStore store) {
  var done = 0;
  for (final level in levelNames.keys) {
    done += levelProgress(store, level).done;
  }
  return (done: done, total: lessons.length);
}

/// The first open lesson the player has not practised yet, or null when every
/// open lesson is done.
Lesson? nextLesson(ProgressStore store) {
  for (final lesson in lessons) {
    if (isLevelUnlocked(store, lesson.level) && !isPractised(store, lesson)) {
      return lesson;
    }
  }
  return null;
}
