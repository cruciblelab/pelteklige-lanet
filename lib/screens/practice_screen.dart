import 'package:flutter/material.dart';

import '../audio/pronunciation_scorer.dart';
import '../models/sound.dart';
import '../services/progress.dart';
import '../services/tts.dart';
import '../utils/text_align.dart';
import '../widgets/pronunciation_panel.dart';
import '../widgets/speech_check.dart';
import '../widgets/word_feedback.dart';
import 'bridge_screen.dart';

/// Bir basamağın alıştırması: dinle → söyle → ses analizi sonucu.
/// Doğru söyleyince bir sonraki öğeye kendiliğinden geçer.
class PracticeScreen extends StatefulWidget {
  final SoundInfo sound;
  final Level level;

  const PracticeScreen({super.key, required this.sound, required this.level});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final _page = PageController();
  int _index = 0;
  final Map<int, (String, AlignmentResult)> _checks = {};

  List<String> get _items => widget.level.items;

  @override
  void dispose() {
    _page.dispose();
    Tts.instance.stop();
    super.dispose();
  }

  void _onResult(int i, Verdict v) {
    final passedNow = Progress.instance.record(
      widget.sound.id,
      widget.level.id,
      v == Verdict.correct,
    );
    setState(() {});
    if (passedNow) {
      showLevelPassedDialog(context, widget.sound, widget.level);
    } else if (v == Verdict.correct && i < _items.length - 1) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && _index == i) {
          _page.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.sound.letter} · ${widget.level.title}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_index + 1) / _items.length),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final text = _items[i];
                final isSentence = text.contains(' ');
                final check = _checks[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      _HighlightedText(
                        text: text,
                        letter: widget.sound.letter,
                        style:
                            (isSentence
                                    ? theme.textTheme.headlineSmall
                                    : theme.textTheme.displayMedium)!
                                .copyWith(fontWeight: FontWeight.w600),
                        highlight: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => Tts.instance.speak(text),
                            icon: const Icon(Icons.volume_up),
                            label: const Text('Dinle'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                Tts.instance.speak(text, slow: true),
                            icon: const Icon(Icons.slow_motion_video),
                            label: const Text('Yavaş'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PronunciationPanel(
                        key: ValueKey(text),
                        text: text,
                        targetLetter: widget.sound.letter,
                        soundId: widget.sound.id,
                        onResult: (v) => _onResult(i, v),
                      ),
                      if (isSentence) ...[
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Atlanan kelime var mı?'),
                          subtitle: const Text(
                            'Kelime düzeyinde kontrol (telefonun genel tanıyıcısı)',
                          ),
                          children: [
                            SpeechCheckButton(
                              onResult: (heard) => setState(
                                () => _checks[i] = (
                                  heard,
                                  alignTexts(text, heard),
                                ),
                              ),
                            ),
                            if (check != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: WordFeedback(
                                  result: check.$2,
                                  heard: check.$1,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _index == 0
                        ? null
                        : () => _page.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_index + 1} / ${_items.length}'),
                        LevelStatusText(
                          sound: widget.sound,
                          level: widget.level,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _index == _items.length - 1
                        ? null
                        : () => _page.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Son 8 denemede 5/6 doğru" ya da "Basamak geçildi".
class LevelStatusText extends StatelessWidget {
  final SoundInfo sound;
  final Level level;

  const LevelStatusText({super.key, required this.sound, required this.level});

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    final passed = p.isPassed(sound.id, level.id);
    return Text(
      passed
          ? 'Basamak geçildi ✓'
          : 'Basamak: son ${Progress.window} denemede '
                '${p.recentCorrect(sound.id, level.id)}/${Progress.needed} doğru',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// Basamak türüne göre doğru ekranı açar.
Widget levelPage(SoundInfo sound, Level level) => level.kind == LevelKind.bridge
    ? BridgeScreen(sound: sound, level: level)
    : PracticeScreen(sound: sound, level: level);

void showLevelPassedDialog(BuildContext context, SoundInfo sound, Level level) {
  final levels = levelsFor(sound);
  final idx = levels.indexWhere((l) => l.id == level.id);
  final next = idx >= 0 && idx < levels.length - 1 ? levels[idx + 1] : null;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
      title: Text('${level.title} tamam!'),
      content: Text(
        next == null
            ? '${sound.letter} sesinin bütün basamaklarını geçtin. '
                  'Kitap okumada pekiştirebilirsin.'
            : 'Son ${Progress.window} denemenin en az ${Progress.needed} tanesi '
                  'doğru. Sıradaki basamak: ${next.title}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Burada devam et'),
        ),
        if (next != null)
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => levelPage(sound, next)),
              );
            },
            child: const Text('Sıradakine geç'),
          ),
      ],
    ),
  );
}

/// Çalışılan harfi metin içinde renkli gösterir.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String letter;
  final TextStyle style;
  final Color highlight;

  const _HighlightedText({
    required this.text,
    required this.letter,
    required this.style,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final lower = letter == 'I'
        ? 'ı'
        : (letter == 'İ' ? 'i' : letter.toLowerCase());
    final spans = <TextSpan>[];
    for (final ch in text.characters) {
      final hit = ch == letter || ch == lower;
      spans.add(
        TextSpan(
          text: ch,
          style: hit
              ? TextStyle(
                  color: highlight,
                  decoration: TextDecoration.underline,
                )
              : null,
        ),
      );
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: TextAlign.center,
    );
  }
}
