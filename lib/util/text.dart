/// Small text and time formatters shared by the screens and the progress
/// store, so each one lives in a single place.
library;

/// [n] and [word], with an "s" added unless [n] is 1: `1 hint`, `3 hints`.
String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// Seconds as `m:ss`, or `h:mm:ss` past an hour.
String formatClock(int seconds) {
  final time = Duration(seconds: seconds);
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final h = time.inHours;
  final m = time.inMinutes.remainder(Duration.minutesPerHour);
  final s = twoDigits(time.inSeconds.remainder(Duration.secondsPerMinute));
  return h > 0 ? '$h:${twoDigits(m)}:$s' : '$m:$s';
}

/// The calendar day of [date] as `yyyy-MM-dd`, used as a storage key.
String formatDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December', //
];

/// How many letters of a month's name make its short form: `Oct`.
const _shortMonthLength = 3;

/// The full name of [date]'s month: `October`.
String monthName(DateTime date) => _monthNames[date.month - 1];

/// The short name of [date]'s month: `Oct`.
String shortMonthName(DateTime date) =>
    monthName(date).substring(0, _shortMonthLength);
