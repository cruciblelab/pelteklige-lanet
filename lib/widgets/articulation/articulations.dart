import 'dart:ui';

/// Ağzın yan kesit çiziminde dilin biçimi. Koordinatlar 400×300 tasarım
/// alanındadır; ağız sağa bakar.
///
/// Dil beş noktayla tanımlanır ve aralarından yumuşak bir eğri geçirilir:
/// kök (arka), sırt, ön sırt (blade), uç ve ucun altı.
class TonguePose {
  final Offset back, dorsum, blade, tip, under;

  /// Çene açıklığı: 0 kapalı, 1 açık.
  final double jaw;

  /// Dudakların öne uzayıp yuvarlanması (Ş, Ç).
  final double lipRound;

  /// Alt dudağın üst dişlere yaklaşması (V/W).
  final double lipToTeeth;

  const TonguePose({
    required this.back,
    required this.dorsum,
    required this.blade,
    required this.tip,
    required this.under,
    this.jaw = 0.25,
    this.lipRound = 0,
    this.lipToTeeth = 0,
  });

  static TonguePose lerp(TonguePose a, TonguePose b, double t) {
    Offset l(Offset x, Offset y) => Offset.lerp(x, y, t)!;
    double d(double x, double y) => x + (y - x) * t;
    return TonguePose(
      back: l(a.back, b.back),
      dorsum: l(a.dorsum, b.dorsum),
      blade: l(a.blade, b.blade),
      tip: l(a.tip, b.tip),
      under: l(a.under, b.under),
      jaw: d(a.jaw, b.jaw),
      lipRound: d(a.lipRound, b.lipRound),
      lipToTeeth: d(a.lipToTeeth, b.lipToTeeth),
    );
  }
}

/// Hareket türü.
enum Motion {
  /// Konuma gel, orada kal (S, L, Ş, Y…).
  hold,

  /// Dil ucu bir kez vurup düşer (Türkçe R, [ɾ]).
  tap,

  /// Kapat, havayı tut, bırak (T, D, K, G, Ç, C).
  stop,
}

/// Hava akışı biçimi.
enum Air { none, central, lateral, nasal }

class Articulation {
  final String name;

  /// Hareketin ana konumu (tutma/kapanma/vuruş anı).
  final TonguePose pose;

  /// Vuruş öncesi/sonrası ya da bırakma konumu (tap ve stop için).
  final TonguePose? release;
  final Motion motion;
  final Air air;
  final bool voiced;

  /// Temasın parlayacağı nokta (dil ucu–diş eti, dil sırtı–damak…).
  final Offset? contact;

  /// Üç adımlık açıklama: hazırlık, ana hareket, bitiş.
  final List<String> steps;

  const Articulation({
    required this.name,
    required this.pose,
    this.release,
    required this.motion,
    required this.air,
    required this.voiced,
    this.contact,
    required this.steps,
  });
}

// --- Anatomik sabitler -------------------------------------------------------

const ridgePoint = Offset(299, 104); // diş eti (alveol) çıkıntısı
const velumPoint = Offset(178, 86); // sert/yumuşak damak sınırı
const uvulaTip = Offset(151, 124); // küçük dil ucu

const restPose = TonguePose(
  back: Offset(138, 176),
  dorsum: Offset(206, 128),
  blade: Offset(262, 136),
  tip: Offset(300, 152),
  under: Offset(295, 168),
);

/// Dil ucu diş etinde (R vuruşu, L, D, T).
const _alveolarContact = TonguePose(
  back: Offset(138, 174),
  dorsum: Offset(208, 132),
  blade: Offset(268, 122),
  tip: Offset(300, 108),
  under: Offset(291, 123),
  jaw: 0.3,
);

const _alveolarNear = TonguePose(
  back: Offset(138, 174),
  dorsum: Offset(208, 133),
  blade: Offset(266, 129),
  tip: Offset(298, 126),
  under: Offset(290, 140),
  jaw: 0.3,
);

