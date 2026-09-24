import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/kana_entry.dart';
import '../services/data_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_surface.dart';
import 'kana_browse_screen.dart';

/// Groups within one kana type (Hiragana or Katakana), in the recommended
/// learning order from the data spec: Basic -> Dakuten -> Handakuten ->
/// Yōon -> Small/Special -> (Katakana only) Extended.
class KanaGroupListScreen extends StatefulWidget {
  final String type; // 'hiragana' | 'katakana'
  const KanaGroupListScreen({super.key, required this.type});

  @override
  State<KanaGroupListScreen> createState() => _KanaGroupListScreenState();
}

class _KanaGroupListScreenState extends State<KanaGroupListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AudioService>().stopMenuMusic();
  }

  void _openGroup(String group) {
    context.read<AudioService>().playLessonClick();
    Navigator.of(context).push(themedRoute(
      context,
      (_) => KanaBrowseScreen(type: widget.type, group: group),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isHiragana = widget.type == 'hiragana';
    final groups = kKanaGroupOrder
        .where((g) => isHiragana ? g != 'extended_katakana' : true)
        .toList();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.xl,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final count = DataService.instance
                        .kanaByGroup(widget.type, group)
                        .length;
                    return Padding(
                      padding: EdgeInsets.only(bottom: t.spacing.sm),
                      child: _groupTile(context, group, count),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupTile(BuildContext context, String group, int count) {
    final t = context.tokens;
    return ThemedCard(
      onTap: () => _openGroup(group),
      level: SurfaceLevel.standard,
      radius: t.radii.lg,
      padding: EdgeInsets.all(t.spacing.md),
      semanticLabel: '${kanaGroupLabel(group)}, $count characters',
      child: Row(
        children: [
          ThemedIconPlate(
            icon: _iconFor(group),
            color: t.colors.accent,
            size: 48,
            iconSize: 22,
          ),
          SizedBox(width: t.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(kanaGroupLabel(group), style: t.text.cardTitle),
                const SizedBox(height: 3),
                Text(
                  kanaGroupSubtitle(group),
                  style: t.text.secondary.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
          Text('$count', style: t.text.caption.copyWith(
                color: t.colors.accent,
                fontWeight: FontWeight.w800,
              )),
          SizedBox(width: t.spacing.xs),
          Icon(Icons.chevron_right_rounded,
              color: t.colors.textTertiary, size: 22),
        ],
      ),
    );
  }

  IconData _iconFor(String group) {
    switch (group) {
      case 'basic':
        return Icons.grid_view_rounded;
      case 'dakuten':
        return Icons.graphic_eq_rounded;
      case 'handakuten':
        return Icons.circle_outlined;
      case 'yoon':
        return Icons.merge_type_rounded;
      case 'small':
        return Icons.zoom_out_rounded;
      case 'special':
        return Icons.star_outline_rounded;
      case 'extended_katakana':
        return Icons.public_rounded;
      default:
        return Icons.category_outlined;
    }
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: widget.type == 'hiragana' ? 'Hiragana' : 'Katakana',
      subtitle: widget.type == 'hiragana' ? 'ひらがな' : 'カタカナ',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}
