import 'package:flutter/material.dart';

import '../services/recordings.dart';
import '../services/settings.dart';
import '../services/stt.dart';
import 'word_feedback.dart';

/// "Söyle, kontrol edeyim" düğmesi. Telefonun konuşma tanıyıcısını açar,
/// bitince [onResult] ile duyulan metni verir.
class SpeechCheckButton extends StatefulWidget {
  final void Function(String heard) onResult;
  final List<String>? hints;
  final String label;
  final Duration pauseFor;

  const SpeechCheckButton({
    super.key,
    required this.onResult,
    this.hints,
    this.label = 'Söyle, kontrol edeyim',
    this.pauseFor = const Duration(seconds: 3),
  });

  @override
  State<SpeechCheckButton> createState() => _SpeechCheckButtonState();
}

class _SpeechCheckButtonState extends State<SpeechCheckButton> {
  bool _listening = false;
  double _level = 0;
  String _partial = '';

  @override
  void dispose() {
    if (_listening) Stt.instance.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_listening) {
      await Stt.instance.stop();
      return;
    }
    if (await RecordingStore.instance.isRecording) {
      _snack('Önce kaydı durdur: mikrofon aynı anda iki işe yetmiyor.');
      return;
    }
    await RecordingStore.instance.stopPlayback();
    setState(() {
      _listening = true;
      _partial = '';
      _level = 0;
    });
    try {
      final heard = await Stt.instance.listen(
        hints: widget.hints,
        pauseFor: widget.pauseFor,
        onPartial: (t) {
          if (mounted) setState(() => _partial = t);
        },
        onLevel: (db) {
          if (mounted) setState(() => _level = (db + 2) / 12);
        },
      );
      if (!mounted) return;
      setState(() => _listening = false);
      widget.onResult(heard);
    } on SttException catch (e) {
      if (!mounted) return;
      setState(() => _listening = false);
      if (e.offlineUnavailable && Settings.instance.onDeviceOnly) {
        _offerOnline(e);
      } else {
        _snack(e.message);
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _offerOnline(SttException e) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çevrimdışı tanıma yok'),
        content: Text(
          '${e.message}\n\n'
          'Paketi indirmek için: Telefon Ayarları → Google → Ses / Konuşma tanıma → '
          'Çevrimdışı konuşma tanıma → Türkçe.\n\n'
          'Ya da şimdilik internet üzerinden tanımayı açabilirsin; bu durumda ses '
          'Google sunucularına gönderilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              Settings.instance.onDeviceOnly = false;
              Navigator.pop(ctx);
              _start();
            },
            child: const Text('İnternetle dene'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _start,
          icon: Icon(_listening ? Icons.stop : Icons.record_voice_over),
          label: Text(_listening ? 'Bitirdim' : widget.label),
        ),
        if (_listening)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ListeningIndicator(level: _level, partial: _partial),
          ),
      ],
    );
  }
}
