import 'package:flutter/material.dart';

import '../audio/phoneme_model.dart';
import '../audio/pronunciation_scorer.dart';
import '../audio/voice_capture.dart';
import '../services/recordings.dart';
import '../services/progress.dart';
import '../services/settings.dart';
import '../services/stt.dart';
import 'focus_gauge.dart';

enum _Phase { idle, loading, listening, analyzing, done }

/// Söyle → ses analizi → "R ←●→ L" ibresi.
///
/// Kişinin hatası ([focusError], ör. "R yerine L") biliniyorsa yalnızca
/// doğrusu ile o hata yarıştırılır (odaklı mod). Bilinmiyorsa ibrenin karşı
/// ucunda o anki en olası hata durur.
class PronunciationPanel extends StatefulWidget {
  final String text;
  final String targetLetter;
  final String soundId;
  final String? focusError;
  final void Function(Verdict overall)? onResult;

  const PronunciationPanel({
    super.key,
    required this.text,
    required this.targetLetter,
    required this.soundId,
    this.focusError,
    this.onResult,
  });

  @override
  State<PronunciationPanel> createState() => _PronunciationPanelState();
}

class _Shown {
  final double ratio;
  final String errorLabel;
  final Verdict verdict;
  final SoundCheck check;
  final String? otherError;
  const _Shown(
    this.ratio,
    this.errorLabel,
    this.verdict,
    this.check,
    this.otherError,
  );
}

class _PronunciationPanelState extends State<PronunciationPanel> {
  _Phase _phase = _Phase.idle;
  VoiceCapture? _capture;
  double _level = 0;
  PronunciationResult? _result;
  _Shown? _shown;
  RecordingEntry? _recording;
  String? _message;
  bool _details = false;

  /// "Önce ben tahmin edeyim" açıksa kişinin tahmini (0 doğru, 1 arada, 2 hata).
  int? _guess;

  @override
  void dispose() {
    _capture?.cancel();
    super.dispose();
  }

  /// Gösterilecek tek sonuç: hedef sesin geçtiği yerlerden en kötüsü.
  _Shown? _pick(PronunciationResult r) {
    if (r.mismatch || r.checks.isEmpty) return null;
    _Shown? worst;
    for (final c in r.checks) {
      final _Shown s;
      if (widget.focusError != null && c.probs.containsKey(widget.focusError)) {
        final f = c.focus(widget.focusError!);
        s = _Shown(f.ratio, f.shownLabel, f.verdict, c, f.otherError);
      } else {
        final top = c.topError;
        final pc = c.correctProb;
        final ratio = pc + top.value <= 0 ? 0.5 : pc / (pc + top.value);
        s = _Shown(ratio, top.key, c.verdict, c, null);
      }
      if (worst == null || s.ratio < worst.ratio) worst = s;
    }
    return worst;
  }

