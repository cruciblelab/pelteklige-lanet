import 'dart:math' as math;

import 'package:flutter_tts/flutter_tts.dart';

import 'settings.dart';

/// Cihazın Türkçe metin okuma motoru ile örnek söyleyiş.
///
/// Not: Tek bir harfi ("r") okutmak motorun harfin adını ("re") söylemesine
/// yol açar; bu yüzden örnekler hece ve kelime üzerinden verilir.
class Tts {
  Tts._();
  static final instance = Tts._();

  final _tts = FlutterTts();
  bool _ready = false;
  bool available = true;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      final ok = await _tts.isLanguageAvailable('tr-TR');
      available = ok == true || ok == 1;
      await _tts.setLanguage('tr-TR');
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      available = false;
    }
  }

  Future<void> speak(String text, {bool slow = false}) async {
    await _init();
    final rate = Settings.instance.speechRate;
    await _reset();
    await _tts.setSpeechRate(slow ? rate * 0.6 : rate);
    await _tts.stop();
    await _tts.speak(text);
  }

  List<Map<String, String>>? _trVoices;
  bool _varied = false;

  /// Telefondaki Türkçe sesler (varsa birden fazla).
  Future<List<Map<String, String>>> _voices() async {
    if (_trVoices != null) return _trVoices!;
    try {
      final all = await _tts.getVoices as List?;
      _trVoices = [
        for (final v in all ?? const [])
          if (v is Map &&
              '${v['locale']}'
                  .toLowerCase()
                  .replaceAll('_', '-')
                  .startsWith('tr'))
            {'name': '${v['name']}', 'locale': '${v['locale']}'},
      ];
    } catch (_) {
      _trVoices = [];
    }
    return _trVoices!;
  }

  /// Kulak eğitimi için her seferinde farklı ses tonu, hız ve (varsa) farklı
  /// Türkçe ses. Araştırmada çok sesli dinleme daha iyi genelleniyor
  /// (Bradlow ve ark., 1997); gerçek insan kaydı kadar iyi değildir.
  Future<void> speakVaried(String text, math.Random rnd) async {
    await _init();
    final voices = await _voices();
    if (voices.length > 1) {
      await _tts.setVoice(voices[rnd.nextInt(voices.length)]);
    }
    await _tts.setPitch(0.75 + rnd.nextDouble() * 0.6);
    await _tts.setSpeechRate(0.32 + rnd.nextDouble() * 0.25);
    _varied = true;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _reset() async {
    if (!_varied) return;
    _varied = false;
    await _tts.setPitch(1.0);
    await _tts.setLanguage('tr-TR');
  }

  Future<void> stop() => _tts.stop();
}
