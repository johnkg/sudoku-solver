import '../engine/engine.dart';
import '../progress/progress_store.dart';

/// Techniques the player keeps missing, worst first: at least [minAttempts]
/// tries and under [maxAccuracy] right. At most [limit] are returned.
List<Technique> weakSpots(
  ProgressStore store, {
  int minAttempts = 3,
  double maxAccuracy = 0.7,
  int limit = 3,
}) {
  final stats = store.techniqueStats;
  final weak = [
    for (final t in Technique.values)
      if (stats[t.name] case final stat?
          when stat.attempts >= minAttempts && stat.accuracy < maxAccuracy)
        t,
  ];
  weak.sort((a, b) {
    final byAccuracy = stats[a.name]!.accuracy.compareTo(
      stats[b.name]!.accuracy,
    );
    return byAccuracy != 0
        ? byAccuracy
        : stats[b.name]!.attempts.compareTo(stats[a.name]!.attempts);
  });
  return weak.take(limit).toList();
}
