import 'package:flutter/material.dart';

import '../models/sound.dart';
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
    final levels = <(String, String, List<String>)>[
      ('Heceler', 'Sesi ünlülerle birleştir', s.syllables),
      ('Kelime başında', s.wordsStart.take(3).join(', '), s.wordsStart),
      ('Kelime ortasında', s.wordsMiddle.take(3).join(', '), s.wordsMiddle),
      ('Kelime sonunda', s.wordsEnd.take(3).join(', '), s.wordsEnd),
      ('Cümleler', 'Akıcı konuşmaya geçiş', s.sentences),
      ('Tekerlemeler', 'Hız ve kontrol', s.tongueTwisters),
    ].where((l) => l.$3.isNotEmpty).toList();

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
          Text('Alıştırmalar', style: theme.textTheme.titleLarge),
          Text(
            'Kolaydan zora sırayla ilerle. Bir basamakta rahatlayınca bir sonrakine geç.',
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
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(levels[i].$1),
                subtitle: Text(
                  levels[i].$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text('${levels[i].$3.length}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PracticeScreen(
                      sound: s,
                      title: levels[i].$1,
                      items: levels[i].$3,
                    ),
                  ),
                ),
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
