import '../engine/engine.dart';
import '../progress/progress_store.dart';

/// Most techniques the review card offers at once.
const reviewLimit = 5;

/// The techniques due for review today, most urgent first: the ones the
/// player gets wrong most often, and then the longest overdue. At most
/// [limit] are returned.
List<Technique> dueForReview(ProgressStore store, {int limit = reviewLimit}) {
  final today = store.today;
  final stats = store.techniqueStats;
  final due = [
    for (final t in Technique.values)
      if (stats[t.name] case final stat? when stat.isDueOn(today)) t,
  ];
  due.sort((a, b) {
    final byAccuracy = stats[a.name]!.accuracy.compareTo(
      stats[b.name]!.accuracy,
    );
    if (byAccuracy != 0) return byAccuracy;
    final dueA = stats[a.name]!.dueOn ?? DateTime(0);
    final dueB = stats[b.name]!.dueOn ?? DateTime(0);
    return dueA.compareTo(dueB);
  });
  return due.take(limit).toList();
}

/// How many whole days [technique] is overdue on [today]: 0 when it is due
/// today.
int daysOverdue(TechniqueStat stat, DateTime today) {
  final due = stat.dueOn;
  if (due == null) return 0;
  final day = DateTime(today.year, today.month, today.day);
  return day.difference(due).inDays;
}
