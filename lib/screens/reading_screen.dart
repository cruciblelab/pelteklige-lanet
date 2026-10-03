import 'package:flutter/material.dart';

import '../models/sound.dart';
import '../services/tts.dart';
import '../utils/text_align.dart';
import '../widgets/record_panel.dart';
import '../widgets/speech_check.dart';
import '../widgets/word_feedback.dart';

enum ReadMode { read, record, follow }

class ReadingScreen extends StatefulWidget {
  final Story story;
  const ReadingScreen({super.key, required this.story});

  ReadingScreen.custom(String text, {super.key})
    : story = Story(
        id: 'ozel',
        title: 'Kendi metnim',
        focus: '-',
        level: 0,
        paragraphs: text.split(RegExp(r'\n\s*\n')),
      );

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  ReadMode _mode = ReadMode.read;
  late final List<String> _sentences = widget.story.sentences;
  int _current = 0;
  final Map<int, (String, AlignmentResult)> _results = {};
  double _fontScale = 1;

  @override
  void dispose() {
    Tts.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.titleLarge!.copyWith(
      height: 1.6,
      fontSize: (theme.textTheme.titleLarge!.fontSize ?? 22) * _fontScale,
      fontWeight: FontWeight.w400,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.story.title),
        actions: [
          IconButton(
            tooltip: 'Yazıyı küçült',
            onPressed: () =>
                setState(() => _fontScale = (_fontScale - 0.1).clamp(0.8, 1.8)),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: 'Yazıyı büyüt',
            onPressed: () =>
                setState(() => _fontScale = (_fontScale + 0.1).clamp(0.8, 1.8)),
            icon: const Icon(Icons.text_increase),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<ReadMode>(
              segments: const [
                ButtonSegment(
                  value: ReadMode.read,
                  label: Text('Oku'),
                  icon: Icon(Icons.chrome_reader_mode),
                ),
                ButtonSegment(
                  value: ReadMode.record,
                  label: Text('Kaydet'),
                  icon: Icon(Icons.mic),
                ),
                ButtonSegment(
                  value: ReadMode.follow,
                  label: Text('Takip'),
                  icon: Icon(Icons.spellcheck),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(switch (_mode) {
              ReadMode.read => 'Sessizce ya da sesli oku. Bir cümlenin nasıl okunduğunu duymak için ona dokun.',
              ReadMode.record => 'Kayda başla ve tüm metni oku. Sonra kendini dinle; kayıt “Kayıtlarım”a eklenir.',
              ReadMode.follow => 'Cümle cümle oku. Telefon dinler; atladığın ya da farklı duyduğu kelimeleri gösterir.',
            }, style: theme.textTheme.bodySmall),
          ),
          if (_mode == ReadMode.record)
            Padding(
              padding: const EdgeInsets.all(8),
              child: RecordPanel(
                label: 'Okuma: ${widget.story.title}',
                category: 'okuma',
              ),
            ),
          const Divider(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _sentences.length + (_mode == ReadMode.follow ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _sentences.length) return _summary(theme);
                final active = _mode == ReadMode.follow && i == _current;
                final res = _results[i];
                return GestureDetector(
                  onTap: () {
                    if (_mode == ReadMode.follow) {
                      setState(() => _current = i);
                    } else {
                      Tts.instance.speak(_sentences[i]);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: active
                          ? theme.colorScheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_sentences[i], style: textStyle),
                        if (active) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Dinle',
                                onPressed: () =>
                                    Tts.instance.speak(_sentences[i]),
                                icon: const Icon(Icons.volume_up),
                              ),
                              Expanded(
                                child: SpeechCheckButton(
                                  key: ValueKey(i),
                                  label: 'Okumaya başla',
                                  onResult: (heard) => setState(() {
                                    _results[i] = (
                                      heard,
                                      alignTexts(_sentences[i], heard),
                                    );
                                    if (heard.isNotEmpty &&
                                        _current < _sentences.length) {
                                      _current = i + 1;
                                    }
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (res != null && _mode == ReadMode.follow)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: WordFeedback(result: res.$2, heard: res.$1),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(ThemeData theme) {
    if (_results.isEmpty) return const SizedBox.shrink();
    var words = 0, correct = 0, missed = 0;
    final subs = <String, int>{};
    for (final r in _results.values) {
      words += r.$2.words.length;
      correct += r.$2.correctCount;
      missed += r.$2.missedCount;
      for (final e in r.$2.substitutions) {
        subs[e.key] = (subs[e.key] ?? 0) + e.value;
      }
    }
    final top = subs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Özet (${_results.length}/${_sentences.length} cümle)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Doğru duyulan kelime: $correct / $words'),
            Text('Duyulmayan (yutulmuş olabilecek) kelime: $missed'),
            if (top.isNotEmpty)
              Text(
                'En sık harf farkları: ${top.take(5).map((e) => '${e.key} (${e.value})').join(', ')}',
              ),
            const SizedBox(height: 8),
            Text(
              'Bu sayılar telefonun tanıyıcısına dayanır ve kesin değildir. '
              'Aynı farkı birçok cümlede görüyorsan (ör. sürekli “r → y”), '
              'o sesi “Sesler” bölümünde çalışmak iyi bir fikir.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
