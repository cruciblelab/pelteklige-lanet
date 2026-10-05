import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/phoneme_model.dart';
import '../audio/pronunciation_scorer.dart';
import '../data/sounds.dart';
import '../models/sound.dart';
import '../widgets/model_listen_button.dart';

/// Kısa tarama: her ses için iki kelime söylenir, ses analizi hangi seslerde
/// zorlanıldığını bulur. Sonunda odak sesleri önerilir.
///
/// Testin bulduğu hata türü kendiliğinden kaydedilmez: yalnızca bir öneri
/// olarak [onDone]'a verilir, son kararı kişi verir. İki kelimelik bir test
/// hata türünü (L mi D mi) güvenilir biçimde ayıramaz.
class ScreeningScreen extends StatefulWidget {
  final List<String> soundIds;

  /// [focus]: seçilen sesler. [hints]: ses → testte en olası görünen hata.
  final void Function(List<String> focus, Map<String, String> hints) onDone;

  const ScreeningScreen({
    super.key,
    required this.soundIds,
    required this.onDone,
  });

  @override
  State<ScreeningScreen> createState() => _ScreeningScreenState();
}

class _Item {
  final SoundInfo sound;
  final String word;
  const _Item(this.sound, this.word);
}

class _ScreeningScreenState extends State<ScreeningScreen> {
  late final List<_Item> _items = [
    for (final id in widget.soundIds)
      for (final w in _wordsFor(soundById(id))) _Item(soundById(id), w),
  ];
  int _index = 0;
  final Map<String, List<Verdict>> _results = {};

  /// Ses → hata → denemeler boyunca toplanan olasılık.
  final Map<String, Map<String, double>> _errorMass = {};
  String? _note;
  bool _done = false;
  final Set<String> _chosen = {};

  static List<String> _wordsFor(SoundInfo s) => [
    s.wordsStart.first,
    if (s.wordsMiddle.isNotEmpty) s.wordsMiddle.first,
  ];

  _Item get _cur => _items[_index];

  Future<void> _onSpeech(Float32List samples) async {
    final r = await PhonemeModel.instance.evaluate(
      samples,
      _cur.word,
      _cur.sound.letter,
    );
    if (!mounted) return;
    if (r.mismatch || r.checks.isEmpty) {
      setState(
        () =>
            _note = '“${_cur.word}” kelimesine benzemedi, bir kez daha söyle.',
      );
      return;
    }
    final v = r.checks.any((c) => c.verdict == Verdict.error)
        ? Verdict.error
        : r.checks.every((c) => c.verdict == Verdict.correct)
        ? Verdict.correct
        : Verdict.unsure;
    // Tek bir "en olası hata" yerine olasılıkları topla: L ile D arasında
    // kararsız kalan iki deneme, tek tek bakınca yanlış hatayı seçtirebilir.
    final mass = _errorMass.putIfAbsent(_cur.sound.id, () => {});
    for (final c in r.checks) {
      for (final e in c.probs.entries) {
        if (e.key == SoundCheck.correctLabel) continue;
        mass[e.key] = (mass[e.key] ?? 0) + e.value;
      }
    }
    _results.putIfAbsent(_cur.sound.id, () => []).add(v);
    _next();
  }

  void _next() {
    setState(() {
      _note = null;
      if (_index < _items.length - 1) {
        _index++;
      } else {
        _done = true;
        _chosen.addAll(_flagged);
      }
    });
  }

  void _skipSound() {
    final id = _cur.sound.id;
    setState(() {
      while (_index < _items.length && _items[_index].sound.id == id) {
        _index++;
      }
      if (_index >= _items.length) {
        _index = _items.length - 1;
        _done = true;
        _chosen.addAll(_flagged);
      }
      _note = null;
    });
  }

  /// Testte en olası görünen hata ve payı (hatalar arasında).
  (String, double)? _hint(String id) {
    final m = _errorMass[id];
    if (m == null || m.isEmpty) return null;
    final total = m.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return null;
    final top = m.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return (top.key, top.value / total);
  }

  /// Hata ya da belirsizlik olan sesler, hatalılar önce.
  List<String> get _flagged {
    int score(String id) => (_results[id] ?? [])
        .map(
          (v) => switch (v) {
            Verdict.error => 2,
            Verdict.unsure => 1,
            Verdict.correct => 0,
          },
        )
        .fold(0, (a, b) => a + b);
    final ids = widget.soundIds.where((id) => score(id) > 0).toList()
      ..sort((a, b) => score(b).compareTo(score(a)));
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kısa test'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _done ? 1 : _index / _items.length,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _done ? _summary(theme) : _ask(theme),
        ),
      ),
    );
  }

  Widget _ask(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Kelimeyi normal sesinle bir kez söyle.',
        style: theme.textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
      const Spacer(),
      Text(
        _cur.word,
        style: theme.textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      Text(
        '${_cur.sound.letter} sesi · ${_index + 1}/${_items.length}',
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
      const Spacer(),
      if (_note != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_note!, textAlign: TextAlign.center),
        ),
      ModelListenButton(
        key: ValueKey(_index),
        label: 'Söyle',
        onSpeech: _onSpeech,
        onSilence: () => setState(() => _note = 'Ses duymadım, tekrar dene.'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _skipSound,
        child: Text('${_cur.sound.letter} sesini atla'),
      ),
    ],
  );

  Widget _summary(ThemeData theme) {
    final flagged = _flagged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sonuç', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          flagged.isEmpty
              ? 'Test ettiğin seslerde belirgin bir hata duymadım. Yine de '
                    'çalışmak istediğin sesleri seçebilirsin.'
              : 'Şu seslerde zorlanıyor olabilirsin. Plana eklemek istediklerini işaretle.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final id in widget.soundIds)
                CheckboxListTile(
                  value: _chosen.contains(id),
                  onChanged: (v) => setState(
                    () => v == true ? _chosen.add(id) : _chosen.remove(id),
                  ),
                  title: Text(
                    '${soundById(id).letter} sesi',
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    _results[id] == null
                        ? 'Test edilmedi'
                        : flagged.contains(id)
                        ? switch (_hint(id)) {
                            (final l, final share) =>
                              'En çok “${PronunciationScorer.errorChip(l)}” '
                                  'duyuldu (%${(share * 100).round()}). '
                                  'Bir sonraki adımda sen seçeceksin.',
                            null => 'Net değil',
                          }
                        : 'İyi görünüyor',
                  ),
                  secondary: Icon(
                    _results[id] == null
                        ? Icons.remove
                        : flagged.contains(id)
                        ? Icons.priority_high
                        : Icons.check_circle,
                    color: _results[id] == null
                        ? null
                        : flagged.contains(id)
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
            ],
          ),
        ),
        Text(
          'Bu kısa test bir tanı değildir; her ses için yalnızca iki kelime dinlendi.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _chosen.isEmpty
              ? null
              : () => widget.onDone(
                  widget.soundIds.where(_chosen.contains).toList(),
                  {
                    for (final id in _chosen)
                      if (_hint(id) case (final l, _)) id: l,
                  },
                ),
          child: const Text('Devam'),
        ),
      ],
    );
  }
}
