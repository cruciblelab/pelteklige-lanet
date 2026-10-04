import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/phoneme_model.dart';
import '../audio/voice_capture.dart';
import '../services/recordings.dart';
import '../services/stt.dart';
import 'focus_gauge.dart';

/// Büyük mikrofon: dokununca dinler, konuşma bitince kendisi durur ve sesi
/// [onSpeech] ile verir. Fonem modeli ilk kullanımda yüklenir.
class ModelListenButton extends StatefulWidget {
  final String label;
  final Future<void> Function(Float32List samples) onSpeech;
  final VoidCallback onSilence;
  final double size;

  const ModelListenButton({
    super.key,
    required this.label,
    required this.onSpeech,
    required this.onSilence,
    this.size = 96,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        MicButton(
          listening: _listening,
          busy: _busy,
          level: _level,
          onTap: _tap,
          size: widget.size,
        ),
        Text(
          _listening
              ? 'Dinliyorum…'
              : _busy
              ? 'İnceliyorum…'
              : widget.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