const articulations = <String, Articulation>{
  'rest': Articulation(
    name: 'Dil hareket etmiyor',
    pose: restPose,
    motion: Motion.hold,
    air: Air.central,
    voiced: true,
    steps: ['Dil aşağıda durur', 'Dil ucu hiç kalkmaz', 'Ses atlanır'],
  ),
  'r': Articulation(
    name: 'R [ɾ]',
    pose: _alveolarContact,
    release: _alveolarNear,
    motion: Motion.tap,
    air: Air.central,
    voiced: true,
    contact: ridgePoint,
    steps: [
      'Dil ucu kalkar, diş etine yaklaşır',
      'Diş etine bir kez, çok hızlı vurur',
      'Hemen geri düşer, ses akmaya devam eder',
    ],
  ),
  'l': Articulation(
    name: 'L',
    pose: TonguePose(
      back: Offset(138, 178),
      dorsum: Offset(206, 142),
      blade: Offset(266, 122),
      tip: Offset(300, 107),
      under: Offset(291, 122),
      jaw: 0.35,
    ),
    motion: Motion.hold,
    air: Air.lateral,
    voiced: true,
    contact: ridgePoint,
    steps: [
      'Dil ucu diş etine kalkar',
      'Orada YAPIŞIK kalır',
      'Hava dilin iki yanından akar',
    ],
  ),
  'y': Articulation(
    name: 'Y [j]',
    pose: TonguePose(
      back: Offset(140, 168),
      dorsum: Offset(214, 108),
      blade: Offset(266, 104),
      tip: Offset(306, 150),
      under: Offset(300, 165),
      jaw: 0.25,
    ),
    motion: Motion.hold,
    air: Air.central,
    voiced: true,
    steps: [
      'Dil ucu aşağıda kalır',
      'Dilin ORTASI damağa doğru kalkar',
      'Ses dil ile damak arasından akar',
    ],
  ),
  'd': Articulation(
    name: 'D',
    pose: _alveolarContact,
    release: _alveolarNear,
    motion: Motion.stop,
    air: Air.central,
    voiced: true,
    contact: ridgePoint,
    steps: [
      'Dil ucu diş etine yapışır',
      'Hava bir an tutulur (uzun ve sıkı temas)',
      'Dil bırakılır, hava patlar',
    ],
  ),
  't': Articulation(
    name: 'T',
    pose: _alveolarContact,
    release: _alveolarNear,
    motion: Motion.stop,
    air: Air.central,
    voiced: false,
    contact: ridgePoint,
    steps: [
      'Dil ucu diş etine yapışır',
      'Hava bir an tutulur',
      'Dil bırakılır, hava patlar (titreşim yok)',
    ],
  ),
  'n': Articulation(
    name: 'N',
    pose: _alveolarContact,
    motion: Motion.hold,
    air: Air.nasal,
    voiced: true,
    contact: ridgePoint,
    steps: [
      'Dil ucu diş etine yapışır',
      'Yumuşak damak iner',
      'Hava burundan çıkar',
    ],
  ),
  's': Articulation(
    name: 'S',
    pose: TonguePose(
      back: Offset(138, 172),
      dorsum: Offset(210, 126),
      blade: Offset(268, 117),
      tip: Offset(302, 114),
      under: Offset(294, 128),
      jaw: 0.1,
    ),
    motion: Motion.hold,
    air: Air.central,
    voiced: false,
    steps: [
      'Dişler neredeyse kapanır',
      'Dil ucu diş etine yaklaşır ama DEĞMEZ',
      'Hava ortadan ince bir çizgi gibi dişlere çarpar',
    ],
  ),
  'z': Articulation(
    name: 'Z',
    pose: TonguePose(
      back: Offset(138, 172),
      dorsum: Offset(210, 126),
      blade: Offset(268, 117),
      tip: Offset(302, 114),
      under: Offset(294, 128),
      jaw: 0.1,
    ),
    motion: Motion.hold,
    air: Air.central,
    voiced: true,
    steps: [
      'S konumu: dişler yakın, dil ucu değmiyor',
      'Ses telleri titrer',
      'Arı sesi: zzzz',
    ],
  ),
  'ş': Articulation(
    name: 'Ş',
    pose: TonguePose(
      back: Offset(138, 170),
      dorsum: Offset(206, 120),
      blade: Offset(260, 110),
      tip: Offset(292, 116),
      under: Offset(286, 130),
      jaw: 0.14,
      lipRound: 1,
    ),
    motion: Motion.hold,
    air: Air.central,
    voiced: false,
    steps: [
      'Dudaklar öne uzar',
      'Dil ucu S’ye göre biraz geride',
      'Hava geniş bir kanaldan akar: şşşş',
    ],
  ),
  'ç': Articulation(
    name: 'Ç',
    pose: TonguePose(
      back: Offset(138, 170),
      dorsum: Offset(206, 120),
      blade: Offset(262, 110),
      tip: Offset(294, 106),
      under: Offset(286, 120),
      jaw: 0.14,
      lipRound: 0.8,
    ),
    release: TonguePose(
      back: Offset(138, 170),
      dorsum: Offset(206, 120),
      blade: Offset(260, 112),
      tip: Offset(292, 117),
      under: Offset(286, 131),
      jaw: 0.14,
      lipRound: 0.8,
    ),
    motion: Motion.stop,
    air: Air.central,
    voiced: false,
    contact: Offset(293, 101),
    steps: [
      'Dudaklar hafif önde, dil ucu diş etinin arkasında',
      'Hava tutulur',
      'Dil bırakılır, hava Ş gibi akar',
    ],
  ),
  'c': Articulation(
    name: 'C',
    pose: TonguePose(
      back: Offset(138, 170),
      dorsum: Offset(206, 120),
      blade: Offset(262, 110),
      tip: Offset(294, 106),
      under: Offset(286, 120),
      jaw: 0.14,
      lipRound: 0.8,
    ),
    release: TonguePose(
      back: Offset(138, 170),
      dorsum: Offset(206, 120),
      blade: Offset(260, 112),
      tip: Offset(292, 117),
      under: Offset(286, 131),
      jaw: 0.14,
      lipRound: 0.8,
    ),
    motion: Motion.stop,
    air: Air.central,
    voiced: true,
    contact: Offset(293, 101),
    steps: ['Ç konumu', 'Ses telleri titrer', 'Dil bırakılır: c'],
  ),
  'k': Articulation(
    name: 'K',
    pose: TonguePose(
      back: Offset(140, 140),
      dorsum: Offset(178, 91),
      blade: Offset(240, 118),
      tip: Offset(312, 158),
      under: Offset(304, 170),
      jaw: 0.3,
    ),
    release: TonguePose(
      back: Offset(140, 152),
      dorsum: Offset(180, 110),
      blade: Offset(242, 126),
      tip: Offset(312, 158),
      under: Offset(304, 170),
      jaw: 0.3,
    ),
    motion: Motion.stop,
    air: Air.central,
    voiced: false,
    contact: velumPoint,
    steps: [
      'Dil ucu alt dişlerin arkasında kalır',
      'Dilin ARKASI damağa yapışır, hava tutulur',
      'Bırakılır, hava patlar',
    ],
  ),
  'g': Articulation(
    name: 'G',
    pose: TonguePose(
      back: Offset(140, 140),
      dorsum: Offset(178, 91),
      blade: Offset(240, 118),
      tip: Offset(312, 158),
      under: Offset(304, 170),
      jaw: 0.3,
    ),
    release: TonguePose(
      back: Offset(140, 152),
      dorsum: Offset(180, 110),
      blade: Offset(242, 126),
      tip: Offset(312, 158),
      under: Offset(304, 170),
      jaw: 0.3,
    ),
    motion: Motion.stop,
    air: Air.central,
    voiced: true,
    contact: velumPoint,
    steps: [
      'Dil ucu aşağıda',
      'Dilin arkası damağa yapışır, ses telleri titrer',
      'Bırakılır',
    ],
  ),
  'gırtlak': Articulation(
    name: 'Gırtlaktan R [ʁ]',
    pose: TonguePose(
      back: Offset(147, 131),
      dorsum: Offset(190, 112),
      blade: Offset(252, 132),
      tip: Offset(306, 154),
      under: Offset(300, 168),
      jaw: 0.3,
    ),
    motion: Motion.hold,
    air: Air.central,
    voiced: true,
    contact: uvulaTip,
    steps: [
      'Dil ucu aşağıda kalır',
      'Dilin kökü küçük dile yaklaşır',
      'Ses boğazın arkasında hışırdar',
    ],
  ),
  'v': Articulation(
    name: 'V / W',
    pose: TonguePose(
      back: Offset(138, 176),
      dorsum: Offset(206, 128),
      blade: Offset(262, 136),
      tip: Offset(300, 152),
      under: Offset(295, 168),
      jaw: 0.2,
      lipToTeeth: 1,
    ),
    motion: Motion.hold,
    air: Air.central,
    voiced: true,
    steps: [
      'Dil kalkmaz',
      'Alt dudak üst dişlere yaklaşır',
      'Ses dudaklarda oluşur',
    ],
  ),
  'θ': Articulation(
    name: 'Peltek [θ]',
    pose: TonguePose(
      back: Offset(140, 172),
      dorsum: Offset(214, 132),
      blade: Offset(294, 136),
      tip: Offset(340, 150),
      under: Offset(328, 160),
      jaw: 0.55,
    ),
    motion: Motion.hold,
    air: Air.central,
    voiced: false,
    steps: [
      'Dişler açılır',
      'Dil ucu dişlerin ARASINDAN dışarı çıkar',
      'Hava dilin üstünden yumuşak akar (th)',
    ],
  ),
  'ɬ': Articulation(
    name: 'Yanal S [ɬ]',
    pose: TonguePose(
      back: Offset(138, 176),
      dorsum: Offset(206, 140),
      blade: Offset(266, 122),
      tip: Offset(300, 107),
      under: Offset(291, 122),
      jaw: 0.15,
    ),
    motion: Motion.hold,
    air: Air.lateral,
    voiced: false,
    contact: ridgePoint,
    steps: [
      'Dil ucu diş etine yapışır',
      'Ortadan hava geçemez',
      'Hava yanlardan hışırtıyla kaçar',
    ],
  ),
};

