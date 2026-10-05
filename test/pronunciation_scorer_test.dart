import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pelteklige_lanet/audio/pronunciation_scorer.dart';

void main() {
  final scorer = PronunciationScorer.fromTokensFile(
    File('assets/models/tokens.txt').readAsStringSync(),
  );
  // Fikstürler Python prototipiyle (scripts/model_eval) gerçek model çıktısından üretildi.
  final fx = jsonDecode(
    File('test/fixtures/scorer_fixture.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  for (final e in fx.entries) {
    test('Python ile aynı olasılıklar: ${e.key}', () {
      final d = e.value as Map<String, dynamic>;
      final lp = Float32List.fromList(
        (d['logprobs'] as List).map((x) => (x as num).toDouble()).toList(),
      );
      final r = scorer.evaluate(
        lp,
        d['T'] as int,
        d['word'] as String,
        d['target'] as String,
      );
      final exp = d['expected'] as List;
      expect(r.checks.length, exp.length);
      for (var i = 0; i < exp.length; i++) {
        final probs = (exp[i]['probs'] as Map).cast<String, num>();
        for (final p in probs.entries) {
          expect(
            r.checks[i].probs[p.key],
            closeTo(p.value.toDouble(), 0.01),
            reason: p.key,
          );
        }
      }
      expect(r.fit, closeTo((d['fit'] as num).toDouble(), 0.01));
      expect('▁${r.heardPhones}', d['greedy']);
    });
  }

  test('radyo doğru, yadyo hatalı (R yerine Y) bulunur', () {
    PronunciationResult run(String key) {
      final d = fx[key] as Map<String, dynamic>;
      final lp = Float32List.fromList(
        (d['logprobs'] as List).map((x) => (x as num).toDouble()).toList(),
      );
      return scorer.evaluate(lp, d['T'] as int, 'radyo', 'R');
    }

    expect(run('pp_radyo.wav').checks.single.verdict, Verdict.correct);
    final bad = run('pp_yadyo.wav').checks.single;
    expect(bad.verdict, Verdict.error);
    expect(bad.topError.key, 'R yerine Y');
  });

  test('sınıf dizisi', () {
    expect(PronunciationScorer.toClasses('dağa'), ['d', 'a']);
    expect(PronunciationScorer.toClasses('çocuk'), [
      't',
      'ş',
      'o',
      'd',
      'j',
      'u',
      'k',
    ]);
  });
}
