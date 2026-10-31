import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';

import '../engine/engine.dart';
import '../scan/photo_scan.dart';
import '../scan/scan_result.dart';
import '../util/text.dart';
import 'board_view.dart';
import 'board_with_panel.dart';
import 'confirm_dialog.dart';
import 'digit_keys.dart';
import 'navigation.dart';
import 'puzzle_library.dart';
import 'puzzle_link.dart';
import 'solve_screen.dart';
import 'solver/entry_controls.dart';
import 'solver/import_dialog.dart';
import 'solver/puzzle_text.dart';
import 'solver/scan_photo.dart';
import 'walkthrough_screen.dart';

/// How far each arrow key moves the selected cell, in cells.
final _arrowMoves = {
  LogicalKeyboardKey.arrowLeft: -1,
  LogicalKeyboardKey.arrowRight: 1,
  LogicalKeyboardKey.arrowUp: -Board.size,
  LogicalKeyboardKey.arrowDown: Board.size,
};

/// A blank grid to type any puzzle into, then a button to be taught how to
/// solve it.
class SolverTab extends StatefulWidget {
  const SolverTab({super.key, this.scanner, this.initialCells, this.baseUri});

  /// Digits to start with, such as from a shared link.
  final List<int>? initialCells;

  /// The page's address, which share links are built from. Defaults to the
  /// browser's current address.
  final Uri? baseUri;

  /// Reads a puzzle from a photo. Defaults to the browser's reader where one
  /// exists; tests pass their own.
  final PhotoScanner? scanner;

  @override
  State<SolverTab> createState() => _SolverTabState();
}

class _SolverTabState extends State<SolverTab> {
  final cells = List.filled(Board.cellCount, 0);
  final focus = FocusNode();
  int? selected;

  /// Cells read from a photo that the reader was unsure about.
  Set<int> doubtful = {};
  String? note;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCells;
    if (initial != null) {
      cells.setAll(0, initial);
      note = 'Loaded the puzzle from the link.';
    }
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  /// Entered digits that share a row, column or box with the same digit.
  Set<int> get clashing => {
    for (var c = 0; c < Board.cellCount; c++)
      if (cells[c] != 0 && Board.peers[c].any((p) => cells[p] == cells[c])) c,
  };

  int get filled => cells.where((v) => v != 0).length;

  PhotoScanner? get _scanner =>
      widget.scanner ?? (photoScanSupported ? scanPuzzlePhoto : null);

  /// Replaces the grid with [newCells] and forgets what was selected or
  /// doubted.
  void _replaceGrid(List<int> newCells, {Set<int> unsure = const {}}) {
    cells.setAll(0, newCells);
    selected = null;
    doubtful = {...unsure};
    note = null;
  }

  void _enter(int digit) {
    final cell = selected;
    if (cell == null) return;
    setState(() {
      cells[cell] = digit;
      doubtful.remove(cell);
      note = null;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    final digit = digitOfKey(key);
    if (digit != null) {
      _enter(digit);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete ||
        key.keyLabel == '0') {
      _enter(0);
      return KeyEventResult.handled;
    }
    final move = _arrowMoves[key];
    if (move == null) return KeyEventResult.ignored;
    _moveSelection(move);
    return KeyEventResult.handled;
  }

  /// Moves the selection by [move] cells, but not off the grid or round the
  /// end of a row. With nothing selected it selects the first cell.
  void _moveSelection(int move) {
    final from = selected;
    if (from == null) return setState(() => selected = 0);

    final to = from + move;
    final wrapsRow = move.abs() == 1 && Board.rowOf(to) != Board.rowOf(from);
    if (to >= 0 && to < Board.cellCount && !wrapsRow) {
      setState(() => selected = to);
    }
  }

  Future<void> _clear() async {
    if (filled > 0) {
      final ok = await confirm(
        context,
        title: 'Clear the grid?',
        confirmLabel: 'Clear',
      );
      if (!ok) return;
    }
    setState(() => _replaceGrid(List.filled(Board.cellCount, 0)));
  }

  Future<void> _import() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const ImportDialog(),
    );
    final parsed = text == null ? null : parsePuzzleText(text);
    if (parsed == null) return;
    setState(() => _replaceGrid(parsed));
  }

