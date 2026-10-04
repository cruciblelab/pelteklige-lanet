import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/phoneme_model.dart';
import '../audio/pronunciation_scorer.dart';
import '../models/sound.dart';
import '../services/progress.dart';
import '../services/tts.dart';
import '../widgets/model_listen_button.dart';
import 'practice_screen.dart';

/// "D'den R'ye köprü": dil terapisinde kullanılan geçiş tekniği.
///
/// "ada" giderek hızlı söylendiğinde dil ucunun diş etine dokunuşu kısalır
/// ve R'ye (tek vuruş, [ɾ]) dönüşür. Model her denemede sesin R'ye mi, D'ye
/// mi, Y'ye mi, L'ye mi benzediğini gösterir; R'ye ulaşana kadar yönlendirir.
class BridgeScreen extends StatefulWidget {
  final SoundInfo sound;
  final Level level;

  const BridgeScreen({super.key, required this.sound, required this.level});

  @override
  State<BridgeScreen> createState() => _BridgeScreenState();
}

class _BridgeScreenState extends State<BridgeScreen> {
  int _index = 0;
  Map<String, double>? _probs;
  String? _message;
  bool _good = false;

  (String, String) get _pair => widget.sound.bridge[_index];
  String get _target => _pair.$1;
  String get _helper => _pair.$2;

  String _swap(String word, String to) {
    final r = widget.sound.letter.toLowerCase();
    return word.replaceAll(r, to);
  }

  /// Aday → kullanıcıya gösterilecek ses adı.
  Map<String, String> get _candidates {
    final m = <String, String>{_target: widget.sound.letter};
    void add(String w, String label) => m.putIfAbsent(w, () => label);
    add(_helper, 'D');
    add(_swap(_target, 'y'), 'Y');
    add(_swap(_target, 'l'), 'L');
    return m;
  }

  static const _coach = {
    'D':
        'D’ye yakın: dil ucun doğru yerde ama fazla bastırıyorsun. '
        'Aynı kelimeyi daha hızlı ve daha hafif söyle; dil sadece dokunup kalksın.',
    'Y':
        'Y’ye yakın: dil ucun yukarı çıkmıyor. Ucunu üst dişlerin arkasındaki '
        'kabarık yere kaldır.',
    'L': 'L’ye yakın: dil ucun yapışıp kalıyor. Dokun ve hemen bırak.',
  };

  Future<void> _onSpeech(Float32List samples) async {
    final cands = _candidates;
    final (probs, fit) = await PhonemeModel.instance.compare(
      samples,
      cands.keys.toList(),
    );
    if (!mounted) return;
    final byLabel = {for (final e in probs.entries) cands[e.key]!: e.value};
    final target = widget.sound.letter;
    final pt = byLabel[target] ?? 0;
    final top = byLabel.entries.reduce((a, b) => a.value >= b.value ? a : b);
    String msg;
    var good = false;
    if (fit < PronunciationScorer.mismatchFit) {
      msg =
          '“$_target” ya da “$_helper”a benzemedi. Kelimeyi tek ve net söyle.';
    } else if (pt >= 0.6) {
      good = true;
      msg =
          'Oldu! Bu bir $target (%${(pt * 100).round()}). Aynı hızla birkaç kez daha tekrarla.';
    } else {
      msg = _coach[top.key] ?? 'Arada kaldı, bir daha dene.';
    }
    if (fit >= PronunciationScorer.mismatchFit) {
      final passedNow = Progress.instance.record(
        widget.sound.id,
        widget.level.id,
        good,
      );
      if (passedNow && mounted) {
        showLevelPassedDialog(context, widget.sound, widget.level);
      }
    }
    setState(() {
      _probs = byLabel;
      _message = msg;
      _good = good;
    });
  }

  void _go(int delta) => setState(() {
    _index = (_index + delta) % widget.sound.bridge.length;
    if (_index < 0) _index += widget.sound.bridge.length;
    _probs = null;
    _message = null;
    _good = false;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letter = widget.sound.letter;
    return Scaffold(
      appBar: AppBar(title: Text('$letter · ${widget.level.title}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nasıl?', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    '1. “$_helper” de. Dil ucun üst dişlerin arkasına dokunur.',
                  ),
                  Text(
                    '2. Durmadan tekrarla ve hızlan: $_helper-$_helper-$_helper…',
                  ),
                  Text(
                    '3. Hızlandıkça dokunuş kısalır ve “$_target” olur. '
                    'Hazır olunca mikrofona bas, bir kez söyle.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _go(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Column(
                children: [
                  Text(
                    _target,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text('yardımcı: $_helper', style: theme.textTheme.bodySmall),
                ],
              ),
              IconButton(
                onPressed: () => _go(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => Tts.instance.speak(_helper),
                icon: const Icon(Icons.volume_up),
                label: Text(_helper),
              ),
              FilledButton.tonalIcon(
                onPressed: () => Tts.instance.speak(_target),
                icon: const Icon(Icons.volume_up),
                label: Text(_target),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ModelListenButton(
            key: ValueKey(_target),
            label: '“$_target” de',
            onSpeech: _onSpeech,
            onSilence: () => setState(
              () => _message = 'Ses duymadım, biraz daha yüksek söyle.',
            ),
          ),
          if (_probs != null) ...[
            const SizedBox(height: 16),
            for (final label in [letter, 'D', 'Y', 'L'])
              if (_probs!.containsKey(label))
                _Bar(
                  label: label,
                  value: _probs![label]!,
                  highlight: label == letter,
                ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Card(
              color: _good ? Colors.green.shade100 : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: LevelStatusText(sound: widget.sound, level: widget.level),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;

  const _Bar({
    required this.label,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? Colors.green : Colors.orange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 14,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text('%${(value * 100).round()}', textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
