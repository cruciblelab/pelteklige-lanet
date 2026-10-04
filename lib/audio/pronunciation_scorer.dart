import 'dart:math' as math;
import 'dart:typed_data';

import '../utils/turkish.dart';

/// Fonem modelinin çıktısından (her 40 ms için 127 sesin log-olasılığı)
/// hedef sesin doğru mu, yoksa bilinen bir hatayla mı söylendiğini bulur.
///
/// Yöntem: Kelimenin doğru hâli ile hatalı hâllerinin ("radyo", "yadyo",
/// "ladyo", "adyo"…) her biri için CTC olasılığı hesaplanır ve yarıştırılır.
/// Kelimenin geri kalanı iki tarafta aynı olduğu için fark yalnızca hedef
/// sesten gelir. Model "dil modeli" içermez: duyduğunu düzeltmeye çalışmaz.
///
/// Eşikler gerçek Türkçe konuşmada (FLEURS) ve sentetik hatalı söyleyişte
/// ölçüldü; ayrıntılar docs/MODEL_DEGERLENDIRME.md.
enum Verdict { correct, error, unsure }

class SoundCheck {
  /// Normalize metinde (boşluksuz) hedef harfin konumu.
  final int position;

  /// Hedefin geçtiği kelime ve kelime içindeki konumu.
  final String word;
  final int indexInWord;

  /// "Doğru" ve hata adları → olasılık (toplamı 1).
  final Map<String, double> probs;

  const SoundCheck({
    required this.position,
    required this.word,
    required this.indexInWord,
    required this.probs,
  });

  double get correctProb => probs[correctLabel] ?? 0;

  MapEntry<String, double> get topError => probs.entries
      .where((e) => e.key != correctLabel)
      .reduce((a, b) => a.value >= b.value ? a : b);

  Verdict get verdict {
    // Doğru olma ihtimali çok düşük ve hatalardan biri belirgin şekilde öndeyse.
    // (Olasılık birkaç hata arasında bölünebildiği için en olası hatanın tek
    // başına çok yüksek olması beklenmez.)
    if (correctProb < PronunciationScorer.errorMaxCorrect &&
        topError.value >= PronunciationScorer.errorMinTop) {
      return Verdict.error;
    }
    if (correctProb >= PronunciationScorer.correctThreshold) {
      return Verdict.correct;
    }
    return Verdict.unsure;
  }

  static const correctLabel = 'Doğru';

  /// Kişinin kendi hatasına odaklı ikili karşılaştırma: yalnızca "doğru" ile
  /// [errorLabel] yarıştırılır. 1 = tamamen doğru, 0 = tamamen hata.
  /// Ölçüm: docs/MODEL_DEGERLENDIRME.md (odaklı mod).
  FocusResult focus(String errorLabel) {
    final pc = correctProb;
    final pe = probs[errorLabel] ?? 0;
    final ratio = pc + pe <= 0 ? 0.5 : pc / (pc + pe);
    // Seçilen hata dışında başka bir hata baskınsa bunu ayrıca söyle.
    final others = probs.entries
        .where((e) => e.key != correctLabel && e.key != errorLabel)
        .toList();
    final otherTop = others.isEmpty
        ? null
        : others.reduce((a, b) => a.value >= b.value ? a : b);
    return FocusResult(
      ratio: ratio,
      errorLabel: errorLabel,
      verdict: ratio < FocusResult.errorBelow
          ? Verdict.error
          : ratio >= FocusResult.correctFrom
          ? Verdict.correct
          : Verdict.unsure,
      otherError:
          otherTop != null && otherTop.value > 0.6 && otherTop.value > pc + pe
          ? otherTop.key
          : null,
    );
  }
}

class FocusResult {
  /// Hata: oran < 0,20. Doğru: oran ≥ 0,70. Arası: "arada".
  static const errorBelow = 0.2;
  static const correctFrom = 0.7;

  final double ratio;
  final String errorLabel;
  final Verdict verdict;

