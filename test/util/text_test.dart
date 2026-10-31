import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/util/text.dart';

void main() {
  test('plural adds an s unless the count is 1', () {
    expect(plural(0, 'hint'), '0 hints');
    expect(plural(1, 'hint'), '1 hint');
    expect(plural(3, 'day'), '3 days');
  });

  test('formatClock shows m:ss, and h:mm:ss past an hour', () {
    expect(formatClock(0), '0:00');
    expect(formatClock(65), '1:05');
    expect(formatClock(3599), '59:59');
    expect(formatClock(3600), '1:00:00');
    expect(formatClock(3725), '1:02:05');
  });

  test('formatDayKey pads year, month and day', () {
    expect(formatDayKey(DateTime(2026, 10, 5)), '2026-10-05');
    expect(formatDayKey(DateTime(987, 1, 2)), '0987-01-02');
  });
}