  Future<void> _scan() async {
    ScanResult? result;
    try {
      result = await scanPhotoWithDialog(context, _scanner!);
    } on ScanFailure catch (e) {
      if (mounted) _say(e.message);
      return;
    }
    if (!mounted) return;

    final parsed = result == null ? null : parsePuzzleText(result.text);
    if (parsed == null) return;
    final found = parsed.where((v) => v != 0).length;
    if (found == 0) return _say('I could not see any digits in that photo.');
    final unsure = result!.uncertain;
    setState(() {
      _replaceGrid(parsed, unsure: unsure);
      note = unsure.isEmpty
          ? 'Read $found digits. Check each one against your photo.'
          : 'Read $found digits. The tinted cells are ones I was unsure '
                'about. Check every digit against your photo.';
    });
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The typed puzzle and how many solutions it has, or null after telling
  /// the player why it cannot be used: nothing typed, a digit that breaks a
  /// rule, or no solution.
  ({Board board, int solutions})? _checkedPuzzle() {
    if (filled == 0) {
      _say('Enter a puzzle first.');
    } else if (clashing.isNotEmpty) {
      _say('Fix the red digits first.');
    } else {
      final board = Board.parse(cells.map((v) => '$v').join());
      final solutions = countSolutions(board);
      if (solutions > 0) return (board: board, solutions: solutions);
      _say('This puzzle has no solution. Check the digits you entered.');
    }
    return null;
  }

  Future<void> _teach() async {
    final puzzle = _checkedPuzzle();
    if (puzzle == null) return;

    if (puzzle.solutions > 1) {
      final go = await confirm(
        context,
        title: 'More than one solution',
        message:
            'A proper Sudoku has exactly one solution, so this puzzle may be '
            'missing some digits. I can still show how far logic gets.',
        cancelLabel: 'Keep editing',
        confirmLabel: 'Show me anyway',
      );
      if (!go || !mounted) return;
    }
    await pushScreen(context, (_) => WalkthroughScreen(start: puzzle.board));
  }

  Future<void> _copyLink() async {
    final link = puzzleLink(widget.baseUri ?? Uri.base, cells);
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (mounted) _say('Link copied. Anyone who opens it gets this puzzle.');
  }

  /// Opens the entered puzzle in the normal solve screen, with notes, hints
  /// and a clock. Needs exactly one solution so mistakes can be told apart.
  Future<void> _play() async {
    final puzzle = _checkedPuzzle();
    if (puzzle == null) return;
    if (puzzle.solutions > 1) {
      return _say(
        'To play it, the puzzle needs exactly one solution. Check that every '
        'given is entered.',
      );
    }

    final entry = PuzzleEntry(
      id: 'custom',
      title: 'My puzzle',
      text: puzzle.board.toDigits(),
      technique: ratePuzzle(puzzle.board).required ?? Technique.values.last,
    );
    await pushScreen(
      context,
      (_) => SolveScreen(puzzle: entry, recordProgress: false),
    );
  }

  String _statusText({required bool hasClash}) {
    if (hasClash) {
      return 'Red digits break a rule: the same digit twice in a row, column '
          'or box.';
    }
    if (note != null) return note!;
    return filled == 0
        ? 'Tap a cell, then a digit, to type in your puzzle.'
        : '${plural(filled, 'digit')} entered.';
  }

  @override
  Widget build(BuildContext context) {
    final bad = clashing;
    // Clashing digits are drawn as mistakes, not as part of the board.
    final board = Board.fromState([
      for (var c = 0; c < Board.cellCount; c++) bad.contains(c) ? 0 : cells[c],
    ], List.filled(Board.cellCount, 0));

    return Focus(
      focusNode: focus,
      onKeyEvent: _onKey,
      child: BoardWithPanel(
        board: BoardView(
          board: board,
          givens: {
            for (var c = 0; c < Board.cellCount; c++)
              if (cells[c] != 0) c,
          },
          showCandidates: false,
          selected: selected,
          marked: doubtful,
          wrong: {for (final c in bad) c: cells[c]},
          onCellTap: (c) {
            focus.requestFocus();
            setState(() => selected = c);
          },
        ),
        panel: PuzzleEntryControls(
          status: _statusText(hasClash: bad.isNotEmpty),
          statusIsError: bad.isNotEmpty,
          hasSelection: selected != null,
          hasDigits: filled > 0,
          canCopyLink: filled > 0 && bad.isEmpty,
          canScan: _scanner != null,
          onDigit: _enter,
          onPaste: _import,
          onClear: _clear,
          onScan: _scan,
          onCopyLink: _copyLink,
          onTeach: _teach,
          onPlay: _play,
        ),
      ),
    );
  }
}
