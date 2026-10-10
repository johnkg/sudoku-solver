import 'bits.dart';
import 'step.dart';

enum UnitKind { row, column, box }

/// A row, column, or box: nine cells that must hold each digit once.
class Unit {
  const Unit(this.kind, this.index, this.cells);

  final UnitKind kind;

  /// 0-8 within its kind.
  final int index;
  final List<int> cells;

  String get name => switch (kind) {
    UnitKind.row => 'Row ${index + 1}',
    UnitKind.column => 'Column ${index + 1}',
    UnitKind.box => 'Box ${index + 1}',
  };
}

/// A 9x9 grid with placed values and pencil-mark candidates.
///
/// Cells are indexed 0-80, row by row. A value of 0 means empty.
class Board {
  Board._(this.values, this.candidates);

  /// Parses 81 characters: `1`-`9` for givens, `0` or `.` for blanks.
  /// Whitespace is ignored. Throws [FormatException] on bad input or if the
  /// givens already break a rule.
  factory Board.parse(String text) {
    final chars = text.replaceAll(RegExp(r'\s'), '').split('');
    if (chars.length != 81) {
      throw FormatException('Expected 81 cells, got ${chars.length}');
    }
    final board = Board._(List.filled(81, 0), List.filled(81, allDigitsMask));
    for (var cell = 0; cell < 81; cell++) {
      final ch = chars[cell];
      if (ch == '0' || ch == '.') continue;
      final digit = int.tryParse(ch);
      if (digit == null || digit < 1 || digit > 9) {
        throw FormatException('Bad character "$ch" at cell $cell');
      }
      if (!hasDigit(board.candidates[cell], digit)) {
        throw FormatException('Given $digit at ${cellName(cell)} conflicts');
      }
      board.place(cell, digit);
    }
    return board;
  }

  /// Rebuilds a board from saved [values] and [candidates]. Throws
  /// [FormatException] if either list is the wrong size or holds impossible
  /// numbers.
  factory Board.fromState(List<int> values, List<int> candidates) {
    if (values.length != 81 || candidates.length != 81) {
      throw const FormatException('Expected 81 values and 81 candidate masks');
    }
    for (var i = 0; i < 81; i++) {
      if (values[i] < 0 || values[i] > 9) {
        throw FormatException('Bad value ${values[i]} at cell $i');
      }
      if (candidates[i] < 0 || candidates[i] > allDigitsMask) {
        throw FormatException('Bad candidates ${candidates[i]} at cell $i');
      }
      if (values[i] != 0 && candidates[i] != 0) {
        throw FormatException('Filled cell $i still has candidates');
      }
    }
    return Board._(List.of(values), List.of(candidates));
  }

  final List<int> values;

  /// Candidate bitmask per cell. 0 for filled cells.
  final List<int> candidates;

  static final List<Unit> units = _buildUnits();

  /// For each cell, the 20 other cells sharing a row, column, or box.
  static final List<List<int>> peers = _buildPeers();

  static int rowOf(int cell) => cell ~/ 9;
  static int columnOf(int cell) => cell % 9;
  static int boxOf(int cell) => (rowOf(cell) ~/ 3) * 3 + columnOf(cell) ~/ 3;

  static String cellName(int cell) =>
      'r${rowOf(cell) + 1}c${columnOf(cell) + 1}';

  /// The three units (row, column, box) containing [cell].
  static List<Unit> unitsOf(int cell) => [
    units[rowOf(cell)],
    units[9 + columnOf(cell)],
    units[18 + boxOf(cell)],
  ];

  Board copy() => Board._(List.of(values), List.of(candidates));

  bool get isSolved => !values.contains(0);

  /// True if some empty cell has no candidates left.
  bool get hasContradiction {
    for (var cell = 0; cell < 81; cell++) {
      if (values[cell] == 0 && candidates[cell] == 0) return true;
    }
    return false;
  }

  /// Fills [cell] with [digit] and removes [digit] from its peers.
  void place(int cell, int digit) {
    values[cell] = digit;
    candidates[cell] = 0;
    final bit = digitBit(digit);
    for (final peer in peers[cell]) {
      candidates[peer] &= ~bit;
    }
  }

  /// Removes [digit] as a candidate. Returns whether anything changed.
  bool eliminate(int cell, int digit) {
    final before = candidates[cell];
    candidates[cell] &= ~digitBit(digit);
    return candidates[cell] != before;
  }

  void applyStep(Step step) {
    for (final p in step.placements) {
      place(p.cell, p.digit);
    }
    for (final e in step.eliminations) {
      for (final d in e.digits) {
        eliminate(e.cell, d);
      }
    }
  }

  /// The 81-character form accepted by [Board.parse].
  String toLine() => values.map((v) => v == 0 ? '.' : '$v').join();

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var r = 0; r < 9; r++) {
      if (r > 0 && r % 3 == 0) buffer.writeln('------+-------+------');
      for (var c = 0; c < 9; c++) {
        if (c > 0 && c % 3 == 0) buffer.write('| ');
        final v = values[r * 9 + c];
        buffer.write(v == 0 ? '. ' : '$v ');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  static List<Unit> _buildUnits() => [
    for (var r = 0; r < 9; r++)
      Unit(UnitKind.row, r, [for (var c = 0; c < 9; c++) r * 9 + c]),
    for (var c = 0; c < 9; c++)
      Unit(UnitKind.column, c, [for (var r = 0; r < 9; r++) r * 9 + c]),
    for (var b = 0; b < 9; b++)
      Unit(UnitKind.box, b, [
        for (var i = 0; i < 9; i++)
          ((b ~/ 3) * 3 + i ~/ 3) * 9 + (b % 3) * 3 + i % 3,
      ]),
  ];

  static List<List<int>> _buildPeers() => [
    for (var cell = 0; cell < 81; cell++)
      {for (final unit in unitsOf(cell)) ...unit.cells}
          .where((c) => c != cell)
          .toList(),
  ];
}
