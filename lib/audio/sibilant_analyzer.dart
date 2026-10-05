import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

/// Tıslamalı seslerin (S, Ş, Z) spektrumunu ölçer.
///
/// Fikir: S sesinin enerjisi yüksek frekanslarda (yaklaşık 5–9 kHz) toplanır,
/// Ş sesi daha alçaktadır (yaklaşık 2,5–4,5 kHz). Dişler arası (peltek) S'de
/// ses kısık ve yayvandır, yanal S'de enerji Ş'ye doğru kayar. Spektral ağırlık
/// merkezi (centroid) bu farkı tek bir sayıyla gösterir.
///
/// Bu bir teşhis aracı değil, görsel geri bildirimdir: kişinin yaşı, sesi ve
/// telefonun mikrofonu değerleri kaydırır.
class SibilantFrame {
  /// Kare ses seviyesi (dBFS, 0 en yüksek).
  final double levelDb;

  /// 1 kHz üstündeki enerjinin ağırlık merkezi (Hz).
  final double centroidHz;

  /// En güçlü frekans (Hz).
  final double peakHz;

  /// 2 kHz üstü enerjinin toplam enerjiye oranı (0–1). Ünlülerde düşük,
  /// tıslamalı ünsüzlerde yüksektir.
  final double highRatio;

  const SibilantFrame({
    required this.levelDb,
    required this.centroidHz,
    required this.peakHz,
    required this.highRatio,
  });

  /// Tıslamalı bir ses mi (yeterince yüksek ve tiz)?
  bool get isFricative => levelDb > -55 && highRatio > 0.6;
}

enum SibilantZone { silence, low, sh, s }

class SibilantAnalyzer {
  final int sampleRate;
  final int frameSize;
  final FFT _fft;
  final Float64List _window;
  final List<double> _pending = [];

  /// S/Ş sınırı ve Ş alt sınırı (Hz). Çocuklarda frekanslar daha yüksektir.
  double shMinHz;
  double sMinHz;

  SibilantAnalyzer({
    this.sampleRate = 44100,
    this.frameSize = 2048,
    this.shMinHz = 2400,
    this.sMinHz = 4800,
  }) : _fft = FFT(frameSize),
       _window = Float64List.fromList(
         List.generate(
           frameSize,
           (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / (frameSize - 1)),
         ),
       );

  SibilantZone zoneOf(SibilantFrame f) {
    if (!f.isFricative) return SibilantZone.silence;
    if (f.centroidHz >= sMinHz) return SibilantZone.s;
    if (f.centroidHz >= shMinHz) return SibilantZone.sh;
    return SibilantZone.low;
  }

  /// Little-endian PCM16 baytlarını ekler, tamamlanan kareleri döndürür.
  List<SibilantFrame> addPcm16(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final samples = <double>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      samples.add(data.getInt16(i, Endian.little) / 32768.0);
    }
    return addSamples(samples);
  }

  List<SibilantFrame> addSamples(List<double> samples) {
    _pending.addAll(samples);
    final out = <SibilantFrame>[];
    final hop = frameSize ~/ 2;
    while (_pending.length >= frameSize) {
      out.add(analyzeFrame(_pending.sublist(0, frameSize)));
      _pending.removeRange(0, hop);
    }
    return out;
  }

  SibilantFrame analyzeFrame(List<double> frame) {
    assert(frame.length == frameSize);
    var sumSq = 0.0;
    final windowed = Float64List(frameSize);
    for (var i = 0; i < frameSize; i++) {
      sumSq += frame[i] * frame[i];
      windowed[i] = frame[i] * _window[i];
    }
    final rms = math.sqrt(sumSq / frameSize);
    final levelDb = 20 * math.log(math.max(rms, 1e-9)) / math.ln10;

    final power = _fft.realFft(windowed).discardConjugates().squareMagnitudes();
    final binHz = sampleRate / frameSize;
    final floor = (100 / binHz).ceil();
    final lo = (1000 / binHz).ceil();
    final split = (2000 / binHz).ceil();
    final hi = math.min(power.length - 1, (16000 / binHz).floor());

    var all = 0.0, high = 0.0, band = 0.0, weighted = 0.0, peak = 0.0;
    var peakBin = lo;
    for (var k = floor; k <= hi; k++) {
      final p = power[k];
      all += p;
      if (k >= split) high += p;
      if (k < lo) continue;
      band += p;
      weighted += p * k * binHz;
      if (p > peak) {
        peak = p;
        peakBin = k;
      }
    }

    return SibilantFrame(
      levelDb: levelDb,
      centroidHz: band > 0 ? weighted / band : 0,
      peakHz: peakBin * binHz,
      highRatio: all > 0 ? high / all : 0,
    );
  }

  void reset() => _pending.clear();
}
