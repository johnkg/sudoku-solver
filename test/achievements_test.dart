import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/achievements.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/daily_calendar.dart';
import 'package:sudoku_solver/ui/puzzle_library.dart';
import 'package:sudoku_solver/ui/share_result.dart';

void main() {
  ProgressStore dailies(Iterable<String> days, {DateTime? now}) {
    final store = ProgressStore.memory(
      now: () => now ?? DateTime(2026, 10, 20),
    );
    for (final day in days) {
      store.recordDaily(day, mistakes: 0, hints: 0);
    }
    return store;
  }

  Achievement achievement(ProgressStore store, String id) =>
      achievementsFor(store).firstWhere((a) => a.id == id);

  group('bestDailyStreak', () {
    test('is 0 with no dailies', () {
      expect(ProgressStore.memory().bestDailyStreak, 0);
    });

    test('finds the longest run, not the current one', () {
      final store = dailies([
        '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', // 4 days
        '2026-10-10', // gap
        '2026-10-19', '2026-10-20', // current: 2
      ]);
      expect(store.bestDailyStreak, 4);
      expect(store.dailyStreak, 2);
    });

    test('runs across a month and a year end', () {
      expect(
        dailies(['2026-12-30', '2026-12-31', '2027-01-01']).bestDailyStreak,
        3,
      );
      expect(dailies(['2026-02-28', '2026-03-01']).bestDailyStreak, 2);
    });
  });

  group('achievements', () {
    test('none are earned at the start', () {
      final all = achievementsFor(ProgressStore.memory());
      expect(all.where((a) => a.unlocked), isEmpty);
      expect(all.map((a) => a.id).toSet().length, all.length);
    });

    test('a first solve, flawless and quick', () {
      final store = ProgressStore.memory()
        ..recordSolve(
          puzzleLibrary.first.id,
          mistakes: 0,
          hints: 0,
          seconds: 90,
        );
      expect(achievement(store, 'first-solve').unlocked, isTrue);
      expect(achievement(store, 'flawless').unlocked, isTrue);
      expect(achievement(store, 'quick').unlocked, isTrue);
    });

    test('a slow or sloppy solve is not flawless or quick', () {
      final store = ProgressStore.memory()
        ..recordSolve(puzzleLibrary[0].id, mistakes: 1, hints: 0, seconds: 90)
        ..recordSolve(puzzleLibrary[1].id, mistakes: 0, hints: 0, seconds: 400);
      expect(achievement(store, 'first-solve').unlocked, isTrue);
      expect(achievement(store, 'flawless').unlocked, isTrue); // the second one
      expect(achievement(store, 'quick').unlocked, isFalse);
    });

    test('a daily counts as a first solve', () {
      expect(
        achievement(dailies(['2026-10-20']), 'first-solve').unlocked,
        isTrue,
      );
    });

    test('clearing a level needs every puzzle of it', () {
      final store = ProgressStore.memory();
      final level1 = puzzleLibrary.where((p) => p.level == 1).toList();
      for (final p in level1.skip(1)) {
        store.recordSolve(p.id, mistakes: 0, hints: 0);
      }
      var a = achievement(store, 'level-1');
      expect(a.unlocked, isFalse);
      expect(a.progress, level1.length - 1);
      expect(a.goal, level1.length);

      store.recordSolve(level1.first.id, mistakes: 0, hints: 0);
      expect(achievement(store, 'level-1').unlocked, isTrue);
      expect(achievement(store, 'level-2').unlocked, isFalse);
    });

    test('streaks and regulars', () {
      final store = dailies([
        for (var d = 1; d <= 7; d++) '2026-10-${d.toString().padLeft(2, '0')}',
      ]);
      expect(achievement(store, 'streak-3').unlocked, isTrue);
      expect(achievement(store, 'streak-7').unlocked, isTrue);
      expect(achievement(store, 'streak-30').unlocked, isFalse);
      expect(achievement(store, 'streak-30').progress, 7);
      expect(achievement(store, 'daily-10').progress, 7);
      expect(achievement(store, 'daily-10').unlocked, isFalse);
    });

    test('completionist needs the whole library', () {
      final store = ProgressStore.memory();
      for (final p in puzzleLibrary) {
        store.recordSolve(p.id, mistakes: 0, hints: 0);
      }
      expect(achievement(store, 'completionist').unlocked, isTrue);
      expect(unlockedAchievementIds(store), contains('completionist'));
    });

    test('sharp eye counts right answers across techniques', () {
      final store = ProgressStore.memory();
      for (var i = 0; i < 24; i++) {
        store.recordTechnique(i.isEven ? 'nakedPair' : 'xWing', right: true);
      }
      store.recordTechnique('xWing', right: false); // wrong ones do not count
      expect(achievement(store, 'sharp-eye').progress, 24);
      expect(achievement(store, 'sharp-eye').unlocked, isFalse);
      store.recordTechnique('yWing', right: true);
      expect(achievement(store, 'sharp-eye').unlocked, isTrue);
    });

    test('technique master needs ten tries at 90% or better', () {
      final store = ProgressStore.memory();
      for (var i = 0; i < 9; i++) {
        store.recordTechnique('nakedPair', right: true);
      }
      expect(
        achievement(store, 'technique-master').unlocked,
        isFalse,
      ); // 9 tries
      store.recordTechnique('nakedPair', right: true);
      expect(achievement(store, 'technique-master').unlocked, isTrue); // 10/10

      final sloppy = ProgressStore.memory();
      for (var i = 0; i < 8; i++) {
        sloppy.recordTechnique('xWing', right: true);
      }
      sloppy.recordTechnique('xWing', right: false);
      sloppy.recordTechnique('xWing', right: false); // 8 of 10
      expect(achievement(sloppy, 'technique-master').unlocked, isFalse);
    });

    test('a reset forgets them', () {
      final store = ProgressStore.memory()
        ..recordSolve(puzzleLibrary.first.id, mistakes: 0, hints: 0);
      store.reset();
      expect(unlockedAchievementIds(store), isEmpty);
    });
  });

  group('sharing', () {
    final link = Uri.parse('https://example.com/sudoku-solver/');

    test('the share text', () {
      expect(
        dailyShareText(
          date: DateTime(2026, 10, 10),
          level: 5,
          levelName: 'Expert',
          stars: 2,
          seconds: 272,
          mistakes: 1,
          hints: 0,
          streak: 5,
          link: link,
        ),
        'Sudoku Technique Teacher · Sat, Oct 10\n'
        'Level 5 · Expert\n'
        '★★☆  4:32 · 1 mistake · 0 hints\n'
        '🔥 5 days in a row\n'
        'https://example.com/sudoku-solver/',
      );
    });

    test('a streak of one is not mentioned', () {
      final text = dailyShareText(
        date: DateTime(2026, 10, 12),
        level: 1,
        levelName: 'Beginner',
        stars: 3,
        seconds: 65,
        mistakes: 0,
        hints: 1,
        streak: 1,
        link: link,
      );
      expect(text, isNot(contains('🔥')));
      expect(text, contains('1:05 · 0 mistakes · 1 hint\n'));
    });

    test('the app link drops the query and fragment', () {
      expect(
        appHome(Uri.parse('https://example.com:8080/app/?puzzle=1#/x')),
        Uri.parse('https://example.com:8080/app/'),
      );
      expect(
        appHome(Uri.parse('https://example.com/app/')).toString(),
        'https://example.com/app/',
      );
    });
  });

  group('calendar', () {
    Future<void> show(
      WidgetTester tester,
      Set<String> solved,
      DateTime today,
    ) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyCalendar(solved: solved, today: today),
        ),
      ),
    );

    testWidgets('shows this month, with solved days marked', (tester) async {
      await show(tester, {'2026-10-12'}, DateTime(2026, 10, 20));
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.byKey(const Key('cal-day-2026-10-12')), findsOneWidget);
      expect(find.byKey(const Key('cal-day-2026-10-31')), findsOneWidget);
      expect(find.byKey(const Key('cal-day-2026-10-32')), findsNothing);
      final solved = tester.widget<Container>(
        find.byKey(const Key('cal-day-2026-10-12')),
      );
      final other = tester.widget<Container>(
        find.byKey(const Key('cal-day-2026-10-13')),
      );
      expect((solved.decoration as BoxDecoration).color, isNotNull);
      expect((other.decoration as BoxDecoration).color, isNull);
    });

    testWidgets('moves back to the first month with a solve, not past it', (
      tester,
    ) async {
      await show(tester, {'2026-08-30'}, DateTime(2026, 10, 20));
      IconButton button(String key) =>
          tester.widget<IconButton>(find.byKey(Key(key)));
      expect(button('cal-next').onPressed, isNull);

      await tester.tap(find.byKey(const Key('cal-prev')));
      await tester.pump();
      expect(find.text('September 2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cal-prev')));
      await tester.pump();
      expect(find.text('August 2026'), findsOneWidget);
      expect(find.byKey(const Key('cal-day-2026-08-30')), findsOneWidget);
      expect(button('cal-prev').onPressed, isNull);

      await tester.tap(find.byKey(const Key('cal-next')));
      await tester.pump();
      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('has nowhere to go back to with no history', (tester) async {
      await show(tester, {}, DateTime(2026, 10, 20));
      expect(
        tester.widget<IconButton>(find.byKey(const Key('cal-prev'))).onPressed,
        isNull,
      );
    });

    testWidgets('starts the right day of the week', (tester) async {
      // 1 October 2026 is a Thursday, so it sits in the fourth column, on the
      // first row, above the 8th and to the right of Monday the 5th.
      await show(tester, {}, DateTime(2026, 10, 20));
      Offset at(int day) => tester.getTopLeft(
        find.byKey(Key('cal-day-2026-10-${day.toString().padLeft(2, '0')}')),
      );
      expect(at(1).dx, at(8).dx);
      expect(at(1).dy, lessThan(at(8).dy));
      expect(at(5).dx, lessThan(at(1).dx));
      expect(at(5).dy, greaterThan(at(1).dy));
      expect(at(5).dx, at(12).dx);
    });
  });

  testWidgets('the Statistics screen shows the calendar and achievements', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = dailies(
      ['2026-10-19', '2026-10-20'],
    )..recordSolve(puzzleLibrary.first.id, mistakes: 0, hints: 0, seconds: 100);
    await tester.pumpWidget(SudokuApp(store: store));
    await tester.tap(find.byTooltip('Progress options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-calendar')), findsOneWidget);
    expect(find.text('Current streak 2 · Best 2'), findsOneWidget);
    expect(find.byKey(const Key('cal-day-2026-10-20')), findsOneWidget);
    expect(find.textContaining('Achievements · 3 of'), findsOneWidget);
    expect(find.byKey(const Key('achievement-first-solve')), findsOneWidget);
    expect(find.text('Flawless'), findsOneWidget);
    // The 3-day streak is two thirds of the way.
    expect(find.text('2 of 3'), findsOneWidget);
  });
}
