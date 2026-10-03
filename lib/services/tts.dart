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
    await _tts.setSpeechRate(slow ? rate * 0.6 : rate);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
