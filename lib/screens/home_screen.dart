import 'package:flutter/material.dart';

import '../audio/pronunciation_scorer.dart';
import '../data/sounds.dart';
import '../services/progress.dart';
import '../services/settings.dart';
import 'meter_screen.dart';
import 'onboarding_screen.dart';
import 'practice_screen.dart';
import 'sound_detail_screen.dart';
import 'minimal_pairs_screen.dart';
import 'reading_list_screen.dart';
import 'recordings_screen.dart';
import 'settings_screen.dart';
import 'sounds_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (!Progress.instance.onboarded) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _go(const OnboardingScreen()),
      );
    }
  }

  void _go(Widget page) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => page),
  ).then((_) => setState(() {}));

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;
    final theme = Theme.of(context);
    final items = [
      _Tile(
        'Tüm sesler',
        'Animasyon ve basamaklar',
        Icons.abc,
        const Color(0xFF00897B),
        () => _go(const SoundsScreen()),
      ),
      _Tile(
        'Kitap okuma',
        'Sesli oku, kaydet, takip et',
        Icons.menu_book,
        const Color(0xFF5E35B1),
        () => _go(const ReadingListScreen()),
      ),
      _Tile(
        'Benzer kelimeler',
        'kar / kay, su / şu: duy ve söyle',
        Icons.compare_arrows,
        const Color(0xFFEF6C00),
        () => _go(const MinimalPairsScreen()),
      ),
      _Tile(
        'Tıslama ölçer',
        'S ve Ş sesini ekranda gör',
        Icons.graphic_eq,
        const Color(0xFF1E88E5),
        () => _go(const MeterScreen()),
      ),
      _Tile(
        'Kayıtlarım',
        'Eski kayıtlarını dinle, karşılaştır',
        Icons.library_music,
        const Color(0xFFD81B60),
        () => _go(const RecordingsScreen()),
      ),
      _Tile(
        'Ayarlar',
        'Tanıma, ses hızı, hakkında',
        Icons.settings,
        const Color(0xFF546E7A),
        () => _go(const SettingsScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Peltekliğe Lanet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PlanCard(onOpen: _go),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.deepOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bugün ${s.todayCount} deneme'
                  '${s.streak > 1 ? ' · ${s.streak} gündür aralıksız' : ''}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: [for (final t in items) _TileCard(t)],
          ),
        ],
      ),
    );
  }
}

class _Tile {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _Tile(this.title, this.subtitle, this.icon, this.color, this.onTap);
}

class _TileCard extends StatelessWidget {
  final _Tile t;
  const _TileCard(this.t);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: t.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: t.color,
                foregroundColor: Colors.white,
                child: Icon(t.icon),
              ),
              const Spacer(),
              Text(t.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                t.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Odak sesleri ve her birinin önerilen basamağı; "Devam et" ile tek dokunuş.
class _PlanCard extends StatelessWidget {
  final void Function(Widget page) onOpen;
  const _PlanCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Progress.instance;
    final focus = p.focusSounds.map(soundById).toList();
    final first = focus.first;
    final firstLevels = levelsFor(first);
    final firstLevel = firstLevels[p.currentLevelIndex(first)];
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Senin planın', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final snd in focus)
              InkWell(
                onTap: () => onOpen(SoundDetailScreen(sound: snd)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          snd.letter,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              levelsFor(snd)[p.currentLevelIndex(snd)].title,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (p.focusError(snd.id) case final e?)
                              Text(
                                'Odak: ${snd.letter} ↔ '
                                '${PronunciationScorer.errorShort(e)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: p.passedCount(snd) / levelsFor(snd).length,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${p.passedCount(snd)}/${levelsFor(snd).length}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => onOpen(levelPage(first, firstLevel)),
              icon: const Icon(Icons.play_arrow),
              label: Text('Devam et: ${first.letter} · ${firstLevel.title}'),
            ),
          ],
        ),
      ),
    );
  }
}
