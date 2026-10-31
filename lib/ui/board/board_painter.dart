import 'package:flutter/material.dart' hide Step;
import 'package:flutter/semantics.dart';

import '../../engine/engine.dart';
import 'board_drawing.dart';
import 'step_markup.dart';

/// Paints the grid, digits, pencil marks and the highlights for a step.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.board,
    required this.givens,
    required this.showCandidates,
    required Step? step,
    required Step? candidateFocus,
    required this.selected,
    required this.wrong,
    required this.marks,
    required this.flash,
    required this.flashProgress,
    required this.marked,
    required this.patterns,
    required this.onTap,
    required this.scheme,
  }) : markup = StepMarkup(step, candidateFocus);

  /// Placed digits and pencil marks, as a share of a cell's width.
  static const _digitScale = 0.62;
  static const _markScale = 0.24;

  /// Opacity of the tints over cells.
  static const _peerTint = 0.10;
  static const _selectedTint = 0.28;
  static const _removedTint = 0.6;
  static const _flashTint = 0.45;

  /// Outline of a cell a hint fills, and how far it sits inside the cell.
  static const _placedOutline = 3.0;
  static const _placedOutlineInset = 2.0;

  final Board board;
  final Set<int> givens;
  final bool showCandidates;
  final StepMarkup markup;
  final int? selected;
  final Map<int, int> wrong;
  final List<int>? marks;
  final Set<int> flash;
  final double flashProgress;
  final Set<int> marked;

  /// Whether to draw patterns (hatching, outlines) as well as colour.
  final bool patterns;
  final ValueChanged<int>? onTap;
  final ColorScheme scheme;

  /// Cells in the same row, column or box as the selected cell.
  late final Set<int> _peers = selected == null
      ? const {}
      : {...Board.peers[selected!]};

  /// The digit in the selected cell, or 0 when it is empty or none is selected.
  late final int _selectedValue = selected == null
      ? 0
      : board.values[selected!];

  /// The placed digits a wrong digit clashes with.
  late final Set<int> _clashes = {
    for (final entry in wrong.entries)
      for (final peer in Board.peers[entry.key])
        if (board.values[peer] == entry.value) peer,
  };

  Color _tint(double alpha) => Color.alphaBlend(
    scheme.primary.withValues(alpha: alpha),
    scheme.surfaceContainerLowest,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / Board.size;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = scheme.surfaceContainerLowest,
    );
    for (var c = 0; c < Board.cellCount; c++) {
      _paintBackground(canvas, c, cellRect(c, cellSize));
    }
    drawGridLines(canvas, size, scheme);
    for (var c = 0; c < Board.cellCount; c++) {
      _paintContents(canvas, c, cellRect(c, cellSize));
    }
    drawChainLinks(canvas, markup.links, cellSize, scheme);
  }

  /// The colour behind [cell], or null for the plain board.
  Color? _fillOf(int cell) {
    Color? fill;
    if (_peers.contains(cell)) fill = _tint(_peerTint);
    if (_selectedValue != 0 && board.values[cell] == _selectedValue) {
      fill = scheme.secondaryContainer;
    }
    if (_clashes.contains(cell)) fill = scheme.errorContainer;
    if (cell == selected || marked.contains(cell)) {
      fill = _tint(_selectedTint);
    }
    if (markup.placed.containsKey(cell)) {
      fill = scheme.tertiaryContainer;
    } else if (markup.removed.containsKey(cell)) {
      fill = scheme.errorContainer.withValues(alpha: _removedTint);
    } else if (markup.highlighted.contains(cell)) {
      fill = scheme.primaryContainer;
    }
    return fill;
  }

  void _paintBackground(Canvas canvas, int cell, Rect rect) {
    final fill = _fillOf(cell);
    if (fill != null) canvas.drawRect(rect, Paint()..color = fill);

    if (patterns) _paintPatterns(canvas, cell, rect);

    if (flash.contains(cell) && flashProgress < 1) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = scheme.primary.withValues(
            alpha: _flashTint * (1 - flashProgress),
          ),
      );
    }
  }

  /// Marks that show a cell's state without relying on colour.
  void _paintPatterns(Canvas canvas, int cell, Rect rect) {
    if (wrong.containsKey(cell)) {
      drawHatch(canvas, rect, scheme.error, forward: true);
    } else if (_clashes.contains(cell) || markup.removed.containsKey(cell)) {
      drawHatch(canvas, rect, scheme.error, forward: false);
    }
    if (markup.placed.containsKey(cell)) {
      canvas.drawRect(
        rect.deflate(_placedOutlineInset),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _placedOutline
          ..color = scheme.tertiary,
      );
    }
  }

  void _paintContents(Canvas canvas, int cell, Rect rect) {
    final digitSize = rect.width * _digitScale;
    final value = board.values[cell];
    if (value != 0) {
      final given = givens.contains(cell);
      drawCenteredText(
        canvas,
        '$value',
        rect.center,
        fontSize: digitSize,
        color: given ? scheme.onSurface : scheme.primary,
        weight: given ? FontWeight.w700 : FontWeight.w500,
      );
    } else if (wrong.containsKey(cell)) {
      drawCenteredText(
        canvas,
        '${wrong[cell]}',
        rect.center,
        fontSize: digitSize,
        color: scheme.error,
        weight: FontWeight.w500,
      );
    } else if (markup.placed.containsKey(cell)) {
      drawCenteredText(
        canvas,
        '${markup.placed[cell]}',
        rect.center,
        fontSize: digitSize,
        color: scheme.onTertiaryContainer,
        weight: FontWeight.w700,
      );
    } else if (showCandidates) {
      _paintNotes(canvas, cell, rect);
    }
  }

  /// The pencil marks to show in an empty [cell]: the player's own notes if
  /// they keep any, but the real candidates where a hint is about the cell.
  int _notesOf(int cell) {
    final own = marks;
    if (own == null) return board.candidates[cell];
    final hintIsAboutCell =
        markup.highlighted.contains(cell) || markup.removed.containsKey(cell);
    return own[cell] | (hintIsAboutCell ? board.candidates[cell] : 0);
  }

  void _paintNotes(Canvas canvas, int cell, Rect rect) {
    final gone = markup.removed[cell] ?? const <int>[];
    for (final digit in digitsOf(_notesOf(cell))) {
      if (!markup.showsNote(cell, digit)) continue;
      final eliminated = gone.contains(digit);
      final inPattern = markup.inPattern(cell, digit);
      drawCenteredText(
        canvas,
        '$digit',
        rect.topLeft + markOffset(digit, rect.width),
        fontSize: rect.width * _markScale,
        color: eliminated
            ? scheme.error
            : inPattern
            ? scheme.primary
            : scheme.onSurfaceVariant,
        weight: eliminated || inPattern ? FontWeight.w800 : FontWeight.w400,
        strike: eliminated,
      );
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final cellSize = size.width / Board.size;
    return [
      for (var c = 0; c < Board.cellCount; c++)
        CustomPainterSemantics(
          key: ValueKey(c),
          rect: cellRect(c, cellSize),
          properties: SemanticsProperties(
            label: _cellLabel(c),
            selected: c == selected,
            button: onTap != null,
            onTap: onTap == null ? null : () => onTap!(c),
            textDirection: TextDirection.ltr,
          ),
        ),
    ];
  };

  /// What a screen reader says for [cell]: where it is, and what it holds.
  String _cellLabel(int cell) {
    final where =
        'Row ${Board.rowOf(cell) + 1}, column '
        '${Board.columnOf(cell) + 1}';
    final value = board.values[cell];
    if (value != 0) {
      return '$where, $value${givens.contains(cell) ? ', given' : ''}';
    }
    final mistake = wrong[cell];
    if (mistake != null) return '$where, $mistake, mistake';
    if (!showCandidates) return '$where, empty';
    final notes = digitsOf(marks?[cell] ?? board.candidates[cell]);
    return notes.isEmpty
        ? '$where, empty'
        : '$where, empty, notes ${notes.join(', ')}';
  }

  @override
  bool shouldRebuildSemantics(BoardPainter oldDelegate) => true;

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => true;
}