  Future<void> _start() async {
    if (_phase == _Phase.listening) {
      await _capture?.stop();
      return;
    }
    if (await RecordingStore.instance.isRecording) return;
    if (Stt.instance.isListening) await Stt.instance.cancel();
    setState(() {
      _message = null;
      _result = null;
      _shown = null;
      _recording = null;
    });

    final model = PhonemeModel.instance;
    if (!model.isLoaded) {
      if (!await PhonemeModel.isBundled()) {
        setState(
          () => _message =
              'Bu sürümde ses modeli yok (yerelde: tool/fetch_model.sh).',
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
        _message = 'Ses duymadım. Biraz daha yakından, normal sesle söyle.';
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
      final shown = _pick(r);
      var annotated = rec;
      if (shown != null) {
        annotated = await RecordingStore.instance.annotate(
          rec,
          soundId: widget.soundId,
          errorLabel: shown.errorLabel,
          ratio: shown.ratio,
        );
      }
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _result = r;
        _shown = shown;
        _recording = annotated;
        _guess = null;
        if (shown == null) {
          _message =
              '“${widget.text}” gibi duyulmadı. Kelimeyi tam ve net söyle.';
        }
      });
      if (shown != null) {
        Settings.instance.logAttempt(
          widget.soundId,
          good: shown.verdict == Verdict.correct,
        );
        widget.onResult?.call(shown.verdict);
      }
    } catch (e) {
      setState(() {
        _phase = _Phase.idle;
        _message = 'Analiz başarısız: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _phase == _Phase.loading || _phase == _Phase.analyzing;
    final shown = _shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: MicButton(
            listening: _phase == _Phase.listening,
            busy: busy,
            level: _level,
            onTap: _start,
          ),
        ),
        Text(
          switch (_phase) {
            _Phase.loading => 'Model hazırlanıyor…',
            _Phase.listening => 'Dinliyorum… bitince kendisi durur',
            _Phase.analyzing => 'İnceliyorum…',
            _ when shown != null => 'Tekrar denemek için dokun',
            _ => 'Dokun ve söyle',
          },
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: shown == null
              ? (_message == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_message!, textAlign: TextAlign.center),
                      ))
              : (Settings.instance.selfEvalFirst && _guess == null)
              ? _guessView(theme, shown)
              : _resultView(theme, shown),
        ),
      ],
    );
  }

  /// Öz-değerlendirme: sonuç gösterilmeden önce kişinin kendi tahmini.
  Widget _guessView(ThemeData theme, _Shown s) {
    final err = PronunciationScorer.errorShort(s.errorLabel);
    final labels = [widget.targetLetter, 'Arada', err];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Text('Sence nasıl söyledin?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: () {
                        Progress.instance.recordEar(
                          'own',
                          i == FocusResult.categoryOf(s.ratio),
                        );
                        setState(() => _guess = i);
                      },
                      child: Text(labels[i], style: theme.textTheme.titleLarge),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultView(ThemeData theme, _Shown s) {
    final letter = widget.targetLetter;
    final errShort = PronunciationScorer.errorShort(s.errorLabel);
    final (title, color) = switch (s.verdict) {
      Verdict.correct => ('Harika, bu bir $letter!', FocusGauge.good),
      Verdict.error => ('$errShort gibi duyuldu', FocusGauge.bad),
      Verdict.unsure => (
        '$letter ile $errShort arasında',
        const Color(0xFF8D6E63),
      ),
    };
    final tip = s.verdict == Verdict.correct
        ? null
        : PronunciationScorer.tips[s.errorLabel];
    final multi = (_result?.checks.length ?? 0) > 1;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FocusGauge(
            ratio: s.ratio,
            correctLabel: letter,
            errorLabel: errShort,
            errorBelow: FocusResult.errorBelow,
            correctFrom: FocusResult.correctFrom,
          ),
          TweenAnimationBuilder<double>(
            key: ValueKey(_recording?.path),
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Text(
              multi ? '$title  ·  ${s.check.word}' : title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_guess != null)
            Text(
              _guess == FocusResult.categoryOf(s.ratio)
                  ? 'Tahminin modelle aynı.'
                  : 'Sen “${[widget.targetLetter, 'arada', PronunciationScorer.errorShort(s.errorLabel)][_guess!]}” dedin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          if (s.otherError != null)
            Text(
              'Seçili hatan “${PronunciationScorer.errorChip(widget.focusError ?? '')}”, '
              'ama bu sefer “${PronunciationScorer.errorChip(s.otherError!)}” duyuldu. '
              'Sık oluyorsa ses sayfasından hatanı değiştir.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          if (tip != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip, style: theme.textTheme.bodyLarge)),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_recording != null)
                TextButton.icon(
                  onPressed: () =>
                      RecordingStore.instance.play(_recording!.path),
                  icon: const Icon(Icons.hearing),
                  label: const Text('Kendimi dinle'),
                ),
              TextButton(
                onPressed: () => setState(() => _details = !_details),
                child: Text(_details ? 'Ayrıntıyı gizle' : 'Ayrıntı'),
              ),
            ],
          ),
          if (_details && _result != null) _detailsView(theme, _result!),
        ],
      ),
    );
  }

  Widget _detailsView(ThemeData theme, PronunciationResult r) {
    final style = theme.textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modelin duyduğu sesler: /${r.heardPhones}/', style: style),
        for (final c in r.checks) ...[
          const SizedBox(height: 4),
          Text('“${c.word}” içindeki ${widget.targetLetter}:', style: style),
          for (final e
              in (c.probs.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value))))
            Text('   ${e.key}: %${(e.value * 100).round()}', style: style),
        ],
      ],
    );
  }
}
