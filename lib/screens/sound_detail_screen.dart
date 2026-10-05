import 'package:flutter/material.dart';

import '../audio/pronunciation_scorer.dart';
import '../models/sound.dart';
import '../services/progress.dart';
import '../services/tts.dart';
import '../widgets/articulation/articulation_view.dart';
import '../widgets/articulation/articulations.dart';
import 'meter_screen.dart';
import 'practice_screen.dart';

class SoundDetailScreen extends StatefulWidget {
  final SoundInfo sound;
  const SoundDetailScreen({super.key, required this.sound});

  @override
  State<SoundDetailScreen> createState() => _SoundDetailScreenState();
}

class _SoundDetailScreenState extends State<SoundDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final s = widget.sound;
    final theme = Theme.of(context);
    final levels = levelsFor(s);
    final p = Progress.instance;
    final current = p.currentLevelIndex(s);
    final focus = p.focusError(s.id);

    return Scaffold(
      appBar: AppBar(title: Text('${s.title}  ${s.ipa}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ArticulationView(
            key: ValueKey(focus),
            correct: articulationForLetter(s.letter),
            error: focus == null ? null : articulationForError(focus),
            errorTitle: focus == null
                ? null
                : PronunciationScorer.errorShort(focus),
          ),
          const SizedBox(height: 12),
          _MyErrorPicker(
            sound: s,
            value: focus,
            onChanged: (v) => setState(() => p.setFocusError(s.id, v)),
          ),
          const SizedBox(height: 8),
          Text(s.summary, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final w in [s.syllables.first, s.wordsStart.first])
                ActionChip(
                  avatar: const Icon(Icons.volume_up, size: 18),
                  label: Text(w),
                  onPressed: () => Tts.instance.speak(w, slow: true),
                ),
            ],
          ),
          _Section(
            title: 'Nasıl söylenir?',
            icon: Icons.format_list_numbered,
            children: [
              for (var i = 0; i < s.steps.length; i++)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 12, child: Text('${i + 1}')),
                  title: Text(s.steps[i]),
                ),
            ],
          ),
          _Section(
            title: 'Isınma hareketleri',
            icon: Icons.fitness_center,
            children: [
              for (final w in s.warmups)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.chevron_right),
                  title: Text(w),
                ),
            ],
          ),
          _Section(
            title: 'Sık yapılan hatalar',
            icon: Icons.report_outlined,
            children: [
              for (final e in s.commonErrors)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.close, color: Colors.redAccent),
                  title: Text(e),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Basamaklar', style: theme.textTheme.titleLarge),
          Text(
            'Ses analizi son ${Progress.window} denemenin ${Progress.needed} tanesini '
            'doğru bulunca basamak geçilir. İstediğin basamağa yine de girebilirsin.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (s.meterFriendly)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.graphic_eq),
                title: const Text('0. Sesi tek başına uzat'),
                subtitle: const Text('Tıslama ölçer ile sesini ekranda gör'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeterScreen(initialTarget: s.letter),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < levels.length; i++)
            Card(
              color: i == current ? theme.colorScheme.primaryContainer : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: p.isPassed(s.id, levels[i].id)
                      ? Colors.green
                      : null,
                  foregroundColor: p.isPassed(s.id, levels[i].id)
                      ? Colors.white
                      : null,
                  child: p.isPassed(s.id, levels[i].id)
                      ? const Icon(Icons.check)
                      : Text('${i + 1}'),
                ),
                title: Text(levels[i].title),
                subtitle: Text(
                  levels[i].hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: i == current
                    ? const Icon(Icons.play_circle_fill)
                    : Text(
                        '${p.recentCorrect(s.id, levels[i].id)}/${Progress.needed}',
                      ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => levelPage(s, levels[i])),
                ).then((_) => setState(() {})),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        children: children,
      ),
    );
  }
}

/// "Ben nasıl söylüyorum?": kişinin kendi hatasını seçmesi. Seçim animasyonu,
/// ses analizini ve alıştırmaları o ayrıma odaklar.
class _MyErrorPicker extends StatelessWidget {
  final SoundInfo sound;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _MyErrorPicker({
    required this.sound,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errs =
        PronunciationScorer.errors[sound.letter.toLowerCase()] ?? const [];
    if (errs.isEmpty) return const SizedBox.shrink();
    final example = sound.wordsMiddle.isNotEmpty
        ? sound.wordsMiddle.first
        : sound.wordsStart.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ben nasıl söylüyorum?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in errs)
                  ChoiceChip(
                    label: Text(() {
                      final ex = PronunciationScorer.errorExample(
                        example,
                        sound.letter,
                        e.$2,
                      );
                      final chip = PronunciationScorer.errorChip(e.$2);
                      return ex == example ? chip : '$chip  ·  $ex';
                    }()),
                    selected: value == e.$2,
                    onSelected: (sel) => onChanged(sel ? e.$2 : null),
                  ),
                ChoiceChip(
                  label: const Text('Bilmiyorum'),
                  selected: value == null,
                  onSelected: (_) => onChanged(null),
                ),
              ],
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Analiz ve alıştırmalar ${sound.letter} ile '
                  '${PronunciationScorer.errorShort(value!)} ayrımına odaklanıyor.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