/// Harf → doğru söyleyişin hareketi.
String articulationForLetter(String letter) => switch (letter) {
  'R' => 'r',
  'L' => 'l',
  'S' => 's',
  'Z' => 'z',
  'Ş' => 'ş',
  'Ç' => 'ç',
  'C' => 'c',
  'K' => 'k',
  'G' => 'g',
  'T' => 't',
  'D' => 'd',
  _ => 'rest',
};

/// Hata etiketi → o hatada dilin yaptığı hareket.
String articulationForError(String label) => switch (label) {
  'R yerine Y' || 'L yerine Y' => 'y',
  'R yerine L' => 'l',
  'R yerine D' || 'G yerine D' || 'C yerine D' => 'd',
  'R yerine V/W' => 'v',
  'Gırtlaktan R' => 'gırtlak',
  'R yutuldu' => 'rest',
  'Dişler arası (peltek) S' || 'Dişler arası (peltek) Z' => 'θ',
  'Yanal S' => 'ɬ',
  'S yerine Ş' || 'Z yerine J' || 'Ç yerine Ş' => 'ş',
  'S yerine T' || 'Ç yerine T' || 'K yerine T' || 'D yerine T' => 't',
  'Z yerine S' || 'Ş yerine S' || 'Ç yerine S' => 's',
  'Ş yerine Ç' || 'C yerine Ç' => 'ç',
  'C yerine Z' => 'z',
  'L yerine N' => 'n',
  'T yerine K' => 'k',
  'D yerine G' => 'g',
  _ => 'rest',
};
