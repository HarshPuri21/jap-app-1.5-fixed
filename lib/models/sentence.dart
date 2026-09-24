class BreakdownChunk {
  final String chunk;
  final String? reading;
  final String? meaning;
  final String? note;

  BreakdownChunk({
    required this.chunk,
    this.reading,
    this.meaning,
    this.note,
  });

  factory BreakdownChunk.fromJson(Map<String, dynamic> json) {
    return BreakdownChunk(
      chunk: json['chunk'] as String,
      reading: json['reading'] as String?,
      meaning: json['meaning'] as String?,
      note: json['note'] as String?,
    );
  }
}

class Sentence {
  final String jp;
  final String en;
  final String difficulty; // 'easy' | 'normal' | 'hard'
  final List<String> tags;
  final List<BreakdownChunk> breakdown;
  final List<String> options;
  final String answer;

  Sentence({
    required this.jp,
    required this.en,
    required this.difficulty,
    required this.tags,
    required this.breakdown,
    required this.options,
    required this.answer,
  });

  factory Sentence.fromJson(Map<String, dynamic> json) {
    return Sentence(
      jp: json['jp'] as String,
      en: json['en'] as String,
      difficulty: json['difficulty'] as String,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      breakdown: (json['breakdown'] as List<dynamic>)
          .map((e) => BreakdownChunk.fromJson(e as Map<String, dynamic>))
          .toList(),
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      answer: json['answer'] as String,
    );
  }
}
