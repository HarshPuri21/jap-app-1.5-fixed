import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/progress_service.dart';

/// One calendar day's worth of Daily Review activity, keyed by a
/// `YYYY-MM-DD` string in the user's local time.
class DayActivity {
  int reviews;
  int correct;
  int wrong;

  DayActivity({this.reviews = 0, this.correct = 0, this.wrong = 0});

  factory DayActivity.fromJson(Map<String, dynamic> json) => DayActivity(
        reviews: json['r'] as int? ?? 0,
        correct: json['c'] as int? ?? 0,
        wrong: json['w'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {'r': reviews, 'c': correct, 'w': wrong};
}

/// One entry in the recent-activity feed.
class RecentEvent {
  final String itemId;
  final ReviewCategory category;
  final bool correct;
  final DateTime at;

  RecentEvent({
    required this.itemId,
    required this.category,
    required this.correct,
    required this.at,
  });

  factory RecentEvent.fromJson(Map<String, dynamic> json) => RecentEvent(
        itemId: json['id'] as String,
        category: ReviewCategory.values[json['cat'] as int? ?? 0],
        correct: json['ok'] as bool? ?? false,
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': itemId,
        'cat': category.index,
        'ok': correct,
        'at': at.toIso8601String(),
      };
}

/// Per-category running accuracy, used to surface "weak areas".
class CategoryAccuracy {
  int correct;
  int total;
  CategoryAccuracy({this.correct = 0, this.total = 0});

  double? get pct => total == 0 ? null : correct / total;

  factory CategoryAccuracy.fromJson(Map<String, dynamic> json) =>
      CategoryAccuracy(
        correct: json['c'] as int? ?? 0,
        total: json['t'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {'c': correct, 't': total};
}

/// Real, on-device tracked study activity: streaks, a daily goal, a rolling
/// day-by-day log, per-category accuracy, and a short recent-activity feed.
///
/// This is genuinely new state -- nothing like it existed before this
/// feature -- so it lives in its own store (`study_stats_v1`), entirely
/// separate from `srs_progress_v1` (ProgressService) and the legacy
/// lifetime-accuracy counters in SettingsService. Nothing here is invented:
/// every number is either counted directly from a real rating event, or
/// left absent (never faked) when there isn't enough data yet.
class StatsService extends ChangeNotifier {
  static const _kKey = 'study_stats_v1';
  static const int _kMaxDaysKept = 60; // bounds on-device storage growth
  static const int _kMaxRecentKept = 30;
  static const int kDefaultDailyGoal = 10;

  int dailyGoal = kDefaultDailyGoal;
  int _longestStreak = 0;
  final Map<String, DayActivity> _days = {}; // 'YYYY-MM-DD' -> activity
  final Map<ReviewCategory, CategoryAccuracy> _categoryAccuracy = {};
  final List<RecentEvent> _recent = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        dailyGoal = decoded['goal'] as int? ?? kDefaultDailyGoal;
        _longestStreak = decoded['longest'] as int? ?? 0;
        final days = decoded['days'] as Map<String, dynamic>? ?? {};
        for (final entry in days.entries) {
          _days[entry.key] =
              DayActivity.fromJson(entry.value as Map<String, dynamic>);
        }
        final cats = decoded['cats'] as Map<String, dynamic>? ?? {};
        for (final entry in cats.entries) {
          final idx = int.tryParse(entry.key);
          if (idx == null || idx >= ReviewCategory.values.length) continue;
          _categoryAccuracy[ReviewCategory.values[idx]] =
              CategoryAccuracy.fromJson(entry.value as Map<String, dynamic>);
        }
        final recent = decoded['recent'] as List<dynamic>? ?? [];
        for (final e in recent) {
          _recent.add(RecentEvent.fromJson(e as Map<String, dynamic>));
        }
      }
    } catch (e) {
      debugPrint('StatsService.load failed, starting fresh: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode({
        'goal': dailyGoal,
        'longest': _longestStreak,
        'days': _days.map((k, v) => MapEntry(k, v.toJson())),
        'cats': _categoryAccuracy
            .map((k, v) => MapEntry(k.index.toString(), v.toJson())),
        'recent': _recent.map((e) => e.toJson()).toList(),
      });
      await prefs.setString(_kKey, encoded);
    } catch (e) {
      debugPrint('StatsService.save failed (kept in memory only): $e');
    }
  }

