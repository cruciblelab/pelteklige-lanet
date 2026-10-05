import 'dart:math' as math;

import 'turkish.dart';

/// Hedef metin ile tanınan metni kelime kelime hizalar.
///
/// Amaç: atlanan (yutulan) kelimeleri, kısaltılan kelimeleri ve hangi harfin
/// hangi harfe dönüştüğünü (ör. r → y) bulmak.
enum WordStatus { correct, close, wrong, missed }

class CharEdit {
  /// Beklenen harf ('' ise fazladan söylenmiş harf).
  final String expected;

  /// Duyulan harf ('' ise harf atlanmış).
  final String got;

  const CharEdit(this.expected, this.got);

  bool get isDeletion => got.isEmpty;
  bool get isInsertion => expected.isEmpty;

  String get label {
    if (isDeletion) return '$expected → (atlandı)';
    if (isInsertion) return '(fazla) $got';
    return '$expected → $got';
  }

  @override
  bool operator ==(Object other) =>
      other is CharEdit && other.expected == expected && other.got == got;

  @override
  int get hashCode => Object.hash(expected, got);

  @override
  String toString() => label;
}

class WordResult {
  /// Ekranda gösterilecek orijinal kelime (noktalama dahil).
  final String display;
  final String target;
  final String? heard;
  final WordStatus status;
  final double similarity;
  final List<CharEdit> edits;

  const WordResult({
    required this.display,
    required this.target,
    required this.heard,
    required this.status,
    required this.similarity,
    required this.edits,
  });

  /// Kelime tanındı ama hedeften kısa: hece veya ses yutulmuş olabilir.
  bool get shortened =>
      heard != null &&
      status != WordStatus.correct &&
      status != WordStatus.missed &&
      heard!.length < target.length;
}

class AlignmentResult {
  final List<WordResult> words;
  final List<String> extraWords;

  const AlignmentResult(this.words, this.extraWords);

  int get correctCount =>
      words.where((w) => w.status == WordStatus.correct).length;

  int get missedCount =>
      words.where((w) => w.status == WordStatus.missed).length;

  double get accuracy => words.isEmpty ? 0 : correctCount / words.length;

  /// "r → y" gibi harf dönüşümlerinin sayısı, en sık olandan başlayarak.
  List<MapEntry<String, int>> get substitutions {
    final counts = <String, int>{};
    for (final w in words) {
      if (w.status == WordStatus.missed) continue;
      for (final e in w.edits) {
        counts[e.label] = (counts[e.label] ?? 0) + 1;
      }
    }
    final list = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }
}

/// İki kelime arasındaki harf düzeyindeki farklar (Levenshtein geri izleme).
List<CharEdit> charEdits(String a, String b) {
  final n = a.length, m = b.length;
  final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= m; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final c = a[i - 1] == b[j - 1] ? 0 : 1;
      d[i][j] = math.min(
        d[i - 1][j - 1] + c,
        math.min(d[i - 1][j] + 1, d[i][j - 1] + 1),
      );
    }
  }
  final edits = <CharEdit>[];
  var i = n, j = m;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0) {
      final c = a[i - 1] == b[j - 1] ? 0 : 1;
      if (d[i][j] == d[i - 1][j - 1] + c) {
        if (c == 1) edits.add(CharEdit(a[i - 1], b[j - 1]));
        i--;
        j--;
        continue;
      }
    }
    if (i > 0 && d[i][j] == d[i - 1][j] + 1) {
      edits.add(CharEdit(a[i - 1], ''));
      i--;
    } else {
      edits.add(CharEdit('', b[j - 1]));
      j--;
    }
  }
  return edits.reversed.toList();
}

int levenshtein(String a, String b) => charEdits(a, b).length;

double similarity(String a, String b) {
  if (a == b) return 1;
  final maxLen = math.max(a.length, b.length);
  if (maxLen == 0) return 1;
  return 1 - levenshtein(a, b) / maxLen;
}

WordStatus _statusFor(double sim) {
  if (sim >= 1) return WordStatus.correct;
  if (sim >= 0.6) return WordStatus.close;
  return WordStatus.wrong;
}

/// [targetText] okunması gereken metin, [heardText] tanıyıcının duyduğu.
AlignmentResult alignTexts(String targetText, String heardText) {
  final display = <String>[];
  final target = <String>[];
  for (final raw in targetText.split(RegExp(r'\s+'))) {
    final n = normalizeText(raw).replaceAll(' ', '');
    if (n.isEmpty) continue;
    display.add(raw);
    target.add(n);
  }
  final heard = tokenize(heardText);

  final n = target.length, m = heard.length;
  // cost[i][j]: ilk i hedef kelime ile ilk j duyulan kelimenin en düşük maliyeti.
  final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  final sims = List.generate(n, (i) => List<double>.filled(m, 0));
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < m; j++) {
      sims[i][j] = similarity(target[i], heard[j]);
    }
  }
  for (var i = 1; i <= n; i++) {
    cost[i][0] = i.toDouble();
  }
  for (var j = 1; j <= m; j++) {
    cost[0][j] = j.toDouble();
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final sub = cost[i - 1][j - 1] + 2 * (1 - sims[i - 1][j - 1]);
      final del = cost[i - 1][j] + 1;
      final ins = cost[i][j - 1] + 1;
      cost[i][j] = math.min(sub, math.min(del, ins));
    }
  }

  final words = <WordResult>[];
  final extras = <String>[];
  var i = n, j = m;
  const eps = 1e-9;
  while (i > 0 || j > 0) {
    if (i > 0 &&
        j > 0 &&
        (cost[i][j] - (cost[i - 1][j - 1] + 2 * (1 - sims[i - 1][j - 1])))
                .abs() <
            eps) {
      final sim = sims[i - 1][j - 1];
      words.add(
        WordResult(
          display: display[i - 1],
          target: target[i - 1],
          heard: heard[j - 1],
          status: _statusFor(sim),
          similarity: sim,
          edits: sim >= 1 ? const [] : charEdits(target[i - 1], heard[j - 1]),
        ),
      );
      i--;
      j--;
    } else if (i > 0 && (cost[i][j] - (cost[i - 1][j] + 1)).abs() < eps) {
      words.add(
        WordResult(
          display: display[i - 1],
          target: target[i - 1],
          heard: null,
          status: WordStatus.missed,
          similarity: 0,
          edits: const [],
        ),
      );
      i--;
    } else {
      extras.add(heard[j - 1]);
      j--;
    }
  }
  return AlignmentResult(words.reversed.toList(), extras.reversed.toList());
}