  /// Seçilen hatadan farklı ve baskın bir hata varsa adı (ör. "R yerine Y").
  final String? otherError;

  const FocusResult({
    required this.ratio,
    required this.errorLabel,
    required this.verdict,
    required this.otherError,
  });
}

class PronunciationResult {
  final String text;
  final String targetLetter;
  final List<SoundCheck> checks;

  /// Modelin dil bilgisi olmadan duyduğu sesler (IPA), şeffaflık için.
  final String heardPhones;

  /// Söylenen, hedef metne hiç benzemiyor (başka kelime ya da gürültü).
  final bool mismatch;
  final double fit;

  const PronunciationResult({
    required this.text,
    required this.targetLetter,
    required this.checks,
    required this.heardPhones,
    required this.mismatch,
    required this.fit,
  });
}

class PronunciationScorer {
  /// Hata: doğru < %3 ve en olası hata ≥ %50. Doğru: doğru ≥ %30.
  /// Arası "net değil". Beş kural karşılaştırıldı: docs/MODEL_DEGERLENDIRME.md
  static const errorMaxCorrect = 0.03;
  static const errorMinTop = 0.5;
  static const correctThreshold = 0.3;

  /// Ortalama uyum bunun altındaysa söylenen başka bir şeydir.
  static const mismatchFit = -0.3;

  static const _alphabet = 'abcçdefghıijklmnoöprsştuüvyz';

  /// Türkçe harf/ses sınıfları → modelin IPA sembolleri.
  static const Map<String, List<String>> classes = {
    'a': ['a', 'ɑ', 'æ', 'ɐ', 'ʌ', 'ə'],
    'e': ['e', 'ɛ', 'æ', 'ə', 'ɪ'],
    'ı': ['ɯ', 'ɨ', 'ə', 'ɪ', 'ɤ', 'ɘ', 'ʊ'],
    'i': ['i', 'ɪ'],
    'o': ['o', 'ɔ', 'ʊ'],
    'ö': ['ø', 'œ', 'ɵ', 'ʏ', 'ɞ'],
    'u': ['u', 'ʊ', 'ʉ'],
    'ü': ['y', 'ʏ', 'ʉ'],
    'b': ['b', 'β'],
    'd': ['d', 'ɖ', 'ɗ'],
    'f': ['f', 'ɸ'],
    'g': ['g', 'ɟ', 'ɠ', 'ɢ'],
    'h': ['h', 'ħ', 'x', 'ɦ'],
    'j': ['ʒ', 'ʑ'],
    'k': ['k', 'c', 'q'],
    'l': ['l', 'ɭ', 'ʎ', 'ɮ'],
    'm': ['m', 'ɱ'],
    'n': ['n', 'ŋ', 'ɲ', 'ɳ'],
    'p': ['p'],
    'r': ['r', 'ɾ', 'ɹ', 'ɺ', 'ɽ', 'ɻ'],
    's': ['s'],
    'ş': ['ʃ', 'ɕ', 'ʂ'],
    't': ['t', 'ʈ'],
    'v': ['v', 'ʋ', 'w', 'β'],
    'y': ['j', 'ʝ'],
    'z': ['z'],
    // Hata sesleri (Türkçede harfi olmayanlar)
    'R_gırtlak': ['ʁ', 'ʀ', 'ɣ', 'χ', 'ɰ', 'ʕ'],
    'θ': ['θ', 'f'],
    'ð': ['ð'],
    'ɬ': ['ɬ', 'ɮ'],
  };

  /// Kaynaşık sesler iki sınıf olarak modellenir.
  static const Map<String, List<String>> _affricates = {
    'c': ['d', 'j'],
    'ç': ['t', 'ş'],
  };

