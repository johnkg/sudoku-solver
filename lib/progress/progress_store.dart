import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/text.dart';

/// How well the player solved a puzzle.
class PuzzleRecord {
  const PuzzleRecord({
    required this.mistakes,
    required this.hints,
    this.seconds,
  });

  factory PuzzleRecord.fromJson(Map<String, Object?> json) => PuzzleRecord(
    mistakes: json['mistakes']! as int,
    hints: json['hints']! as int,
    seconds: json['seconds'] as int?,
  );

  final int mistakes;
  final int hints;

  /// The fastest solve in seconds, or null for results saved before the clock
  /// existed.
  final int? seconds;

  /// 3 for a clean solve, minus one for any mistakes and one for any hints.
  /// The most stars a solve can earn.
  static const maxStars = 3;

  int get stars => maxStars - (mistakes > 0 ? 1 : 0) - (hints > 0 ? 1 : 0);

  bool isBetterThan(PuzzleRecord other) =>
      mistakes + hints < other.mistakes + other.hints;

  /// This result or [other], whichever is better, with the faster time of
  /// the two (the fastest solve need not be the cleanest).
  PuzzleRecord bestWith(PuzzleRecord other) {
    final best = other.isBetterThan(this) ? other : this;
    final times = [?seconds, ?other.seconds];
    return PuzzleRecord(
      mistakes: best.mistakes,
      hints: best.hints,
      seconds: times.isEmpty ? null : times.reduce((a, b) => a < b ? a : b),
    );
  }

  Map<String, Object?> toJson() => {
    'mistakes': mistakes,
    'hints': hints,
    'seconds': ?seconds,
  };
}

/// How often the player got a technique right when asked to spot or apply it.
class TechniqueStat {
  const TechniqueStat(this.right, this.wrong);

  factory TechniqueStat.fromJson(Map<String, Object?> json) =>
      TechniqueStat(json['right']! as int, json['wrong']! as int);

  final int right;
  final int wrong;

  int get attempts => right + wrong;

  /// Share of attempts that went right, 1 when there are none yet.
  double get accuracy => attempts == 0 ? 1 : right / attempts;

  Map<String, Object?> toJson() => {'right': right, 'wrong': wrong};
}

