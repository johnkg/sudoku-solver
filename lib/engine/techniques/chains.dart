import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'strong_links.dart';
import 'subsets.dart';
import 'technique.dart';

/// X-Chain: for one digit, a chain of cells joined alternately by strong and
/// weak links, starting and ending with a strong link. In a strong link
/// exactly one of the two cells holds the digit; in a weak link the cells see
/// each other, so not both do.
///
/// If the first cell is not the digit, its strong link makes the next cell
/// the digit, the weak link rules out the one after, and so on down the
/// chain, so the last cell is the digit. Either way one of the two ends holds
/// it, and any cell that sees both ends cannot.
///
/// The shortest chains, with two strong links, are turbot fish and skyscrapers.
class XChain extends SolvingTechnique {
  const XChain();

  /// Most strong links in a chain. More is rarely worth the search.
  static const maxStrong = 4;

  @override
  Technique get technique => Technique.xChain;

  @override
  Step? find(Board board) {
    for (var digit = 1; digit <= 9; digit++) {
      final strong = <int, List<int>>{};
      for (final (a, b) in strongLinks(board, digit)) {
        (strong[a] ??= []).add(b);
        (strong[b] ??= []).add(a);
      }
      if (strong.length < 4) continue;

      final spots = {
        for (var c = 0; c < 81; c++)
          if (board.values[c] == 0 && hasDigit(board.candidates[c], digit)) c,
      };
      for (final start in strong.keys) {
        for (final second in strong[start]!) {
          final step = _extend(board, digit, strong, spots, [start, second]);
          if (step != null) return step;
        }
      }
    }
    return null;
  }

  /// [path] ends with a strong link. Checks it, then tries to extend it by a
  /// weak link and another strong link.
  Step? _extend(
    Board board,
    int digit,
    Map<int, List<int>> strong,
    Set<int> spots,
    List<int> path,
  ) {
    final strongCount = path.length ~/ 2;
    final first = path.first;
    final last = path.last;

    if (strongCount >= 2) {
      final eliminations = [
        for (final cell in Board.peers[first])
          if (spots.contains(cell) &&
              !path.contains(cell) &&
              Board.peers[last].contains(cell))
            Elimination(cell, [digit]),
      ];
      if (eliminations.isNotEmpty) {
        return _step(digit, path, eliminations);
      }
    }
    if (strongCount >= maxStrong) return null;

    for (final next in Board.peers[last]) {
      if (!spots.contains(next) || path.contains(next)) continue;
      for (final end in strong[next] ?? const <int>[]) {
        if (path.contains(end)) continue;
        final step = _extend(board, digit, strong, spots, [...path, next, end]);
        if (step != null) return step;
      }
    }
    return null;
  }

  Step _step(int digit, List<int> path, List<Elimination> eliminations) {
    final links = [
      for (var i = 0; i + 1 < path.length; i++)
        ChainLink(path[i], path[i + 1], digit, strong: i.isEven),
    ];
    final chain = StringBuffer(Board.cellName(path.first));
    for (var i = 1; i < path.length; i++) {
      chain.write(i.isOdd ? ' = ' : ' - ');
      chain.write(Board.cellName(path[i]));
    }
    final first = Board.cellName(path.first);
    final last = Board.cellName(path.last);
    return Step(
      technique: technique,
      eliminations: eliminations,
      highlightCells: path,
      highlightDigits: [digit],
      links: links,
      explanation:
          'X-Chain on $digit: $chain. An "=" is a strong link, where exactly '
          'one of the two cells is $digit. A "-" is a weak link, where the '
          'cells see each other so they cannot both be $digit. If $first is '
          'not $digit, the strong link makes ${Board.cellName(path[1])} '
          '$digit, which rules $digit out of the next cell, and so on down '
          'the chain until $last is $digit. So one of $first and $last is '
          '$digit, and any cell that sees both cannot be. Remove $digit from '
          '${joinCells(eliminations.map((e) => e.cell))}.',
    );
  }
}

