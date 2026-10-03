import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'settings.dart';

class SttException implements Exception {
  final String code;
  final String message;
  const SttException(this.code, this.message);

  /// Cihaz üzerinde Türkçe tanıma paketi yok gibi görünüyor.
  bool get offlineUnavailable =>
      code.contains('language') || code.contains('not_supported');

  @override
  String toString() => message;
}

/// Telefonun kendi konuşma tanıyıcısını (Android SpeechRecognizer) kullanır.
///
/// Gerçekçi sınırlar:
/// - Tanıyıcı kelime tanımak için eğitilmiştir, telaffuz değerlendirmek için
///   değil. Hafif bozuk söyleyişi çoğu zaman doğru kelimeye "düzeltir".
///   Bu yüzden en güvenilir olduğu yer: atlanan kelimeler ve minimal çiftler.
/// - Aynı anda hem kayıt hem tanıma yapılamaz (mikrofonu tek bir iş kullanır).
/// - [Settings.onDeviceOnly] yalnızca bir tercihtir: telefonda cihaz içi
///   tanıyıcı yoksa eklenti normal tanıyıcıya geçer ve ses Google
///   sunucularına gidebilir.
class Stt {
  Stt._();
  static final instance = Stt._();

  final _speech = SpeechToText();
  bool _initialized = false;
  String? _localeId;
  Completer<String>? _pending;
  String _last = '';

  bool get isListening => _speech.isListening;

  Future<bool> _init() async {
    if (_initialized) return _speech.isAvailable;
    _initialized = await _speech.initialize(
      onError: _onError,
      onStatus: _onStatus,
    );
    if (_initialized) {
      final locales = await _speech.locales();
      final tr = locales.where(
        (l) => l.localeId.toLowerCase().startsWith('tr'),
      );
      _localeId = tr.isNotEmpty ? tr.first.localeId : 'tr_TR';
    }
    return _initialized;
  }

  void _onError(SpeechRecognitionError e) {
    final p = _pending;
    if (p == null || p.isCompleted) return;
    // Hiçbir şey duyulmadıysa boş sonuç dön, hata gösterme.
    if (e.errorMsg == 'error_no_match' ||
        e.errorMsg == 'error_speech_timeout') {
      p.complete(_last);
      return;
    }
    p.completeError(SttException(e.errorMsg, _message(e.errorMsg)));
  }

  void _onStatus(String status) {
    final p = _pending;
    if (p == null || p.isCompleted) return;
    if (status == SpeechToText.doneStatus) p.complete(_last);
  }

  static String _message(String code) => switch (code) {
    'error_network' || 'error_network_timeout' || 'error_server' =>
      'İnternet bağlantısı gerekiyor ya da sunucuya ulaşılamadı.',
    'error_language_not_supported' || 'error_language_unavailable' =>
      'Telefonda Türkçe çevrimdışı konuşma tanıma paketi yok. '
          'Ayarlardan paketi indirebilir ya da "mümkünse telefonda" seçeneğini kapatabilirsin.',
    'error_permission' ||
    'error_insufficient_permissions' => 'Mikrofon izni verilmedi.',
    'error_busy' || 'error_recognizer_busy' =>
      'Tanıyıcı meşgul, birkaç saniye sonra tekrar dene.',
    'error_audio_error' || 'error_audio' => 'Mikrofon açılamadı.',
    _ => 'Konuşma tanıma hatası ($code).',
  };

  /// Dinler ve son tanınan metni döndürür. [onPartial] konuşurken gelir.
  Future<String> listen({
    void Function(String text)? onPartial,
    void Function(double level)? onLevel,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
    List<String>? hints,
  }) async {
    if (!await _init()) {
      throw const SttException(
        'init',
        'Bu telefonda konuşma tanıma servisi bulunamadı (Google uygulaması gerekebilir).',
      );
    }
    if (_speech.isListening) await _speech.cancel();
    _last = '';
    final completer = _pending = Completer<String>();
    await _speech.listen(
      onResult: (r) {
        _last = r.recognizedWords;
        onPartial?.call(_last);
        if (r.finalResult && !completer.isCompleted) completer.complete(_last);
      },
      onSoundLevelChange: onLevel,
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        onDevice: Settings.instance.onDeviceOnly,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        listenFor: listenFor,
        pauseFor: pauseFor,
        contextualPhrases: hints,
      ),
    );
    return completer.future;
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() async {
    await _speech.cancel();
    final p = _pending;
    if (p != null && !p.isCompleted) p.complete(_last);
  }
}
