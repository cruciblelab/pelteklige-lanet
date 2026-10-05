import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pelteklige_lanet/audio/sibilant_analyzer.dart';

List<double> sine(double hz, int n, {double amp = 0.3, int sr = 44100}) =>
    List.generate(n, (i) => amp * math.sin(2 * math.pi * hz * i / sr));

/// Belirli bir frekans bandında gürültü (sinüslerin rastgele fazlı toplamı).
List<double> bandNoise(double loHz, double hiHz, int n, {int sr = 44100}) {
  final rnd = math.Random(1);
  final out = List<double>.filled(n, 0);
  for (var f = loHz; f <= hiHz; f += 50) {
    final phase = rnd.nextDouble() * 2 * math.pi;
    for (var i = 0; i < n; i++) {
      out[i] += 0.01 * math.sin(2 * math.pi * f * i / sr + phase);
    }
  }
  return out;
}

void main() {
  test('6 kHz ses S bölgesine düşer', () {
    final a = SibilantAnalyzer();
    final f = a.analyzeFrame(sine(6000, 2048));
    expect(f.centroidHz, closeTo(6000, 150));
    expect(a.zoneOf(f), SibilantZone.s);
  });

  test('3,5 kHz ses Ş bölgesine düşer', () {
    final a = SibilantAnalyzer();
    final f = a.analyzeFrame(sine(3500, 2048));
    expect(f.centroidHz, closeTo(3500, 150));
    expect(a.zoneOf(f), SibilantZone.sh);
  });

  test('alçak frekanslı ünlü tıslama sayılmaz', () {
    final a = SibilantAnalyzer();
    final f = a.analyzeFrame(sine(500, 2048));
    expect(a.zoneOf(f), SibilantZone.silence);
  });

  test('sessizlik tıslama sayılmaz', () {
    final a = SibilantAnalyzer();
    final f = a.analyzeFrame(List.filled(2048, 0));
    expect(a.zoneOf(f), SibilantZone.silence);
  });

  test('bant gürültüsü merkezi bandın ortasına yakın', () {
    final a = SibilantAnalyzer();
    final f = a.analyzeFrame(bandNoise(5000, 8000, 2048));
    expect(f.centroidHz, inInclusiveRange(5800, 7200));
    expect(a.zoneOf(f), SibilantZone.s);
  });

  test('PCM16 akışı karelere bölünür', () {
    final a = SibilantAnalyzer();
    final samples = sine(6000, 4096);
    final bytes = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(i * 2, (samples[i] * 32767).round(), Endian.little);
    }
    final frames = a.addPcm16(bytes.buffer.asUint8List());
    expect(frames.length, 3); // 2048'lik kareler, 1024 adımla
  });
}