  /// Her ses için bilinen hatalar: (yerine geçen, etiket). null = yutma.
  static const Map<String, List<(String?, String)>> errors = {
    'r': [
      ('y', 'R yerine Y'),
      ('l', 'R yerine L'),
      ('d', 'R yerine D'),
      ('v', 'R yerine V/W'),
      ('R_gırtlak', 'Gırtlaktan R'),
      (null, 'R yutuldu'),
    ],
    's': [
      ('θ', 'Dişler arası (peltek) S'),
      ('ş', 'S yerine Ş'),
      ('ɬ', 'Yanal S'),
      ('t', 'S yerine T'),
    ],
    'z': [
      ('ð', 'Dişler arası (peltek) Z'),
      ('s', 'Z yerine S'),
      ('j', 'Z yerine J'),
    ],
    'ş': [('s', 'Ş yerine S'), ('ç', 'Ş yerine Ç')],
    'ç': [('ş', 'Ç yerine Ş'), ('t', 'Ç yerine T'), ('s', 'Ç yerine S')],
    'c': [('ç', 'C yerine Ç'), ('z', 'C yerine Z'), ('d', 'C yerine D')],
    'k': [('t', 'K yerine T')],
    'g': [('d', 'G yerine D')],
    'l': [('y', 'L yerine Y'), ('n', 'L yerine N')],
    't': [('k', 'T yerine K')],
    'd': [('g', 'D yerine G'), ('t', 'D yerine T')],
  };

  /// Hatanın yerine geçen sesin kısa adı (ibre etiketi için): "L", "Y", "θ"…
  static String errorShort(String label) => switch (label) {
    'Gırtlaktan R' => 'ʁ',
    'R yutuldu' => '—',
    'Dişler arası (peltek) S' => 'θ',
    'Dişler arası (peltek) Z' => 'ð',
    'Yanal S' => 'ɬ',
    'R yerine V/W' => 'V',
    _ => label.split(' ')[2],
  };

  /// Kısa seçim etiketi: "L gibi", "Boğazdan", "Peltek"…
  static String errorChip(String label) => switch (label) {
    'Gırtlaktan R' => 'Boğazdan',
    'R yutuldu' => 'Atlıyorum',
    'Dişler arası (peltek) S' || 'Dişler arası (peltek) Z' => 'Peltek',
    'Yanal S' => 'Islak / yanal',
    _ => '${errorShort(label)} gibi',
  };

  /// Kullanıcıya seçim olarak sunulan, gündelik dille hata adı.
  static String errorPlain(String label) => switch (label) {
    'R yerine Y' => 'Y gibi söylüyorum',
    'R yerine L' => 'L gibi (ya da L ile R arası) söylüyorum',
    'R yerine D' => 'D gibi söylüyorum',
    'R yerine V/W' => 'V / W gibi, dudaklarla söylüyorum',
    'Gırtlaktan R' => 'Boğazdan, “Fransız R’si” gibi söylüyorum',
    'R yutuldu' => 'Hiç çıkmıyor, atlıyorum',
    'Dişler arası (peltek) S' => 'Dilim dişlerimin arasından çıkıyor (peltek)',
    'Dişler arası (peltek) Z' => 'Dilim dişlerimin arasından çıkıyor (peltek)',
    'Yanal S' => 'Islak, hışırtılı; hava yanlardan kaçıyor',
    _ => '${label.split(' ')[2]} gibi söylüyorum',
  };

  /// Örnek kelimede hatanın nasıl duyulduğu: araba → alaba.
  static String errorExample(String word, String target, String label) {
    final t = trLower(target);
    final errs = errors[t] ?? const [];
    final rep = errs.where((e) => e.$2 == label).map((e) => e.$1).firstOrNull;
    if (label == 'R yutuldu') return word.replaceFirst(t, '');
    if (rep == null || rep.length > 1 || !_alphabet.contains(rep)) {
      return word;
    }
    return word.replaceFirst(t, rep);
  }

