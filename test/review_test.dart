import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/progress/review_schedule.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/review.dart';

void main() {
  var day = DateTime(2026, 10, 10);
  DateTime clock() => day;
  void advance(int days) => day = DateTime(day.year, day.month, day.day + days);

  setUp(() => day = DateTime(2026, 10, 10));

  ProgressStore newStore() => ProgressStore.memory(now: clock);

  TechniqueStat stat(ProgressStore store, Technique t) =>
      store.techniqueStats[t.name]!;

  group('reviewIntervalAfter', () {
    test('starts at a day, doubles on each right answer, and is capped', () {
      var interval = 0;
      final seen = <int>[];
      for (var i = 0; i < 8; i++) {
        interval = reviewIntervalAfter(current: interval, right: true);
        seen.add(interval);
      }
      expect(seen, [1, 2, 4, 8, 16, 32, 32, 32]);
    });

    test('a wrong answer starts again from a day', () {
      expect(reviewIntervalAfter(current: 16, right: false), 1);
      expect(reviewIntervalAfter(current: 0, right: false), 1);
    });
  });

  group('the schedule in the store', () {
    test('a technique is due the day after its first try', () {
      final store = newStore()
        ..recordTechnique(Technique.xWing.name, right: true);

      expect(stat(store, Technique.xWing).isDueOn(day), isFalse);
      advance(1);
      expect(stat(store, Technique.xWing).isDueOn(day), isTrue);
    });

    test('right answers push the next review further out', () {
      final store = newStore();
      for (final gap in [1, 2, 4]) {
        store.recordTechnique(Technique.xWing.name, right: true);
        expect(stat(store, Technique.xWing).intervalDays, gap);
        advance(gap);
        expect(stat(store, Technique.xWing).isDueOn(day), isTrue);
      }
    });

    test('a whole quiz round moves the schedule once', () {
      final store = newStore();
      for (var i = 0; i < 5; i++) {
        store.recordTechnique(Technique.xWing.name, right: true);
      }

      expect(stat(store, Technique.xWing).intervalDays, 1);
      expect(stat(store, Technique.xWing).right, 5);
    });

    test('a wrong answer brings it back, even the same day', () {
      final store = newStore();
      store.recordTechnique(Technique.xWing.name, right: true);
      advance(1);
      store.recordTechnique(Technique.xWing.name, right: true);
      expect(stat(store, Technique.xWing).intervalDays, 2);

      store.recordTechnique(Technique.xWing.name, right: false);
      expect(stat(store, Technique.xWing).intervalDays, 1);
      store.recordTechnique(Technique.xWing.name, right: true);
      expect(stat(store, Technique.xWing).intervalDays, 1);
    });

    test('saved data from before reviews is due now', () async {
      SharedPreferences.setMockInitialValues({
        'progress.techniques': '{"xWing":{"right":2,"wrong":1}}',
      });
      final store = await ProgressStore.load(now: clock);

      expect(stat(store, Technique.xWing).lastTried, isNull);
      expect(stat(store, Technique.xWing).isDueOn(day), isTrue);
      expect(dueForReview(store), [Technique.xWing]);
    });

    test('the schedule is remembered between runs', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await ProgressStore.load(now: clock);
      first.recordTechnique(Technique.yWing.name, right: true);
      advance(1);
      first.recordTechnique(Technique.yWing.name, right: true);

      final second = await ProgressStore.load(now: clock);
      expect(stat(second, Technique.yWing).intervalDays, 2);
      expect(stat(second, Technique.yWing).lastTried, '2026-10-11');
    });

    test('a technique never tried is never due', () {
      expect(dueForReview(newStore()), isEmpty);
    });
  });

  group('dueForReview', () {
    test('lists what is due, worst first, and no more than the limit', () {
      final store = newStore();
      for (final t in Technique.values.take(7)) {
        store.recordTechnique(t.name, right: true);
      }
      store.recordTechnique(Technique.hiddenPair.name, right: false);
      advance(1);

      final due = dueForReview(store);

      expect(due, hasLength(reviewLimit));
      expect(due.first, Technique.hiddenPair);
      expect(dueForReview(store, limit: 2), hasLength(2));
    });

    test('leaves out what is not due yet', () {
      final store = newStore()
        ..recordTechnique(Technique.xWing.name, right: true);
      advance(1);
      store.recordTechnique(Technique.xWing.name, right: true);

      expect(dueForReview(store), isEmpty);
      advance(2);
      expect(dueForReview(store), [Technique.xWing]);
    });

    test('counts days overdue', () {
      final store = newStore()
        ..recordTechnique(Technique.xWing.name, right: true);
      advance(1);
      expect(daysOverdue(stat(store, Technique.xWing), day), 0);
      advance(3);
      expect(daysOverdue(stat(store, Technique.xWing), day), 3);
    });
  });

  group('the review card', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(500, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> openPractice(WidgetTester tester, ProgressStore store) async {
      phone(tester);
      await tester.pumpWidget(SudokuApp(store: store));
      await tester.tap(find.text('Practice').last);
      await tester.pumpAndSettle();
    }

    testWidgets('shows what is due and opens a quiz on it', (tester) async {
      final store = newStore()
        ..recordTechnique(Technique.nakedPair.name, right: false);
      advance(1);
      await openPractice(tester, store);

      expect(find.byKey(const Key('review-card')), findsOneWidget);
      expect(find.text('Naked Pair'), findsWidgets);
      expect(find.text('Due today'), findsOneWidget);

      await tester.tap(find.text('Quiz'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-prompt')), findsOneWidget);
    });

    testWidgets('is hidden when nothing is due', (tester) async {
      final store = newStore()
        ..recordTechnique(Technique.nakedPair.name, right: true);
      await openPractice(tester, store);

      expect(find.byKey(const Key('review-card')), findsNothing);
    });

    testWidgets('says how overdue a technique is', (tester) async {
      final store = newStore()
        ..recordTechnique(Technique.nakedPair.name, right: true);
      advance(4);
      await openPractice(tester, store);

      expect(find.text('3 days overdue'), findsOneWidget);
    });
  });
}
