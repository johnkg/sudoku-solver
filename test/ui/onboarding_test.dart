import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/settings/settings.dart';
import 'package:sudoku_solver/ui/app.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> start(
    WidgetTester tester,
    Settings settings, {
    bool showIntro = true,
    List<int>? initialPuzzle,
  }) async {
    phone(tester);
    await tester.pumpWidget(
      SudokuApp(
        store: ProgressStore.memory(),
        settings: settings,
        showIntro: showIntro,
        initialPuzzle: initialPuzzle,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the intro walks through its pages and is remembered', (
    tester,
  ) async {
    final settings = Settings.memory();
    await start(tester, settings);

    expect(find.text('Solve like a person, not a computer'), findsOneWidget);
    await tester.tap(find.byKey(const Key('intro-next')));
    await tester.pumpAndSettle();
    expect(find.text('Learn a trick, then use it'), findsOneWidget);
    await tester.tap(find.byKey(const Key('intro-next')));
    await tester.pumpAndSettle();
    expect(find.text('Stuck? Ask for a hint'), findsOneWidget);
    expect(find.text('Start learning'), findsOneWidget);
    expect(settings.introSeen, isFalse);

    await tester.tap(find.byKey(const Key('intro-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('intro-next')), findsNothing);
    expect(settings.introSeen, isTrue);
    expect(find.text('Learn'), findsWidgets);
  });

  testWidgets('skipping also remembers it', (tester) async {
    final settings = Settings.memory();
    await start(tester, settings);

    await tester.tap(find.byKey(const Key('intro-skip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('intro-skip')), findsNothing);
    expect(settings.introSeen, isTrue);
  });

  testWidgets('swiping moves between pages', (tester) async {
    await start(tester, Settings.memory());

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Learn a trick, then use it'), findsOneWidget);
  });

  testWidgets('it is not shown unless asked for', (tester) async {
    await start(tester, Settings.memory(), showIntro: false);

    expect(find.byKey(const Key('intro-next')), findsNothing);
  });

  testWidgets('a shared puzzle link goes straight to the Solver', (
    tester,
  ) async {
    await start(tester, Settings.memory(), initialPuzzle: List.filled(81, 0));

    expect(find.byKey(const Key('intro-next')), findsNothing);
    expect(find.byKey(const Key('teach-me')), findsOneWidget);
  });

  testWidgets('Settings can show it again', (tester) async {
    final settings = Settings.memory()..introSeen = true;
    await start(tester, settings, showIntro: false);

    await tester.tap(find.byTooltip('Progress options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-intro')));
    await tester.pumpAndSettle();

    expect(find.text('Solve like a person, not a computer'), findsOneWidget);
  });
}
