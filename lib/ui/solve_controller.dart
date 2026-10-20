import 'package:flutter/foundation.dart';

import '../engine/engine.dart';
import 'hint_ladder.dart';

/// What a digit button does to the selected cell: place the digit, or toggle
/// it as a note (pencil mark).
enum EntryMode { place, notes }

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
        for (var i = 0; i < Board.cellCount; i++)
          if (_start.values[i] != 0) i,
      };

  static const _solver = Solver();

  final Board _start;
  Board _board;

  /// The puzzle's one solution, used to check the player's moves.
  final Board solution;
  final Set<int> givens;

  /// Boards and notes before each change, newest last. [technique] is set
  /// when the change was a solver step the player applied, [note] when it
  /// only edited notes.
  final List<({Board board, List<int> marks, Technique? technique, bool note})>
  _history = [];

  /// The player's own notes: a bit mask of digits per cell, empty at the
  /// start. They are separate from the board's candidates, which the solver
  /// and hints work from.
  List<int> marks = List.filled(Board.cellCount, 0);

  Step? _pending;

  /// Stages of the hint ladder: where to look, which technique, the move.
  static const hintNudge = 1;
  static const hintTechnique = 2;
  static const hintMove = 3;

  int _hintLevel = 0;
  bool _stuck = false;
  bool showCandidates = true;

  int? selected;

  /// Wrong digits the player typed, by cell. They are shown in red and kept
  /// off the board, so the solver and hints keep working. Placing the right
  /// digit, erasing, undo and restart clear them.
  final Map<int, int> wrong = {};

  EntryMode mode = EntryMode.place;
  int mistakes = 0;

  /// Seconds spent on this puzzle. Only changes through [tick].
  final ValueNotifier<int> seconds = ValueNotifier(0);

  /// A digit the player long-pressed on the number pad: tapping cells now
  /// fills them with it, until it is tapped again.
  int? armed;

  /// Cells of the rows, columns and boxes the last placement completed, and a
  /// counter that changes whenever there is a new set to celebrate.
  Set<int> completed = const {};
  int completedSerial = 0;

  /// True while the board is hidden and the clock stopped.
  bool paused = false;
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
      hintNudge => nudgeView(step),
      hintTechnique => patternView(step),
      _ => step,
    };
  }

  /// True after a search found no technique that applies.
  bool get stuck => _stuck;

  bool get solved => _board.isSolved;
  bool get canUndo => _history.isNotEmpty;

  /// Moves made so far, by the player or from solver steps. Note edits do
  /// not count.
  int get moveCount => _history.where((m) => !m.note).length;

  /// Moves and note edits, for knowing when the game needs saving.
  int get changeCount => _history.length;

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
    _hintLevel = _pending == null ? 0 : hintNudge;
    if (_pending != null) hintsUsed++;
    _clearMessage();
    notifyListeners();
  }

  /// Records that the player opened the step-by-step guide, which counts as a
  /// hint.
  void useGuide() {
    hintsUsed++;
    notifyListeners();
  }

  /// Goes one stage up the hint ladder.
  void moreHelp() {
    if (_pending == null || _hintLevel >= hintMove) return;
    _hintLevel++;
    if (_hintLevel == hintMove) movesShown++;
    notifyListeners();
  }

  /// Jumps straight to the full move.
  void showMove() {
    if (_pending == null || _hintLevel >= hintMove) return;
    _hintLevel = hintMove;
    movesShown++;
    notifyListeners();
  }

  void applyPending() {
    final step = _pending;
    if (step == null) return;
    _push(step.technique);
    _board.applyStep(step);
    for (final p in step.placements) {
      _clearMarksAround(p.cell, p.digit);
      _noteCompleted(p.cell);
    }
    for (final e in step.eliminations) {
      for (final d in e.digits) {
        marks[e.cell] &= ~digitBit(d);
      }
    }
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

  /// A tap on the board: selects the cell, and fills it when a digit is armed.
  void tapCell(int cell) {
    select(cell);
    final digit = armed;
    if (digit == null || _board.values[cell] != 0) return;
    if (_board.values.where((v) => v == digit).length >= Board.size) {
      armed = null;
      notifyListeners();
      return;
    }
    enter(digit);
  }

  /// Arms [digit] for filling several cells, or disarms it when it already is.
  void toggleArmed(int digit) {
    armed = armed == digit ? null : digit;
    _clearMessage();
    notifyListeners();
  }

  void select(int cell) {
    selected = cell;
    _clearMessage();
    notifyListeners();
  }

  /// Moves the selection by whole cells, staying on the board.
  void moveSelection(int rowDelta, int columnDelta) {
    final current = selected ?? Board.cellCount ~/ 2; // the centre cell
    final row = (Board.rowOf(current) + rowDelta).clamp(0, Board.size - 1);
    final column = (Board.columnOf(current) + columnDelta).clamp(
      0,
      Board.size - 1,
    );
    select(Board.cellAt(row, column));
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
      _toggleNote(cell, digit);
    }
    notifyListeners();
  }

  /// Clears a wrong digit, or else the notes, from the selected cell.
  void erase() {
    final cell = selected;
    if (cell != null && wrong.remove(cell) != null) {
      _clearMessage();
    } else if (cell != null && _board.values[cell] == 0 && marks[cell] != 0) {
      _push(null, note: true);
      marks[cell] = 0;
      _clearMessage();
    } else {
      _say('Nothing to erase.');
    }
    notifyListeners();
  }

  /// The notes every empty cell would have if filled in automatically.
  List<int> get _allNotes => [
    for (var c = 0; c < Board.cellCount; c++)
      _board.values[c] == 0 ? _board.candidates[c] : 0,
  ];

  /// True when the notes show everything the board allows.
  bool get notesFilled => listEquals(marks, _allNotes);

  /// Toggles the notes: fills them all in, or clears them when they are
  /// already filled in. Either can be undone.
  void toggleAutoNotes() {
    _push(null, note: true);
    marks = notesFilled ? List.filled(Board.cellCount, 0) : _allNotes;
    _clearMessage();
    notifyListeners();
  }

  void _noteCompleted(int cell) {
    final cells = <int>{
      for (final unit in Board.unitsOf(cell))
        if (unit.cells.every((c) => _board.values[c] != 0)) ...unit.cells,
    };
    if (cells.isEmpty) return;
    completed = cells;
    completedSerial++;
  }

  /// Drops [digit] from the notes of [cell] and its peers once it is placed.
  void _clearMarksAround(int cell, int digit) {
    marks[cell] = 0;
    final bit = digitBit(digit);
    for (final peer in Board.peers[cell]) {
      marks[peer] &= ~bit;
    }
  }

  void _place(int cell, int digit) {
    if (!hasDigit(_board.candidates[cell], digit)) {
      mistakes++;
      wrong[cell] = digit;
      _say(_whyNotCandidate(cell, digit), error: true);
      return;
    }
    if (solution.values[cell] != digit) {
      mistakes++;
      wrong[cell] = digit;
      _say(
        'Not $digit. It breaks no rule yet, but the puzzle cannot be '
        'finished with $digit in ${Board.cellName(cell)}.',
        error: true,
      );
      return;
    }
    _push(null);
    _board.place(cell, digit);
    _clearMarksAround(cell, digit);
    _noteCompleted(cell);
    wrong.remove(cell);
    _dropHint();
    _stuck = false;
    _clearMessage();
  }

  /// Notes mode: adds the digit as a note in the cell, or removes it.
  void _toggleNote(int cell, int digit) {
    _push(null, note: true);
    marks[cell] ^= digitBit(digit);
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

  void _push(Technique? technique, {bool note = false}) => _history.add((
    board: _board.copy(),
    marks: List.of(marks),
    technique: technique,
    note: note,
  ));

  void undo() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    _board = last.board;
    marks = last.marks;
    wrong.clear();
    _dropHint();
    _stuck = false;
    _clearMessage();
    notifyListeners();
  }

  void restart() {
    _board = _start.copy();
    marks = List.filled(Board.cellCount, 0);
    seconds.value = 0;
    paused = false;
    armed = null;
    _history.clear();
    wrong.clear();
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
        {
          'board': _encode(move.board),
          'marks': move.marks,
          'note': move.note,
          'technique': move.technique?.name,
        },
    ],
    'marks': marks,
    'seconds': seconds.value,
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
      for (final entry in json['history']! as List<Object?>)
        if (entry! as Map<String, Object?> case final move)
          (
            board: controller._decode(move['board']),
            marks: _decodeMarks(move['marks']),
            note: move['note'] == true,
            technique: switch (move['technique']) {
              null => null,
              final String name => Technique.values.byName(name),
              _ => throw const FormatException('Bad technique'),
            },
          ),
    ];
    controller
      .._board = board
      ..marks = _decodeMarks(json['marks'])
      .._history.addAll(history)
      ..seconds.value = json['seconds'] as int? ?? 0
      ..mistakes = json['mistakes']! as int
      ..hintsUsed = json['hintsUsed']! as int
      ..movesShown = json['movesShown']! as int;
    return controller;
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
    for (var i = 0; i < Board.cellCount; i++) {
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

  /// Adds a second to the clock, unless paused or solved.
  void tick() {
    if (!paused && !solved) seconds.value++;
  }

  void togglePause() {
    if (solved) return;
    paused = !paused;
    notifyListeners();
  }

  @override
  void dispose() {
    seconds.dispose();
    super.dispose();
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
