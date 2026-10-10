import 'package:flutter/foundation.dart';

import '../engine/engine.dart';
import 'hint_ladder.dart';

/// What a digit button does to the selected cell.
enum EntryMode { place, remove }

/// State of one puzzle session: the board, the player's moves, hints from the
/// solver, and history for undo.
///
/// The board always stays consistent with the puzzle's unique solution. A
/// digit that cannot be right is rejected with an explanation and counted as
/// a mistake, so the solver can still be asked for a hint at any point.
class SolveController extends ChangeNotifier {
  SolveController(String puzzleText) : this._(Board.parse(puzzleText));

  SolveController._(this._start)
    : _board = _start.copy(),
      solution = solveByBacktracking(_start)!,
      givens = {
        for (var i = 0; i < 81; i++)
          if (_start.values[i] != 0) i,
      };

  static const _solver = Solver();

  final Board _start;
  Board _board;

  /// The puzzle's one solution, used to check the player's moves.
  final Board solution;
  final Set<int> givens;

  /// Boards before each move, newest last. [technique] is set when the move
  /// was a solver step the player applied.
  final List<({Board board, Technique? technique})> _history = [];

  Step? _pending;
  int _hintLevel = 0;
  bool _stuck = false;
  bool showCandidates = true;

  int? selected;
  EntryMode mode = EntryMode.place;
  int mistakes = 0;
  int hintsUsed = 0;

  /// Hints that went all the way to showing the move.
  int movesShown = 0;

  /// Feedback for the last action, or null.
  String? message;
  bool messageIsError = false;

  Board get board => _board;

  /// The step the hint ladder is on, but not yet applied.
  Step? get pending => _pending;

  /// How far up the hint ladder the player is: 0 none, 1 where to look,
  /// 2 which technique, 3 the full move.
  int get hintLevel => _hintLevel;

  /// What the board should draw for the current hint stage.
  Step? get shown {
    final step = _pending;
    if (step == null) return null;
    return switch (_hintLevel) {
      1 => nudgeView(step),
      2 => patternView(step),
      _ => step,
    };
  }

  /// True after a search found no technique that applies.
  bool get stuck => _stuck;

  bool get solved => _board.isSolved;
  bool get canUndo => _history.isNotEmpty;

  /// Moves made so far, by the player or from solver steps.
  int get moveCount => _history.length;

  /// Techniques of the solver steps the player applied, oldest first.
  List<Technique> get applied => [
    for (final move in _history)
      if (move.technique != null) move.technique!,
  ];

  /// Looks for the next step and starts the hint ladder at stage 1. Counts as
  /// a hint.
  void findNextStep() {
    if (solved) return;
    _pending = _solver.nextStep(_board);
    _stuck = _pending == null;
    _hintLevel = _pending == null ? 0 : 1;
    if (_pending != null) hintsUsed++;
    _clearMessage();
    notifyListeners();
  }

  /// Goes one stage up the hint ladder.
  void moreHelp() {
    if (_pending == null || _hintLevel >= 3) return;
    _hintLevel++;
    if (_hintLevel == 3) movesShown++;
    notifyListeners();
  }

  /// Jumps straight to the full move.
  void showMove() {
    if (_pending == null || _hintLevel >= 3) return;
    _hintLevel = 3;
    movesShown++;
    notifyListeners();
  }

  void applyPending() {
    final step = _pending;
    if (step == null) return;
    _push(step.technique);
    _board.applyStep(step);
    _dropHint();
    notifyListeners();
  }

  void dismissPending() {
    _dropHint();
    notifyListeners();
  }

  void _dropHint() {
    _pending = null;
    _hintLevel = 0;
  }

  void select(int cell) {
    selected = cell;
    _clearMessage();
    notifyListeners();
  }

  /// Moves the selection by whole cells, staying on the board.
  void moveSelection(int rowDelta, int columnDelta) {
    final current = selected ?? 40;
    final row = (Board.rowOf(current) + rowDelta).clamp(0, 8);
    final column = (Board.columnOf(current) + columnDelta).clamp(0, 8);
    select(row * 9 + column);
  }

  void setMode(EntryMode value) {
    mode = value;
    _clearMessage();
    notifyListeners();
  }