/// XY-Chain: a chain of cells that each hold exactly two candidates, where
/// neighbours in the chain see each other and share a digit, and the first
/// and last cells both hold the same digit X.
///
/// If the first cell is not X it is its other digit, which rules that digit
/// out of the second cell, which makes the second cell its other digit, and
/// so on until the last cell is X. So one of the two ends is X, and any cell
/// that sees both ends cannot be. A Y-Wing is the three-cell case; this
/// finds chains of four or more.
class XYChain extends SolvingTechnique {
  const XYChain();

  static const maxLength = 8;

  @override
  Technique get technique => Technique.xyChain;

  @override
  Step? find(Board board) {
    final bivalue = [
      for (var c = 0; c < 81; c++)
        if (board.values[c] == 0 && popCount(board.candidates[c]) == 2) c,
    ];
    if (bivalue.length < 4) return null;
    final isBivalue = bivalue.toSet();

    for (final start in bivalue) {
      for (final x in digitsOf(board.candidates[start])) {
        final out = digitsOf(board.candidates[start] & ~digitBit(x)).single;
        final step = _extend(board, isBivalue, x, [start], out);
        if (step != null) return step;
      }
    }
    return null;
  }

  /// [chain] is a chain whose first cell holds [x] and whose last cell's
  /// other digit is [out].
  Step? _extend(
    Board board,
    Set<int> bivalue,
    int x,
    List<int> chain,
    int out,
  ) {
    if (chain.length >= maxLength) return null;
    for (final next in Board.peers[chain.last]) {
      if (!bivalue.contains(next) ||
          chain.contains(next) ||
          !hasDigit(board.candidates[next], out)) {
        continue;
      }
      final nextOut = digitsOf(board.candidates[next] & ~digitBit(out)).single;
      final longer = [...chain, next];

      if (nextOut == x && longer.length >= 4) {
        final first = longer.first;
        final eliminations = [
          for (final cell in Board.peers[first])
            if (board.values[cell] == 0 &&
                hasDigit(board.candidates[cell], x) &&
                !longer.contains(cell) &&
                Board.peers[next].contains(cell))
              Elimination(cell, [x]),
        ];
        if (eliminations.isNotEmpty) {
          return _step(board, x, longer, eliminations);
        }
      }
      final step = _extend(board, bivalue, x, longer, nextOut);
      if (step != null) return step;
    }
    return null;
  }

  Step _step(Board board, int x, List<int> chain, List<Elimination> removed) {
    String pair(int cell) =>
        '${Board.cellName(cell)} (${joinDigits(digitsOf(board.candidates[cell]))})';

    final links = <ChainLink>[];
    final reasons = <String>[];
    var out = digitsOf(board.candidates[chain.first] & ~digitBit(x)).single;
    reasons.add('If ${Board.cellName(chain.first)} is not $x, it is $out.');
    for (var i = 1; i < chain.length; i++) {
      links.add(ChainLink(chain[i - 1], chain[i], out));
      final next = digitsOf(board.candidates[chain[i]] & ~digitBit(out)).single;
      reasons.add(
        '${Board.cellName(chain[i])} sees ${Board.cellName(chain[i - 1])}, so '
        'it is not $out and must be $next.',
      );
      out = next;
    }
    final first = Board.cellName(chain.first);
    final last = Board.cellName(chain.last);
    return Step(
      technique: technique,
      eliminations: removed,
      highlightCells: chain,
      highlightDigits: {
        for (final c in chain) ...digitsOf(board.candidates[c]),
      }.toList()..sort(),
      links: links,
      explanation:
          'XY-Chain on $x: ${chain.map(pair).join(' → ')}. Each cell holds '
          'only the two digits shown, and each sees the one before it. '
          '${reasons.join(' ')} So one of $first and $last is $x, and any '
          'cell that sees both cannot be $x. Remove $x from '
          '${joinCells(removed.map((e) => e.cell))}.',
    );
  }
}
