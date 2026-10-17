import '../engine/engine.dart';

/// A plain description of what [step] changes on the board.
String describeResult(Step step) => [
  for (final p in step.placements)
    '${Board.cellName(p.cell)} is now ${p.digit}.',
  for (final e in step.eliminations)
    'Removed ${e.digits.join(', ')} from ${Board.cellName(e.cell)}.',
].join(' ');
