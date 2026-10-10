// Searching for puzzles is slow in the web debug build.
@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';

void main() {
  group('SeededRandom', () {
    test('gives the same numbers for the same seed', () {
      final a = SeededRandom(42);
      final b = SeededRandom(42);
      expect(
        [for (var i = 0; i < 20; i++) a.nextInt(1000)],
        [for (var i = 0; i < 20; i++) b.nextInt(1000)],
      );
    });

    test('is pinned, so every device and Dart version agrees', () {
      final random = SeededRandom(20261010);
      expect(
        [for (var i = 0; i < 6; i++) random.nextInt(1000)],
        [121, 475, 188, 810, 448, 728],
      );
    });

    test('different seeds differ', () {
      expect(
        SeededRandom(1).nextInt(1 << 30),
        isNot(SeededRandom(2).nextInt(1 << 30)),
      );
    });

    test('a zero seed still works', () {
      expect(SeededRandom(0).nextInt(10), inInclusiveRange(0, 9));
    });

    test('nextInt stays in range', () {
      final random = SeededRandom(7);
      for (var i = 0; i < 2000; i++) {
        expect(random.nextInt(9), inInclusiveRange(0, 8));
      }
      expect(() => random.nextInt(0), throwsRangeError);
    });

    test('nextDouble is in [0, 1) and nextBool varies', () {
      final random = SeededRandom(3);
      final bools = <bool>{};
      for (var i = 0; i < 100; i++) {
        final d = random.nextDouble();
        expect(d, inInclusiveRange(0, 0.9999999999));
        bools.add(random.nextBool());
      }
      expect(bools, {true, false});
    });
  });

  group('daily puzzle', () {
    test('level follows the weekday', () {
      // 2026-10-05 is a Monday.
      final levels = [
        for (var d = 5; d <= 11; d++) dailyLevel(DateTime(2026, 10, d)),
      ];
      expect(levels, [1, 2, 3, 4, 4, 5, 5]);
    });

    test('the seed identifies the day', () {
      expect(dailySeed(DateTime(2026, 10, 10)), 20261010);
      expect(dailySeed(DateTime(2027, 1, 5)), 20270105);
    });

    test('the same day always gives the same puzzle', () async {
      final a = await findDailyPuzzle(DateTime(2026, 10, 12));
      final b = await findDailyPuzzle(DateTime(2026, 10, 12, 23, 59));
      expect(a!.puzzle.toLine(), b!.puzzle.toLine());
    });

    test('different days give different puzzles', () async {
      final a = await findDailyPuzzle(DateTime(2026, 10, 12));
      final b = await findDailyPuzzle(DateTime(2026, 10, 13));
      expect(a!.puzzle.toLine(), isNot(b!.puzzle.toLine()));
    });

    test('the puzzle has one solution and the day\'s level', () async {
      for (final day in [12, 13, 14]) {
        final date = DateTime(2026, 10, day);
        final found = await findDailyPuzzle(date);
        expect(countSolutions(found!.puzzle), 1);
        expect(found.rating.level, dailyLevel(date));
      }
    });

    test(
      'is pinned: a change to the generator or rater changes the daily',
      () async {
        // If this fails after an intended change, update the expected puzzles.
        final monday = await findDailyPuzzle(DateTime(2026, 10, 12));
        expect(
          monday!.puzzle.toLine().replaceAll('.', '0'),
          '819647035006500987072389061950026813031094070287135600460951708098263150005478006',
        );
        final saturday = await findDailyPuzzle(DateTime(2026, 10, 10));
        expect(
          saturday!.puzzle.toLine().replaceAll('.', '0'),
          '021000900709000000005080300800050020000300010070004500002039000100400050000000600',
        );
        expect(saturday.rating.required, Technique.uniqueRectangle);
      },
    );

    test('can be cancelled', () async {
      expect(
        await findDailyPuzzle(DateTime(2026, 10, 10), isCancelled: () => true),
        isNull,
      );
    });
  });
}
