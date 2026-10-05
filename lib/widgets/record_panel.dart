import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/recordings.dart';
import '../services/stt.dart';

/// Kayıt al → kendi sesini dinle akışı. Bir etiket için son kaydı hatırlar.
class RecordPanel extends StatefulWidget {
  final String label;
  final String category;
  final void Function(RecordingEntry entry)? onRecorded;
  final bool compact;

  const RecordPanel({
    super.key,
    required this.label,
    required this.category,
    this.onRecorded,
    this.compact = false,
  });

  @override
  State<RecordPanel> createState() => _RecordPanelState();
}

class _RecordPanelState extends State<RecordPanel> {
  final _store = RecordingStore.instance;
  bool _recording = false;
  bool _playing = false;
  double _level = 0;
  RecordingEntry? _last;
  StreamSubscription? _ampSub, _playerSub;
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _loadLast();
    _playerSub = _store.player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
  }

  @override
  void didUpdateWidget(RecordPanel old) {
    super.didUpdateWidget(old);
    if (old.label != widget.label) {
      _last = null;
      _loadLast();
    }
  }

  Future<void> _loadLast() async {
    final list = await _store.byLabel(widget.label);
    if (mounted) setState(() => _last = list.isEmpty ? null : list.first);
  }

  @override
  void dispose() {
    if (_recording) _store.cancel();
    _ampSub?.cancel();
    _playerSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      _ampSub?.cancel();
      _timer?.cancel();
      final e = await _store.stop();
      setState(() {
        _recording = false;
        _level = 0;
        if (e != null) _last = e;
      });
      if (e != null) {
        widget.onRecorded?.call(e);
      } else if (mounted) {
        _snack('Kayıt çok kısa oldu, tekrar dene.');
      }
      return;
    }
    if (Stt.instance.isListening) await Stt.instance.cancel();
    final ok = await _store.start(
      label: widget.label,
      category: widget.category,
    );
    if (!ok) {
      _snack('Mikrofon izni gerekli. Telefon ayarlarından izin verebilirsin.');
      return;
    }
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    _ampSub = _store.amplitude().listen((a) {
      // -60 dB sessizlik, 0 dB en yüksek
      final v = ((a.current + 60) / 60).clamp(0.0, 1.0);
      if (mounted) setState(() => _level = v);
    });
    setState(() => _recording = true);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _togglePlay() async {
    if (_playing) {
      await _store.stopPlayback();
    } else if (_last != null) {
      await _store.play(_last!.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recordBtn = SizedBox(
      width: widget.compact ? 56 : 72,
      height: widget.compact ? 56 : 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_recording)
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: (widget.compact ? 44 : 58) + 20 * _level,
              height: (widget.compact ? 44 : 58) + 20 * _level,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.25),
              ),
            ),
          FloatingActionButton(
            heroTag: null,
            onPressed: _toggleRecord,
            backgroundColor: _recording ? Colors.red : scheme.primary,
            foregroundColor: Colors.white,
            tooltip: _recording ? 'Kaydı durdur' : 'Kaydet',
            child: Icon(_recording ? Icons.stop : Icons.mic, size: 30),
          ),
        ],
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        recordBtn,
        const SizedBox(width: 16),
        if (_recording)
          Text(
            'Kaydediliyor  ${_seconds}s',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          FilledButton.tonalIcon(
            onPressed: _last == null ? null : _togglePlay,
            icon: Icon(_playing ? Icons.stop : Icons.hearing),
            label: Text(_playing ? 'Durdur' : 'Kendi sesimi dinle'),
          ),
      ],
    );
  }
}
