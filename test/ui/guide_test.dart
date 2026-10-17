import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/ui/solve_screen.dart';

import '../support.dart';

void main() {
  testWidgets(
    'the guide explains the puzzle, costs a hint and pauses the clock',
    (tester) async {
      tester.view.physicalSize = const Size(500, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(SolveScreen(puzzle: warmUp)));

      await tester.tap(find.byTooltip('Step-by-step guide'));
      await tester.pumpAndSettle();
      expect(find.text('Open the step-by-step guide?'), findsOneWidget);
      await tester.tap(find.text('Not yet'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pause'), findsOneWidget);

      await tester.tap(find.byTooltip('Step-by-step guide'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show me'));
      await tester.pumpAndSettle();
      expect(find.text('Guide: Warm-up'), findsOneWidget);
      expect(find.textContaining('Step 1 of'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      // The second time there is no warning.
      await tester.tap(find.byTooltip('Step-by-step guide'));
      await tester.pumpAndSettle();
      expect(find.text('Guide: Warm-up'), findsOneWidget);
    },
  );
}
