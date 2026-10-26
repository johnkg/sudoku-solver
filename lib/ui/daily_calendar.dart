import 'package:flutter/material.dart';

import 'layout.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December', //
];

/// A month at a time, with the days the daily puzzle was solved filled in.
class DailyCalendar extends StatefulWidget {
  const DailyCalendar({super.key, required this.solved, required this.today});

  /// Days solved, as `2026-10-10`.
  final Set<String> solved;
  final DateTime today;

  @override
  State<DailyCalendar> createState() => _DailyCalendarState();
}

class _DailyCalendarState extends State<DailyCalendar> {
  /// A calendar wider than this would be taller than the screen.
  static const _maxWidth = 360.0;

  late DateTime month = DateTime(widget.today.year, widget.today.month);

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The oldest month worth showing: the first one with a solve, else now.
  DateTime get _earliest {
    final days = [
      for (final key in widget.solved)
        if (DateTime.tryParse(key) case final d?) DateTime(d.year, d.month),
    ]..sort();
    return days.isEmpty
        ? DateTime(widget.today.year, widget.today.month)
        : days.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thisMonth = DateTime(widget.today.year, widget.today.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final blanks = DateTime(month.year, month.month).weekday - 1;
    final today = DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('cal-prev'),
                  tooltip: 'Previous month',
                  onPressed: month.isAfter(_earliest)
                      ? () => setState(
                          () => month = DateTime(month.year, month.month - 1),
                        )
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[month.month - 1]} ${month.year}',
                    key: const Key('cal-title'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: const Key('cal-next'),
                  tooltip: 'Next month',
                  onPressed: month.isBefore(thisMonth)
                      ? () => setState(
                          () => month = DateTime(month.year, month.month + 1),
                        )
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.xs),
            GridView.count(
              crossAxisCount: DateTime.daysPerWeek,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysInMonth; day++)
                  Builder(
                    builder: (context) {
                      final date = DateTime(month.year, month.month, day);
                      final solved = widget.solved.contains(_key(date));
                      final isToday = date == today;
                      final future = date.isAfter(today);
                      return Semantics(
                        label:
                            '${_monthNames[month.month - 1]} $day'
                            '${solved ? ', solved' : ''}',
                        child: Container(
                          key: Key('cal-day-${_key(date)}'),
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: solved ? theme.colorScheme.primary : null,
                            border: isToday
                                ? Border.all(
                                    color: theme.colorScheme.primary,
                                    width: todayRingWidth,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            child: Text(
                              '$day',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: solved ? FontWeight.w700 : null,
                                color: solved
                                    ? theme.colorScheme.onPrimary
                                    : future
                                    ? theme.colorScheme.outline
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
