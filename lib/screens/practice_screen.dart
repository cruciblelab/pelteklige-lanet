import 'package:flutter/material.dart';

import '../audio/pronunciation_scorer.dart';
import '../models/sound.dart';
import '../services/progress.dart';
import '../services/tts.dart';
import '../widgets/articulation/articulation_view.dart';
import '../widgets/articulation/articulations.dart';
import '../widgets/pronunciation_panel.dart';
import 'bridge_screen.dart';
import 'pairs_screen.dart';

/// Bir basamağın alıştırması: kelime → söyle → ibre. Sade tutulur:
/// ekranda yalnızca kelime, dinleme, mikrofon ve sonuç vardır.
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
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted && _index == i) {
          _page.nextPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focus = Progress.instance.focusError(widget.sound.id);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.sound.letter} · ${widget.level.title}'),
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
      body: PageView.builder(
        controller: _page,
        itemCount: _items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final text = _items[i];
          final isSentence = text.contains(' ');
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              _HighlightedText(
                text: text,
                letter: widget.sound.letter,
                style:
                    (isSentence
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.displayLarge)!
                        .copyWith(fontWeight: FontWeight.w700),
                highlight: theme.colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Dinle',
                    onPressed: () => Tts.instance.speak(text),
                    icon: const Icon(Icons.volume_up),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Yavaş dinle',
                    onPressed: () => Tts.instance.speak(text, slow: true),
                    icon: const Icon(Icons.slow_motion_video),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PronunciationPanel(
                key: ValueKey('$text/$focus'),
                text: text,
                targetLetter: widget.sound.letter,
                soundId: widget.sound.id,
                focusError: focus,
                onResult: (v) => _onResult(i, v),
              ),
              const SizedBox(height: 16),
              Text(
                '${i + 1} / ${_items.length}   ·   kaydırarak sonrakine geç',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// AppBar altında son denemeler: yeşil = doğru, turuncu = değil.
class LevelDots extends StatelessWidget {
  final SoundInfo sound;
  final Level level;

  const LevelDots({super.key, required this.sound, required this.level});

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    final r = p.resultsFor(sound.id, level.id);
    final last = r.length > Progress.window
        ? r.sublist(r.length - Progress.window)
        : r;
    final passed = p.isPassed(sound.id, level.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < Progress.window; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < last.length
                    ? (last[i]
                          ? const Color(0xFF14A38B)
                          : const Color(0xFFE0663D))
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          const SizedBox(width: 10),
          Text(
            passed
                ? 'geçildi ✓'
                : '${p.recentCorrect(sound.id, level.id)}/${Progress.needed}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// "Nasıl?": doğru söyleyiş ile kişinin hatasını karşılaştıran animasyon.
void showHowSheet(BuildContext context, SoundInfo sound) {
  final focus = Progress.instance.focusError(sound.id);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              focus == null
                  ? '${sound.letter} nasıl söylenir?'
                  : '${sound.letter} ile senin söyleyişin',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            ArticulationView(
              correct: articulationForLetter(sound.letter),
              error: focus == null ? null : articulationForError(focus),
              errorTitle: focus == null
                  ? null
                  : PronunciationScorer.errorShort(focus),
            ),
            if (focus != null && PronunciationScorer.tips[focus] != null) ...[
              const SizedBox(height: 10),
              Text(
                PronunciationScorer.tips[focus]!,
                style: Theme.of(ctx).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Basamak türüne göre doğru ekranı açar.
Widget levelPage(SoundInfo sound, Level level) => switch (level.kind) {
  LevelKind.bridge => BridgeScreen(sound: sound, level: level),
  LevelKind.pairs => PairsScreen(sound: sound, level: level),
  LevelKind.practice => PracticeScreen(sound: sound, level: level),
};

void showLevelPassedDialog(BuildContext context, SoundInfo sound, Level level) {
  final levels = levelsFor(sound);
  final idx = levels.indexWhere((l) => l.id == level.id);
  final next = idx >= 0 && idx < levels.length - 1 ? levels[idx + 1] : null;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: const Icon(Icons.emoji_events, color: Colors.amber, size: 56),
      ),
      title: Text('${level.title} tamam!'),
      content: Text(
        next == null
            ? '${sound.letter} sesinin bütün basamaklarını geçtin. '
                  'Kitap okumada pekiştirebilirsin.'
            : 'Sıradaki: ${next.title}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Burada kal'),
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
