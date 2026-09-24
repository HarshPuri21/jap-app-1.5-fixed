import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/mode_card.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import 'kana_group_list_screen.dart';
import 'kana_quiz_screen.dart';

/// Entry point for the Kana section: choose Hiragana or Katakana to browse
/// by group, or jump straight into the mixed Kana Quiz.
class KanaHomeScreen extends StatefulWidget {
  const KanaHomeScreen({super.key});

  @override
  State<KanaHomeScreen> createState() => _KanaHomeScreenState();
}

class _KanaHomeScreenState extends State<KanaHomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AudioService>().stopMenuMusic();
  }

  void _open(Widget screen) {
    context.read<AudioService>().playLessonClick();
    Navigator.of(context).push(themedRoute(context, (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ds = DataService.instance;
    final hiraganaCount = ds.kanaByType('hiragana').length;
    final katakanaCount = ds.kanaByType('katakana').length;

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
                    ModeCard(
                      icon: Icons.text_fields_rounded,
                      title: 'Hiragana',
                      subtitle: '$hiraganaCount characters — basic through yōon',
                      accentColor: t.colors.accent,
                      onTap: () =>
                          _open(const KanaGroupListScreen(type: 'hiragana')),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.font_download_outlined,
                      title: 'Katakana',
                      subtitle:
                          '$katakanaCount characters — including extended combos',
                      accentColor: Color.lerp(
                          t.colors.accent, const Color(0xFF6366F1), 0.55)!,
                      onTap: () =>
                          _open(const KanaGroupListScreen(type: 'katakana')),
                    ),
                    SizedBox(height: t.spacing.xl),
                    const ThemedSectionLabel('Practice'),
                    ModeCard(
                      icon: Icons.quiz_outlined,
                      title: 'Kana Quiz',
                      subtitle: 'Kana ↔ romaji, any group',
                      accentColor: t.colors.good,
                      onTap: () => _open(const KanaQuizScreen()),
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

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Hiragana & Katakana',
      subtitle: '仮名',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}