  /// Her hata için ne yapılması gerektiğini söyleyen kısa yönlendirme.
  static const Map<String, String> tips = {
    'R yerine Y':
        'Dil ucun aşağıda kalıyor. Ucunu üst ön dişlerinin arkasındaki kabarık '
        'yere kaldır ve oraya hızlıca bir kez vur.',
    'R yerine L': 'Dil ucun diş etine yapışıp kalıyor. Dokun ve hemen bırak, top sektirir gibi.',
    'R yerine D':
        'Dil ucun doğru yerde ama fazla bastırıyorsun. Aynı yere çok daha hafif '
        've hızlı dokun.',
    'R yerine V/W': 'Ses dudaklardan çıkıyor. Dudaklarını gevşek bırak, işi dil ucu yapsın.',
    'Gırtlaktan R':
        'Ses boğazın arkasından geliyor. Önce “d-d-d” de, sonra hızlandır; sesi '
        'dil ucuna taşı.',
    'R yutuldu': 'R duyulmadı. Kelimeyi yavaş söyle, R’ye gelince dil ucunu bilerek kaldır.',
    'Dişler arası (peltek) S':
        'Dil ucun dişlerin arasından çıkıyor. Dişlerini hafifçe kapat, dili '
        'dişlerin arkasında tut.',
    'S yerine Ş': 'Dudakların öne çıkıyor. Gülümser gibi dudaklarını yana çek.',
    'Yanal S':
        'Hava yanlardan kaçıyor. Dilin yanlarını azı dişlerine yapıştır, havayı '
        'ortadan ince bir çizgi gibi üfle.',
    'S yerine T':
        'Havayı kesiyorsun. Dili diş etine değdirmeden, sürekli üfle: ssss.',
    'Dişler arası (peltek) Z': 'Dil ucun dişlerin arasından çıkıyor. Dişleri hafif kapat, dili arkada tut.',
    'Z yerine S': 'Titreşim yok. Elini boğazına koy ve sesini aç: zzzz.',
    'Z yerine J': 'Dudakların öne çıkıyor. Gülümse, dili S konumunda tut.',
    'Ş yerine S':
        'Dudaklarını öne uzat (öpücük gibi) ve dilini biraz geri çek.',
    'Ş yerine Ç': 'Dili diş etine değdirmeden, kesintisiz üfle: şşşş.',
    'Ç yerine Ş': 'Önce dil ucunu diş etine değdir, sonra bırak: t-ş.',
    'Ç yerine T': 'Dili bırakırken havayı ş gibi akıt: t-şşş.',
    'Ç yerine S':
        'Dudaklarını hafif öne uzat, dil ucunu diş etine değdirip bırak.',
    'C yerine Ç': 'Titreşim yok. Elini boğazına koy ve sesini aç.',
    'C yerine Z': 'Önce dil ucunu diş etine değdir, sonra bırak: d-j.',
    'C yerine D': 'Dili bırakırken sesi j gibi akıt.',
    'K yerine T': 'Dil ucun kalkıyor. Ucunu alt dişlerinin arkasına bastır, dilin ARKASINI kaldır.',
    'G yerine D': 'Dil ucun kalkıyor. Ucunu alt dişlerinin arkasına bastır, dilin ARKASINI kaldır.',
    'L yerine Y': 'Dil ucunu üst diş etine değdir ve orada tut: llll.',
    'L yerine N':
        'Hava burundan çıkıyor. Dil ucunu tutarken havayı ağızdan, dilin '
        'yanlarından akıt.',
    'T yerine K': 'Dilin arkası kalkıyor. Ucunu üst diş etine değdir.',
    'D yerine G': 'Dilin arkası kalkıyor. Ucunu üst diş etine değdir.',
    'D yerine T': 'Titreşim yok. Elini boğazına koy ve sesini aç.',
  };

  final List<String> tokens;
  final int vocab;
  late final List<int> _blankIds;
  late final Map<String, List<int>> _classIds;

