import 'package:flutter/material.dart';

import '../services/settings.dart';
import 'meter_screen.dart';
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
    if (!Settings.instance.seenIntro) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showIntro());
    }
  }

  void _showIntro() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hoş geldin!'),
        content: const Text(
          'Bu uygulama sesleri doğru söylemeyi çalışmak için bir alıştırma '
          'defteridir: sesin nasıl çıkarıldığını gösterir, kendi sesini kaydedip '
          'dinlemeni ve kitap okumanı sağlar.\n\n'
          'Bir dil ve konuşma terapistinin (DKT) değerlendirmesinin yerine geçmez. '
          'Bir terapistle çalışıyorsan, buradaki alıştırmaları onun önerdiği '
          'seslerle kullanman en iyisidir.\n\n'
          'Kayıtların sadece bu telefonda saklanır.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Settings.instance.seenIntro = true;
              Navigator.pop(ctx);
            },
            child: const Text('Başlayalım'),
          ),
        ],
      ),
    );
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
        'Sesler',
        'Harfler nasıl söylenir, alıştırmalar',
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
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    size: 40,
                    color: Colors.deepOrange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bugün ${s.todayCount} alıştırma',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          s.streak > 0
                              ? '${s.streak} gündür aralıksız çalışıyorsun'
                              : 'Her gün 10 dakika, aralıklı tekrar en etkili yoldur',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
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
