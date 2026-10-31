import 'package:flutter/material.dart' hide Step;

import '../../engine/engine.dart';

/// Pencil marks sit in a small grid inside the cell, laid out like a box.
const _marksPerRow = Board.boxSize;

/// The heavy lines around boxes.
const _boxLineWidth = 2.5;
const _boxLineAlpha = 0.75;

/// Hatching: thin diagonal lines that show a state without relying on colour.
const _hatchWidth = 1.2;
const _hatchAlpha = 0.55;
const _hatchGap = 7.0;

/// Lines between the cells of a pattern. A weak link is dashed: [_dash]
/// drawn in every [_dashPeriod].
const _strongLinkWidth = 3.0;
const _weakLinkWidth = 2.0;
const _linkAlpha = 0.9;
const _dash = 5.0;
const _dashPeriod = 9.0;
const _linkDotRadius = 3.5;

/// Where digit [digit]'s pencil mark sits inside a cell of side [cellSize],
/// measured from the cell's top left corner.
Offset markOffset(int digit, double cellSize) => Offset(
  cellSize * ((digit - 1) % _marksPerRow + 0.5) / _marksPerRow,
  cellSize * ((digit - 1) ~/ _marksPerRow + 0.5) / _marksPerRow,
);

/// The top left corner of [cell] on a board whose cells have side [cellSize].
Offset cellOrigin(int cell, double cellSize) =>
    Offset(Board.columnOf(cell) * cellSize, Board.rowOf(cell) * cellSize);

/// The square [cell] fills on a board whose cells have side [cellSize].
Rect cellRect(int cell, double cellSize) =>
    cellOrigin(cell, cellSize) & Size.square(cellSize);

/// The grid lines: thin between cells, heavy between boxes.
void drawGridLines(Canvas canvas, Size size, ColorScheme scheme) {
  final cell = size.width / Board.size;
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

/// Thin diagonal lines across [rect], rising to the right when [forward].
void drawHatch(Canvas canvas, Rect rect, Color color, {required bool forward}) {
  canvas.save();
  canvas.clipRect(rect);
  final paint = Paint()
    ..color = color.withValues(alpha: _hatchAlpha)
    ..strokeWidth = _hatchWidth;
  for (var d = -rect.height; d < rect.width; d += _hatchGap) {
    final start = forward ? rect.bottom : rect.top;
    final end = forward ? rect.top : rect.bottom;
    canvas.drawLine(
      Offset(rect.left + d, start),
      Offset(rect.left + d + rect.height, end),
      paint,
    );
  }
  canvas.restore();
}

/// The links of a step's pattern, drawn between the pencil marks they are
/// about: solid for strong links, dashed for weak ones.
void drawChainLinks(
  Canvas canvas,
  List<ChainLink> links,
  double cellSize,
  ColorScheme scheme,
) {
  Offset markCenter(int cell, int digit) =>
      cellOrigin(cell, cellSize) + markOffset(digit, cellSize);

  for (final link in links) {
    final from = markCenter(link.from, link.digit);
    final to = markCenter(link.to, link.digit);
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
      _drawDashedLine(canvas, from, to, line);
    }
    for (final end in [from, to]) {
      canvas.drawCircle(end, _linkDotRadius, Paint()..color = color);
    }
  }
}

void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
  final length = (to - from).distance;
  final direction = (to - from) / length;
  for (var d = 0.0; d < length; d += _dashPeriod) {
    canvas.drawLine(
      from + direction * d,
      from + direction * (d + _dash < length ? d + _dash : length),
      paint,
    );
  }
}

/// Draws [text] centred on [center].
void drawCenteredText(
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
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}
