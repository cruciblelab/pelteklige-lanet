/// Ağız içi yan kesit çiziminde dilin, çenenin ve dudakların konumu.
///
/// Koordinatlar 320x240'lık tasarım alanındadır (ağız sağa bakar).
class ArticulationPose {
  /// Dil ucu.
  final double tipX, tipY;

  /// Dil sırtının en yüksek noktası.
  final double bodyX, bodyY;

  /// Çene açıklığı (0 kapalı, 1 tam açık).
  final double jaw;

  /// Dudakların öne uzaması / yuvarlanması (0–1).
  final double lipRound;

  const ArticulationPose({
    required this.tipX,
    required this.tipY,
    required this.bodyX,
    required this.bodyY,
    this.jaw = 0.3,
    this.lipRound = 0,
  });

  static const rest = ArticulationPose(
    tipX: 222,
    tipY: 150,
    bodyX: 150,
    bodyY: 140,
    jaw: 0.35,
  );

  static ArticulationPose lerp(
    ArticulationPose a,
    ArticulationPose b,
    double t,
  ) {
    double l(double x, double y) => x + (y - x) * t;
    return ArticulationPose(
      tipX: l(a.tipX, b.tipX),
      tipY: l(a.tipY, b.tipY),
      bodyX: l(a.bodyX, b.bodyX),
      bodyY: l(a.bodyY, b.bodyY),
      jaw: l(a.jaw, b.jaw),
      lipRound: l(a.lipRound, b.lipRound),
    );
  }
}

enum Airflow {
  /// Hava dilin ortasından, dişlerin arasından ince bir akımla çıkar (S, Ş, Z).
  central,

  /// Hava dilin yanlarından akar (L).
  lateral,

  /// Hava önce tutulur, sonra patlar (K, T, Ç...).
  burst,

  /// Hava kesintili akar, dil ucu titrer (R).
  trill,
}

class SoundInfo {
  final String letter;
  final String title;
  final String ipa;
  final String summary;
  final List<String> steps;
  final List<String> commonErrors;
  final List<String> warmups;
  final ArticulationPose pose;
  final Airflow airflow;
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

  /// Sık yapılan hatanın ağız konumu (karşılaştırma animasyonu için).
  final ArticulationPose? errorPose;
  final String? errorLabel;

  const SoundInfo({
    required this.letter,
    required this.title,
    required this.ipa,
    required this.summary,
    required this.steps,
    required this.commonErrors,
    required this.warmups,
    required this.pose,
    required this.airflow,
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
    this.errorPose,
    this.errorLabel,
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
