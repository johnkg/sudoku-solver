import '../engine/engine.dart';

/// A board and notes as they were before one change, so it can be undone.
/// [technique] is set when the change was a solver step the player applied,
/// [note] when it only edited notes.
typedef Move = ({
  Board board,
  List<int> marks,
  Technique? technique,
  bool note,
});

/// A solve session as it is stored between visits.
class SavedGame {
  const SavedGame({
    required this.board,
    required this.history,
    required this.marks,
    required this.seconds,
    required this.mistakes,
    required this.hintsUsed,
    required this.movesShown,
  });

  final Board board;
  final List<Move> history;
  final List<int> marks;
  final int seconds;
  final int mistakes;
  final int hintsUsed;
  final int movesShown;

  Map<String, Object?> toJson() => {
    'board': _encodeBoard(board),
    'history': [
      for (final move in history)
        {
          'board': _encodeBoard(move.board),
          'marks': move.marks,
          'note': move.note,
          'technique': move.technique?.name,
        },
    ],
    'marks': marks,
    'seconds': seconds,
    'mistakes': mistakes,
    'hintsUsed': hintsUsed,
    'movesShown': movesShown,
  };

  /// Reads a game saved by [toJson] for the puzzle that starts at [start]
  /// and has [solution]. Throws if the data is malformed or does not fit the
  /// puzzle, so callers can fall back to a fresh start.
  factory SavedGame.fromJson(
    Map<String, Object?> json, {
    required Board start,
    required Board solution,
  }) {
    Board decodeBoard(Object? data) =>
        _decodeBoard(data, start: start, solution: solution);

    return SavedGame(
      board: decodeBoard(json['board']),
      history: [
        for (final entry in json['history']! as List<Object?>)
          if (entry! as Map<String, Object?> case final move)
            (
              board: decodeBoard(move['board']),
              marks: _decodeMarks(move['marks']),
              note: move['note'] == true,
              technique: switch (move['technique']) {
                null => null,
                final String name => Technique.values.byName(name),
                _ => throw const FormatException('Bad technique'),
              },
            ),
      ],
      marks: _decodeMarks(json['marks']),
      seconds: json['seconds'] as int? ?? 0,
      mistakes: json['mistakes']! as int,
      hintsUsed: json['hintsUsed']! as int,
      movesShown: json['movesShown']! as int,
    );
  }

  static Map<String, Object?> _encodeBoard(Board board) => {
    'values': board.values,
    'candidates': board.candidates,
  };

  /// Reads a board and checks it agrees with the puzzle and its solution.
  static Board _decodeBoard(
    Object? data, {
    required Board start,
    required Board solution,
  }) {
    final map = data! as Map<String, Object?>;
    final board = Board.fromState(
      (map['values']! as List<Object?>).cast<int>(),
      (map['candidates']! as List<Object?>).cast<int>(),
    );
    for (var i = 0; i < Board.cellCount; i++) {
      final value = board.values[i];
      if (start.values[i] != 0 && value != start.values[i]) {
        throw const FormatException('Saved board changes a given');
      }
      if (value != 0 && value != solution.values[i]) {
        throw const FormatException('Saved board has a wrong digit');
      }
      if (value == 0 && !hasDigit(board.candidates[i], solution.values[i])) {
        throw const FormatException('Saved board lost the right candidate');
      }
    }
    return board;
  }

  /// Notes saved before notes existed are empty.
  static List<int> _decodeMarks(Object? data) {
    if (data == null) return List.filled(Board.cellCount, 0);
    final list = (data as List<Object?>).cast<int>();
    if (list.length != Board.cellCount ||
        list.any((m) => m < 0 || m > allDigitsMask)) {
      throw const FormatException('Bad notes');
    }
    return List.of(list);
  }
}
