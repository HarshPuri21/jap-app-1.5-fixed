import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/progress_service.dart';
import '../services/stats_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';
import 'daily_review_screen.dart';

/// "What do I need to study today?" -- the landing screen the home
/// screen's Daily Review card opens. Shows the numbers, then hands off to
/// the existing review flow (DailyReviewScreen) via Start Review, rather
/// than being a second review engine itself.
class DailyReviewSummaryScreen extends StatefulWidget {
  const DailyReviewSummaryScreen({super.key});

  @override
  State<DailyReviewSummaryScreen> createState() =>
      _DailyReviewSummaryScreenState();
}

class _DailyReviewSummaryScreenState extends State<DailyReviewSummaryScreen> {
  late List<String> _queue;

  @override
  void initState() {
    super.initState();
    context.read<AudioService>().stopMenuMusic();
    // Built once here so the breakdown below reflects exactly what Start
    // Review is about to hand you -- not just a live due-count that could
    // shift by the time you tap through.
    _queue = context.read<ProgressService>().buildDailyQueue();
  }

  void _startReview() {
    context.read<AudioService>().playLessonClick();
    Navigator.of(context)
        .push(themedRoute(context, (_) => const DailyReviewScreen()))
        .then((_) {
      // The queue's composition (what's due) may have changed after a
      // review session, so recompute for an accurate re-display.
      if (mounted) {
        setState(() {
          _queue = context.read<ProgressService>().buildDailyQueue();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progressService = context.watch<ProgressService>();
    final stats = context.watch<StatsService>();

    final due = _queue.length;
    final completedToday = stats.reviewsToday;
    final estMinutes = due == 0 ? 0 : ((due * 30) / 60).ceil();

    final counts = <ReviewCategory, int>{};
    for (final id in _queue) {
      final cat = progressService.categoryOf(id);
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    final breakdown = ReviewCategory.values
        .where((c) => c != ReviewCategory.unknown && (counts[c] ?? 0) > 0)
        .toList();

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
                    t.spacing.xl,
                  ),
                  children: [
                    _statsRow(context, due, completedToday, estMinutes),
                    if (breakdown.isNotEmpty) ...[
                      SizedBox(height: t.spacing.xl),
                      const ThemedSectionLabel('Breakdown'),
                      _breakdownCard(context, breakdown, counts),
                    ],
                    if (stats.weakCategories.isNotEmpty) ...[
                      SizedBox(height: t.spacing.xl),
                      const ThemedSectionLabel('Could use more practice'),
                      _weakCard(context, stats),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.spacing.gutter,
                  0,
                  t.spacing.gutter,
                  t.spacing.md,
                ),
                child: ThemedButton(
                  label: due == 0 ? "Nothing due — review anyway" : 'Start Review',
                  icon: Icons.play_arrow_rounded,
                  variant: due == 0
                      ? ThemedButtonVariant.secondary
                      : ThemedButtonVariant.primary,
                  onPressed: _startReview,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsRow(
      BuildContext context, int due, int completedToday, int estMinutes) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: _statTile(
            context,
            icon: Icons.menu_book_rounded,
            value: due == 0 ? '0' : '$due',
            label: due == 0 ? 'Nothing due today' : 'Due now',
          ),
        ),
        SizedBox(width: t.spacing.sm),
        Expanded(
          child: _statTile(
            context,
            icon: Icons.check_circle_outline_rounded,
            value: '$completedToday',
            label: 'Completed today',
          ),
        ),
        SizedBox(width: t.spacing.sm),
        Expanded(
          child: _statTile(
            context,
            icon: Icons.schedule_rounded,
            value: due == 0 ? '—' : '~$estMinutes',
            label: due == 0 ? '' : 'Minutes',
          ),
        ),
      ],
    );
  }

  Widget _statTile(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.xs,
        vertical: t.spacing.sm + 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: t.colors.accent, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: t.text.title.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: t.text.caption.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _breakdownCard(
    BuildContext context,
    List<ReviewCategory> breakdown,
    Map<ReviewCategory, int> counts,
  ) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        children: breakdown.map((cat) {
          final isLast = cat == breakdown.last;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : t.spacing.sm),
            child: Row(
              children: [
                Expanded(child: Text(reviewCategoryLabel(cat), style: t.text.body)),
                Text(
                  '${counts[cat]}',
                  style: t.text.body.copyWith(
                    color: t.colors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _weakCard(BuildContext context, StatsService stats) {
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
                Expanded(child: Text(reviewCategoryLabel(cat), style: t.text.body)),
                Text('$pct%', style: t.text.caption.copyWith(color: t.colors.warn)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Daily Review',
      subtitle: '復習',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}