  /// Applies a digit button press to the selected cell.
  void enter(int digit) {
    final cell = selected;
    if (cell == null) {
      _say('Tap a cell first.');
    } else if (_board.values[cell] != 0) {
      _say(
        givens.contains(cell)
            ? 'That cell is a given.'
            : 'That cell is already filled.',
      );
    } else if (mode == EntryMode.place) {
      _place(cell, digit);
    } else {
      _remove(cell, digit);
    }
    notifyListeners();
  }

  void _place(int cell, int digit) {
    if (!hasDigit(_board.candidates[cell], digit)) {
      mistakes++;
      _say(_whyNotCandidate(cell, digit), error: true);
      return;
    }
    if (solution.values[cell] != digit) {
      mistakes++;
      _say(
        'Not $digit. It breaks no rule yet, but the puzzle cannot be '
        'finished with $digit in ${Board.cellName(cell)}.',
        error: true,
      );
      return;
    }
    _push(null);
    _board.place(cell, digit);
    _dropHint();
    _stuck = false;
    _clearMessage();
  }

  void _remove(int cell, int digit) {
    if (!hasDigit(_board.candidates[cell], digit)) {
      _say('$digit is not a candidate in ${Board.cellName(cell)}.');
      return;
    }
    if (solution.values[cell] == digit) {
      mistakes++;
      _say(
        'Not safe: removing $digit from ${Board.cellName(cell)} would make '
        'the puzzle impossible.',
        error: true,
      );
      return;
    }
    _push(null);
    _board.eliminate(cell, digit);
    _dropHint();
    _stuck = false;
    _clearMessage();
  }

  String _whyNotCandidate(int cell, int digit) {
    for (final unit in Board.unitsOf(cell)) {
      if (unit.cells.any((c) => _board.values[c] == digit)) {
        return 'There is already a $digit in ${unit.name}.';
      }
    }
    return 'You already ruled out $digit in ${Board.cellName(cell)}.';
  }

  void _push(Technique? technique) =>
      _history.add((board: _board.copy(), technique: technique));

  void undo() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    _board = last.board;
    _dropHint();
    _stuck = false;
    _clearMessage();
    notifyListeners();
  }

  void restart() {
    _board = _start.copy();
    _history.clear();
    _dropHint();
    _stuck = false;
    selected = null;
    mistakes = 0;
    hintsUsed = 0;
    movesShown = 0;
    _clearMessage();
    notifyListeners();
  }

  /// Everything needed to resume this session later.
  Map<String, Object?> toJson() => {
    'board': _encode(_board),
    'history': [
      for (final move in _history)
        {'board': _encode(move.board), 'technique': move.technique?.name},
    ],
    'mistakes': mistakes,
    'hintsUsed': hintsUsed,
    'movesShown': movesShown,
  };

  /// Resumes a session saved by [toJson]. Throws if the data is malformed or
  /// does not fit the puzzle, so callers can fall back to a fresh start.
  factory SolveController.restore(
    String puzzleText,
    Map<String, Object?> json,
  ) {
    final controller = SolveController(puzzleText);
    final board = controller._decode(json['board']);
    final history = [
      for (final move in json['history']! as List<Object?>)
        (
          board: controller._decode((move! as Map<String, Object?>)['board']),
          technique: switch ((move as Map<String, Object?>)['technique']) {
            null => null,
            final String name => Technique.values.byName(name),
            _ => throw const FormatException('Bad technique'),
          },
        ),
    ];
    controller
      .._board = board
      .._history.addAll(history)
      ..mistakes = json['mistakes']! as int
      ..hintsUsed = json['hintsUsed']! as int
      ..movesShown = json['movesShown']! as int;
    return controller;
  }

  static Map<String, Object?> _encode(Board board) => {
    'values': board.values,
    'candidates': board.candidates,
  };

  /// Reads a board and checks it agrees with the puzzle and its solution.
  Board _decode(Object? data) {
    final map = data! as Map<String, Object?>;
    final board = Board.fromState(
      (map['values']! as List<Object?>).cast<int>(),
      (map['candidates']! as List<Object?>).cast<int>(),
    );
    for (var i = 0; i < 81; i++) {
      final value = board.values[i];
      if (givens.contains(i) && value != _start.values[i]) {
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

  void toggleCandidates() {
    showCandidates = !showCandidates;
    notifyListeners();
  }

  void _say(String text, {bool error = false}) {
    message = text;
    messageIsError = error;
  }

  void _clearMessage() {
    message = null;
    messageIsError = false;
  }
}
