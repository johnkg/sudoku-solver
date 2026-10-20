import '../engine/engine.dart';
import '../lessons/lessons.dart';
import 'puzzle_library.dart';

/// A board where [step] is available, for the player to spot.
class QuizQuestion {
  QuizQuestion(this.board, this.step);

  final Board board;
  final Step step;

  /// Whether the answer is the one cell the technique fills.
  bool get placesDigit => step.placements.isNotEmpty;

  /// The cells to tap: the cell it fills, or the cells forming the pattern.
  Set<int> get targets => placesDigit
      ? {for (final p in step.placements) p.cell}
      : step.highlightCells.toSet();
}

/// Questions in one round of a quiz.
const questionsPerRound = 5;

/// A round with fewer library questions than this also gets the lesson's own
/// example.
const _minLibraryQuestions = 3;

/// Up to [max] questions about [technique]: the first moment each library
/// puzzle needs it, then the lesson's own example if there are too few.
List<QuizQuestion> quizQuestions(
  Technique technique, {
  int max = questionsPerRound,
}) {
  const solver = Solver();
  final questions = <QuizQuestion>[];

  for (final puzzle in puzzleLibrary) {
    if (questions.length >= max) break;
    final board = Board.parse(puzzle.text);
    for (
      var step = solver.nextStep(board);
      step != null;
      step = solver.nextStep(board)
    ) {
      if (step.technique == technique) {
        questions.add(QuizQuestion(board.copy(), step));
        break;
      }
      board.applyStep(step);
    }
  }

  if (questions.length < _minLibraryQuestions) {
    final example = lessonFor(technique).example();
    questions.add(QuizQuestion(example.board, example.step));
  }
  return questions;
}
