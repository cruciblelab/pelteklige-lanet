import 'package:flutter/material.dart';

import '../models/sound.dart';
import '../services/progress.dart';
import '../services/tts.dart';
import '../widgets/mouth_animation.dart';
import 'meter_screen.dart';
import 'practice_screen.dart';

class SoundDetailScreen extends StatefulWidget {
  final SoundInfo sound;
  const SoundDetailScreen({super.key, required this.sound});

  @override
  State<SoundDetailScreen> createState() => _SoundDetailScreenState();
}

class _SoundDetailScreenState extends State<SoundDetailScreen> {
  bool _showError = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.sound;
    final theme = Theme.of(context);
    final levels = levelsFor(s);
    final p = Progress.instance;
    final current = p.currentLevelIndex(s);

    return Scaffold(
      appBar: AppBar(title: Text('${s.title}  ${s.ipa}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  MouthAnimation(
                    key: ValueKey(_showError),
                    pose: _showError ? s.errorPose! : s.pose,
                    airflow: s.airflow,
                    voiced: s.voiced,
                    tongueColor: _showError ? const Color(0xFFB0737D) : null,
                  ),
                  const SizedBox(height: 8),
                  if (s.errorPose != null)
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Doğrusu'),
                          icon: Icon(Icons.check),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Sık hata'),
                          icon: Icon(Icons.close),
                        ),
                      ],
                      selected: {_showError},
                      onSelectionChanged: (v) =>
                          setState(() => _showError = v.first),
                    ),
                  if (_showError && s.errorLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        s.errorLabel!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Durdurmak için çizime dokun',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
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
            initiallyExpanded: true,
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
  final bool initiallyExpanded;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        initiallyExpanded: initiallyExpanded,
        children: children,
      ),
    );
  }
}
