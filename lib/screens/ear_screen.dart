import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/pronunciation_scorer.dart';
import '../data/minimal_pairs.dart';
import '../models/sound.dart';
import '../services/progress.dart';
import '../services/recordings.dart';
import '../services/tts.dart';
import '../widgets/focus_gauge.dart';
import 'practice_screen.dart';

enum _Mode { tts, own }

/// Kulak eğitimi: "R mi L mi?"
///
/// Araştırma (docs/ARASTIRMA.md): R'si bozuk olanlar kendi hatalarını çoğu
/// zaman duyamıyor (Shuster, 1998); r/l ayrımını dinleyerek çalışmak hem algıyı
/// hem söyleyişi iyileştirebiliyor (Bradlow ve ark., 1997, 1999).
///
/// İki mod:
/// - Telefonun sesi: farklı ton ve hızlarda bir kelime söylenir, hangisi seç.
/// - Kendi sesin: kendi eski kayıtların çalınır, tahmin et, sonra modelin
///   kararını gör. "Kulak uyumu" bu ikisinin ne kadar örtüştüğüdür.
class EarScreen extends StatefulWidget {
  final SoundInfo sound;

  /// Plan basamağı olarak açıldıysa (yalnızca "Telefonun sesi" sayılır).
  final Level? level;

  const EarScreen({super.key, required this.sound, this.level});

  @override
  State<EarScreen> createState() => _EarScreenState();
}

class _EarScreenState extends State<EarScreen> {
  final _rnd = math.Random();
  _Mode _mode = _Mode.tts;

  // Telefonun sesi
  late List<(String, String)> _pairs;
  (String, String)? _pair;
  late bool _saidTarget;
  late bool _targetFirst;
  bool? _ttsCorrect;

  // Kendi sesin
  List<RecordingEntry> _own = [];
  RecordingEntry? _rec;
  int? _guess;

  String get _letter => widget.sound.letter;

  String get _errorLabel {
    final f = Progress.instance.focusError(widget.sound.id);
    if (f != null) return f;
    final errs = PronunciationScorer.errors[_letter.toLowerCase()] ?? const [];
    for (final e in errs) {
      if (pairsFor(_letter, PronunciationScorer.errorShort(e.$2)).isNotEmpty) {
        return e.$2;
      }
    }
    return errs.isEmpty ? '' : errs.first.$2;
  }

  String get _errShort => PronunciationScorer.errorShort(_errorLabel);

