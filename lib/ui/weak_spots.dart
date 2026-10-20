import '../engine/engine.dart';
import '../progress/progress_store.dart';

/// Tries needed before a technique can count as a weak spot.
const weakSpotMinAttempts = 3;

/// A technique got right less often than this is a weak spot.
const weakSpotMaxAccuracy = 0.7;

/// Most weak spots shown at once.
const weakSpotLimit = 3;

/// Techniques the player keeps missing, worst first: at least [minAttempts]
/// tries and under [maxAccuracy] right. At most [limit] are returned.
List<Technique> weakSpots(
  ProgressStore store, {
  int minAttempts = weakSpotMinAttempts,
  double maxAccuracy = weakSpotMaxAccuracy,
  int limit = weakSpotLimit,
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
