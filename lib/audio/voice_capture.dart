import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../services/recordings.dart';

class CaptureResult {
  /// 16 kHz mono, -1..1; baştaki/sondaki sessizlik kırpılmış.
  final Float32List samples;

  /// Konuşma algılandı mı? Algılanmadıysa analiz edilmemeli.
  final bool hadSpeech;

  const CaptureResult(this.samples, this.hadSpeech);

  Duration get duration =>
      Duration(milliseconds: samples.length * 1000 ~/ VoiceCapture.sampleRate);
}

/// Mikrofondan 16 kHz ham ses alır; konuşma bitince kendiliğinden durur.
///
/// Konuşma algılama: 20 ms'lik parçaların enerjisi, ilk anlardaki ortam
/// gürültüsünün belirgin üstündeyse "konuşma" sayılır. Hiç konuşma yoksa
/// sonuç boş döner; böylece sessizliğe anlam yüklenmez.
class VoiceCapture {
  static const sampleRate = 16000;
  static const _chunk = 320; // 20 ms
  static const _minSpeech = 10; // 200 ms konuşma şart
  static const _endSilence = 45; // konuşmadan sonra 900 ms sessizlik → dur
  static const _maxChunks = 600; // en fazla 12 sn

  final void Function(double level)? onLevel;
  final _done = Completer<CaptureResult>();
  final List<double> _samples = [];
  final List<bool> _speechChunks = [];
  final List<double> _pending = [];
  StreamSubscription? _sub;
  double _noise = 0.004;
  int _speechCount = 0, _silenceAfter = 0;
  bool _stopping = false;

  VoiceCapture({this.onLevel});

  Future<CaptureResult> get result => _done.future;

  Future<void> start({bool autoStop = true}) async {
    final store = RecordingStore.instance;
    if (!await store.hasPermission()) {
      throw StateError('Mikrofon izni verilmedi.');
    }
    final stream = await store.startPcmStream(sampleRate: sampleRate);
    _sub = stream.listen((bytes) {
      final data = ByteData.sublistView(bytes);
      for (var i = 0; i + 1 < bytes.length; i += 2) {
        _pending.add(data.getInt16(i, Endian.little) / 32768.0);
      }
      while (_pending.length >= _chunk) {
        final c = _pending.sublist(0, _chunk);
        _pending.removeRange(0, _chunk);
        _onChunk(c, autoStop);
      }
    });
  }

  void _onChunk(List<double> c, bool autoStop) {
    _samples.addAll(c);
    var sq = 0.0;
    for (final v in c) {
      sq += v * v;
    }
    final rms = math.sqrt(sq / c.length);
    // Ortam gürültüsünü yavaşça izle (yalnızca sessiz parçalarda).
    final threshold = math.max(0.012, _noise * 3);
    final speech = rms > threshold;
    if (!speech) _noise = _noise * 0.95 + rms * 0.05;
    _speechChunks.add(speech);
    onLevel?.call((rms / 0.2).clamp(0.0, 1.0));
    if (speech) {
      _speechCount++;
      _silenceAfter = 0;
    } else if (_speechCount > 0) {
      _silenceAfter++;
    }
    if (autoStop &&
        ((_speechCount >= _minSpeech && _silenceAfter >= _endSilence) ||
            _speechChunks.length >= _maxChunks)) {
      stop();
    }
  }

  Future<void> stop() async {
    if (_stopping) return;
    _stopping = true;
    await _sub?.cancel();
    await RecordingStore.instance.stopPcmStream();
    if (_speechCount < _minSpeech) {
      _done.complete(CaptureResult(Float32List(0), false));
      return;
    }
    // Konuşmanın başından 250 ms önce, sonundan 300 ms sonrasına kadar kırp.
    final first = _speechChunks.indexOf(true);
    final last = _speechChunks.lastIndexOf(true);
    final from = math.max(0, (first - 12) * _chunk);
    final to = math.min(_samples.length, (last + 16) * _chunk);
    _done.complete(
      CaptureResult(Float32List.fromList(_samples.sublist(from, to)), true),
    );
  }

  Future<void> cancel() async {
    if (_stopping) return;
    _stopping = true;
    await _sub?.cancel();
    await RecordingStore.instance.stopPcmStream();
    if (!_done.isCompleted) {
      _done.complete(CaptureResult(Float32List(0), false));
    }
  }
}

/// 16 bit PCM WAV dosyası baytları.
Uint8List encodeWav(Float32List samples, {int sampleRate = 16000}) {
  final dataLen = samples.length * 2;
  final b = ByteData(44 + dataLen);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + dataLen, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, dataLen, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    b.setInt16(
      44 + i * 2,
      (samples[i].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  return b.buffer.asUint8List();
}
