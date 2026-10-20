import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/board_view.dart';
import 'package:sudoku_solver/ui/quiz.dart';
import 'package:sudoku_solver/ui/quiz_screen.dart';
import 'package:sudoku_solver/ui/walkthrough_screen.dart';

import '../support.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> tapCell(WidgetTester tester, int cell) async {
    final box = find.byType(BoardView);
    final size = tester.getSize(box).width / 9;
    await tester.tapAt(
      tester.getTopLeft(box) +
          Offset(
            (Board.columnOf(cell) + 0.5) * size,
            (Board.rowOf(cell) + 0.5) * size,
          ),
    );
    await tester.pump();
  }

  void record(ProgressStore store, Technique t, int right, int wrong) {
    for (var i = 0; i < right; i++) {
      store.recordTechnique(t.name, right: true);
    }
    for (var i = 0; i < wrong; i++) {
      store.recordTechnique(t.name, right: false);
    }
  }

  group('what gets recorded', () {
    testWidgets('quiz answers count for the technique asked about', (
      tester,
    ) async {
      phone(tester);
      final store = ProgressStore.memory();
      await tester.pumpWidget(
        testApp(
          const QuizScreen(technique: Technique.nakedSingle),
          store: store,
        ),
      );
      final q = quizQuestions(Technique.nakedSingle);

      await tapCell(tester, q[0].targets.first); // right
      await tester.tap(find.byKey(const Key('quiz-next')));
      await tester.pump();
      final wrong = List.generate(
        81,
        (i) => i,
      ).firstWhere((c) => !q[1].targets.contains(c));
      await tapCell(tester, wrong); // wrong

      final stat = store.techniqueStats[Technique.nakedSingle.name]!;
      expect(stat.right, 1);
      expect(stat.wrong, 1);
    });

    testWidgets('Your turn: first try is right, Show me is not', (
      tester,
    ) async {
      phone(tester);
      final store = ProgressStore.memory();
      final start = Board.parse(warmUp.text);
      final steps = <Step>[];
      final board = start.copy();
      const solver = Solver();
      for (
        var s = solver.nextStep(board);
        s != null && steps.length < 2;
        s = solver.nextStep(board)
      ) {
        steps.add(s);
        board.applyStep(s);
      }

      await tester.pumpWidget(
        testApp(WalkthroughScreen(start: start), store: store),
      );
      await tester.tap(find.byKey(const Key('mode-play')));
      await tester.pump();

      final p = steps.first.placements.first;
      await tapCell(tester, p.cell);
      await tester.tap(find.byKey(Key('play-digit-${p.digit}')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('next-step')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('show-me')));
      await tester.pump();

      int right(Technique t) => store.techniqueStats[t.name]?.right ?? 0;
      int wrong(Technique t) => store.techniqueStats[t.name]?.wrong ?? 0;
      final first = steps[0].technique;
      final second = steps[1].technique;
      expect(right(first), greaterThanOrEqualTo(1));
      expect(wrong(second), greaterThanOrEqualTo(1));
    });

    testWidgets('a miss then Show me counts once, as wrong', (tester) async {
      phone(tester);
      final store = ProgressStore.memory();
      final start = Board.parse(warmUp.text);
      final first = const Solver().nextStep(start)!;
      final target = first.placements.first;

      await tester.pumpWidget(
        testApp(WalkthroughScreen(start: start), store: store),
      );
      await tester.tap(find.byKey(const Key('mode-play')));
      await tester.pump();
      await tapCell(tester, target.cell);
      await tester.tap(
        find.byKey(Key('play-digit-${target.digit == 1 ? 2 : 1}')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('show-me')));
      await tester.pump();

      final stat = store.techniqueStats[first.technique.name]!;
      expect(stat.attempts, 1);
      expect(stat.wrong, 1);
    });
  });

  group('where weak spots show', () {
    testWidgets('the Statistics screen lists techniques and what to revisit', (
      tester,
    ) async {
      phone(tester);
      final store = ProgressStore.memory();
      record(store, Technique.nakedPair, 1, 3);
      record(store, Technique.yWing, 5, 0);
      await tester.pumpWidget(SudokuApp(store: store));
      await tester.tap(find.byTooltip('Progress options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();

      expect(find.text('Techniques'), findsOneWidget);
      expect(find.byKey(const Key('weak-spots')), findsOneWidget);
      expect(find.textContaining('Worth revisiting: Naked Pair'), findsOne);
      expect(find.byKey(const Key('stat-nakedPair')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('stat-nakedPair'))).data,
        '1/4',
      );
    });

    testWidgets('no section until a technique has been tried', (tester) async {
      phone(tester);
      await tester.pumpWidget(SudokuApp(store: ProgressStore.memory()));
      await tester.tap(find.byTooltip('Progress options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();
      expect(find.text('Techniques'), findsNothing);
    });

    testWidgets('the Learn tab links to the weak technique', (tester) async {
      phone(tester);
      final store = ProgressStore.memory()..unlockAllLevels();
      record(store, Technique.hiddenPair, 0, 3);
      await tester.pumpWidget(SudokuApp(store: store));
      expect(find.byKey(const Key('revisit')), findsOneWidget);

      await tester.tap(find.byKey(const Key('revisit-hiddenPair')));
      await tester.pumpAndSettle();
      expect(find.text('The idea'), findsOneWidget);
    });

    testWidgets('the Learn tab has no banner when all is well', (tester) async {
      phone(tester);
      final store = ProgressStore.memory();
      record(store, Technique.hiddenPair, 5, 0);
      await tester.pumpWidget(SudokuApp(store: store));
      expect(find.byKey(const Key('revisit')), findsNothing);
    });
  });

  group('fresh boards', () {
    testWidgets('start a new round after the last question', (tester) async {
      phone(tester);
      var asked = 0;
      await tester.pumpWidget(
        testApp(
          QuizScreen(
            technique: Technique.nakedSingle,
            freshQuestions: (isCancelled) async {
              asked++;
              return quizQuestions(Technique.nakedSingle, max: 2);
            },
          ),
        ),
      );
      final total = quizQuestions(Technique.nakedSingle).length;
      for (var i = 0; i < total; i++) {
        await tapCell(
          tester,
          quizQuestions(Technique.nakedSingle)[i].targets.first,
        );
        await tester.tap(find.byKey(const Key('quiz-next')));
        await tester.pump();
      }

      await tester.tap(find.byKey(const Key('quiz-more')));
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(
        find.textContaining(
          'Round 2 · Question 1 of '
          '${quizQuestions(Technique.nakedSingle, max: 2).length}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('say so when nothing is found', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        testApp(
          QuizScreen(
            technique: Technique.nakedSingle,
            freshQuestions: (isCancelled) async => null,
          ),
        ),
      );
      final total = quizQuestions(Technique.nakedSingle).length;
      for (var i = 0; i < total; i++) {
        await tapCell(
          tester,
          quizQuestions(Technique.nakedSingle)[i].targets.first,
        );
        await tester.tap(find.byKey(const Key('quiz-next')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('quiz-more')));
      await tester.pumpAndSettle();
      expect(find.textContaining('No fresh boards this time'), findsOneWidget);
      expect(find.byKey(const Key('quiz-score')), findsOneWidget);
    });
  });

  group('practise a technique', () {
    Future<void> openPractice(WidgetTester tester, ProgressStore store) async {
      await tester.pumpWidget(SudokuApp(store: store));
      await tester.tap(find.text('Practice'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists only techniques from unlocked levels', (tester) async {
      phone(tester);
      await openPractice(tester, ProgressStore.memory());
      await tester.tap(find.byKey(const Key('technique-picker')));
      await tester.pumpAndSettle();
      expect(find.text('Naked Single').hitTestable(), findsWidgets);
      expect(find.text('X-Wing'), findsNothing);
      expect(find.text('Full House'), findsNothing);
    });

    testWidgets('opens a puzzle built around the choice', (tester) async {
      phone(tester);
      final store = ProgressStore.memory();
      await openPractice(tester, store);

      await tester.tap(find.byKey(const Key('technique-puzzle')));
      await tester.pump();
      final title = find.text('Naked Single puzzle');
      for (var i = 0; i < 400 && title.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      expect(store.hasSavedGame('technique'), isFalse);
    });
  });
}
