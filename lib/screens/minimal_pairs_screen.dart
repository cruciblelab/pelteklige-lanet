import 'dart:math';

import 'package:flutter/material.dart';

import '../data/minimal_pairs.dart';
import '../data/sounds.dart';
import '../models/sound.dart';
import '../services/settings.dart';
import '../services/tts.dart';
import '../utils/turkish.dart';
import '../widgets/speech_check.dart';

/// Minimal çiftler: tek sesle ayrılan kelimeler (kar / kay).
///
/// 1) Duy ve seç: önce kulağın farkı ayırt etmeyi öğrenir.
/// 2) Söyle: tanıyıcı iki kelimeden hangisini duyduğunu söyler.
class MinimalPairsScreen extends StatefulWidget {
  const MinimalPairsScreen({super.key});

  @override
  State<MinimalPairsScreen> createState() => _MinimalPairsScreenState();
}

class _MinimalPairsScreenState extends State<MinimalPairsScreen> {
  final _rnd = Random();
  String _contrast = contrasts.first;
  bool _speakMode = false;
  late MinimalPair _pair;
  late bool _targetIsA;
  String? _feedback;
  bool? _correct;
  int _score = 0, _total = 0;

  @override
  void initState() {
    super.initState();
    _next();
  }

  List<MinimalPair> get _pairs =>
      minimalPairs.where((p) => p.contrast == _contrast).toList();

  String get _target => _targetIsA ? _pair.a : _pair.b;
  String get _other => _targetIsA ? _pair.b : _pair.a;

  void _next() {
    final list = _pairs;
    setState(() {
      _pair = list[_rnd.nextInt(list.length)];
      _targetIsA = _rnd.nextBool();
      _feedback = null;
      _correct = null;
    });
  }

  void _log(bool good) {
    final letter = _contrast.split(' / ').first;
    if (sounds.any((s) => s.id == letter)) {
      Settings.instance.logAttempt(letter, good: good);
    }
    setState(() {
      _total++;
      if (good) _score++;
      _correct = good;
    });
  }

  void _choose(String word) {
    if (_correct != null) return;
    final good = word == _target;
    _log(good);
    _feedback = good
        ? 'Doğru! “$_target” dedim.'
        : 'Ben “$_target” dedim. Bir daha dinle.';
  }

  void _onHeard(String heard) {
    final words = tokenize(heard);
    final t = normalizeText(_target), o = normalizeText(_other);
    if (words.contains(t)) {
      _log(true);
      _feedback = '“$_target” duydum. Harika!';
    } else if (words.contains(o)) {
      _log(false);
      _feedback =
          '“$_other” duydum. Hedef “$_target” idi; animasyona bakıp tekrar dene.';
    } else {
      setState(
        () => _feedback = heard.isEmpty
            ? 'Bir şey duyamadım, biraz daha yüksek sesle dene.'
            : '“$heard” duydum. İkisine de benzemedi, tekrar dene.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Benzer kelimeler'),
        actions: [
          if (_total > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('$_score / $_total'),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Duy ve seç'),
                icon: Icon(Icons.hearing),
              ),
              ButtonSegment(
                value: true,
                label: Text('Söyle'),
                icon: Icon(Icons.record_voice_over),
              ),
            ],
            selected: {_speakMode},
            onSelectionChanged: (v) {
              _speakMode = v.first;
              _next();
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in contrasts)
                ChoiceChip(
                  label: Text(c),
                  selected: c == _contrast,
                  onSelected: (_) {
                    _contrast = c;
                    _next();
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (!_speakMode) ..._listenMode(theme) else ..._sayMode(theme),
          if (_feedback != null) ...[
            const SizedBox(height: 20),
            Card(
              color: _correct == null
                  ? theme.colorScheme.surfaceContainerHighest
                  : (_correct!
                        ? Colors.green.shade100
                        : Colors.orange.shade100),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _feedback!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.skip_next),
              label: const Text('Sonraki'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _listenMode(ThemeData theme) => [
    Text(
      'Dinle: hangi kelimeyi söyledim?',
      style: theme.textTheme.titleMedium,
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 12),
    Center(
      child: IconButton.filled(
        iconSize: 48,
        onPressed: () => Tts.instance.speak(_target),
        icon: const Icon(Icons.volume_up),
      ),
    ),
    const SizedBox(height: 16),
    Row(
      children: [
        for (final w in [_pair.a, _pair.b])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                height: 80,
                child: OutlinedButton(
                  onPressed: () => setState(() => _choose(w)),
                  child: Text(w, style: theme.textTheme.headlineMedium),
                ),
              ),
            ),
          ),
      ],
    ),
  ];

  List<Widget> _sayMode(ThemeData theme) => [
    Text(
      'Bu kelimeyi söyle:',
      style: theme.textTheme.titleMedium,
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 8),
    Text(
      _target,
      style: theme.textTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
      textAlign: TextAlign.center,
    ),
    Text(
      '(karıştırılan: $_other)',
      style: theme.textTheme.bodySmall,
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 16),
    SpeechCheckButton(
      key: ValueKey(_target + _other),
      label: 'Söyle',
      hints: [_pair.a, _pair.b],
      pauseFor: const Duration(seconds: 2),
      onResult: _onHeard,
    ),
  ];
}
