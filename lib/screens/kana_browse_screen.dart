import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/kana_entry.dart';
import '../services/data_service.dart';
import '../services/progress_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_definition.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_surface.dart';
import '../widgets/themed/themed_controls.dart';

/// A grid of every kana in one type+group. Tapping a tile opens a compact
/// detail sheet -- romaji, pronunciation notes, and its paired kana --
/// rather than a whole new screen, keeping this a first pass focused on
/// browsing + recognition rather than a deep reference app.
class KanaBrowseScreen extends StatefulWidget {
  final String type;
  final String group;
  const KanaBrowseScreen({super.key, required this.type, required this.group});

  @override
  State<KanaBrowseScreen> createState() => _KanaBrowseScreenState();
}

class _KanaBrowseScreenState extends State<KanaBrowseScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AudioService>().stopMenuMusic();
  }

  void _openDetail(KanaEntry k) {
    context.read<AudioService>().playLessonClick();
    showThemedDialog(
      context: context,
      title: kanaGroupLabel(k.group),
      content: _KanaDetail(entry: k),
      actions: [
        ThemedButton(
          label: 'Close',
          expand: false,
          variant: ThemedButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final entries = DataService.instance.kanaByGroup(widget.type, widget.group);
    final progress = context.watch<ProgressService>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          'Nothing in this group yet.',
                          style: t.text.secondary,
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          t.spacing.gutter,
                          t.spacing.xs,
                          t.spacing.gutter,
                          t.spacing.xl,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final k = entries[index];
                          final studied = progress
                              .hasBeenStudied(kanaItemId(k.character));
                          return _kanaTile(context, k, studied);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kanaTile(BuildContext context, KanaEntry k, bool studied) {
    final t = context.tokens;
    return ThemedCard(
      onTap: () => _openDetail(k),
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      allowHeavyEffects: false,
      selected: studied,
      padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
      semanticLabel: '${k.character}, ${k.romaji}${studied ? ", studied" : ""}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(k.character, style: t.text.jp(30, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            k.romaji,
            style: t.text.caption.copyWith(
              color: t.colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: kanaGroupLabel(widget.group),
      subtitle: widget.type == 'hiragana' ? 'ひらがな' : 'カタカナ',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}

class _KanaDetail extends StatelessWidget {
  final KanaEntry entry;
  const _KanaDetail({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThemedReveal(
          moment: ThemeMoment.kanjiReveal,
          child: Text(entry.character, style: t.text.jp(72, weight: FontWeight.w700)),
        ),
        SizedBox(height: t.spacing.sm),
        Text(
          entry.romaji,
          style: t.text.display.copyWith(
            color: t.colors.accent,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (entry.pairedKana != null) ...[
          SizedBox(height: t.spacing.xs),
          Text(
            '${entry.isHiragana ? "Katakana" : "Hiragana"} pair: ${entry.pairedKana}',
            style: t.text.jp(16, color: t.colors.textSecondary),
          ),
        ],
        if (entry.notes != null && entry.notes!.isNotEmpty) ...[
          SizedBox(height: t.spacing.md),
          Text(
            entry.notes!,
            textAlign: TextAlign.center,
            style: t.text.secondary,
          ),
        ],
      ],
    );
  }
}
