import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/phoneme_model.dart';
import '../audio/pronunciation_scorer.dart';
import '../models/sound.dart';
import '../services/progress.dart';
import '../services/tts.dart';
import '../widgets/focus_gauge.dart';
import '../widgets/model_listen_button.dart';
import 'practice_screen.dart';

/// "kar mı kal mı?": kişinin hatasıyla ayrışan kelime çiftleri. Model yalnızca
/// iki kelimeyi yarıştırır; ibre hangisine yakın söylendiğini gösterir.
class PairsScreen extends StatefulWidget {
  final SoundInfo sound;
  final Level level;

  const PairsScreen({super.key, required this.sound, required this.level});

  @override
  State<PairsScreen> createState() => _PairsScreenState();
}

class _PairsScreenState extends State<PairsScreen> {
  int _index = 0;
  double? _ratio;
  String? _message;
  Verdict? _verdict;

  (String, String) get _pair {
    final parts = widget.level.items[_index].split('|');
    return (parts[0], parts[1]);
  }

  String get _errShort => PronunciationScorer.errorShort(
    Progress.instance.focusError(widget.sound.id)!,
  );

  Future<void> _onSpeech(Float32List samples) async {
    final (target, wrong) = _pair;
    final (probs, fit) = await PhonemeModel.instance.compare(samples, [
      target,
      wrong,
    ]);
    if (!mounted) return;
    if (fit < PronunciationScorer.mismatchFit) {
      setState(() {
        _ratio = null;
        _verdict = null;
        _message =
            '“$target” ya da “$wrong” gibi duyulmadı. Tek kelime, net söyle.';
      });
      return;
    }
    final r = probs[target]!;
    final v = r < FocusResult.errorBelow
        ? Verdict.error
        : r >= FocusResult.correctFrom
        ? Verdict.correct
        : Verdict.unsure;
    final passedNow = Progress.instance.record(
      widget.sound.id,
      widget.level.id,
      v == Verdict.correct,
    );
    setState(() {
      _ratio = r;
      _verdict = v;
      _message = switch (v) {
        Verdict.correct => '“$target” dedin!',
        Verdict.error => '“$wrong” gibi duyuldu.',
        Verdict.unsure => '“$target” ile “$wrong” arasında.',
      };
    });
    if (passedNow) {
      showLevelPassedDialog(context, widget.sound, widget.level);
    } else if (v == Verdict.correct) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _verdict == Verdict.correct) _go(1);
      });
    }
  }

  void _go(int d) => setState(() {
    final n = widget.level.items.length;
    _index = (_index + d + n) % n;
    _ratio = null;
    _message = null;
    _verdict = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (target, wrong) = _pair;
    final letter = widget.sound.letter;
    final err = Progress.instance.focusError(widget.sound.id);
    final tip = err == null ? null : PronunciationScorer.tips[err];
    return Scaffold(
      appBar: AppBar(
        title: Text('$letter · Çiftler'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: LevelDots(sound: widget.sound, level: widget.level),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _go(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      target,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '“$wrong” değil',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _go(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Dinle',
                onPressed: () => Tts.instance.speak(target),
                icon: const Icon(Icons.volume_up),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Yavaş dinle',
                onPressed: () => Tts.instance.speak(target, slow: true),
                icon: const Icon(Icons.slow_motion_video),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: ModelListenButton(
              key: ValueKey(_index),
              label: 'Dokun ve “$target” de',
              onSpeech: _onSpeech,
              onSilence: () => setState(() {
                _ratio = null;
                _message = 'Ses duymadım, biraz daha yüksek söyle.';
              }),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: Column(
              children: [
                if (_ratio != null) ...[
                  const SizedBox(height: 12),
                  FocusGauge(
                    ratio: _ratio!,
                    correctLabel: letter,
                    errorLabel: _errShort,
                  ),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: switch (_verdict) {
                          Verdict.correct => FocusGauge.good,
                          Verdict.error => FocusGauge.bad,
                          _ => null,
                        },
                      ),
                    ),
                  ),
                if (_verdict != null &&
                    _verdict != Verdict.correct &&
                    tip != null)
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
                        Expanded(child: Text(tip)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