  PronunciationScorer(this.tokens) : vocab = tokens.length {
    final idx = {for (var i = 0; i < tokens.length; i++) tokens[i]: i};
    const modifiers = 'ʰʲʷʼːˠˤ˞̴̥̩̪̺̃̚';
    _blankIds = [
      0, 1, 2, // <blk> <sos/eos> <unk>
      if (idx['▁'] != null) idx['▁']!,
      for (var i = 0; i < tokens.length; i++)
        if (tokens[i].length == 1 && modifiers.contains(tokens[i])) i,
    ];
    _classIds = classes.map(
      (k, v) => MapEntry(k, [
        for (final t in v)
          if (idx[t] != null) idx[t]!,
      ]),
    );
  }

  /// tokens.txt içeriğinden ("sembol id" satırları).
  factory PronunciationScorer.fromTokensFile(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty);
    final list = <String>[];
    for (final l in lines) {
      final sp = l.lastIndexOf(' ');
      list.add(l.substring(0, sp));
    }
    return PronunciationScorer(list);
  }

  static bool supports(String letter) => errors.containsKey(trLower(letter));

  /// Metni modelin sınıf dizisine çevirir (ğ okunmaz, ardışık aynılar birleşir).
  static List<String> toClasses(String text) {
    final out = <String>[];
    for (final ch in text.split('')) {
      if (ch == 'ğ' || !_alphabet.contains(ch)) continue;
      out.addAll(_affricates[ch] ?? [ch]);
    }
    return _collapse(out);
  }

  static List<String> _collapse(List<String> seq) {
    final res = <String>[];
    for (final c in seq) {
      if (res.isEmpty || res.last != c) res.add(c);
    }
    return res;
  }

  static List<String> _variant(String? rep) {
    if (rep == null) return const [];
    if (!_alphabet.contains(rep) || rep.length > 1) return [rep];
    return toClasses(rep);
  }

  double _logSumExp(Float32List lp, int base, List<int> ids) {
    var m = double.negativeInfinity;
    for (final i in ids) {
      final v = lp[base + i];
      if (v > m) m = v;
    }
    if (m == double.negativeInfinity) return m;
    var s = 0.0;
    for (final i in ids) {
      s += math.exp(lp[base + i] - m);
    }
    return m + math.log(s);
  }

  static double _lae(double a, double b) {
    if (a == double.negativeInfinity) return b;
    if (b == double.negativeInfinity) return a;
    return a > b
        ? a + math.log(1 + math.exp(b - a))
        : b + math.log(1 + math.exp(a - b));
  }

  /// Sınıf dizisinin CTC log-olasılığı. [emis] önceden hesaplanmış
  /// sınıf log-olasılıkları (kare × sınıf).
  double _ctc(
    int frames,
    Float64List blank,
    Map<String, Float64List> emis,
    List<String> seq,
  ) {
    if (seq.isEmpty) {
      var s = 0.0;
      for (var t = 0; t < frames; t++) {
        s += blank[t];
      }
      return s;
    }
    final l = 2 * seq.length + 1;
    final cols = [
      for (var s = 0; s < l; s++) s.isEven ? blank : emis[seq[s ~/ 2]]!,
    ];
    final skip = List<bool>.generate(
      l,
      (s) => s.isOdd && s >= 3 && seq[s ~/ 2] != seq[s ~/ 2 - 1],
    );
    var a = Float64List(l)..fillRange(0, l, double.negativeInfinity);
    a[0] = cols[0][0];
    a[1] = cols[1][0];
    var n = Float64List(l);
    for (var t = 1; t < frames; t++) {
      for (var s = 0; s < l; s++) {
        var v = a[s];
        if (s > 0) v = _lae(v, a[s - 1]);
        if (skip[s]) v = _lae(v, a[s - 2]);
        n[s] = v + cols[s][t];
      }
      final tmp = a;
      a = n;
      n = tmp;
    }
    return _lae(a[l - 1], a[l - 2]);
  }

  String greedy(Float32List lp, int frames) {
    final sb = StringBuffer();
    var prev = -1;
    for (var t = 0; t < frames; t++) {
      var best = 0;
      var bv = lp[t * vocab];
      for (var v = 1; v < vocab; v++) {
        if (lp[t * vocab + v] > bv) {
          bv = lp[t * vocab + v];
          best = v;
        }
      }
      if (best != prev && best > 3 && !_blankIds.contains(best)) {
        sb.write(tokens[best]);
      }
      if (best != prev && best == 3 && sb.isNotEmpty) sb.write(' ');
      prev = best;
    }
    return sb.toString().trim();
  }

  /// Aday kelimelerin (ör. "kar" / "kay") olasılıkları (toplamı 1) ve en iyi
  /// adayın uyum puanı; uyum [mismatchFit] altındaysa ikisi de söylenmemiştir.
  (Map<String, double>, double) compareWords(
    Float32List logProbs,
    int frames,
    List<String> candidates,
  ) {
    final (blank, emis, bestPath) = _emissions(logProbs, frames);
    final scores = [
      for (final c in candidates)
        _ctc(frames, blank, emis, toClasses(tokenize(c).join())),
    ];
    final mx = scores.reduce(math.max);
    final exps = scores.map((s) => math.exp(s - mx)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return (
      {
        for (var i = 0; i < candidates.length; i++)
          candidates[i]: exps[i] / sum,
      },
      frames == 0 ? double.negativeInfinity : (mx - bestPath) / frames,
    );
  }

  /// Boşluk ve sınıf log-olasılıkları, bir de en iyi yolun toplamı.
  (Float64List, Map<String, Float64List>, double) _emissions(
    Float32List logProbs,
    int frames,
  ) {
    final blank = Float64List(frames);
    final emis = <String, Float64List>{
      for (final c in classes.keys) c: Float64List(frames),
    };
    var bestPath = 0.0;
    for (var t = 0; t < frames; t++) {
      final base = t * vocab;
      blank[t] = _logSumExp(logProbs, base, _blankIds);
      var m = double.negativeInfinity;
      for (var v = 0; v < vocab; v++) {
        if (logProbs[base + v] > m) m = logProbs[base + v];
      }
      bestPath += m;
      for (final e in _classIds.entries) {
        emis[e.key]![t] = _logSumExp(logProbs, base, e.value);
      }
    }
    return (blank, emis, bestPath);
  }

  /// [logProbs] kare × sözlük boyutunda, satır satır.
  PronunciationResult evaluate(
    Float32List logProbs,
    int frames,
    String text,
    String targetLetter,
  ) {
    final target = trLower(targetLetter);
    final words = tokenize(text);
    final flat = words.join();
    final (blank, emis, bestPath) = _emissions(logProbs, frames);

    final fullSeq = toClasses(flat);
    final fit = frames == 0
        ? double.negativeInfinity
        : (_ctc(frames, blank, emis, fullSeq) - bestPath) / frames;

    final checks = <SoundCheck>[];
    final errs = errors[target] ?? const [];
    var wordStart = 0;
    for (final w in words) {
      for (var i = 0; i < w.length; i++) {
        if (w[i] != target) continue;
        final pos = wordStart + i;
        final pre = toClasses(flat.substring(0, pos));
        final suf = toClasses(flat.substring(pos + 1));
        final hyps = <(String, List<String>)>[
          (SoundCheck.correctLabel, _variant(target)),
          for (final e in errs) (e.$2, _variant(e.$1)),
        ];
        final scores = [
          for (final h in hyps)
            _ctc(frames, blank, emis, _collapse([...pre, ...h.$2, ...suf])),
        ];
        final mx = scores.reduce(math.max);
        final exps = scores.map((s) => math.exp(s - mx)).toList();
        final sum = exps.reduce((a, b) => a + b);
        checks.add(
          SoundCheck(
            position: pos,
            word: w,
            indexInWord: i,
            probs: {
              for (var k = 0; k < hyps.length; k++) hyps[k].$1: exps[k] / sum,
            },
          ),
        );
      }
      wordStart += w.length;
    }

    return PronunciationResult(
      text: text,
      targetLetter: targetLetter,
      checks: checks,
      heardPhones: greedy(logProbs, frames),
      mismatch: fit < mismatchFit,
      fit: fit,
    );
  }
}
