/// A precomputed multiple-choice kana question: one character, its romaji,
/// and four plausible options (built so distractors never share the
/// correct romaji -- important because a few kana pairs, e.g. じ/ぢ, have
/// the same modern reading).
///
/// [options] and [answer] are always in terms of romaji. The quiz screen
/// itself decides direction: "Kana -> Romaji" shows [character] as the
/// prompt and [options] as the choices; "Romaji -> Kana" flips this by
/// showing [answer] as the prompt and resolving each option back to its
/// kana character at quiz time.
class KanaQuestion {
  final String character;
  final String romaji;
  final String sound;
  final String type; // 'hiragana' | 'katakana'
  final String group;
  final String difficulty; // 'easy' | 'normal' | 'hard'
  final List<String> options; // romaji choices, including the answer
  final String answer; // romaji

  KanaQuestion({
    required this.character,
    required this.romaji,
    required this.sound,
    required this.type,
    required this.group,
    required this.difficulty,
    required this.options,
    required this.answer,
  });

  factory KanaQuestion.fromJson(Map<String, dynamic> json) {
    return KanaQuestion(
      character: json['character'] as String,
      romaji: json['romaji'] as String,
      sound: json['sound'] as String? ?? json['romaji'] as String,
      type: json['type'] as String,
      group: json['group'] as String,
      difficulty: json['difficulty'] as String,
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      answer: json['answer'] as String,
    );
  }
}
