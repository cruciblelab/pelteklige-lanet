import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/phoneme_model.dart';
import '../audio/voice_capture.dart';
import '../services/recordings.dart';
import '../services/stt.dart';

/// Mikrofona basınca dinler, konuşma bitince kendisi durur ve sesi verir.
/// Fonem modeli ilk kullanımda yüklenir. Sessizlikte [onSilence] çağrılır.
class ModelListenButton extends StatefulWidget {
  final String label;
  final Future<void> Function(Float32List samples) onSpeech;
  final VoidCallback onSilence;

  const ModelListenButton({
    super.key,
    required this.label,
    required this.onSpeech,
    required this.onSilence,
  });

  @override
  State<ModelListenButton> createState() => _ModelListenButtonState();
}

class _ModelListenButtonState extends State<ModelListenButton> {
  VoiceCapture? _cap;
  bool _listening = false, _busy = false;
  double _level = 0;

  @override
  void dispose() {
    _cap?.cancel();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_listening) {
      await _cap?.stop();
      return;
    }
    if (await RecordingStore.instance.isRecording) return;
    if (Stt.instance.isListening) await Stt.instance.cancel();
    setState(() => _busy = true);
    try {
      if (!await PhonemeModel.isBundled()) {
        throw StateError('Bu sürümde ses modeli yok.');
      }
      await PhonemeModel.instance.load();
      final cap = _cap = VoiceCapture(
        onLevel: (l) {
          if (mounted) setState(() => _level = l);
        },
      );
      await cap.start();
      setState(() {
        _busy = false;
        _listening = true;
      });
      final r = await cap.result;
      if (!mounted) return;
      setState(() {
        _listening = false;
        _busy = r.hadSpeech;
      });
      if (r.hadSpeech) {
        await widget.onSpeech(r.samples);
      } else {
        widget.onSilence();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _listening = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : _tap,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_listening ? Icons.stop : Icons.mic),
          label: Text(_listening ? 'Dinliyorum…' : widget.label),
        ),
        if (_listening)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(value: _level),
          ),
      ],
    );
  }
}
