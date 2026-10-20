/// Every technique the engine can use, easiest first.
enum Technique {
  fullHouse(1, 'Full House'),
  nakedSingle(1, 'Naked Single'),
  hiddenSingle(1, 'Hidden Single'),
  pointingPair(2, 'Pointing Pair/Triple'),
  boxLineReduction(2, 'Box/Line Reduction'),
  nakedPair(3, 'Naked Pair'),
  hiddenPair(3, 'Hidden Pair'),
  nakedTriple(3, 'Naked Triple'),
  hiddenTriple(3, 'Hidden Triple'),
  xWing(4, 'X-Wing'),
  skyscraper(4, 'Skyscraper'),
  yWing(4, 'Y-Wing'),
  swordfish(4, 'Swordfish'),
  nakedQuad(4, 'Naked Quad'),
  hiddenQuad(4, 'Hidden Quad'),
  xyzWing(5, 'XYZ-Wing'),
  uniqueRectangle(5, 'Unique Rectangle'),
  wWing(5, 'W-Wing'),
  simpleColoring(5, 'Simple Coloring'),
  jellyfish(5, 'Jellyfish'),
  xChain(5, 'X-Chain'),
  xyChain(5, 'XY-Chain');

  const Technique(this.level, this.label);

  /// Difficulty level, 1 (beginner) to 5 (expert).
  final int level;
  final String label;
}

class Placement {
  const Placement(this.cell, this.digit);

  final int cell;
  final int digit;
}

class Elimination {
  const Elimination(this.cell, this.digits);

  final int cell;
  final List<int> digits;
}

/// A line the UI draws between two cells of a pattern, for [digit]. A strong
/// link means exactly one of the two cells holds the digit; a weak link only
/// means they cannot both hold it.
class ChainLink {
  const ChainLink(this.from, this.to, this.digit, {this.strong = false});

  final int from;
  final int to;
  final int digit;
  final bool strong;
}

/// One logical move: what technique found it, what it changes, and why.
class Step {
  const Step({
    required this.technique,
    required this.explanation,
    this.placements = const [],
    this.eliminations = const [],
    this.highlightCells = const [],
    this.highlightDigits = const [],
    this.links = const [],
  });

  final Technique technique;
  final String explanation;
  final List<Placement> placements;
  final List<Elimination> eliminations;

  /// Cells forming the pattern, for the UI to draw.
  final List<int> highlightCells;
  final List<int> highlightDigits;

  /// Lines to draw between cells of the pattern.
  final List<ChainLink> links;
}