  @override
  void initState() {
    super.initState();
    _pairs = pairsFor(_letter, _errShort);
    _loadOwn();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nextTts());
  }

  Future<void> _loadOwn() async {
    final all = await RecordingStore.instance.list();
    if (!mounted) return;
    setState(() {
      _own = all
          .where(
            (e) =>
                e.soundId == widget.sound.id &&
                e.ratio != null &&
                e.errorLabel == _errorLabel,
          )
          .take(60)
          .toList();
    });
  }

  // --- Telefonun sesi ---

  void _nextTts() {
    if (_pairs.isEmpty) return;
    setState(() {
      _pair = _pairs[_rnd.nextInt(_pairs.length)];
      _saidTarget = _rnd.nextBool();
      _targetFirst = _rnd.nextBool();
      _ttsCorrect = null;
    });
    _playTts();
  }

  void _playTts() {
    final p = _pair;
    if (p == null) return;
    Tts.instance.speakVaried(_saidTarget ? p.$1 : p.$2, _rnd);
  }

  void _answerTts(bool choseTarget) {
    if (_ttsCorrect != null) return;
    final correct = choseTarget == _saidTarget;
    Progress.instance.recordEar('tts', correct);
    var passedNow = false;
    if (widget.level != null) {
      passedNow = Progress.instance.record(
        widget.sound.id,
        widget.level!.id,
        correct,
      );
    }
    setState(() => _ttsCorrect = correct);
    if (passedNow) {
      showLevelPassedDialog(context, widget.sound, widget.level!);
    } else {
      Future.delayed(Duration(milliseconds: correct ? 1100 : 2200), () {
        if (mounted && _mode == _Mode.tts && _ttsCorrect != null) _nextTts();
      });
    }
  }

  // --- Kendi sesin ---

  void _nextOwn() {
    if (_own.isEmpty) return;
    RecordingEntry r;
    do {
      r = _own[_rnd.nextInt(_own.length)];
    } while (_own.length > 1 && r.path == _rec?.path);
    setState(() {
      _rec = r;
      _guess = null;
    });
    RecordingStore.instance.play(r.path);
  }

  void _answerOwn(int guess) {
    if (_guess != null || _rec == null) return;
    final model = FocusResult.categoryOf(_rec!.ratio!);
    Progress.instance.recordEar('own', guess == model);
    setState(() => _guess = guess);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Kulak: $_letter mi $_errShort mi?'),
        bottom: widget.level == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: LevelDots(sound: widget.sound, level: widget.level!),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(
                value: _Mode.tts,
                label: Text('Telefonun sesi'),
                icon: Icon(Icons.record_voice_over),
              ),
              ButtonSegment(
                value: _Mode.own,
                label: Text('Kendi sesin'),
                icon: Icon(Icons.person),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (v) {
              setState(() => _mode = v.first);
              if (_mode == _Mode.own && _rec == null) _nextOwn();
              if (_mode == _Mode.tts) _nextTts();
            },
          ),
          const SizedBox(height: 20),
          if (_mode == _Mode.tts) ..._ttsView(theme) else ..._ownView(theme),
          const SizedBox(height: 24),
          _AccuracyLine(
            kind: _mode == _Mode.tts ? 'tts' : 'own',
            label: _mode == _Mode.tts ? 'Doğru tanıma' : 'Kulak uyumun',
          ),
        ],
      ),
    );
  }

  List<Widget> _ttsView(ThemeData theme) {
    final p = _pair;
    if (_pairs.isEmpty || p == null) {
      return [
        Text(
          'Bu ses için kelime çifti yok.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ];
    }
    final words = _targetFirst ? [p.$1, p.$2] : [p.$2, p.$1];
    final said = _saidTarget ? p.$1 : p.$2;
    return [
      Text(
        'Dinle. Hangisini duydun?',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 16),
      Center(
        child: IconButton.filled(
          iconSize: 56,
          padding: const EdgeInsets.all(18),
          onPressed: _playTts,
          icon: const Icon(Icons.volume_up),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          for (final w in words)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _AnswerButton(
                  text: w,
                  state: _ttsCorrect == null
                      ? null
                      : w == said
                      ? true
                      : false,
                  onTap: () => _answerTts(w == p.$1),
                ),
              ),
            ),
        ],
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: _ttsCorrect == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  _ttsCorrect! ? 'Doğru! “$said” idi.' : 'Bu “$said” idi.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _ttsCorrect! ? FocusGauge.good : FocusGauge.bad,
                  ),
                ),
              ),
      ),
    ];
  }

  List<Widget> _ownView(ThemeData theme) {
    if (_own.isEmpty) {
      return [
        const Icon(Icons.mic_none, size: 48),
        const SizedBox(height: 8),
        Text(
          'Henüz analiz edilmiş kaydın yok. Alıştırmalarda birkaç kelime söyle; '
          'kayıtların burada sana sorulacak: “Sence R mi, $_errShort mi?”',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ];
    }
    final r = _rec;
    if (r == null) return const [];
    final word = r.label.contains(': ')
        ? r.label.substring(r.label.indexOf(': ') + 2)
        : r.label;
    final model = FocusResult.categoryOf(r.ratio!);
    final labels = [_letter, 'Arada', _errShort];
    return [
      Text(
        'Kendi kaydın. Sence nasıl söylemişsin?',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        word,
        textAlign: TextAlign.center,
        style: theme.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: IconButton.filled(
          iconSize: 48,
          padding: const EdgeInsets.all(16),
          onPressed: () => RecordingStore.instance.play(r.path),
          icon: const Icon(Icons.hearing),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _AnswerButton(
                  text: labels[i],
                  state: _guess == null
                      ? null
                      : i == model
                      ? true
                      : (i == _guess ? false : null),
                  onTap: () => _answerOwn(i),
                ),
              ),
            ),
        ],
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: _guess == null
            ? const SizedBox(width: double.infinity)
            : Column(
                children: [
                  const SizedBox(height: 12),
                  FocusGauge(
                    ratio: r.ratio!,
                    correctLabel: _letter,
                    errorLabel: _errShort,
                  ),
                  Text(
                    _guess == model
                        ? 'Kulağın modelle aynı şeyi duydu.'
                        : 'Sen “${labels[_guess!]}” dedin, model “${labels[model]}” duydu.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _guess == model ? FocusGauge.good : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Model de yanılabilir; amaç farkı duymayı öğrenmek.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _nextOwn,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Sonraki kayıt'),
                  ),
                ],
              ),
      ),
    ];
  }
}

class _AnswerButton extends StatelessWidget {
  final String text;

  /// null = cevap bekleniyor, true = doğru cevap, false = yanlış seçim.
  final bool? state;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (state) {
      true => FocusGauge.good,
      false => FocusGauge.bad,
      null => theme.colorScheme.primary,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 84,
      decoration: BoxDecoration(
        color: state == null ? null : color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: state == null ? 1.5 : 3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccuracyLine extends StatelessWidget {
  final String kind;
  final String label;
  const _AccuracyLine({required this.kind, required this.label});

  @override
  Widget build(BuildContext context) {
    final acc = Progress.instance.earAccuracy(kind);
    final n = Progress.instance.earResults(kind).length;
    return Text(
      acc == null
          ? '$label: henüz deneme yok'
          : '$label (son ${math.min(n, 20)}): %${(acc * 100).round()}',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
