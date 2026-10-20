import 'dart:math';

import 'puzzle_finder.dart';
import 'techniques/techniques.dart';

/// A small random number generator that gives the same numbers on every
/// device and every Dart version, which `Random(seed)` does not promise. The
/// daily puzzle needs that, so everyone gets the same puzzle on the same day.
///
/// Uses xorshift32 with explicit 32-bit masks so it behaves the same on the
/// web as on the VM.
class SeededRandom implements Random {
  SeededRandom(int seed)
    : _state = (seed & _mask) == 0 ? _zeroSeedState : seed & _mask;

  static const _mask = 0xFFFFFFFF;

  /// xorshift32 gets stuck at zero, so a zero seed starts here instead. Any
  /// non-zero value works; this is the usual golden-ratio constant.
  static const _zeroSeedState = 0x9E3779B9;

  /// Marsaglia's shift triple for xorshift32.
  static const _shiftA = 13;
  static const _shiftB = 17;
  static const _shiftC = 5;

  int _state;

  int _next32() {
    var x = _state;
    x ^= (x << _shiftA) & _mask;
    x ^= x >> _shiftB;
    x ^= (x << _shiftC) & _mask;
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

/// The daily puzzle's level for each weekday, Monday first: easy early in the
/// week, hardest at the weekend.
const _levelByWeekday = [1, 2, 3, 4, 4, 5, 5];

int dailyLevel(DateTime date) =>
    _levelByWeekday[date.weekday - DateTime.monday];

/// A number that identifies the calendar day, such as 20261010: the date's
/// digits run together.
int dailySeed(DateTime date) =>
    date.year * _yearPlace + date.month * _monthPlace + date.day;

const _yearPlace = 10000;
const _monthPlace = 100;

/// How many puzzles the daily search may try before giving up. Far more than
/// any day needs.
const dailyMaxAttempts = 20000;

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
  maxAttempts: dailyMaxAttempts,
  techniques: legacyTechniques,
  isCancelled: isCancelled,
  yieldTurn: yieldTurn,
);
