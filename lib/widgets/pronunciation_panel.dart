import 'package:flutter/material.dart';

import '../audio/phoneme_model.dart';
import '../audio/pronunciation_scorer.dart';
import '../audio/voice_capture.dart';
import '../services/recordings.dart';
import '../services/settings.dart';
import '../services/stt.dart';

enum _Phase { idle, loading, listening, analyzing, done }

/// Cihaz içi fonem modeliyle hedef sesin doğru söylenip söylenmediğini gösterir.
class PronunciationPanel extends StatefulWidget {
  final String text;
  final String targetLetter;
  final String soundId;

  /// Her analizden sonra genel sonuç (alakasız söz ya da sessizlikte çağrılmaz).
  final void Function(Verdict overall)? onResult;

  const PronunciationPanel({
    super.key,
    required this.text,
    required this.targetLetter,
    required this.soundId,
    this.onResult,
  });

  @override
  State<PronunciationPanel> createState() => _PronunciationPanelState();
}

class _PronunciationPanelState extends State<PronunciationPanel> {
  _Phase _phase = _Phase.idle;
  VoiceCapture? _capture;
  double _level = 0;
  PronunciationResult? _result;
  RecordingEntry? _recording;
  String? _message;

  @override
  void dispose() {
    _capture?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_phase == _Phase.listening) {
      await _capture?.stop();
      return;
    }
    if (await RecordingStore.instance.isRecording) {
      _snack('Önce diğer kaydı durdur.');
      return;
    }
    if (Stt.instance.isListening) await Stt.instance.cancel();
    setState(() {
      _message = null;
      _result = null;
      _recording = null;
    });

    final model = PhonemeModel.instance;
    if (!model.isLoaded) {
      if (!await PhonemeModel.isBundled()) {
        setState(
          () => _message =
              'Bu sürümde ses modeli yok. CI ile derlenen APK’yı kullan '
              '(yerelde: tool/fetch_model.sh).',
        );
        return;
      }
      setState(() => _phase = _Phase.loading);
      try {
        await model.load();
      } catch (e) {
        setState(() {
          _phase = _Phase.idle;
          _message = 'Model yüklenemedi: $e';
        });
        return;
      }
    }

    final cap = _capture = VoiceCapture(
      onLevel: (l) {
        if (mounted) setState(() => _level = l);
      },
    );
    try {
      await cap.start();
    } catch (e) {
      setState(() {
        _phase = _Phase.idle;
        _message = '$e';
      });
      return;
    }
    setState(() => _phase = _Phase.listening);

    final captured = await cap.result;
    if (!mounted) return;
    if (!captured.hadSpeech) {
      setState(() {
        _phase = _Phase.idle;
        _message =
            'Ses duymadım. Telefonu ağzına biraz daha yaklaştırıp '
            'normal sesle tekrar dene.';
      });
      return;
    }

    setState(() => _phase = _Phase.analyzing);
    final rec = await RecordingStore.instance.saveBytes(
      encodeWav(captured.samples),
      label: '${widget.targetLetter}: ${widget.text}',
      category: 'alistirma',
      durationMs: captured.duration.inMilliseconds,
    );
    try {
      final r = await model.evaluate(
        captured.samples,
        widget.text,
        widget.targetLetter,
      );
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _result = r;
        _recording = rec;
      });
      if (!r.mismatch && r.checks.isNotEmpty) {
        final overall = r.checks.any((c) => c.verdict == Verdict.error)
            ? Verdict.error
            : r.checks.every((c) => c.verdict == Verdict.correct)
            ? Verdict.correct
            : Verdict.unsure;
        Settings.instance.logAttempt(
          widget.soundId,
          good: overall == Verdict.correct,
        );
        widget.onResult?.call(overall);
      }
    } catch (e) {
      setState(() {
        _phase = _Phase.idle;
        _message = 'Analiz başarısız: $e';
      });
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _phase == _Phase.loading || _phase == _Phase.analyzing;
    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.memory, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ses analizi (telefonda, internetsiz)',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy ? null : _start,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_phase == _Phase.listening ? Icons.stop : Icons.mic),
              label: Text(switch (_phase) {
                _Phase.loading => 'Model hazırlanıyor…',
                _Phase.listening => 'Dinliyorum… (bitince kendisi durur)',
                _Phase.analyzing => 'İnceliyorum…',
                _ => 'Söyle, sesimi incele',
              }),
            ),
            if (_phase == _Phase.listening)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(value: _level),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_message!),
              ),
            if (_result != null) ..._resultView(theme, _result!),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultView(ThemeData theme, PronunciationResult r) {
    final widgets = <Widget>[const SizedBox(height: 10)];
    if (r.mismatch) {
      widgets.add(
        _line(
          Icons.help_outline,
          Colors.orange,
          'Söylediğin, “${r.text}” metnine benzemedi. Kelimeyi tam ve net söyleyip tekrar dene.',
        ),
      );
    } else {
      for (final c in r.checks) {
        widgets.add(_checkRow(theme, c));
      }
    }
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            if (_recording != null)
              TextButton.icon(
                onPressed: () => RecordingStore.instance.play(_recording!.path),
                icon: const Icon(Icons.hearing),
                label: const Text('Bu kaydı dinle'),
              ),
            const Spacer(),
            Flexible(
              child: Text(
                'Duyulan sesler: /${r.heardPhones}/',
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    return widgets;
  }

  Widget _checkRow(ThemeData theme, SoundCheck c) {
    final w = c.word;
    final i = c.indexInWord;
    final wordSpan = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: w.substring(0, i)),
          TextSpan(
            text: w[i],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
          TextSpan(text: w.substring(i + 1)),
        ],
      ),
    );
    String pct(double p) => '%${(p * 100).round()}';
    final (icon, color, msg) = switch (c.verdict) {
      Verdict.correct => (
        Icons.check_circle,
        Colors.green,
        'Doğru duyuldu (${pct(c.correctProb)})',
      ),
      Verdict.error => (
        Icons.cancel,
        Colors.red,
        '${c.topError.key} (${pct(c.topError.value)})',
      ),
      Verdict.unsure => (
        Icons.help,
        Colors.orange,
        'Net değil: doğru ${pct(c.correctProb)}, '
            '${c.topError.key.toLowerCase()} ${pct(c.topError.value)}. Tekrar dene.',
      ),
    };
    final tip = c.verdict == Verdict.correct
        ? null
        : PronunciationScorer.tips[c.topError.key];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              DefaultTextStyle.merge(
                style: theme.textTheme.titleMedium,
                child: wordSpan,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(msg, style: TextStyle(color: color)),
              ),
            ],
          ),
          if (tip != null)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(tip)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, Color color, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}
