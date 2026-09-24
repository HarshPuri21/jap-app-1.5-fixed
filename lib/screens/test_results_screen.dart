import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_surface.dart';
import 'test_run_screen.dart' show TestReviewEntry;

class TestResultsScreen extends StatelessWidget {
  final int score;
  final int total;

  /// Every question from the run, revealed here for the first time --
  /// Take a Test never shows correct/wrong mid-test, only once it's over.
  final List<TestReviewEntry> review;

  const TestResultsScreen({
    super.key,
    required this.score,
    required this.total,
    this.review = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pct = total == 0 ? 0 : (100 * score / total).round();
    final (emoji, message) = _messageFor(pct);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: t.spacing.xl,
                vertical: t.spacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 58)),
                  SizedBox(height: t.spacing.md),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: t.text.display.copyWith(fontSize: 22),
                  ),
                  SizedBox(height: t.spacing.xl),
                  ThemedSurface(
                    level: SurfaceLevel.elevated,
                    radius: t.radii.lg,
                    padding: EdgeInsets.symmetric(
                      horizontal: t.spacing.xl,
                      vertical: t.spacing.lg,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$score / $total',
                          style: t.text.display.copyWith(
                            color: t.colors.accent,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: t.spacing.xs),
                        Text('$pct% correct', style: t.text.secondary),
                        SizedBox(height: t.spacing.sm),
                        SizedBox(
                          width: 180,
                          child:
                              ThemedProgressBar(value: pct / 100, height: 6),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: t.spacing.xxl),
                  ThemedButton(
                    label: 'Try Another Test',
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      context.read<AudioService>().playMenuClick();
                      Navigator.of(context).pop();
                    },
                  ),
                  SizedBox(height: t.spacing.sm),
                  ThemedButton(
                    label: 'Back to Home',
                    variant: ThemedButtonVariant.secondary,
                    onPressed: () {
                      context.read<AudioService>().playMenuClick();
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                  if (review.isNotEmpty) ...[
                    SizedBox(height: t.spacing.xl),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('REVIEW ANSWERS', style: t.text.overline),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ...review.asMap().entries.map(
                          (e) => Padding(
                            padding: EdgeInsets.only(bottom: t.spacing.xs),
                            child: _ReviewRow(index: e.key + 1, entry: e.value),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (String, String) _messageFor(int pct) {
    if (pct >= 90) return ('🎉', 'Excellent work!');
    if (pct >= 70) return ('😊', 'Great job!');
    if (pct >= 50) return ('🙂', 'Good effort — keep practicing!');
    return ('📚', 'Keep at it — practice makes perfect!');
  }
}

/// One row of the post-test review: the question, what was chosen, and
/// (only if wrong) the correct answer -- the first moment either is shown.
class _ReviewRow extends StatelessWidget {
  final int index;
  final TestReviewEntry entry;
  const _ReviewRow({required this.index, required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = entry.isCorrect ? t.colors.good : t.colors.bad;

    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      allowHeavyEffects: false,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.sm + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            entry.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 19,
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.prompt,
                  style: t.text.jp(
                    entry.isSingleChar ? 22 : 15,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.isCorrect
                      ? 'Your answer: ${entry.chosen}'
                      : 'You chose: ${entry.chosen}  →  correct: ${entry.answer}',
                  style: t.text.caption.copyWith(color: color),
                ),
              ],
            ),
          ),
          SizedBox(width: t.spacing.xs),
          Text('#$index', style: t.text.caption),
        ],
      ),
    );
  }
}
