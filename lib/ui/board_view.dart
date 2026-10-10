import 'package:flutter/material.dart' hide Step;

import '../engine/engine.dart';

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

  /// Called with a cell index when the player taps the board.
  final ValueChanged<int>? onCellTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sudoku board',
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            onTapUp: onCellTap == null
                ? null
                : (details) {
                    final cell = constraints.maxWidth / 9;
                    final column = (details.localPosition.dx / cell)
                        .floor()
                        .clamp(0, 8);
                    final row = (details.localPosition.dy / cell).floor().clamp(
                      0,
                      8,
                    );
                    onCellTap!(row * 9 + column);
                  },
            child: CustomPaint(
              painter: _BoardPainter(
                board: board,
                givens: givens,
                showCandidates: showCandidates,
                step: step,
                candidateFocus: candidateFocus,
                selected: selected,
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
  _BoardPainter({
    required this.board,
    required this.givens,
    required this.showCandidates,
    required this.step,
    required this.candidateFocus,
    required this.selected,
    required this.scheme,
  });

  final Board board;
  final Set<int> givens;
  final bool showCandidates;
  final Step? step;
  final Step? candidateFocus;
  final int? selected;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
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

    for (var c = 0; c < 81; c++) {
      Color? fill;
      if (selectedValue != 0 && board.values[c] == selectedValue) {
        fill = scheme.secondaryContainer;
      }
      if (placed.containsKey(c)) {
        fill = scheme.tertiaryContainer;
      } else if (removed.containsKey(c)) {
        fill = scheme.errorContainer.withValues(alpha: 0.6);
      } else if (highlighted.contains(c)) {
        fill = scheme.primaryContainer;
      }
      if (fill != null) canvas.drawRect(rectOf(c), Paint()..color = fill);
    }

    _drawGrid(canvas, size, cell);

    final pick = selected;
    if (pick != null) {
      canvas.drawRect(
        rectOf(pick).deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = scheme.primary,
      );
    }

    for (var c = 0; c < 81; c++) {
      final rect = rectOf(c);
      final value = board.values[c];
      if (value != 0) {
        _text(
          canvas,
          '$value',
          rect.center,
          fontSize: cell * 0.62,
          color: givens.contains(c) ? scheme.onSurface : scheme.primary,
          weight: givens.contains(c) ? FontWeight.w700 : FontWeight.w500,
        );
        continue;
      }
      if (placed.containsKey(c)) {
        _text(
          canvas,
          '${placed[c]}',
          rect.center,
          fontSize: cell * 0.62,
          color: scheme.onTertiaryContainer,
          weight: FontWeight.w700,
        );
        continue;
      }
      if (!showCandidates) continue;

      final gone = removed[c] ?? const <int>[];
      for (final digit in digitsOf(board.candidates[c])) {
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
            rect.left + cell * ((digit - 1) % 3 + 0.5) / 3,
            rect.top + cell * ((digit - 1) ~/ 3 + 0.5) / 3,
          ),
          fontSize: cell * 0.24,
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
  }

  void _drawGrid(Canvas canvas, Size size, double cell) {
    final thin = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = scheme.outline
      ..strokeWidth = 2.5;
    for (var i = 0; i <= 9; i++) {
      final paint = i % 3 == 0 ? thick : thin;
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
  bool shouldRepaint(_BoardPainter old) => true;
}
