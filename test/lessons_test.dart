import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/lessons/lessons.dart';

void main() {
  test('there is exactly one lesson per technique, easiest first', () {
    expect(lessons.map((l) => l.technique).toSet(), Technique.values.toSet());
    expect(lessons.length, Technique.values.length);
    final levels = lessons.map((l) => l.level).toList();
    expect(levels, [...levels]..sort());
  });

  for (final lesson in lessons) {
    group(lesson.technique.label, () {
      test('example is found by its own technique and changes the board', () {
        final example = lesson.example();
        expect(example.step.technique, lesson.technique);
        expect(
          example.step.placements.isNotEmpty ||
              example.step.eliminations.isNotEmpty,
          isTrue,
        );
        final before = example.board.copy();
        example.board.applyStep(example.step);
        expect(
          example.board.toLine() != before.toLine() ||
              example.board.candidates.toString() !=
                  before.candidates.toString(),
          isTrue,
        );
      });

      test('has text', () {
        expect(lesson.tagline, isNotEmpty);
        expect(lesson.idea, isNotEmpty);
        expect(lesson.spot, isNotEmpty);
      });
    });
  }
}
