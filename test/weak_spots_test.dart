import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/weak_spots.dart';

void main() {
  void record(ProgressStore store, Technique t, int right, int wrong) {
    for (var i = 0; i < right; i++) {
      store.recordTechnique(t.name, right: true);
    }
    for (var i = 0; i < wrong; i++) {
      store.recordTechnique(t.name, right: false);
    }
  }

  group('technique stats', () {
    test('add up right and wrong tries', () {
      final store = ProgressStore.memory();
      record(store, Technique.xWing, 2, 1);
      final stat = store.techniqueStats[Technique.xWing.name]!;
      expect(stat.right, 2);
      expect(stat.wrong, 1);
      expect(stat.attempts, 3);
      expect(stat.accuracy, closeTo(2 / 3, 1e-9));
    });

    test('are remembered between runs and cleared by reset', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await ProgressStore.load();
      record(first, Technique.nakedPair, 1, 2);

      final second = await ProgressStore.load();
      expect(second.techniqueStats[Technique.nakedPair.name]!.wrong, 2);

      second.reset();
      expect(second.techniqueStats, isEmpty);
      expect((await ProgressStore.load()).techniqueStats, isEmpty);
    });

    test('ignore unreadable saved data', () async {
      SharedPreferences.setMockInitialValues({'progress.techniques': 'oops'});
      expect((await ProgressStore.load()).techniqueStats, isEmpty);
    });
  });

  group('weakSpots', () {
    test('is empty until there is enough to go on', () {
      final store = ProgressStore.memory();
      record(store, Technique.xWing, 0, 2);
      expect(weakSpots(store), isEmpty);
    });

    test('lists techniques under 70% right, worst first', () {
      final store = ProgressStore.memory();
      record(store, Technique.nakedPair, 1, 2); // 33%
      record(store, Technique.xWing, 0, 4); // 0%
      record(store, Technique.yWing, 4, 1); // 80%, fine
      record(store, Technique.swordfish, 2, 2); // 50%
      expect(weakSpots(store), [
        Technique.xWing,
        Technique.nakedPair,
        Technique.swordfish,
      ]);
    });

    test('returns at most the limit', () {
      final store = ProgressStore.memory();
      for (final t in Technique.values.take(5)) {
        record(store, t, 0, 3);
      }
      expect(weakSpots(store, limit: 2), hasLength(2));
    });
  });
}
