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

/// "D'den R'ye köprü": dil terapisinde kullanılan geçiş tekniği.
///
/// "ada" giderek hızlı söylendiğinde dil ucunun diş etine dokunuşu kısalır
/// ve R'ye (tek vuruş, [ɾ]) dönüşür. İbre sesin D'ye mi R'ye mi yakın
/// olduğunu gösterir. Kişinin hatası (ör. L) baskın çıkarsa o da söylenir.
class BridgeScreen extends StatefulWidget {
  final SoundInfo sound;
  final Level level;

  const BridgeScreen({super.key, required this.sound, required this.level});

  @override
  State<BridgeScreen> createState() => _BridgeScreenState();
}

class _BridgeScreenState extends State<BridgeScreen> {
  int _index = 0;
  double? _ratio;
  String? _message;
  bool _good = false;

  (String, String) get _pair => widget.sound.bridge[_index];
  String get _target => _pair.$1;
  String get _helper => _pair.$2;

  Future<void> _onSpeech(Float32List samples) async {
    final letter = widget.sound.letter;
    final r = letter.toLowerCase();
    final focus = Progress.instance.focusError(widget.sound.id);
    final focusShort = focus == null
        ? null
        : PronunciationScorer.errorShort(focus);
    final errWord =
        focusShort != null && focusShort.length == 1 && focusShort != 'D'
        ? _target.replaceAll(r, focusShort.toLowerCase())
        : null;
    final cands = [_target, _helper, ?errWord];
    final (probs, fit) = await PhonemeModel.instance.compare(samples, cands);
    if (!mounted) return;
    if (fit < PronunciationScorer.mismatchFit) {
      setState(() {
        _ratio = null;
        _message =
            '“$_target” ya da “$_helper” gibi duyulmadı. Tek kelime, net söyle.';
      });
      return;
    }
    final pr = probs[_target]!, pd = probs[_helper]!;
    final ratio = pr / (pr + pd);
    final pe = errWord == null ? 0.0 : probs[errWord]!;
    final good = ratio >= FocusResult.correctFrom && pr > pe;
    String msg;
    if (good) {
      msg = 'Oldu, bu bir $letter! Aynı hızla birkaç kez tekrarla.';
    } else if (errWord != null && pe > pr && pe > pd) {
      msg =
          '$focusShort gibi duyuldu. ${PronunciationScorer.tips[focus] ?? ''}';
    } else if (ratio < FocusResult.errorBelow) {
      msg = 'Hâlâ D. Daha hızlı ve daha hafif söyle; dil ucu sadece dokunup kalksın.';
    } else {
      msg = 'Yaklaştın! D ile $letter arasında. Biraz daha hızlı.';
    }
    final passedNow = Progress.instance.record(
      widget.sound.id,
      widget.level.id,
      good,
    );
    setState(() {
      _ratio = ratio;
      _message = msg;
      _good = good;
    });
    if (passedNow) showLevelPassedDialog(context, widget.sound, widget.level);
  }

  void _go(int delta) => setState(() {
    final n = widget.sound.bridge.length;
    _index = (_index + delta + n) % n;
    _ratio = null;
    _message = null;
    _good = false;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letter = widget.sound.letter;
    return Scaffold(
      appBar: AppBar(
        title: Text('$letter · Köprü'),
        actions: [
          TextButton.icon(
            onPressed: () => showHowSheet(context, widget.sound),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Nasıl?'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: LevelDots(sound: widget.sound, level: widget.level),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(
            '“$_helper” de ve durmadan hızlan: $_helper-$_helper-$_helper… '
            'Dil ucu hafifçe vurunca “$_target” olur.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: () => _go(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _WordChip(
                      word: _helper,
                      faded: true,
                      onTap: () => Tts.instance.speak(_helper),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 28),
                    ),
                    _WordChip(
                      word: _target,
                      faded: false,
                      onTap: () => Tts.instance.speak(_target),
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
          const SizedBox(height: 16),
          Center(
            child: ModelListenButton(
              key: ValueKey(_target),
              label: 'Dokun ve “$_target” de',
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
                    errorLabel: 'D',
                  ),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _good ? FocusGauge.good : null,
                        fontWeight: _good ? FontWeight.bold : null,
                      ),
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

class _WordChip extends StatelessWidget {
  final String word;
  final bool faded;
  final VoidCallback onTap;

  const _WordChip({
    required this.word,
    required this.faded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          children: [
            Text(
              word,
              style:
                  (faded
                          ? theme.textTheme.headlineMedium
                          : theme.textTheme.displayMedium)
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: faded
                            ? theme.colorScheme.outline
                            : theme.colorScheme.primary,
                      ),
            ),
            Icon(Icons.volume_up, size: 18, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}
