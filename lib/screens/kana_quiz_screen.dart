import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/kana_question.dart';
import '../services/data_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_definition.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/option_button.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

enum _Direction { kanaToRomaji, romajiToKana }

/// Kana <-> Romaji recognition quiz. Reuses the same OptionButton/reveal
/// pattern as Learn Kanji / Radical Quiz (immediate feedback is the
/// intended behaviour for these practice quizzes -- only "Take a Test"
/// defers its reveal).
class KanaQuizScreen extends StatefulWidget {
  const KanaQuizScreen({super.key});

  @override
  State<KanaQuizScreen> createState() => _KanaQuizScreenState();
}

class _KanaQuizScreenState extends State<KanaQuizScreen> {
  String _type = 'all'; // 'all' | 'hiragana' | 'katakana'
  _Direction _direction = _Direction.kanaToRomaji;
  late List<KanaQuestion> _deck;
  int _index = 0;
  String? _selected;
  int _score = 0;
  int _answered = 0;

  /// romaji -> character lookup, scoped to the current type, used only to
  /// flip a question's options into kana characters for the
  /// Romaji -> Kana direction (each question's own option set is already
  /// guaranteed romaji-unique at generation time).
  Map<String, String> _charFor(String type) {
    final pool = type == 'all'
        ? DataService.instance.kana
        : DataService.instance.kanaByType(type);
    final map = <String, String>{};
    for (final k in pool) {
      map.putIfAbsent(k.romaji, () => k.character);
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _reload();
    context.read<AudioService>().stopMenuMusic();
  }

  void _reload() {
    _deck = DataService.instance.drawKana(_type, 'all', 0);
    _index = 0;
    _selected = null;
    _score = 0;
    _answered = 0;
  }

  KanaQuestion get _current => _deck[_index];

  /// What's shown as the big prompt.
  String get _promptText =>
      _direction == _Direction.kanaToRomaji ? _current.character : _current.answer;

  /// What's shown as each tappable option.
  List<String> get _displayOptions {
    if (_direction == _Direction.kanaToRomaji) return _current.options;
    final lookup = _charFor(_current.type);
    return _current.options.map((r) => lookup[r] ?? r).toList();
  }

  /// The correct *displayed* option (a character in Romaji->Kana mode).
  String get _correctDisplay => _direction == _Direction.kanaToRomaji
      ? _current.answer
      : (_charFor(_current.type)[_current.answer] ?? _current.answer);

  void _choose(String displayedOption) {
    if (_selected != null) return;
    final correct = displayedOption == _correctDisplay;
    setState(() {
      _selected = displayedOption;
      _answered += 1;
      if (correct) _score += 1;
    });
    final audio = context.read<AudioService>();
    if (correct) {
      audio.playLessonClick();
    } else {
      audio.playError();
    }
    context.read<SettingsService>().recordAnswer(correct: correct);
  }

  void _next() {
    context.read<AudioService>().playLessonClick();
    setState(() {
      if (_index < _deck.length - 1) {
        _index += 1;
      } else {
        _deck.shuffle();
        _index = 0;
      }
      _selected = null;
    });
  }

  void _setType(String type) {
    context.read<AudioService>().playLessonClick();
    setState(() {
      _type = type;
      _reload();
    });
  }

  void _setDirection(_Direction d) {
    context.read<AudioService>().playLessonClick();
    setState(() {
      _direction = d;
      _selected = null;
    });
  }

  OptionState _stateFor(String displayed) {
    if (_selected == null) return OptionState.idle;
    if (displayed == _correctDisplay) return OptionState.selectedCorrect;
    if (displayed == _selected) return OptionState.selectedWrong;
    return OptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_deck.isEmpty) {
      return Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No kana found for "$_type".',
                        textAlign: TextAlign.center,
                        style: t.text.secondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final q = _current;
    final isKanaPrompt = _direction == _Direction.kanaToRomaji;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -200) _next();
            },
            child: Column(
              children: [
                _buildAppBar(context),
                _buildFilterChips(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      t.spacing.gutter,
                      t.spacing.xs,
                      t.spacing.gutter,
                      t.spacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ThemedReveal(
                          key: ValueKey<String>('$_index-$_direction'),
                          moment: ThemeMoment.kanjiReveal,
                          child: ThemedSurface(
                            level: SurfaceLevel.elevated,
                            radius: t.radii.lg,
                            padding: EdgeInsets.all(t.spacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _typeBadge(context, q.type),
                                    Text(
                                      '${_index + 1} / ${_deck.length}',
                                      style: t.text.caption,
                                    ),
                                  ],
                                ),
                                SizedBox(height: t.spacing.md),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _promptText,
                                    textAlign: TextAlign.center,
                                    style: isKanaPrompt
                                        ? t.text.jp(92, weight: FontWeight.w700)
                                        : t.text.display.copyWith(
                                            fontSize: 44,
                                            fontWeight: FontWeight.w800,
                                            color: t.colors.accent,
                                          ),
                                  ),
                                ),
                                SizedBox(height: t.spacing.xs),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: t.spacing.lg),
                        ..._displayOptions.map(
                          (opt) => Padding(
                            padding: EdgeInsets.only(bottom: t.spacing.sm),
                            child: OptionButton(
                              text: opt,
                              state: _stateFor(opt),
                              onTap: () => _choose(opt),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeBadge(BuildContext context, String type) {
    final t = context.tokens;
    final color = type == 'hiragana' ? t.colors.accent : t.colors.good;
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: ThemeRadii.pill,
      allowHeavyEffects: false,
      showShadow: false,
      tint: color,
      tintStrength: 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        type == 'hiragana' ? 'HIRAGANA' : 'KATAKANA',
        style: t.text.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Kana Quiz',
      subtitle: '仮名クイズ',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
      trailing: ThemedStatPill(
        text: '$_score/$_answered',
        icon: Icons.military_tech_outlined,
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final t = context.tokens;
    const types = ['all', 'hiragana', 'katakana'];
    return Column(
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: t.spacing.gutter),
            children: types.map((ty) {
              return Padding(
                padding: EdgeInsets.only(right: t.spacing.xs),
                child: Center(
                  child: ThemedChip(
                    label: ty == 'all' ? 'All' : ty[0].toUpperCase() + ty.substring(1),
                    selected: ty == _type,
                    onTap: () => _setType(ty),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: t.spacing.gutter),
            children: [
              Padding(
                padding: EdgeInsets.only(right: t.spacing.xs),
                child: Center(
                  child: ThemedChip(
                    label: 'Kana → Romaji',
                    selected: _direction == _Direction.kanaToRomaji,
                    onTap: () => _setDirection(_Direction.kanaToRomaji),
                  ),
                ),
              ),
              Center(
                child: ThemedChip(
                  label: 'Romaji → Kana',
                  selected: _direction == _Direction.romajiToKana,
                  onTap: () => _setDirection(_Direction.romajiToKana),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: t.spacing.xs),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.gutter,
        t.spacing.xs,
        t.spacing.gutter,
        t.spacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: ThemedButton(
              label: 'Skip',
              icon: Icons.skip_next_rounded,
              variant: ThemedButtonVariant.secondary,
              onPressed: _next,
            ),
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: ThemedButton(
              label: 'Next',
              icon: Icons.arrow_forward_rounded,
              onPressed: _selected == null ? null : _next,
            ),
          ),
        ],
      ),
    );
  }
}
