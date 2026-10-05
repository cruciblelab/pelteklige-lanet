import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pelteklige_lanet/audio/fbank.dart';

void main() {
  test('fbank kaldi-native-fbank ile aynı sonucu verir', () {
    // Fikstür Python'da kaldi_native_fbank ile üretildi (sherpa-onnx ayarları).
    final fx = jsonDecode(
      File('test/fixtures/fbank_fixture.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final samples = Float32List.fromList(
      (fx['samples'] as List).map((e) => (e as num).toDouble()).toList(),
    );
    final expected = (fx['fbank'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final out = Fbank().compute(samples);
    expect(Fbank.numFrames(samples.length), fx['frames']);
    expect(out.length, expected.length);
    var maxDiff = 0.0;
    for (var i = 0; i < out.length; i++) {
      final d = (out[i] - expected[i]).abs();
      if (d > maxDiff) maxDiff = d;
    }
    expect(maxDiff, lessThan(2e-3), reason: 'en büyük fark $maxDiff');
  });
}