  Future<void> setDailyGoal(int value) async {
    dailyGoal = value.clamp(1, 200).toInt();
    notifyListeners();
    await _save();
  }

  /// Call once per Daily Review rating -- the single hook that feeds every
  /// derived stat below (streak, goal progress, weekly overview, category
  /// accuracy, recent activity).
  Future<void> recordReview({
    required String itemId,
    required ReviewCategory category,
    required bool correct,
  }) async {
    final now = DateTime.now();
    final key = _dateKey(now);
    final day = _days.putIfAbsent(key, () => DayActivity());
    day.reviews += 1;
    if (correct) {
      day.correct += 1;
    } else {
      day.wrong += 1;
    }

    final acc =
        _categoryAccuracy.putIfAbsent(category, () => CategoryAccuracy());
    acc.total += 1;
    if (correct) acc.correct += 1;

    _recent.insert(
      0,
      RecentEvent(itemId: itemId, category: category, correct: correct, at: now),
    );
    if (_recent.length > _kMaxRecentKept) {
      _recent.removeRange(_kMaxRecentKept, _recent.length);
    }

    _trimOldDays();

    final streak = currentStreak;
    if (streak > _longestStreak) _longestStreak = streak;

    notifyListeners();
    await _save();
  }

  void _trimOldDays() {
    if (_days.length <= _kMaxDaysKept) return;
    final keys = _days.keys.toList()..sort();
    final excess = _days.length - _kMaxDaysKept;
    for (var i = 0; i < excess; i++) {
      _days.remove(keys[i]);
    }
  }

  int get reviewsToday => _days[_dateKey(DateTime.now())]?.reviews ?? 0;

  double get todayGoalProgress =>
      dailyGoal == 0 ? 0 : (reviewsToday / dailyGoal).clamp(0.0, 1.0);

  int get longestStreak => _longestStreak > currentStreak ? _longestStreak : currentStreak;

  /// Consecutive days with at least one review, counted backward from
  /// today. If today has no activity yet, the streak isn't broken until
  /// the day actually passes -- so this counts backward from *yesterday*
  /// instead, showing the still-alive streak rather than a premature zero.
  int get currentStreak {
    final today = DateTime.now();
    final todayHasActivity = (_days[_dateKey(today)]?.reviews ?? 0) > 0;
    var cursor = todayHasActivity ? today : today.subtract(const Duration(days: 1));
    var streak = 0;
    while (true) {
      final activity = _days[_dateKey(cursor)];
      if (activity == null || activity.reviews == 0) break;
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Last 7 calendar days (oldest first), for a compact weekly overview.
  /// Days with no recorded activity simply have reviews == 0 -- never
  /// fabricated.
  List<MapEntry<DateTime, DayActivity>> get lastSevenDays {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      final dateOnly = DateTime(d.year, d.month, d.day);
      return MapEntry(dateOnly, _days[_dateKey(d)] ?? DayActivity());
    });
  }

  Map<ReviewCategory, CategoryAccuracy> get categoryAccuracy =>
      Map.unmodifiable(_categoryAccuracy);

  /// Categories with a meaningful sample (>=5 answers) and accuracy under
  /// 70% -- surfaced as "weak areas". Never invents a weak area from too
  /// little data.
  List<ReviewCategory> get weakCategories {
    const minSample = 5;
    const threshold = 0.7;
    return _categoryAccuracy.entries
        .where((e) => e.value.total >= minSample && (e.value.pct ?? 1) < threshold)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) =>
          (_categoryAccuracy[a]!.pct ?? 1).compareTo(_categoryAccuracy[b]!.pct ?? 1));
  }

  List<RecentEvent> get recentEvents => List.unmodifiable(_recent);
}
