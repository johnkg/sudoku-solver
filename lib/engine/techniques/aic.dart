import 'dart:collection';

import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'subsets.dart';
import 'technique.dart';

/// One candidate: a digit in a cell.
typedef _Node = ({int cell, int digit});

/// AIC (Alternating Inference Chain): a chain of candidates joined
/// alternately by strong and weak links, starting and ending with a strong
/// link. Unlike an X-Chain or XY-Chain, it may mix both kinds of strong link
/// and change digit along the way.
///
/// A strong link joins two candidates of which exactly one is true: the only
/// two places for a digit in a unit, or the only two candidates of a cell. A
/// weak link joins two that cannot both be true: the same digit in cells
/// that see each other, or two digits in one cell.
///
/// If the first candidate is false, the links force the last one to be true.
/// So at least one of the two ends is true, and anything that both of them
/// rule out can be removed.
class Aic extends SolvingTechnique {
  const Aic();

  /// Fewest and most strong links in a chain. One strong link alone is a
  /// simpler technique; long chains are too hard to follow.
  static const minStrong = 2;
  static const maxStrong = 6;

  @override
  Technique get technique => Technique.aic;

  @override
  Step? find(Board board) {
    final strong = _strongLinks(board);
    Step? best;
    var bestStrong = maxStrong + 1;

    for (final start in strong.keys) {
      final found = _shortestFrom(board, strong, start, bestStrong - 1);
      if (found == null) continue;
      best = found.step;
      bestStrong = found.strongCount;
      if (bestStrong == minStrong) break;
    }
    return best;
  }

  /// Every strong link, from each end.
  Map<_Node, List<_Node>> _strongLinks(Board board) {
    final links = <_Node, List<_Node>>{};
    void link(_Node a, _Node b) {
      (links[a] ??= []).add(b);
      (links[b] ??= []).add(a);
    }

    for (var cell = 0; cell < Board.cellCount; cell++) {
      if (board.values[cell] != 0) continue;
      final digits = digitsOf(board.candidates[cell]);
      if (digits.length == pairSize) {
        link((cell: cell, digit: digits[0]), (cell: cell, digit: digits[1]));
      }
    }
    for (var digit = 1; digit <= maxDigit; digit++) {
      final seen = <int>{};
      for (final unit in Board.units) {
        final spots = [
          for (final c in unit.cells)
            if (board.values[c] == 0 && hasDigit(board.candidates[c], digit)) c,
        ];
        // Two cells can share a box and a line; list that link once.
        if (spots.length == pairSize &&
            seen.add(spots[0] * Board.cellCount + spots[1])) {
          link((cell: spots[0], digit: digit), (cell: spots[1], digit: digit));
        }
      }
    }
    return links;
  }

  /// Candidates that cannot be true together with [node].
  Iterable<_Node> _weakLinks(Board board, _Node node) sync* {
    for (final digit in digitsOf(board.candidates[node.cell])) {
      if (digit != node.digit) yield (cell: node.cell, digit: digit);
    }
    for (final peer in Board.peers[node.cell]) {
      if (board.values[peer] == 0 &&
          hasDigit(board.candidates[peer], node.digit)) {
        yield (cell: peer, digit: node.digit);
      }
    }
  }

  /// The shortest useful chain that starts at [start], with at most
  /// [maxStrongCount] strong links.
  ({Step step, int strongCount})? _shortestFrom(
    Board board,
    Map<_Node, List<_Node>> strong,
    _Node start,
    int maxStrongCount,
  ) {
    // Supposing [start] is false: the candidates that must then be true,
    // each with the chain that proves it. Breadth first, so shortest first.
    final chains = <_Node, List<_Node>>{};
    final ruledOut = <_Node>{start};
    final queue = Queue<_Node>();

    void reach(_Node node, List<_Node> chain) {
      if (node == start || chains.containsKey(node)) return;
      chains[node] = chain;
      queue.add(node);
    }

    for (final next in strong[start]!) {
      reach(next, [start, next]);
    }
    while (queue.isNotEmpty) {
      final end = queue.removeFirst();
      final chain = chains[end]!;
      final strongCount = chain.length ~/ 2;

      if (strongCount >= minStrong) {
        final eliminations = _eliminations(board, chain);
        if (eliminations.isNotEmpty) {
          return (
            step: _step(board, chain, eliminations),
            strongCount: strongCount,
          );
        }
      }
      if (strongCount >= maxStrongCount) continue;

      for (final off in _weakLinks(board, end)) {
        if (!ruledOut.add(off)) continue;
        for (final on in strong[off] ?? const <_Node>[]) {
          reach(on, [...chain, off, on]);
        }
      }
    }
    return null;
  }

