import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item_progress.dart';
import '../models/kana_entry.dart';
import 'data_service.dart';

/// How many never-studied items to introduce per day, on top of whatever
/// is genuinely due for review. Reviews are never capped -- only new-item
/// introduction is -- otherwise day one would dump all ~1,069 items into
/// a single overwhelming queue. 20/day is the same default Anki ships with.
const int kNewItemsPerDay = 20;

/// A stable identity for a vocab word, kanji, or kana character, used as
/// the progress-map key. Vocab and kanji sometimes share characters (a
/// kanji and a vocab word can both be "食"), so both are prefixed to stay
/// unambiguous. Kana follows the same `kana:<character>` scheme the
/// implementation notes ask for, so it coexists in the same map/queue as
/// kanji and vocab without a second progress system.
String vocabItemId(String jp) => 'vocab:$jp';
String kanjiItemId(String kanji) => 'kanji:$kanji';
String kanaItemId(String character) => 'kana:$character';

/// The section an item belongs to, for grouping/labelling a mixed review
/// queue ("present all in different sections"). Resolved from the item id
/// prefix plus (for kana) a DataService lookup to tell hiragana and
/// katakana apart.
enum ReviewCategory { kanji, vocab, kanaHiragana, kanaKatakana, unknown }

String reviewCategoryLabel(ReviewCategory c) {
  switch (c) {
    case ReviewCategory.kanji:
      return 'Kanji';
    case ReviewCategory.vocab:
      return 'Vocabulary';
    case ReviewCategory.kanaHiragana:
      return 'Hiragana';
    case ReviewCategory.kanaKatakana:
      return 'Katakana';
    case ReviewCategory.unknown:
      return 'Other';
  }
}

class ProgressService extends ChangeNotifier {
  static const _kProgressMap = 'srs_progress_v1';

  final Map<String, ItemProgress> _progress = {};
  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kProgressMap);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _progress[entry.key] =
              ItemProgress.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    } catch (e) {
      // A corrupted or unreadable prefs blob shouldn't take the app down --
      // worst case, progress resets, which is far better than a crash loop.
      debugPrint('ProgressService.load failed, starting fresh: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _progress.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString(_kProgressMap, encoded);
    } catch (e) {
      debugPrint('ProgressService.save failed (progress kept in memory): $e');
    }
  }

  ItemProgress? progressFor(String itemId) => _progress[itemId];

  bool hasBeenStudied(String itemId) => _progress.containsKey(itemId);

  /// Records a rating for an item, creating its progress record on first
  /// review. Persists immediately -- review volume is human-paced (button
  /// taps), so there's no performance reason to batch writes, and immediate
  /// persistence is what makes "is progress saved reliably" actually true.
  Future<void> rate(String itemId, Rating rating) async {
    final item = _progress[itemId] ?? ItemProgress();
    item.apply(rating);
    _progress[itemId] = item;
    notifyListeners();
    await _save();
  }

  /// All vocab + kanji + kana item IDs currently known to the app (used to
  /// find which ones are "new", i.e. absent from the progress map).
  List<String> _allItemIds() {
    final ds = DataService.instance;
    return [
      ...ds.vocab.map((v) => vocabItemId(v.jp)),
      ...ds.kanjiEntries.map((k) => kanjiItemId(k.kanji)),
      ...ds.kana.map((k) => kanaItemId(k.character)),
    ];
  }

  int get dueCount {
    final now = DateTime.now();
    return _progress.values.where((p) => !p.dueDate.isAfter(now)).length;
  }

  int get newAvailableCount {
    final known = _progress.keys.toSet();
    return _allItemIds().where((id) => !known.contains(id)).length;
  }

  /// How many items today's queue will contain, without actually building
  /// (and shuffling) it -- cheap enough to call from the home screen badge.
  int get todayQueueSize {
    final due = dueCount;
    final newAvail = newAvailableCount;
    return due + (newAvail < kNewItemsPerDay ? newAvail : kNewItemsPerDay);
  }

  /// Today's review queue: every item genuinely due, plus up to
  /// [kNewItemsPerDay] never-studied items, shuffled together.
  List<String> buildDailyQueue({int newItemCap = kNewItemsPerDay}) {
    final now = DateTime.now();
    final due = <String>[];
    final fresh = <String>[];

    for (final id in _allItemIds()) {
      final p = _progress[id];
      if (p == null) {
        fresh.add(id);
      } else if (!p.dueDate.isAfter(now)) {
        due.add(id);
      }
    }

    fresh.shuffle();
    final newBatch = fresh.take(newItemCap).toList();
    final queue = [...due, ...newBatch];
    queue.shuffle();
    return queue;
  }

  /// Resolves an item ID back to its displayable vocab/kanji/kana entry.
  /// Returns null if the ID doesn't match anything currently loaded
  /// (defensive -- e.g. app data changed between sessions).
  dynamic resolveItem(String itemId) {
    final ds = DataService.instance;
    if (itemId.startsWith('vocab:')) {
      final jp = itemId.substring('vocab:'.length);
      for (final v in ds.vocab) {
        if (v.jp == jp) return v;
      }
    } else if (itemId.startsWith('kanji:')) {
      final k = itemId.substring('kanji:'.length);
      for (final entry in ds.kanjiEntries) {
        if (entry.kanji == k) return entry;
      }
    } else if (itemId.startsWith('kana:')) {
      final c = itemId.substring('kana:'.length);
      for (final entry in ds.kana) {
        if (entry.character == c) return entry;
      }
    }
    return null;
  }

  /// Which section [itemId] belongs to, for grouping a mixed review queue.
  ReviewCategory categoryOf(String itemId) {
    if (itemId.startsWith('kanji:')) return ReviewCategory.kanji;
    if (itemId.startsWith('vocab:')) return ReviewCategory.vocab;
    if (itemId.startsWith('kana:')) {
      final item = resolveItem(itemId);
      if (item is KanaEntry) {
        return item.isHiragana
            ? ReviewCategory.kanaHiragana
            : ReviewCategory.kanaKatakana;
      }
    }
    return ReviewCategory.unknown;
  }

  /// Due-count and total-progress broken down by [ReviewCategory], for the
  /// Daily Review screen's "different sections" breakdown and the Progress
  /// Dashboard's per-category rows.
  Map<ReviewCategory, int> dueCountByCategory() {
    final now = DateTime.now();
    final counts = <ReviewCategory, int>{};
    for (final entry in _progress.entries) {
      if (entry.value.dueDate.isAfter(now)) continue;
      final cat = categoryOf(entry.key);
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  /// How many items of each category have ever been studied (i.e. have a
  /// progress record at all) -- used for "learning progress by category".
  Map<ReviewCategory, int> studiedCountByCategory() {
    final counts = <ReviewCategory, int>{};
    for (final key in _progress.keys) {
      final cat = categoryOf(key);
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }
}
