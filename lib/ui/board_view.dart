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
    final peers = selected == null
        ? const <int>{}
        : {...Board.peers[selected!]};
    final peerTint = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.10),
      scheme.surfaceContainerLowest,
    );
    final selectedTint = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.28),
      scheme.surfaceContainerLowest,
    );

    // The placed digits a wrong digit clashes with.
    final clashes = {
      for (final entry in wrong.entries)
        for (final peer in Board.peers[entry.key])
          if (board.values[peer] == entry.value) peer,
    };

    for (var c = 0; c < 81; c++) {
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
        fill = scheme.errorContainer.withValues(alpha: 0.6);
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
              ..strokeWidth = 3
              ..color = scheme.tertiary,
          );
        }
      }
      if (flash.contains(c) && flashProgress < 1) {
        canvas.drawRect(
          rectOf(c),
          Paint()
            ..color = scheme.primary.withValues(
              alpha: 0.45 * (1 - flashProgress),
            ),
        );
      }
    }

    _drawGrid(canvas, size, cell);

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
      if (wrong.containsKey(c)) {
        _text(
          canvas,
          '${wrong[c]}',
          rect.center,
          fontSize: cell * 0.62,
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
          fontSize: cell * 0.62,
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

  /// Thin diagonal lines across [rect], so a state shows without relying on
  /// colour.
  void _hatch(Canvas canvas, Rect rect, Color color, {required bool forward}) {
    canvas.save();
    canvas.clipRect(rect);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;
    const gap = 7.0;
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
      ..color = scheme.onSurface.withValues(alpha: 0.75)
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
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final cell = size.width / 9;
    return [
      for (var c = 0; c < 81; c++)
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
