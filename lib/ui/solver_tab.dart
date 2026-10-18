import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';

import '../engine/engine.dart';
import '../scan/photo_scan.dart';
import '../scan/scan_result.dart';
import 'board_view.dart';
import 'walkthrough_screen.dart';

/// Turns text into 81 cells, or null if it is not a puzzle. Digits are
/// givens; `0`, `.`, `-`, `_` and `*` are blanks; whitespace is ignored.
List<int>? parsePuzzleText(String text) {
  final chars = text.replaceAll(RegExp(r'\s'), '');
  if (chars.length != 81 || !RegExp(r'^[0-9.\-_*]+$').hasMatch(chars)) {
    return null;
  }
  return [for (final ch in chars.split('')) int.tryParse(ch) ?? 0];
}

/// A blank grid to type any puzzle into, then a button to be taught how to
/// solve it.
class SolverTab extends StatefulWidget {
  const SolverTab({super.key, this.scanner});

  /// Reads a puzzle from a photo. Defaults to the browser's reader where one
  /// exists; tests pass their own.
  final PhotoScanner? scanner;

  @override
  State<SolverTab> createState() => _SolverTabState();
}

class _SolverTabState extends State<SolverTab> {
  final cells = List.filled(81, 0);
  final focus = FocusNode();
  int? selected;

  /// Cells read from a photo that the reader was unsure about.
  Set<int> doubtful = {};
  String? scanNote;

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  /// Entered digits that share a row, column or box with the same digit.
  Set<int> get clashing => {
    for (var c = 0; c < 81; c++)
      if (cells[c] != 0 && Board.peers[c].any((p) => cells[p] == cells[c])) c,
  };

  int get filled => cells.where((v) => v != 0).length;

  void _enter(int digit) {
    final cell = selected;
    if (cell == null) return;
    setState(() {
      cells[cell] = digit;
      doubtful.remove(cell);
      scanNote = null;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final label = key.keyLabel;
    if (label.length == 1 && '123456789'.contains(label)) {
      _enter(int.parse(label));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete ||
        label == '0') {
      _enter(0);
      return KeyEventResult.handled;
    }
    final move = {
      LogicalKeyboardKey.arrowLeft: -1,
      LogicalKeyboardKey.arrowRight: 1,
      LogicalKeyboardKey.arrowUp: -9,
      LogicalKeyboardKey.arrowDown: 9,
    }[key];
    if (move != null) {
      final to = (selected ?? 0) + move;
      final wraps = move.abs() == 1 && to ~/ 9 != (selected ?? 0) ~/ 9;
      if (selected != null && to >= 0 && to < 81 && !wraps) {
        setState(() => selected = to);
      } else if (selected == null) {
        setState(() => selected = 0);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _clear() async {
    if (filled > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear the grid?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      cells.fillRange(0, 81, 0);
      selected = null;
      doubtful = {};
      scanNote = null;
    });
  }

  Future<void> _import() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _ImportDialog(),
    );
    final parsed = text == null ? null : parsePuzzleText(text);
    if (parsed == null) return;
    setState(() {
      cells.setAll(0, parsed);
      selected = null;
      doubtful = {};
      scanNote = null;
    });
  }

  PhotoScanner? get _scanner =>
      widget.scanner ?? (photoScanSupported ? scanPuzzlePhoto : null);

  Future<void> _scan() async {
    final scanner = _scanner!;
    final navigator = Navigator.of(context);
    var reading = false;
    ScanResult? result;
    String? failure;
    try {
      result = await scanner(() {
        reading = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Expanded(child: Text('Reading the photo…')),
                ],
              ),
            ),
          ),
        );
      });
    } on ScanFailure catch (e) {
      failure = e.message;
    }
    if (reading) navigator.pop();
    if (!mounted) return;
    if (failure != null) return _say(failure);

    final parsed = result == null ? null : parsePuzzleText(result.text);
    if (parsed == null) return;
    final found = parsed.where((v) => v != 0).length;
    if (found == 0) return _say('I could not see any digits in that photo.');
    setState(() {
      cells.setAll(0, parsed);
      selected = null;
      doubtful = {...result!.uncertain};
      scanNote = doubtful.isEmpty
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

  Future<void> _teach() async {
    if (filled == 0) return _say('Enter a puzzle first.');
    if (clashing.isNotEmpty) return _say('Fix the red digits first.');

    final board = Board.parse(cells.map((v) => '$v').join());
    final solutions = countSolutions(board);
    if (solutions == 0) {
      return _say('This puzzle has no solution. Check the digits you entered.');
    }
    if (solutions > 1) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('More than one solution'),
          content: const Text(
            'A proper Sudoku has exactly one solution, so this puzzle may be '
            'missing some digits. I can still show how far logic gets.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Show me anyway'),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WalkthroughScreen(start: board)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bad = clashing;
    final board = Board.fromState([
      for (var c = 0; c < 81; c++) bad.contains(c) ? 0 : cells[c],
    ], List.filled(81, 0));

    final boardView = BoardView(
      board: board,
      givens: {
        for (var c = 0; c < 81; c++)
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
    );

    final status = bad.isNotEmpty
        ? 'Red digits break a rule: the same digit twice in a row, column or '
              'box.'
        : scanNote ??
              (filled == 0
                  ? 'Tap a cell, then a digit, to type in your puzzle.'
                  : '$filled digit${filled == 1 ? '' : 's'} entered.');

    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          status,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: bad.isNotEmpty ? theme.colorScheme.error : null,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var d = 1; d <= 9; d++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FilledButton.tonal(
                    key: Key('entry-$d'),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: selected == null ? null : () => _enter(d),
                    child: Text('$d', style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('erase-entry'),
                onPressed: selected == null ? null : () => _enter(0),
                icon: const Icon(Icons.backspace_outlined),
                label: const Text('Erase'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('import'),
                onPressed: _import,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('clear-grid'),
                onPressed: filled == 0 ? null : _clear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
        if (_scanner != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('scan-photo'),
            onPressed: _scan,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Scan from a photo'),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('teach-me'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: _teach,
          icon: const Icon(Icons.school),
          label: const Text('Teach me how to solve it'),
        ),
      ],
    );

    return Focus(
      focusNode: focus,
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 840 ||
              constraints.maxWidth > constraints.maxHeight * 1.2;
          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxHeight - 32,
                        ),
                        child: boardView,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(child: controls),
                  ),
                ],
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [boardView, const SizedBox(height: 16), controls],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final controller = TextEditingController();
  bool bad = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (parsePuzzleText(controller.text) == null) {
      setState(() => bad = true);
    } else {
      Navigator.pop(context, controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste a puzzle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste the 81 characters of a puzzle, row by row. Use 0 or . for '
            'blanks.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('import-field'),
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              errorText: bad ? 'That is not 81 digits and blanks.' : null,
            ),
            onChanged: (_) {
              if (bad) setState(() => bad = false);
            },
          ),
          TextButton.icon(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) {
                controller.text = data!.text!;
                setState(() => bad = false);
              }
            },
            icon: const Icon(Icons.content_paste_go),
            label: const Text('Use clipboard'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('import-confirm'),
          onPressed: _submit,
          child: const Text('Use puzzle'),
        ),
      ],
    );
  }
}
