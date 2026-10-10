import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/puzzle_library.dart';
import 'package:sudoku_solver/ui/unlocking.dart';

void main() {
  group('PuzzleRecord', () {
    test('stars drop for mistakes and for hints', () {
      expect(const PuzzleRecord(mistakes: 0, hints: 0).stars, 3);
      expect(const PuzzleRecord(mistakes: 2, hints: 0).stars, 2);
      expect(const PuzzleRecord(mistakes: 0, hints: 4).stars, 2);
      expect(const PuzzleRecord(mistakes: 1, hints: 1).stars, 1);
    });
  });

  group('ProgressStore (memory)', () {
    late ProgressStore store;
    setUp(() => store = ProgressStore.memory());

    test('starts empty', () {
      expect(store.solvedCount, 0);
      expect(store.isSolved('xWing'), isFalse);
      expect(store.unlockedAll, isFalse);
    });

    test('recordSolve keeps the better result', () {
      store.recordSolve('a', mistakes: 2, hints: 1);
      store.recordSolve('a', mistakes: 0, hints: 1);
      store.recordSolve('a', mistakes: 5, hints: 5);
      expect(store.recordFor('a')!.mistakes, 0);
      expect(store.recordFor('a')!.hints, 1);
      expect(store.solvedCount, 1);
    });

    test('solving clears the saved game', () {
      store.saveGame('a', {'x': 1});
      expect(store.hasSavedGame('a'), isTrue);
      store.recordSolve('a', mistakes: 0, hints: 0);
      expect(store.hasSavedGame('a'), isFalse);
    });

    test('reset forgets everything', () {
      store.recordSolve('a', mistakes: 0, hints: 0);
      store.saveGame('b', {'x': 1});
      store.unlockAllLevels();
      store.reset();
      expect(store.solvedCount, 0);
      expect(store.hasSavedGame('b'), isFalse);
      expect(store.unlockedAll, isFalse);
    });

    test('listeners are told about changes', () {
      var calls = 0;
      store.addListener(() => calls++);
      store.saveGame('a', {});
      store.clearGame('a');
      store.clearGame('a'); // nothing to clear, no notification
      store.recordSolve('a', mistakes: 0, hints: 0);
      store.unlockAllLevels();
      store.reset();
      expect(calls, 5);
    });
  });

  group('ProgressStore (saved to the device)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('progress survives loading again', () async {
      final first = await ProgressStore.load();
      first.recordSolve('warm', mistakes: 1, hints: 0);
      first.saveGame('other', {'moves': 3});
      first.unlockAllLevels();

      final second = await ProgressStore.load();
      expect(second.isSolved('warm'), isTrue);
      expect(second.recordFor('warm')!.mistakes, 1);
      expect(second.savedGame('other'), {'moves': 3});
      expect(second.unlockedAll, isTrue);
    });

    test('clearing and resetting are saved too', () async {
      final first = await ProgressStore.load();
      first.saveGame('a', {'x': 1});
      first.saveGame('b', {'x': 2});
      first.recordSolve('c', mistakes: 0, hints: 0);
      first.clearGame('a');
      expect((await ProgressStore.load()).hasSavedGame('a'), isFalse);
      expect((await ProgressStore.load()).hasSavedGame('b'), isTrue);

      first.reset();
      final after = await ProgressStore.load();
      expect(after.solvedCount, 0);
      expect(after.hasSavedGame('b'), isFalse);
    });

    test('unreadable saved data is ignored', () async {
      SharedPreferences.setMockInitialValues({
        'progress.records': 'not json',
        'progress.game.a': '{{{',
        'progress.game.b': jsonEncode({'ok': true}),
      });
      final store = await ProgressStore.load();
      expect(store.solvedCount, 0);
      expect(store.hasSavedGame('a'), isFalse);
      expect(store.savedGame('b'), {'ok': true});
    });
  });

  group('daily puzzle records', () {
    DateTime day = DateTime(2026, 10, 10);
    late ProgressStore store;
    setUp(() {
      day = DateTime(2026, 10, 10);
      store = ProgressStore.memory(now: () => day);
    });

    test('keys are zero padded dates', () {
      expect(ProgressStore.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(store.todayKey, '2026-10-10');
    });

    test('a solve is kept and does not count as a library puzzle', () {
      store.recordDaily('2026-10-10', mistakes: 1, hints: 0);
      expect(store.dailyRecord('2026-10-10')!.stars, 2);
      expect(store.solvedCount, 0);
    });

    test('the better daily result wins', () {
      store.recordDaily('2026-10-10', mistakes: 3, hints: 0);
      store.recordDaily('2026-10-10', mistakes: 0, hints: 0);
      store.recordDaily('2026-10-10', mistakes: 9, hints: 9);
      expect(store.dailyRecord('2026-10-10')!.stars, 3);
    });

    test('solving clears the saved daily game', () {
      final id = ProgressStore.dailyGameId('2026-10-10');
      store.saveGame(id, {'x': 1});
      store.recordDaily('2026-10-10', mistakes: 0, hints: 0);
      expect(store.hasSavedGame(id), isFalse);
    });

    test('streak counts days in a row ending today', () {
      expect(store.dailyStreak, 0);
      store.recordDaily('2026-10-08', mistakes: 0, hints: 0);
      store.recordDaily('2026-10-09', mistakes: 0, hints: 0);
      expect(store.dailyStreak, 2); // still alive: today is not over
      store.recordDaily('2026-10-10', mistakes: 0, hints: 0);
      expect(store.dailyStreak, 3);
    });

    test('a missed day ends the streak', () {
      store.recordDaily('2026-10-07', mistakes: 0, hints: 0);
      store.recordDaily('2026-10-08', mistakes: 0, hints: 0);
      expect(store.dailyStreak, 0);
      day = DateTime(2026, 10, 9);
      expect(store.dailyStreak, 2);
    });

    test('a streak crosses month and year ends', () {
      store.recordDaily('2026-12-31', mistakes: 0, hints: 0);
      store.recordDaily('2027-01-01', mistakes: 0, hints: 0);
      day = DateTime(2027, 1, 1);
      expect(store.dailyStreak, 2);
    });

    test('the daily puzzle text is remembered', () {
      expect(store.dailyPuzzleText('2026-10-10'), isNull);
      store.saveDailyPuzzle('2026-10-10', 'abc');
      expect(store.dailyPuzzleText('2026-10-10'), 'abc');
    });

    test('reset forgets daily results too', () {
      store.recordDaily('2026-10-10', mistakes: 0, hints: 0);
      store.saveDailyPuzzle('2026-10-10', 'abc');
      store.reset();
      expect(store.dailyStreak, 0);
      expect(store.dailyPuzzleText('2026-10-10'), isNull);
    });
  });

  group('daily puzzle records (saved to the device)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('results and today\'s puzzle survive loading again', () async {
      final now = DateTime(2026, 10, 10);
      final first = await ProgressStore.load(now: () => now);
      first.recordDaily('2026-10-09', mistakes: 0, hints: 1);
      first.recordDaily('2026-10-10', mistakes: 0, hints: 0);
      first.saveDailyPuzzle('2026-10-10', 'today');

      final second = await ProgressStore.load(now: () => now);
      expect(second.dailyStreak, 2);
      expect(second.dailyRecord('2026-10-09')!.hints, 1);
      expect(second.dailyPuzzleText('2026-10-10'), 'today');
    });

    test(
      'loading on a later day drops old puzzles and games, keeps results',
      () async {
        final first = await ProgressStore.load(
          now: () => DateTime(2026, 10, 10),
        );
        first.recordDaily('2026-10-10', mistakes: 0, hints: 0);
        first.saveDailyPuzzle('2026-10-10', 'old');
        first.saveGame(ProgressStore.dailyGameId('2026-10-10'), {'x': 1});
        first.saveGame('keepMe', {'x': 2});

        final next = await ProgressStore.load(
          now: () => DateTime(2026, 10, 11),
        );
        expect(next.dailyPuzzleText('2026-10-10'), isNull);
        expect(
          next.hasSavedGame(ProgressStore.dailyGameId('2026-10-10')),
          isFalse,
        );
        expect(next.hasSavedGame('keepMe'), isTrue);
        expect(next.dailyRecord('2026-10-10'), isNotNull);
        expect(next.dailyStreak, 1);
      },
    );

    test('reset also clears saved daily data', () async {
      final now = DateTime(2026, 10, 10);
      final first = await ProgressStore.load(now: () => now);
      first.recordDaily('2026-10-10', mistakes: 0, hints: 0);
      first.saveDailyPuzzle('2026-10-10', 'x');
      first.reset();
      final after = await ProgressStore.load(now: () => now);
      expect(after.dailyStreak, 0);
      expect(after.dailyPuzzleText('2026-10-10'), isNull);
    });
  });

  group('unlocking', () {
    late ProgressStore store;
    setUp(() => store = ProgressStore.memory());

    test('level 1 is always open, the rest start locked', () {
      expect(isLevelUnlocked(store, 1), isTrue);
      for (final level in [2, 3, 4, 5]) {
        expect(isLevelUnlocked(store, level), isFalse);
      }
    });

    test('a level opens once each technique below has a solved puzzle', () {
      // Solve one puzzle for all but the last level-1 technique.
      final techniques = Technique.values.where((t) => t.level == 1).toList();
      for (final t in techniques.take(techniques.length - 1)) {
        store.recordSolve(
          puzzleLibrary.firstWhere((p) => p.technique == t).id,
          mistakes: 0,
          hints: 0,
        );
      }
      expect(isLevelUnlocked(store, 2), isFalse);

      store.recordSolve(
        puzzleLibrary.firstWhere((p) => p.technique == techniques.last).id,
        mistakes: 0,
        hints: 0,
      );
      expect(isLevelUnlocked(store, 2), isTrue);
      expect(isLevelUnlocked(store, 3), isFalse);
    });

    test('one puzzle per technique is enough, even if there are several', () {
      for (final t in Technique.values.where((t) => t.level == 1)) {
        store.recordSolve(
          puzzleLibrary.firstWhere((p) => p.technique == t).id,
          mistakes: 0,
          hints: 0,
        );
      }
      expect(isLevelUnlocked(store, 2), isTrue);
    });

    test('every level up to 5 can be reached by practising each technique', () {
      for (final p in puzzleLibrary) {
        store.recordSolve(p.id, mistakes: 0, hints: 0);
      }
      for (final level in [1, 2, 3, 4, 5]) {
        expect(isLevelUnlocked(store, level), isTrue);
      }
    });

    test('unlock all opens everything', () {
      store.unlockAllLevels();
      for (final level in [1, 2, 3, 4, 5]) {
        expect(isLevelUnlocked(store, level), isTrue);
      }
    });

    test('puzzle ids are unique', () {
      expect(
        puzzleLibrary.map((p) => p.id).toSet().length,
        puzzleLibrary.length,
      );
    });
  });
}
