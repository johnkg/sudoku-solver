// Fails when line coverage in an lcov file is below a minimum.
//
// Usage: dart run tool/check_coverage.dart [lcov file] [minimum percent]
// Defaults: coverage/lcov.info and 80.
import 'dart:io';

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'coverage/lcov.info';
  final minimum = args.length > 1 ? double.parse(args[1]) : 80.0;

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No coverage file at $path. Run `flutter test --coverage`.');
    exit(2);
  }

  var found = 0;
  var hit = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('LF:')) found += int.parse(line.substring(3));
    if (line.startsWith('LH:')) hit += int.parse(line.substring(3));
  }
  if (found == 0) {
    stderr.writeln('No lines found in $path.');
    exit(2);
  }

  final percent = hit * 100 / found;
  stdout.writeln(
    'Line coverage: ${percent.toStringAsFixed(1)}% ($hit of $found lines), '
    'minimum ${minimum.toStringAsFixed(1)}%',
  );
  if (percent < minimum) {
    stderr.writeln('Coverage is below the minimum.');
    exit(1);
  }
}
