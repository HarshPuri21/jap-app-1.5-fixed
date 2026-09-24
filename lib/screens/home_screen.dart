import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/progress_service.dart';
import '../services/stats_service.dart';
import '../services/audio_service.dart';
import '../services/route_observer.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/mode_card.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_surface.dart';
import 'sentence_mode_screen.dart';
import 'kanji_mode_screen.dart';
import 'flashcard_screen.dart';
import 'test_setup_screen.dart';
import 'settings_screen.dart';
import 'daily_review_summary_screen.dart';
import 'radical_list_screen.dart';
import 'radical_quiz_screen.dart';
import 'kana_home_screen.dart';
import 'progress_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  @override
  void initState() {
    super.initState();
    // Covers the very first appearance (app launch) -- subsequent returns
    // from a lesson screen are covered by didPopNext below, since popping
    // back to an already-built screen does not re-run initState.
    context.read<AudioService>().ensureMenuMusicPlaying();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // We're visible again after a pushed screen (a lesson, settings, etc.)
    // was popped off -- resume the menu music if it isn't already playing.
    context.read<AudioService>().ensureMenuMusicPlaying();
  }

  void _openScreen(Widget screen) {
    context.read<AudioService>().playMenuClick();
    Navigator.of(context).push(themedRoute(context, (_) => screen));
  }

  /// Calm, distinguishable hues for the learning modes, derived from the
  /// active theme so they change with it rather than being hard-coded.
  List<Color> _modeHues(ThemeTokens t) => [
        t.colors.accent,
        Color.lerp(t.colors.accent, const Color(0xFF6366F1), 0.55)!,
        t.colors.good,
        Color.lerp(t.colors.accent, t.colors.good, 0.5)!,
        t.colors.warn,
        Color.lerp(t.colors.warn, t.colors.bad, 0.35)!,
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progress = context.watch<ProgressService>();
    final stats = context.watch<StatsService>();
    final queueSize = progress.todayQueueSize;
    final hues = _modeHues(t);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.xl,
                  ),
                  children: [
                    // The two compact dashboard cards, side by side -- "how
                    // am I doing" and "what do I need to study today",
                    // above every learning-mode entry per the spec.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _DailyProgressCard(
                            streak: stats.currentStreak,
                            goalProgress: stats.todayGoalProgress,
                            reviewsToday: stats.reviewsToday,
                            dailyGoal: stats.dailyGoal,
                            onTap: () =>
                                _openScreen(const ProgressDashboardScreen()),
                          ),
                        ),
                        SizedBox(width: t.spacing.sm),
                        Expanded(
                          child: _DailyReviewCard(
                            queueSize: queueSize,
                            onTap: () =>
                                _openScreen(const DailyReviewSummaryScreen()),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: t.spacing.xl),
                    const ThemedSectionLabel('Practice'),
                    ModeCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Learn Sentences',
                      subtitle: '320 example sentences, easy → hard',
                      accentColor: hues[0],
                      onTap: () => _openScreen(const SentenceModeScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.brush_outlined,
                      title: 'Learn Kanji',
                      subtitle: '536 kanji with readings & breakdowns',
                      accentColor: hues[1],
                      onTap: () => _openScreen(const KanjiModeScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.style_outlined,
                      title: 'Flashcards',
                      subtitle: 'Swipe through vocab & kanji',
                      accentColor: hues[2],
                      onTap: () => _openScreen(const FlashcardScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.translate_rounded,
                      title: 'Hiragana / Katakana',
                      subtitle: '269 kana — all groups, quiz included',
                      accentColor: Color.lerp(hues[2], hues[4], 0.5)!,
                      onTap: () => _openScreen(const KanaHomeScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.category_outlined,
                      title: 'Radicals',
                      subtitle: '280 radicals — browse & search',
                      accentColor: hues[3],
                      onTap: () => _openScreen(const RadicalListScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.extension_outlined,
                      title: 'Radical Quiz',
                      subtitle: 'Match each radical to its meaning',
                      accentColor: hues[4],
                      onTap: () => _openScreen(const RadicalQuizScreen()),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.quiz_outlined,
                      title: 'Take a Test',
                      subtitle: 'Timed quiz with a final score',
                      accentColor: hues[5],
                      onTap: () => _openScreen(const TestSetupScreen()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The masthead. Deliberately not a themed bar: on the home screen the
  /// title reads as printed onto the backdrop, with the surfaces beginning
  /// below it -- that contrast is what gives the cards their depth.
  Widget _buildHeader(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.gutter,
        t.spacing.md,
        t.spacing.sm,
        t.spacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '日本語トレーニング',
                  style: t.text
                      .jp(13, color: t.colors.textSecondary)
                      .copyWith(letterSpacing: 3),
                ),
                const SizedBox(height: 4),
                Text('Nihongo Trainer', style: t.text.display),
              ],
            ),
          ),
          SizedBox(width: t.spacing.xs),
          Padding(
            padding: EdgeInsets.only(top: 6, right: t.spacing.xs),
            child: ThemedIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onPressed: () => _openScreen(const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "how am I doing" card -- one of the two dashboard cards that sit
/// above the learning-mode list. Deliberately terse: icon, streak, a hairline
/// goal bar. The full picture lives one tap away in the Progress Dashboard.
class _DailyProgressCard extends StatelessWidget {
  final int streak;
  final double goalProgress; // 0..1
  final int reviewsToday;
  final int dailyGoal;
  final VoidCallback onTap;

  const _DailyProgressCard({
    required this.streak,
    required this.goalProgress,
    required this.reviewsToday,
    required this.dailyGoal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasStreak = streak > 0;
    final accent = hasStreak ? t.colors.warn : t.colors.textTertiary;

    return ThemedCard(
      onTap: onTap,
      level: SurfaceLevel.elevated,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.sm + 2),
      tint: hasStreak ? t.colors.warn : null,
      tintStrength: 0.5,
      semanticLabel: hasStreak
          ? 'Daily progress, $streak day streak, $reviewsToday of $dailyGoal today'
          : 'Daily progress, no streak yet',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: accent, size: 20),
              SizedBox(width: t.spacing.xs),
              Expanded(
                child: Text(
                  'DAILY PROGRESS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.overline.copyWith(fontSize: 10),
                ),
              ),
            ],
          ),
          SizedBox(height: t.spacing.xs),
          Text(
            hasStreak ? '$streak day streak' : 'No streak yet',
            style: t.text.cardTitle.copyWith(fontSize: 15.5),
          ),
          SizedBox(height: t.spacing.xs),
          ThemedProgressBar(value: goalProgress, height: 5, color: accent),
          const SizedBox(height: 4),
          Text('$reviewsToday / $dailyGoal goal', style: t.text.caption),
        ],
      ),
    );
  }
}

/// Compact "what do I need to study today" card -- the other dashboard
/// card. Tapping goes straight into the existing Daily Review flow.
class _DailyReviewCard extends StatelessWidget {
  final int queueSize;
  final VoidCallback onTap;
  const _DailyReviewCard({required this.queueSize, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasReviews = queueSize > 0;
    final accent = hasReviews ? t.colors.accent : t.colors.good;
    // A light per-review time estimate (roughly 30s/item), shown only when
    // there's something due -- never a fabricated number when the queue's
    // empty.
    final estMinutes = hasReviews ? ((queueSize * 30) / 60).ceil() : 0;

    return ThemedCard(
      onTap: onTap,
      level: SurfaceLevel.elevated,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.sm + 2),
      tint: accent,
      tintStrength: hasReviews ? 0.85 : 0.5,
      semanticLabel: hasReviews
          ? 'Daily review, $queueSize items due'
          : 'Daily review, all caught up',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                hasReviews ? Icons.menu_book_rounded : Icons.check_rounded,
                color: accent,
                size: 20,
              ),
              SizedBox(width: t.spacing.xs),
              Expanded(
                child: Text(
                  'DAILY REVIEW',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.overline.copyWith(fontSize: 10),
                ),
              ),
            ],
          ),
          SizedBox(height: t.spacing.xs),
          Text(
            hasReviews ? '$queueSize reviews due' : 'All caught up',
            style: t.text.cardTitle.copyWith(fontSize: 15.5),
          ),
          SizedBox(height: t.spacing.xs),
          ThemedProgressBar(
            value: hasReviews ? 1.0 : 0.0,
            height: 5,
            color: accent,
          ),
          const SizedBox(height: 4),
          Text(
            hasReviews ? '~$estMinutes min' : 'Nothing due today',
            style: t.text.caption,
          ),
        ],
      ),
    );
  }
}
