class SoundInfo {
  final String letter;
  final String title;
  final String ipa;
  final String summary;
  final List<String> steps;
  final List<String> commonErrors;
  final List<String> warmups;
  final bool voiced;

  /// Hazırlık hecelerinden kelimeye: ses tek başına → hece → kelime → cümle.
  final List<String> syllables;
  final List<String> wordsStart;
  final List<String> wordsMiddle;
  final List<String> wordsEnd;
  final List<String> sentences;
  final List<String> tongueTwisters;

  /// Ünsüz kümeleri (tren, kral): ses başka bir ünsüzle yan yana.
  final List<String> wordsClusters;

  /// Köprü alıştırması: (hedef, yardımcı). Ör. R için ("ara", "ada"):
  /// "ada"yı giderek hızlı söyleyince dil ucu hafif vurur ve "ara" olur.
  final List<(String, String)> bridge;

  /// Tıslama ölçeri ile çalışılabilir mi?
  final bool meterFriendly;

  const SoundInfo({
    required this.letter,
    required this.title,
    required this.ipa,
    required this.summary,
    required this.steps,
    required this.commonErrors,
    required this.warmups,
    required this.voiced,
    required this.syllables,
    required this.wordsStart,
    required this.wordsMiddle,
    required this.wordsEnd,
    required this.sentences,
    this.tongueTwisters = const [],
    this.wordsClusters = const [],
    this.bridge = const [],
    this.meterFriendly = false,
  });

  String get id => letter;
}

class MinimalPair {
  final String a;
  final String b;

  /// Hangi iki sesi ayırt etmeye çalıştığı, ör. "R / Y".
  final String contrast;

  const MinimalPair(this.a, this.b, this.contrast);
}

class Story {
  final String id;
  final String title;
  final String focus;
  final int level;
  final List<String> paragraphs;

  const Story({
    required this.id,
    required this.title,
    required this.focus,
    required this.level,
    required this.paragraphs,
  });

  List<String> get sentences => paragraphs
      .expand((p) => p.split(RegExp(r'(?<=[.!?])\s+')))
      .where((s) => s.trim().isNotEmpty)
      .toList();
}
