import '../board.dart';

/// All ways to choose [size] items from [items], in order.
Iterable<List<T>> combinations<T>(List<T> items, int size) sync* {
  if (size == 0) {
    yield const [];
    return;
  }
  for (var i = 0; i <= items.length - size; i++) {
    for (final rest in combinations(items.sublist(i + 1), size - 1)) {
      yield [items[i], ...rest];
    }
  }
}

/// Sizes of the groups the subset and fish techniques look for.
const pairSize = 2;
const tripleSize = 3;
const quadSize = 4;

const sizeNames = {pairSize: 'pair', tripleSize: 'triple', quadSize: 'quad'};

String joinCells(Iterable<int> cells) => cells.map(Board.cellName).join(', ');

String joinDigits(Iterable<int> digits) => digits.join(', ');
