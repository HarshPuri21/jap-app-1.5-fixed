/// One character of modern Japanese kana -- hiragana or katakana, across
/// every standard group (basic, dakuten, handakuten, yōon, small/special,
/// and the common extended katakana combinations used for loanwords).
///
/// Obsolete/historical kana are intentionally not part of this set (see
/// the data pipeline notes) -- this is the modern, beginner-through-
/// intermediate inventory.
class KanaEntry {
  final String character;
  final String romaji;

  /// A short pronunciation guide. Usually equal to [romaji]; kept as its
  /// own field (rather than reusing romaji) so a future revision can add
  /// IPA-ish detail without touching the romaji used for quiz matching.
  final String sound;

  /// 'hiragana' | 'katakana'
  final String type;

  /// 'basic' | 'dakuten' | 'handakuten' | 'yoon' | 'small' | 'special' |
  /// 'extended_katakana'
  final String group;

  final bool isSmall;

  /// The corresponding character in the other kana system (hiragana <->
  /// katakana), when one exists. Null for katakana-only extended
  /// combinations, which have no standard hiragana counterpart.
  final String? pairedKana;

  /// Optional usage/pronunciation note (e.g. the っ doubling rule, the
  /// を/は/へ particle exceptions, じ/ぢ overlap).
  final String? notes;

  KanaEntry({
    required this.character,
    required this.romaji,
    required this.sound,
    required this.type,
    required this.group,
    required this.isSmall,
    this.pairedKana,
    this.notes,
  });

  bool get isHiragana => type == 'hiragana';
  bool get isKatakana => type == 'katakana';

  factory KanaEntry.fromJson(Map<String, dynamic> json) {
    return KanaEntry(
      character: json['character'] as String,
      romaji: json['romaji'] as String,
      sound: json['sound'] as String? ?? json['romaji'] as String,
      type: json['type'] as String,
      group: json['group'] as String,
      isSmall: json['isSmall'] as bool? ?? false,
      pairedKana: json['pairedKana'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'character': character,
        'romaji': romaji,
        'sound': sound,
        'type': type,
        'group': group,
        'isSmall': isSmall,
        'pairedKana': pairedKana,
        'notes': notes,
      };
}

/// Display order and labels for kana groups -- shared by every screen that
/// lists groups, so the order is defined once.
const List<String> kKanaGroupOrder = [
  'basic',
  'dakuten',
  'handakuten',
  'yoon',
  'small',
  'special',
  'extended_katakana',
];

String kanaGroupLabel(String group) {
  switch (group) {
    case 'basic':
      return 'Basic 46';
    case 'dakuten':
      return 'Dakuten';
    case 'handakuten':
      return 'Handakuten';
    case 'yoon':
      return 'Yōon';
    case 'small':
      return 'Small Kana';
    case 'special':
      return 'Special';
    case 'extended_katakana':
      return 'Extended Katakana';
    default:
      return group;
  }
}

String kanaGroupSubtitle(String group) {
  switch (group) {
    case 'basic':
      return 'The 46 foundational characters';
    case 'dakuten':
      return 'Voiced sounds (゛)';
    case 'handakuten':
      return "P-sounds (゜)";
    case 'yoon':
      return 'Contracted sounds (ゃ ゅ ょ)';
    case 'small':
      return 'Small vowels, glides & the doubling mark';
    case 'special':
      return 'ゔ / ヴ and other special cases';
    case 'extended_katakana':
      return 'For foreign names & loanwords';
    default:
      return '';
  }
}
