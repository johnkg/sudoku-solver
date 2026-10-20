import 'package:flutter/material.dart' hide Step;
import 'package:flutter/semantics.dart';

import '../engine/engine.dart';
import '../settings/settings.dart';

/// Draws the grid, digits, pencil marks, and the highlights for [step].
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.board,
    required this.givens,
    required this.showCandidates,
    this.step,
    this.candidateFocus,
    this.selected,
    this.wrong = const {},
    this.marks,
    this.flash = const {},
    this.flashProgress = 1,
    this.marked = const {},
    this.onCellTap,
  });

  final Board board;
  final Set<int> givens;
  final bool showCandidates;
  final Step? step;

  /// When set, pencil marks are drawn only for the cells and digits this step
  /// involves, so a worked example is not buried in noise.
  final Step? candidateFocus;

  /// The cell the player has selected, if any.
  final int? selected;

  /// Wrong digits the player typed, drawn in red.
  final Map<int, int> wrong;

  /// The player's own notes, a digit bit mask per cell. When set they are
  /// drawn instead of the board's candidates, except in cells a hint is
  /// about, which show the real candidates.
  final List<int>? marks;

  /// Cells to flash, and how far the flash has faded: 0 just started, 1 gone.
  final Set<int> flash;
  final double flashProgress;

  /// Cells the player has picked out, tinted like the selected cell.
  final Set<int> marked;

  /// Called with a cell index when the player taps the board.
  final ValueChanged<int>? onCellTap;

  @override
  Widget build(BuildContext context) {
    final patterns =
        context
            .dependOnInheritedWidgetOfExactType<SettingsScope>()
            ?.notifier
            ?.patterns ??
        false;

    return Semantics(
      container: true,
      label: 'Sudoku board',
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            onTapUp: onCellTap == null
                ? null
                : (details) {
                    final cell = constraints.maxWidth / Board.size;
                    final column = (details.localPosition.dx / cell)
                        .floor()
                        .clamp(0, Board.size - 1);
                    final row = (details.localPosition.dy / cell).floor().clamp(
                      0,
                      Board.size - 1,
                    );
                    onCellTap!(Board.cellAt(row, column));
                  },
            child: CustomPaint(
              painter: _BoardPainter(
                board: board,
                givens: givens,
                showCandidates: showCandidates,
                step: step,
                candidateFocus: candidateFocus,
                selected: selected,
                wrong: wrong,
                marks: marks,
                flash: flash,
                flashProgress: flashProgress,
                marked: marked,
                patterns: patterns,
                onTap: onCellTap,
                scheme: Theme.of(context).colorScheme,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  /// Placed digits and pencil marks, as a share of a cell's width.
  static const _digitScale = 0.62;
  static const _markScale = 0.24;

  /// Pencil marks sit in a small grid inside the cell, laid out like a box.
  static const _marksPerRow = Board.boxSize;

  /// Opacity of the tints over cells.
  static const _peerTint = 0.10;
  static const _selectedTint = 0.28;
  static const _removedTint = 0.6;
  static const _flashTint = 0.45;

  /// The heavy lines around boxes.
  static const _boxLineWidth = 2.5;
  static const _boxLineAlpha = 0.75;

  /// Extra markings: the outline of a cell a hint fills, and hatching.
  static const _placedOutline = 3.0;
  static const _hatchWidth = 1.2;
  static const _hatchAlpha = 0.55;
  static const _hatchGap = 7.0;

  /// Lines between the cells of a pattern. A weak link is dashed: [_dash]
  /// drawn in every [_dashPeriod].
  static const _strongLinkWidth = 3.0;
  static const _weakLinkWidth = 2.0;
  static const _linkAlpha = 0.9;
  static const _dash = 5.0;
  static const _dashPeriod = 9.0;
  static const _linkDotRadius = 3.5;

  _BoardPainter({
    required this.board,
    required this.givens,
    required this.showCandidates,
    required this.step,
    required this.candidateFocus,
    required this.selected,
    required this.wrong,
    required this.marks,
    required this.flash,
    required this.flashProgress,
    required this.marked,
    required this.patterns,
    required this.onTap,
    required this.scheme,
  });

  final Board board;
  final Set<int> givens;
  final bool showCandidates;
  final Step? step;
  final Step? candidateFocus;
  final int? selected;
  final Map<int, int> wrong;
  final List<int>? marks;
  final Set<int> flash;
  final double flashProgress;
  final Set<int> marked;
  final bool patterns;
  final ValueChanged<int>? onTap;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / Board.size;
    final step = this.step;
    final highlighted = {...?step?.highlightCells};
    final placed = {
      for (final p in step?.placements ?? <Placement>[]) p.cell: p.digit,
    };
    final removed = {
      for (final e in step?.eliminations ?? <Elimination>[]) e.cell: e.digits,
    };

    final focus = candidateFocus;
    final focusCells = focus == null
        ? null
        : {
            ...focus.highlightCells,
            ...focus.placements.map((p) => p.cell),
            ...focus.eliminations.map((e) => e.cell),
          };
    final focusDigits = focus == null
        ? null
        : {
            ...focus.highlightDigits,
            for (final e in focus.eliminations) ...e.digits,
          };

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = scheme.surfaceContainerLowest,
    );

    Rect rectOf(int c) => Rect.fromLTWH(
      Board.columnOf(c) * cell,
      Board.rowOf(c) * cell,
      cell,
      cell,
    );

    final selectedValue = selected == null ? 0 : board.values[selected!];
    final peers = selected == null
        ? const <int>{}
        : {...Board.peers[selected!]};
    final peerTint = Color.alphaBlend(
      scheme.primary.withValues(alpha: _peerTint),
      scheme.surfaceContainerLowest,
    );
    final selectedTint = Color.alphaBlend(
      scheme.primary.withValues(alpha: _selectedTint),
      scheme.surfaceContainerLowest,
    );

    // The placed digits a wrong digit clashes with.
    final clashes = {
      for (final entry in wrong.entries)
        for (final peer in Board.peers[entry.key])
          if (board.values[peer] == entry.value) peer,
    };

    for (var c = 0; c < Board.cellCount; c++) {
      Color? fill;
      if (peers.contains(c)) fill = peerTint;
      if (selectedValue != 0 && board.values[c] == selectedValue) {
        fill = scheme.secondaryContainer;
      }
      if (clashes.contains(c)) fill = scheme.errorContainer;
      if (c == selected || marked.contains(c)) fill = selectedTint;
      if (placed.containsKey(c)) {
        fill = scheme.tertiaryContainer;
      } else if (removed.containsKey(c)) {
        fill = scheme.errorContainer.withValues(alpha: _removedTint);
      } else if (highlighted.contains(c)) {
        fill = scheme.primaryContainer;
      }
      if (fill != null) canvas.drawRect(rectOf(c), Paint()..color = fill);
      if (patterns) {
        if (wrong.containsKey(c)) {
          _hatch(canvas, rectOf(c), scheme.error, forward: true);
        } else if (clashes.contains(c)) {
          _hatch(canvas, rectOf(c), scheme.error, forward: false);
        } else if (removed.containsKey(c)) {
          _hatch(canvas, rectOf(c), scheme.error, forward: false);
        }
        if (placed.containsKey(c)) {
          canvas.drawRect(
            rectOf(c).deflate(2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = _placedOutline
              ..color = scheme.tertiary,
          );
        }
      }
      if (flash.contains(c) && flashProgress < 1) {
        canvas.drawRect(
          rectOf(c),
          Paint()
            ..color = scheme.primary.withValues(
              alpha: _flashTint * (1 - flashProgress),
            ),
        );
      }
    }

    _drawGrid(canvas, size, cell);

    for (var c = 0; c < Board.cellCount; c++) {
      final rect = rectOf(c);
      final value = board.values[c];
      if (value != 0) {
        _text(
          canvas,
          '$value',
          rect.center,
          fontSize: cell * _digitScale,
          color: givens.contains(c) ? scheme.onSurface : scheme.primary,
          weight: givens.contains(c) ? FontWeight.w700 : FontWeight.w500,
        );
        continue;
      }
      if (wrong.containsKey(c)) {
        _text(
          canvas,
          '${wrong[c]}',
          rect.center,
          fontSize: cell * _digitScale,
          color: scheme.error,
          weight: FontWeight.w500,
        );
        continue;
      }
      if (placed.containsKey(c)) {
        _text(
          canvas,
          '${placed[c]}',
          rect.center,
          fontSize: cell * _digitScale,
          color: scheme.onTertiaryContainer,
          weight: FontWeight.w700,
        );
        continue;
      }
      if (!showCandidates) continue;

      final gone = removed[c] ?? const <int>[];
      final own = marks;
      final mask = own == null
          ? board.candidates[c]
          : own[c] |
                (highlighted.contains(c) || removed.containsKey(c)
                    ? board.candidates[c]
                    : 0);
      for (final digit in digitsOf(mask)) {
        if (focusCells != null &&
            !(focusCells.contains(c) && focusDigits!.contains(digit))) {
          continue;
        }
        final inPattern =
            highlighted.contains(c) &&
            (step?.highlightDigits.contains(digit) ?? false);
        final eliminated = gone.contains(digit);
        _text(
          canvas,
          '$digit',
          Offset(
            rect.left +
                cell * ((digit - 1) % _marksPerRow + 0.5) / _marksPerRow,
            rect.top +
                cell * ((digit - 1) ~/ _marksPerRow + 0.5) / _marksPerRow,
          ),
          fontSize: cell * _markScale,
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
    _drawLinks(canvas, cell);
  }

  /// Where digit [digit]'s pencil mark sits inside [cell]'s square.
  Offset _markCenter(int cell, int digit, double size) => Offset(
    Board.columnOf(cell) * size +
        size * ((digit - 1) % _marksPerRow + 0.5) / _marksPerRow,
    Board.rowOf(cell) * size +
        size * ((digit - 1) ~/ _marksPerRow + 0.5) / _marksPerRow,
  );

  /// The links of the step's pattern, drawn between the pencil marks they are
  /// about: solid for strong links, dashed for weak ones.
  void _drawLinks(Canvas canvas, double cell) {
    for (final link in step?.links ?? const <ChainLink>[]) {
      final from = _markCenter(link.from, link.digit, cell);
      final to = _markCenter(link.to, link.digit, cell);
      final color = (link.strong ? scheme.primary : scheme.tertiary).withValues(
        alpha: _linkAlpha,
      );
      final line = Paint()
        ..color = color
        ..strokeWidth = link.strong ? _strongLinkWidth : _weakLinkWidth
        ..strokeCap = StrokeCap.round;
      if (link.strong) {
        canvas.drawLine(from, to, line);
      } else {
        final length = (to - from).distance;
        final direction = (to - from) / length;
        for (var d = 0.0; d < length; d += _dashPeriod) {
          canvas.drawLine(
            from + direction * d,
            from + direction * (d + _dash < length ? d + _dash : length),
            line,
          );
        }
      }
      for (final end in [from, to]) {
        canvas.drawCircle(end, _linkDotRadius, Paint()..color = color);
      }
    }
  }

  /// Thin diagonal lines across [rect], so a state shows without relying on
  /// colour.
  void _hatch(Canvas canvas, Rect rect, Color color, {required bool forward}) {
    canvas.save();
    canvas.clipRect(rect);
    final paint = Paint()
      ..color = color.withValues(alpha: _hatchAlpha)
      ..strokeWidth = _hatchWidth;
    const gap = _hatchGap;
    for (var d = -rect.height; d < rect.width; d += gap) {
      if (forward) {
        canvas.drawLine(
          Offset(rect.left + d, rect.bottom),
          Offset(rect.left + d + rect.height, rect.top),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(rect.left + d, rect.top),
          Offset(rect.left + d + rect.height, rect.bottom),
          paint,
        );
      }
    }
    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size, double cell) {
    final thin = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = scheme.onSurface.withValues(alpha: _boxLineAlpha)
      ..strokeWidth = _boxLineWidth;
    for (var i = 0; i <= Board.size; i++) {
      final paint = i % Board.boxSize == 0 ? thick : thin;
      final p = i * cell;
      canvas.drawLine(Offset(p, 0), Offset(p, size.height), paint);
      canvas.drawLine(Offset(0, p), Offset(size.width, p), paint);
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color color,
    required FontWeight weight,
    bool strike = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: weight,
          height: 1,
          decoration: strike ? TextDecoration.lineThrough : null,
          decorationColor: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final cell = size.width / Board.size;
    return [
      for (var c = 0; c < Board.cellCount; c++)
        CustomPainterSemantics(
          key: ValueKey(c),
          rect: Rect.fromLTWH(
            Board.columnOf(c) * cell,
            Board.rowOf(c) * cell,
            cell,
            cell,
          ),
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
  bool shouldRebuildSemantics(_BoardPainter old) => true;

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
