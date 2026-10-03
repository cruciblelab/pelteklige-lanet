import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

/// Kaldi uyumlu 80 bantlı log-mel filtre bankası (fbank) özellikleri.
///
/// Fonem modeli (k2-fsa / icefall) bu özelliklerle eğitildi; sherpa-onnx ve
/// kaldi-native-fbank ile aynı ayarlar kullanılır: 16 kHz, 25 ms pencere,
/// 10 ms adım, Povey penceresi, 0,97 ön vurgu, DC kaldırma, snip_edges=false,
/// mel aralığı 20 Hz – 7600 Hz. test/fbank_test.dart Python referansıyla
/// karşılaştırır.
class Fbank {
  static const sampleRate = 16000;
  static const frameLength = 400;
  static const frameShift = 160;
  static const paddedLength = 512;
  static const numBins = 80;
  static const _preemph = 0.97;
  static const _eps = 1.1920928955078125e-07; // float epsilon

  final FFT _fft = FFT(paddedLength);
  late final Float64List _window = Float64List.fromList(
    List.generate(
      frameLength,
      (i) => math
          .pow(0.5 - 0.5 * math.cos(2 * math.pi * i / (frameLength - 1)), 0.85)
          .toDouble(),
    ),
  );
  late final List<(int, Float64List)> _melBanks = _buildMelBanks();

  static double _mel(double f) => 1127.0 * math.log(1 + f / 700.0);

  List<(int, Float64List)> _buildMelBanks() {
    const numFftBins = paddedLength ~/ 2;
    const binWidth = sampleRate / paddedLength;
    final melLow = _mel(20);
    final melHigh = _mel(sampleRate / 2 - 400);
    final delta = (melHigh - melLow) / (numBins + 1);
    final banks = <(int, Float64List)>[];
    for (var b = 0; b < numBins; b++) {
      final left = melLow + b * delta;
      final center = melLow + (b + 1) * delta;
      final right = melLow + (b + 2) * delta;
      final weights = List<double>.filled(numFftBins, 0);
      var first = -1, last = -1;
      for (var i = 0; i < numFftBins; i++) {
        final m = _mel(binWidth * i);
        if (m > left && m < right) {
          weights[i] = m <= center
              ? (m - left) / (center - left)
              : (right - m) / (right - center);
          if (first < 0) first = i;
          last = i;
        }
      }
      banks.add((
        first,
        Float64List.fromList(weights.sublist(first, last + 1)),
      ));
    }
    return banks;
  }

  static int numFrames(int numSamples) =>
      (numSamples + frameShift ~/ 2) ~/ frameShift;

  /// [samples] -1..1 aralığında, 16 kHz mono. Dönüş: kare sayısı × 80.
  Float32List compute(Float32List samples) {
    final n = samples.length;
    final frames = numFrames(n);
    final out = Float32List(frames * numBins);
    final buf = Float64List(paddedLength);
    for (var f = 0; f < frames; f++) {
      final start = f * frameShift + frameShift ~/ 2 - frameLength ~/ 2;
      var sum = 0.0;
      for (var i = 0; i < frameLength; i++) {
        var s = start + i;
        // Kenarlarda yansıtma (Kaldi ExtractWindow ile aynı)
        while (s < 0 || s >= n) {
          s = s < 0 ? -s - 1 : 2 * n - 1 - s;
        }
        buf[i] = samples[s];
        sum += buf[i];
      }
      final mean = sum / frameLength;
      for (var i = 0; i < frameLength; i++) {
        buf[i] -= mean;
      }
      for (var i = frameLength - 1; i > 0; i--) {
        buf[i] -= _preemph * buf[i - 1];
      }
      buf[0] -= _preemph * buf[0];
      for (var i = 0; i < frameLength; i++) {
        buf[i] *= _window[i];
      }
      for (var i = frameLength; i < paddedLength; i++) {
        buf[i] = 0;
      }
      final spec = _fft.realFft(buf);
      final power = Float64List(paddedLength ~/ 2);
      for (var i = 0; i < power.length; i++) {
        final z = spec[i];
        power[i] = z.x * z.x + z.y * z.y;
      }
      for (var b = 0; b < numBins; b++) {
        final (offset, w) = _melBanks[b];
        var e = 0.0;
        for (var i = 0; i < w.length; i++) {
          e += w[i] * power[offset + i];
        }
        out[f * numBins + b] = math.log(math.max(e, _eps));
      }
    }
    return out;
  }
}
