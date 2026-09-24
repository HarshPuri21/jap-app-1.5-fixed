import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';
import '../services/progress_service.dart';
import '../services/stats_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

/// "How am I doing?" -- everything here is either counted directly from
/// StatsService/ProgressService, or left out entirely when there isn't
/// enough data yet. Nothing on this screen is a placeholder number.
class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AudioService>().stopMenuMusic();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stats = context.watch<StatsService>();
    final progress = context.watch<ProgressService>();
    final settings = context.watch<SettingsService>();
    final ds = DataService.instance;

    final studied = progress.studiedCountByCategory();
    final totals = <ReviewCategory, int>{
      ReviewCategory.kanji: ds.kanjiEntries.length,
      ReviewCategory.vocab: ds.vocab.length,
      ReviewCategory.kanaHiragana: ds.kanaByType('hiragana').length,
      ReviewCategory.kanaKatakana: ds.kanaByType('katakana').length,
    };

    final answered = settings.statsAnsweredTotal;
    final correct = settings.statsCorrectTotal;
    final overallPct = answered == 0 ? null : (100 * correct / answered).round();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.xxl,
                  ),
                  children: [
                    _streakCard(context, stats),
                    SizedBox(height: t.spacing.md),
                    _goalCard(context, stats),
                    SizedBox(height: t.spacing.xl),
                    const ThemedSectionLabel('This week'),
                    _weekCard(context, stats),
                    SizedBox(height: t.spacing.xl),
                    const ThemedSectionLabel('Learning progress'),
                    _categoryProgressCard(context, studied, totals),
                    SizedBox(height: t.spacing.md),
                    _untrackedNote(context),
                    if (overallPct != null) ...[
                      SizedBox(height: t.spacing.xl),
                      const ThemedSectionLabel('Overall accuracy'),
                      _accuracyCard(context, correct, answered, overallPct),
                    ],
                    if (stats.weakCategories.isNotEmpty) ...[
                      SizedBox(height: t.spacing.xl),
                      const ThemedSectionLabel('Could use more practice'),
                      _weakAreasCard(context, stats),
                    ],
                    if (stats.recentEvents.isNotEmpty) ...[
                      SizedBox(height: t.spacing.xl),
                      const ThemedSectionLabel('Recent activity'),
                      _recentActivityCard(context, stats, progress),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _streakCard(BuildContext context, StatsService stats) {
    final t = context.tokens;
    final streak = stats.currentStreak;
    return ThemedSurface(
      level: SurfaceLevel.elevated,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md + 2),
      tint: streak > 0 ? t.colors.warn : null,
      tintStrength: 0.5,
      child: Row(
        children: [
          ThemedIconPlate(
            icon: Icons.local_fire_department_rounded,
            color: streak > 0 ? t.colors.warn : t.colors.textTertiary,
            size: 54,
            iconSize: 26,
          ),
          SizedBox(width: t.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  streak == 0
                      ? 'No streak yet'
                      : '$streak day${streak == 1 ? '' : 's'} streak',
                  style: t.text.cardTitle,
                ),
                const SizedBox(height: 3),
                Text(
                  streak == 0
                      ? 'Complete a Daily Review today to start one'
                      : 'Longest: ${stats.longestStreak} day${stats.longestStreak == 1 ? '' : 's'}',
                  style: t.text.secondary.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(BuildContext context, StatsService stats) {
    final t = context.tokens;
    final today = stats.reviewsToday;
    final goal = stats.dailyGoal;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's goal", style: t.text.body),
              Text(
                '$today / $goal',
                style: t.text.body.copyWith(
                  color: t.colors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: t.spacing.xs),
          ThemedProgressBar(value: stats.todayGoalProgress, height: 8),
        ],
      ),
    );
  }

  Widget _weekCard(BuildContext context, StatsService stats) {
    final t = context.tokens;
    final days = stats.lastSevenDays;
    final maxReviews = days.fold<int>(
        1, (m, e) => e.value.reviews > m ? e.value.reviews : m);
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((e) {
          final date = e.key;
          final reviews = e.value.reviews;
          final isToday = _isSameDay(date, DateTime.now());
          final heightFactor = reviews == 0 ? 0.06 : reviews / maxReviews;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$reviews',
                style: t.text.caption.copyWith(
                  fontSize: 10.5,
                  color: reviews == 0
                      ? t.colors.textTertiary
                      : t.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 18,
                height: 56 * heightFactor.clamp(0.06, 1.0),
                decoration: BoxDecoration(
                  color: (isToday ? t.colors.accent : t.colors.textTertiary)
                      .withOpacity(reviews == 0 ? 0.25 : 0.9),
                  borderRadius: BorderRadius.circular(t.radii.xs),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[date.weekday - 1],
                style: t.text.caption.copyWith(
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday ? t.colors.accent : t.colors.textTertiary,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _categoryProgressCard(
    BuildContext context,
    Map<ReviewCategory, int> studied,
    Map<ReviewCategory, int> totals,
  ) {
    final t = context.tokens;
    const order = [
      ReviewCategory.kanji,
      ReviewCategory.vocab,
      ReviewCategory.kanaHiragana,
      ReviewCategory.kanaKatakana,
    ];
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        children: order.map((cat) {
          final total = totals[cat] ?? 0;
          final done = (studied[cat] ?? 0).clamp(0, total);
          final frac = total == 0 ? 0.0 : done / total;
          final isLast = cat == order.last;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : t.spacing.sm + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(reviewCategoryLabel(cat), style: t.text.body),
                    Text('$done / $total', style: t.text.caption),
                  ],
                ),
                SizedBox(height: t.spacing.xxs),
                ThemedProgressBar(value: frac, height: 6),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _untrackedNote(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(top: t.spacing.xs, left: 4),
      child: Text(
        "Sentences & Radicals aren't in Daily Review's spaced repetition yet, "
        'so they have no progress bar here.',
        style: t.text.caption.copyWith(color: t.colors.textTertiary),
      ),
    );
  }

  Widget _accuracyCard(
      BuildContext context, int correct, int answered, int pct) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Lifetime, across all quizzes & tests', style: t.text.caption),
                const SizedBox(height: 5),
                ThemedProgressBar(value: pct / 100, height: 6),
              ],
            ),
          ),
          SizedBox(width: t.spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: t.text.title.copyWith(
                  color: t.colors.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text('$correct / $answered', style: t.text.caption),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weakAreasCard(BuildContext context, StatsService stats) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: stats.weakCategories.map((cat) {
          final acc = stats.categoryAccuracy[cat]!;
          final pct = ((acc.pct ?? 0) * 100).round();
          final isLast = cat == stats.weakCategories.last;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : t.spacing.sm),
            child: Row(
              children: [
                Icon(Icons.trending_down_rounded, color: t.colors.warn, size: 18),
                SizedBox(width: t.spacing.xs),
                Expanded(
                  child: Text(reviewCategoryLabel(cat), style: t.text.body),
                ),
                Text(
                  '$pct% correct (${acc.total} reviewed)',
                  style: t.text.caption.copyWith(color: t.colors.warn),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _recentActivityCard(
    BuildContext context,
    StatsService stats,
    ProgressService progress,
  ) {
    final t = context.tokens;
    final events = stats.recentEvents.take(10).toList();
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.xs,
      ),
      child: Column(
        children: events.map((e) {
          final item = progress.resolveItem(e.itemId);
          final label = _labelFor(item, e.category);
          final isLast = e == events.last;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: t.spacing.xs + 2),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      e.correct
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 16,
                      color: e.correct ? t.colors.good : t.colors.bad,
                    ),
                    SizedBox(width: t.spacing.xs),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.body.copyWith(fontSize: 13.5),
                      ),
                    ),
                    Text(reviewCategoryLabel(e.category), style: t.text.caption),
                  ],
                ),
                if (!isLast) ...[
                  SizedBox(height: t.spacing.xs),
                  Divider(height: 1, color: t.colors.border),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _labelFor(dynamic item, ReviewCategory cat) {
    if (item == null) return '(no longer available)';
    try {
      // Duck-typed: VocabEntry/KanjiEntry/KanaEntry all expose a Japanese
      // display field under a different name, so read the one that exists.
      final dyn = item as dynamic;
      if (cat == ReviewCategory.vocab) return dyn.jp as String;
      if (cat == ReviewCategory.kanji) return dyn.kanji as String;
      return dyn.character as String;
    } catch (_) {
      return '?';
    }
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Progress',
      subtitle: '進捗',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}
