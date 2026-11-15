import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'technique.dart';

/// Forcing Chain (proof by contradiction, which includes Nishio): suppose a
/// candidate is true and follow what it forces, using only singles. If that
/// leaves a cell with no candidate, or a digit with nowhere to go in a unit,
/// the supposition was wrong and the candidate can be removed.
class ForcingChain extends SolvingTechnique {
  const ForcingChain();

  /// Most forced moves followed before giving up on a candidate. Longer
  /// proofs are too hard to follow.
  static const maxForcedMoves = 12;

  @override
  Technique get technique => Technique.forcingChain;

  @override
  Step? find(Board board) {
    Step? best;
    var limit = maxForcedMoves;

    for (var cell = 0; cell < Board.cellCount; cell++) {
      if (board.values[cell] != 0) continue;
      for (final digit in digitsOf(board.candidates[cell])) {
        final proof = _disprove(board, cell, digit, limit);
        if (proof == null) continue;
        best = _step(cell, digit, proof);
        if (proof.forced.isEmpty) return best;
        // Only a shorter proof is worth swapping for.
        limit = proof.forced.length - 1;
      }
    }
    return best;
  }

  /// Supposes [cell] is [digit] and follows at most [limit] forced moves.
  /// Returns the moves and the contradiction they reach, or null if none
  /// turns up.
  ({List<Placement> forced, String contradiction})? _disprove(
    Board board,
    int cell,
    int digit,
    int limit,
  ) {
    final trial = board.copy()..place(cell, digit);
    final forced = <Placement>[];
    while (true) {
      final next = _scan(trial);
      if (next.contradiction != null) {
        return (forced: forced, contradiction: next.contradiction!);
      }
      final move = next.single;
      if (move == null || forced.length >= limit) return null;
      trial.place(move.cell, move.digit);
      forced.add(move);
    }
  }

  /// Looks over [board] once for something impossible (a cell with no
  /// candidate, or a digit with nowhere to go in a unit) and, failing that,
  /// for a single: a cell with one candidate, or a digit with one place in a
  /// unit. Only singles are followed, as they need no explaining.
  ({String? contradiction, Placement? single}) _scan(Board board) {
    Placement? single;
    for (var cell = 0; cell < Board.cellCount; cell++) {
      if (board.values[cell] != 0) continue;
      final candidates = board.candidates[cell];
      if (candidates == 0) {
        return (
          contradiction: '${Board.cellName(cell)} has no candidate left',
          single: null,
        );
      }
      if (single == null && popCount(candidates) == 1) {
        single = Placement(cell, digitsOf(candidates).single);
      }
    }
    for (final unit in Board.units) {
      // Digits placed in the unit, and digits that are a candidate in at
      // least one, and in at least two, of its cells.
      var placed = 0;
      var once = 0;
      var twice = 0;
      for (final cell in unit.cells) {
        final value = board.values[cell];
        if (value != 0) {
          placed |= digitBit(value);
        } else {
          twice |= once & board.candidates[cell];
          once |= board.candidates[cell];
        }
      }
      final homeless = allDigitsMask & ~placed & ~once;
      if (homeless != 0) {
        return (
          contradiction:
              '${digitsOf(homeless).first} has nowhere to go in ${unit.name}',
          single: null,
        );
      }
      final onePlace = once & ~twice;
      if (single == null && onePlace != 0) {
        final digit = digitsOf(onePlace).first;
        final cell = unit.cells.firstWhere(
          (c) => board.values[c] == 0 && hasDigit(board.candidates[c], digit),
        );
        single = Placement(cell, digit);
      }
    }
    return (contradiction: null, single: single);
  }

  Step _step(
    int cell,
    int digit,
    ({List<Placement> forced, String contradiction}) proof,
  ) {
    final name = Board.cellName(cell);
    final forced = proof.forced
        .map((p) => '${Board.cellName(p.cell)} must be ${p.digit}')
        .join(', then ');
    return Step(
      technique: technique,
      eliminations: [
        Elimination(cell, [digit]),
      ],
      highlightCells: [cell, for (final p in proof.forced) p.cell],
      highlightDigits: [digit],
      explanation:
          'Forcing Chain: suppose $name is $digit. '
          '${forced.isEmpty ? '' : 'Then $forced. '}'
          'Now ${proof.contradiction}, which is impossible. So $name is not '
          '$digit. Remove $digit from $name.',
    );
  }
}
