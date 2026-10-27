import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/app.dart';

void main() {
  testWidgets('app starts on the puzzle picker', (tester) async {
    await tester.pumpWidget(SudokuApp(store: ProgressStore.memory()));
    expect(find.text('Sudoku Technique Teacher'), findsOneWidget);
    expect(find.text('Level 1 · Beginner'), findsOneWidget);
    // Learn tab first: the next-up card and the lesson tile.
    expect(find.text('Full House'), findsNWidgets(2));
  });
}
