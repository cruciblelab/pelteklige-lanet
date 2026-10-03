import 'package:flutter/material.dart';

import '../models/sound.dart';
import '../services/settings.dart';
import '../services/tts.dart';
import '../utils/text_align.dart';
import '../widgets/record_panel.dart';
import '../widgets/speech_check.dart';
import '../widgets/word_feedback.dart';

/// Tek tek hece/kelime/cümle alıştırması:
/// dinle → söyle ve kaydet → kendini dinle → kendini değerlendir (→ tanıyıcıya kontrol ettir).
class PracticeScreen extends StatefulWidget {
  final SoundInfo sound;
  final String title;
  final List<String> items;

  const PracticeScreen({
    super.key,
    required this.sound,
    required this.title,
    required this.items,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final _page = PageController();
  int _index = 0;
  final Map<int, bool> _rated = {};
  final Map<int, (String, AlignmentResult)> _checks = {};

  String get _item => widget.items[_index];

  void _rate(bool good) {
    Settings.instance.logAttempt(widget.sound.id, good: good);
    setState(() => _rated[_index] = good);
    if (good && _index < widget.items.length - 1) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _page.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _page.dispose();
    Tts.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = _rated.length;
    final good = _rated.values.where((v) => v).length;
    final isSentence = _item.contains(' ');
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.sound.letter} · ${widget.title}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_index + 1) / widget.items.length,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final text = widget.items[i];
                final check = _checks[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _HighlightedText(
                        text: text,
                        letter: widget.sound.letter,
                        style:
                            (text.contains(' ')
                                    ? theme.textTheme.headlineSmall
                                    : theme.textTheme.displayMedium)!
                                .copyWith(fontWeight: FontWeight.w600),
                        highlight: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
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
                      if (!Tts.instance.available)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Telefonda Türkçe ses motoru bulunamadı. Ayarlar → Metin okuma çıkışı bölümünden Türkçe ses indirebilirsin.',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 28),
                      RecordPanel(
                        label: '${widget.sound.letter}: $text',
                        category: 'alistirma',
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Kendini dinledin mi? Nasıldı?',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            avatar: const Icon(Icons.replay),
                            label: const Text('Tekrar deneyeyim'),
                            selected: _rated[i] == false,
                            onSelected: (_) => _rate(false),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            avatar: const Icon(Icons.check),
                            label: const Text('Doğru söyledim'),
                            selected: _rated[i] == true,
                            onSelected: (_) => _rate(true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (isSentence || text.length > 3) ...[
                        SpeechCheckButton(
                          onResult: (heard) => setState(
                            () => _checks[i] = (heard, alignTexts(text, heard)),
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
                        const SizedBox(height: 8),
                        Text(
                          'Not: Telefonun tanıyıcısı küçük telaffuz hatalarını çoğu zaman '
                          'düzeltip doğru kelimeyi yazar. Yeşil görmek “kusursuz” demek değildir; '
                          'en güvenilir ölçüt kendi kaydını dinlemendir.',
                          style: theme.textTheme.bodySmall,
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
                    child: Text(
                      '${_index + 1} / ${widget.items.length}'
                      '${done > 0 ? '   ·   $good/$done doğru' : ''}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _index == widget.items.length - 1
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
