import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/settings/settings.dart';
import 'package:sudoku_solver/ui/app.dart';

void main() {
  group('Settings', () {
    test('start with the defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      expect(settings.haptics, isTrue);
      expect(settings.showClock, isTrue);
      expect(settings.mistakeLimit, 3);
    });

    test('are remembered between runs', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await Settings.load();
      first
        ..haptics = false
        ..showClock = false
        ..mistakeLimit = 5;

      final second = await Settings.load();
      expect(second.haptics, isFalse);
      expect(second.showClock, isFalse);
      expect(second.mistakeLimit, 5);
    });

    test('ignore a saved limit that is not on offer', () async {
      SharedPreferences.setMockInitialValues({'settings.mistakeLimit': 9});
      expect((await Settings.load()).mistakeLimit, 3);
    });

    test('haptic runs only when vibration is on', () {
      final settings = Settings.memory();
      var buzzes = 0;
      Future<void> buzz() async => buzzes++;
      settings.haptic(buzz);
      settings.haptics = false;
      settings.haptic(buzz);
      expect(buzzes, 1);
    });
  });

  testWidgets('the Settings screen changes them', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings.memory();
    await tester.pumpWidget(
      SudokuApp(store: ProgressStore.memory(), settings: settings),
    );

    await tester.tap(find.byTooltip('Progress options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('setting-haptics')));
    await tester.tap(find.byKey(const Key('setting-clock')));
    await tester.tap(find.byKey(const Key('limit-5')));
    await tester.pumpAndSettle();

    expect(settings.haptics, isFalse);
    expect(settings.showClock, isFalse);
    expect(settings.mistakeLimit, 5);
  });
}
