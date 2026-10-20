import 'daily_puzzle.dart' show dailyDateLabel;

/// A page address with no query or fragment, so a shared result links to the
/// app itself.
Uri appHome(Uri base) => Uri(
  scheme: base.scheme,
  host: base.host,
  port: base.hasPort ? base.port : null,
  path: base.path,
);

/// The text shared after solving the daily puzzle: the day, how it went, and
/// the streak, with a link to the app.
String dailyShareText({
  required DateTime date,
  required int level,
  required String levelName,
  required int stars,
  required int seconds,
  required int mistakes,
  required int hints,
  required int streak,
  required Uri link,
}) {
  String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
  final clock = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  return [
    'Sudoku Technique Teacher · ${dailyDateLabel(date)}',
    'Level $level · $levelName',
    '${'★' * stars}${'☆' * (3 - stars)}  $clock · '
        '${plural(mistakes, 'mistake')} · ${plural(hints, 'hint')}',
    if (streak > 1) '🔥 ${plural(streak, 'day')} in a row',
    '$link',
  ].join('\n');
}
