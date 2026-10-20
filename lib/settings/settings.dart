import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the player likes the game to behave. Saved to the device when built
/// with [load]; [Settings.memory] keeps everything in memory (for tests).
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  Settings.memory() : _prefs = null;

  /// Loads saved settings. Missing or odd values fall back to the defaults.
  static Future<Settings> load() async {
    final settings = Settings._(await SharedPreferences.getInstance());
    final prefs = settings._prefs!;
    settings._haptics = prefs.getBool(_hapticsKey) ?? true;
    settings._showClock = prefs.getBool(_clockKey) ?? true;
    settings._patterns = prefs.getBool(_patternsKey) ?? false;
    final limit = prefs.getInt(_limitKey);
    if (mistakeLimits.contains(limit)) settings._mistakeLimit = limit!;
    return settings;
  }

  static const _hapticsKey = 'settings.haptics';
  static const _clockKey = 'settings.showClock';
  static const _limitKey = 'settings.mistakeLimit';
  static const _patternsKey = 'settings.patterns';

  /// The mistake limits to choose from. 0 means no limit.
  static const mistakeLimits = [0, 3, 5];

  final SharedPreferences? _prefs;
  bool _haptics = true;
  bool _showClock = true;
  bool _patterns = false;
  int _mistakeLimit = 3;

  bool get haptics => _haptics;
  bool get showClock => _showClock;

  /// Whether the board marks mistakes and moves with hatching and outlines as
  /// well as colour.
  bool get patterns => _patterns;

  /// Mistakes allowed before the game offers to start over. 0 means no limit.
  int get mistakeLimit => _mistakeLimit;

  set haptics(bool value) {
    _haptics = value;
    _prefs?.setBool(_hapticsKey, value);
    notifyListeners();
  }

  set showClock(bool value) {
    _showClock = value;
    _prefs?.setBool(_clockKey, value);
    notifyListeners();
  }

  set patterns(bool value) {
    _patterns = value;
    _prefs?.setBool(_patternsKey, value);
    notifyListeners();
  }

  set mistakeLimit(int value) {
    assert(mistakeLimits.contains(value));
    _mistakeLimit = value;
    _prefs?.setInt(_limitKey, value);
    notifyListeners();
  }

  /// Runs [kind] (such as `HapticFeedback.heavyImpact`) if haptics are on.
  void haptic(Future<void> Function() kind) {
    if (_haptics) kind();
  }
}

/// Makes the [Settings] available to the whole app and rebuilds dependents
/// when they change.
class SettingsScope extends InheritedNotifier<Settings> {
  const SettingsScope({
    super.key,
    required Settings settings,
    required super.child,
  }) : super(notifier: settings);

  /// The settings, without rebuilding when they change.
  static Settings read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope above this widget');
    return scope!.notifier!;
  }

  /// The settings, rebuilding the caller whenever they change.
  static Settings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope above this widget');
    return scope!.notifier!;
  }
}
