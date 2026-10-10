import 'dart:math';

import 'puzzle_finder.dart';

/// A small random number generator that gives the same numbers on every
/// device and every Dart version, which `Random(seed)` does not promise. The
/// daily puzzle needs that, so everyone gets the same puzzle on the same day.
///
/// Uses xorshift32 with explicit 32-bit masks so it behaves the same on the
/// web as on the VM.
class SeededRandom implements Random {
  SeededRandom(int seed)
    : _state = (seed & _mask) == 0 ? 0x9E3779B9 : seed & _mask;

  static const _mask = 0xFFFFFFFF;

  int _state;

  int _next32() {
    var x = _state;
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    _state = x & _mask;
    return _state;
  }

  @override
  int nextInt(int max) {
    if (max <= 0 || max > _mask) {
      throw RangeError.range(max, 1, _mask, 'max');
    }
    return _next32() % max;
  }

  @override
  double nextDouble() => _next32() / (_mask + 1);

  @override
  bool nextBool() => _next32() & 1 == 1;
}

/// The difficulty level of the daily puzzle: easy early in the week, hardest
/// at the weekend. Mon 1, Tue 2, Wed 3, Thu 4, Fri 4, Sat 5, Sun 5.
int dailyLevel(DateTime date) =>
    const [1, 2, 3, 4, 4, 5, 5][date.weekday - DateTime.monday];

/// A number that identifies the calendar day, such as 20261010.
int dailySeed(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

/// The puzzle for [date]: the same one for everybody on that day.
///
/// Changing the generator or the rater changes which puzzle a date gives, so
/// a test pins one. Returns null only if [isCancelled] stops the search.
Future<FoundPuzzle?> findDailyPuzzle(
  DateTime date, {
  bool Function()? isCancelled,
  Future<void> Function()? yieldTurn,
}) => findPuzzleOfLevel(
  dailyLevel(date),
  SeededRandom(dailySeed(date)),
  maxAttempts: 20000,
  isCancelled: isCancelled,
  yieldTurn: yieldTurn,
);
