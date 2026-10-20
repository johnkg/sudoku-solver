import 'package:flutter/material.dart';

import '../progress/progress_store.dart';
import 'levels.dart';
import 'puzzle_library.dart';

/// Something to earn. Whether it is earned is worked out from what the player
/// has done, so nothing extra is saved and a reset clears it.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    this.goal = 1,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// How far along the player is, up to [goal].
  final int progress;
  final int goal;

  bool get unlocked => progress >= goal;
}

/// Every achievement with the player's progress on it, in the order shown.
List<Achievement> achievementsFor(ProgressStore store) {
  final records = store.records;
  int solvedAtLevel(int level) => puzzleLibrary
      .where((p) => p.level == level && records.containsKey(p.id))
      .length;
  int puzzlesAtLevel(int level) =>
      puzzleLibrary.where((p) => p.level == level).length;

  final results = [...records.values, ...store.dailyRecords.values];
  final stats = store.techniqueStats.values;
  final rightAnswers = stats.fold<int>(0, (sum, s) => sum + s.right);

  return [
    Achievement(
      id: 'first-solve',
      title: 'First steps',
      description: 'Solve a puzzle.',
      icon: Icons.flag_outlined,
      progress: results.isEmpty ? 0 : 1,
    ),
    Achievement(
      id: 'flawless',
      title: 'Flawless',
      description: 'Solve a puzzle with no mistakes and no hints.',
      icon: Icons.stars_outlined,
      progress: results.any((r) => r.stars == 3) ? 1 : 0,
    ),
    Achievement(
      id: 'quick',
      title: 'Quick thinker',
      description: 'Solve a puzzle in under three minutes, flawlessly.',
      icon: Icons.bolt_outlined,
      progress: results.any((r) => r.stars == 3 && (r.seconds ?? 1 << 30) < 180)
          ? 1
          : 0,
    ),
    for (final level in levelNames.keys)
      Achievement(
        id: 'level-$level',
        title: '${levelNames[level]} cleared',
        description: 'Solve every Level $level puzzle.',
        icon: Icons.looks_one_outlined,
        progress: solvedAtLevel(level),
        goal: puzzlesAtLevel(level),
      ),
    Achievement(
      id: 'completionist',
      title: 'Completionist',
      description: 'Solve every puzzle in the library.',
      icon: Icons.emoji_events_outlined,
      progress: records.keys
          .where((id) => puzzleLibrary.any((p) => p.id == id))
          .length,
      goal: puzzleLibrary.length,
    ),
    Achievement(
      id: 'daily-10',
      title: 'Daily regular',
      description: 'Solve 10 daily puzzles.',
      icon: Icons.calendar_today_outlined,
      progress: store.dailySolvedCount,
      goal: 10,
    ),
    for (final days in const [3, 7, 30])
      Achievement(
        id: 'streak-$days',
        title: '$days days in a row',
        description: 'Solve the daily puzzle $days days in a row.',
        icon: Icons.local_fire_department_outlined,
        progress: store.bestDailyStreak,
        goal: days,
      ),
    Achievement(
      id: 'sharp-eye',
      title: 'Sharp eye',
      description: 'Spot or apply a technique correctly 25 times.',
      icon: Icons.visibility_outlined,
      progress: rightAnswers,
      goal: 25,
    ),
    Achievement(
      id: 'technique-master',
      title: 'Technique master',
      description: 'Be right at least 90% of 10 tries at one technique.',
      icon: Icons.school_outlined,
      progress: stats.any((s) => s.attempts >= 10 && s.accuracy >= 0.9) ? 1 : 0,
    ),
  ];
}

/// Ids of the achievements the player has earned.
Set<String> unlockedAchievementIds(ProgressStore store) => {
  for (final a in achievementsFor(store))
    if (a.unlocked) a.id,
};