/// What the player has done: puzzles solved, games in progress, and whether
/// they skipped the unlocking. Saved to the device when constructed with
/// [load]; [ProgressStore.memory] keeps everything in memory (for tests).
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs, this._now);

  /// A store that is never saved. [now] says what day it is (for the daily
  /// puzzle and its streak); tests pass a fixed day.
  ProgressStore.memory({DateTime Function()? now})
    : _prefs = null,
      _now = now ?? DateTime.now;

  static const _recordsKey = 'progress.records';
  static const _techniquesKey = 'progress.techniques';
  static const _unlockAllKey = 'progress.unlockAll';
  static const _gamePrefix = 'progress.game.';
  static const _dailyKey = 'progress.daily';
  static const _dailyPuzzlePrefix = 'progress.dailyPuzzle.';

  /// Loads saved progress. Unreadable data is ignored. [now] says what day it
  /// is; it defaults to the device clock.
  static Future<ProgressStore> load({DateTime Function()? now}) async {
    final store = ProgressStore._(
      await SharedPreferences.getInstance(),
      now ?? DateTime.now,
    );
    store._read();
    store._pruneDaily();
    return store;
  }

  final SharedPreferences? _prefs;
  final DateTime Function() _now;
  final Map<String, PuzzleRecord> _daily = {};
  final Map<String, String> _dailyPuzzles = {};
  final Map<String, PuzzleRecord> _records = {};
  final Map<String, TechniqueStat> _techniques = {};
  final Map<String, Map<String, Object?>> _games = {};
  bool _unlockAll = false;

  void _read() {
    final prefs = _prefs!;
    _unlockAll = prefs.getBool(_unlockAllKey) ?? false;
    try {
      final saved = jsonDecode(prefs.getString(_recordsKey) ?? '{}');
      for (final entry in (saved as Map<String, Object?>).entries) {
        _records[entry.key] = PuzzleRecord.fromJson(
          entry.value! as Map<String, Object?>,
        );
      }
    } on Object {
      _records.clear();
    }
    try {
      final saved = jsonDecode(prefs.getString(_techniquesKey) ?? '{}');
      for (final entry in (saved as Map<String, Object?>).entries) {
        _techniques[entry.key] = TechniqueStat.fromJson(
          entry.value! as Map<String, Object?>,
        );
      }
    } on Object {
      _techniques.clear();
    }
    try {
      final saved = jsonDecode(prefs.getString(_dailyKey) ?? '{}');
      for (final entry in (saved as Map<String, Object?>).entries) {
        _daily[entry.key] = PuzzleRecord.fromJson(
          entry.value! as Map<String, Object?>,
        );
      }
    } on Object {
      _daily.clear();
    }
    for (final key in prefs.getKeys().where(
      (k) => k.startsWith(_dailyPuzzlePrefix),
    )) {
      final text = prefs.getString(key);
      if (text != null) {
        _dailyPuzzles[key.substring(_dailyPuzzlePrefix.length)] = text;
      }
    }
    for (final key in prefs.getKeys().where((k) => k.startsWith(_gamePrefix))) {
      try {
        _games[key.substring(_gamePrefix.length)] =
            jsonDecode(prefs.getString(key)!) as Map<String, Object?>;
      } on Object {
        prefs.remove(key);
      }
    }
  }

  /// True once the player skipped the unlocking.
  bool get unlockedAll => _unlockAll;

  PuzzleRecord? recordFor(String puzzleId) => _records[puzzleId];

  bool isSolved(String puzzleId) => _records.containsKey(puzzleId);

  int get solvedCount => _records.length;

  /// Every practice result, by puzzle id.
  Map<String, PuzzleRecord> get records => Map.unmodifiable(_records);

  /// Every daily result, by day such as `2026-10-10`.
  Map<String, PuzzleRecord> get dailyRecords => Map.unmodifiable(_daily);

  /// The longest run of days in a row with the daily puzzle solved.
  int get bestDailyStreak {
    final days = [for (final key in _daily.keys) ?DateTime.tryParse(key)]
      ..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in days) {
      final yesterday = DateTime(day.year, day.month, day.day - 1);
      run = previous == yesterday ? run + 1 : 1;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }

  /// How the player has done at each technique, by [Technique.name]. Only
  /// techniques they have been asked about appear.
  Map<String, TechniqueStat> get techniqueStats =>
      Map.unmodifiable(_techniques);

  /// Notes one try at the technique called [name]: spotted or applied right,
  /// or got wrong or needed help with.
  void recordTechnique(String name, {required bool right}) {
    final old = _techniques[name] ?? const TechniqueStat(0, 0);
    _techniques[name] = TechniqueStat(
      old.right + (right ? 1 : 0),
      old.wrong + (right ? 0 : 1),
    );
    _prefs?.setString(
      _techniquesKey,
      jsonEncode({
        for (final e in _techniques.entries) e.key: e.value.toJson(),
      }),
    );
    notifyListeners();
  }

  /// How many daily puzzles the player has solved.
  int get dailySolvedCount => _daily.length;

  /// A saved game for [puzzleId], or null.
  Map<String, Object?>? savedGame(String puzzleId) => _games[puzzleId];

  bool hasSavedGame(String puzzleId) => _games.containsKey(puzzleId);

  /// Remembers a solve, keeping the better of this and any earlier result.
  void recordSolve(
    String puzzleId, {
    required int mistakes,
    required int hints,
    int? seconds,
  }) {
    final record = PuzzleRecord(
      mistakes: mistakes,
      hints: hints,
      seconds: seconds,
    );
    final old = _records[puzzleId];
    _records[puzzleId] = old == null ? record : old.bestWith(record);
    _games.remove(puzzleId);
    _writeRecords();
    _prefs?.remove('$_gamePrefix$puzzleId');
    notifyListeners();
  }

  void saveGame(String puzzleId, Map<String, Object?> game) {
    _games[puzzleId] = game;
    _prefs?.setString('$_gamePrefix$puzzleId', jsonEncode(game));
    notifyListeners();
  }

  void clearGame(String puzzleId) {
    if (_games.remove(puzzleId) == null) return;
    _prefs?.remove('$_gamePrefix$puzzleId');
    notifyListeners();
  }

  /// The current moment, from the injected clock.
  DateTime get today => _now();

  /// Today's date as a key such as `2026-10-10`.
  String get todayKey => dayKey(_now());

  /// The calendar day of [date] as `yyyy-MM-dd`.
  static String dayKey(DateTime date) => formatDayKey(date);

  /// How the player did on the daily puzzle for [dayKey], or null.
  PuzzleRecord? dailyRecord(String dayKey) => _daily[dayKey];

  /// The saved text of the daily puzzle for [dayKey], so it is not searched
  /// for twice.
  String? dailyPuzzleText(String dayKey) => _dailyPuzzles[dayKey];

  void saveDailyPuzzle(String dayKey, String text) {
    _dailyPuzzles[dayKey] = text;
    _prefs?.setString('$_dailyPuzzlePrefix$dayKey', text);
  }

  /// Remembers a daily solve, keeping the better of this and any earlier one.
  void recordDaily(
    String dayKey, {
    required int mistakes,
    required int hints,
    int? seconds,
  }) {
    final record = PuzzleRecord(
      mistakes: mistakes,
      hints: hints,
      seconds: seconds,
    );
    final old = _daily[dayKey];
    _daily[dayKey] = old == null ? record : old.bestWith(record);
    _games.remove(dailyGameId(dayKey));
    _prefs?.remove('$_gamePrefix${dailyGameId(dayKey)}');
    _prefs?.setString(
      _dailyKey,
      jsonEncode({for (final e in _daily.entries) e.key: e.value.toJson()}),
    );
    notifyListeners();
  }

  /// The id a daily puzzle's game is saved under.
  static String dailyGameId(String dayKey) => 'daily-$dayKey';

  /// Days in a row, ending today or yesterday, with the daily puzzle solved.
  /// A streak survives until the end of the day after the last solve.
  int get dailyStreak {
    final today = _now();
    var day = DateTime(today.year, today.month, today.day);
    if (!_daily.containsKey(dayKey(day))) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var streak = 0;
    while (_daily.containsKey(dayKey(day))) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  /// Drops saved puzzles and games from daily puzzles before today. The
  /// results stay, since the streak needs them.
  void _pruneDaily() {
    final today = todayKey;
    final stale = [
      for (final key in _dailyPuzzles.keys)
        if (key != today) key,
    ];
    for (final key in stale) {
      _dailyPuzzles.remove(key);
      _prefs?.remove('$_dailyPuzzlePrefix$key');
    }
    final staleGames = [
      for (final id in _games.keys)
        if (id.startsWith('daily-') && id != dailyGameId(today)) id,
    ];
    for (final id in staleGames) {
      _games.remove(id);
      _prefs?.remove('$_gamePrefix$id');
    }
  }

  void unlockAllLevels() {
    _unlockAll = true;
    _prefs?.setBool(_unlockAllKey, true);
    notifyListeners();
  }

  /// Forgets everything: solves, daily results, games in progress, and the
  /// unlock-all skip.
  void reset() {
    _records.clear();
    _techniques.clear();
    _games.clear();
    _daily.clear();
    _dailyPuzzles.clear();
    _unlockAll = false;
    final prefs = _prefs;
    if (prefs != null) {
      prefs.remove(_recordsKey);
      prefs.remove(_techniquesKey);
      prefs.remove(_unlockAllKey);
      prefs.remove(_dailyKey);
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(_gamePrefix) || key.startsWith(_dailyPuzzlePrefix)) {
          prefs.remove(key);
        }
      }
    }
    notifyListeners();
  }

  void _writeRecords() {
    _prefs?.setString(
      _recordsKey,
      jsonEncode({for (final e in _records.entries) e.key: e.value.toJson()}),
    );
  }
}
