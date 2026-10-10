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

const sizeNames = {2: 'pair', 3: 'triple', 4: 'quad'};

String joinCells(Iterable<int> cells) => cells.map(Board.cellName).join(', ');

String joinDigits(Iterable<int> digits) => digits.join(', ');