  /// What a chain proving "its first or its last candidate is true" removes.
  List<Elimination> _eliminations(Board board, List<_Node> chain) {
    final first = chain.first;
    final last = chain.last;

    if (first.cell == last.cell) {
      // The cell is one of the two digits.
      final others = [
        for (final d in digitsOf(board.candidates[first.cell]))
          if (d != first.digit && d != last.digit) d,
      ];
      return [if (others.isNotEmpty) Elimination(first.cell, others)];
    }
    final seeEachOther = Board.peers[first.cell].contains(last.cell);
    if (first.digit == last.digit) {
      final inChain = {for (final node in chain) node.cell};
      return [
        for (final cell in Board.peers[first.cell])
          if (board.values[cell] == 0 &&
              hasDigit(board.candidates[cell], first.digit) &&
              !inChain.contains(cell) &&
              Board.peers[last.cell].contains(cell))
            Elimination(cell, [first.digit]),
      ];
    }
    if (!seeEachOther) return const [];
    // Each end rules the other's digit out of its own cell.
    return [
      if (hasDigit(board.candidates[first.cell], last.digit))
        Elimination(first.cell, [last.digit]),
      if (hasDigit(board.candidates[last.cell], first.digit))
        Elimination(last.cell, [first.digit]),
    ];
  }

  Step _step(Board board, List<_Node> chain, List<Elimination> eliminations) {
    String name(_Node node) => '${node.digit} in ${Board.cellName(node.cell)}';
    String isTrue(_Node node) =>
        '${Board.cellName(node.cell)} is ${node.digit}';
    String isFalse(_Node node) =>
        '${Board.cellName(node.cell)} is not ${node.digit}';

    final notation = StringBuffer('(${chain.first.digit})');
    notation.write(Board.cellName(chain.first.cell));
    final reasons = <String>[];
    for (var i = 1; i < chain.length; i++) {
      final strongLink = i.isOdd;
      notation.write(strongLink ? ' = ' : ' - ');
      notation.write('(${chain[i].digit})${Board.cellName(chain[i].cell)}');
      reasons.add(strongLink ? isTrue(chain[i]) : isFalse(chain[i]));
    }

    final first = chain.first;
    final last = chain.last;
    final String conclusion;
    if (first.cell == last.cell) {
      conclusion =
          'So ${Board.cellName(first.cell)} is ${first.digit} or '
          '${last.digit}, and its other candidates can go.';
    } else if (first.digit == last.digit) {
      conclusion =
          'So one of ${Board.cellName(first.cell)} and '
          '${Board.cellName(last.cell)} is ${first.digit}, and any cell that '
          'sees both cannot be.';
    } else {
      conclusion =
          'So ${isTrue(first)} or ${isTrue(last)}. The two cells see each '
          'other, so neither can hold the other\'s digit.';
    }
    final sameDigit =
        eliminations.every((e) => e.digits.length == 1) &&
        {for (final e in eliminations) e.digits.single}.length == 1;
    final removed = sameDigit
        ? '${eliminations.first.digits.single} from '
              '${joinCells(eliminations.map((e) => e.cell))}'
        : eliminations
              .map(
                (e) => '${joinDigits(e.digits)} from ${Board.cellName(e.cell)}',
              )
              .join(', ');

    return Step(
      technique: technique,
      eliminations: eliminations,
      highlightCells: {for (final node in chain) node.cell}.toList(),
      highlightDigits: {for (final node in chain) node.digit}.toList()..sort(),
      links: [
        for (var i = 0; i + 1 < chain.length; i++)
          ChainLink(
            chain[i].cell,
            chain[i + 1].cell,
            chain[i].digit,
            toDigit: chain[i + 1].digit,
            strong: i.isEven,
          ),
      ],
      explanation:
          'AIC from ${name(first)} to ${name(last)}: $notation. An "=" is a '
          'strong link, where exactly one of the two is true. A "-" is a '
          'weak link, where both cannot be true. If ${isFalse(first)}, then '
          '${reasons.join(', so ')}. '
          '$conclusion Remove $removed.',
    );
  }
}
