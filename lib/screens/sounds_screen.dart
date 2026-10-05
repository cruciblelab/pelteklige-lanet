import 'package:flutter/material.dart';

import '../data/sounds.dart';
import '../services/settings.dart';
import 'sound_detail_screen.dart';

class SoundsScreen extends StatefulWidget {
  const SoundsScreen({super.key});

  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sesler')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: sounds.length,
        itemBuilder: (context, i) {
          final s = sounds[i];
          final st = Settings.instance.statsFor(s.id);
          return Card(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SoundDetailScreen(sound: s)),
              ).then((_) => setState(() {})),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    s.letter,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(s.ipa, style: theme.textTheme.bodySmall),
                  if (st.attempts > 0)
                    Text(
                      '${st.good}/${st.attempts}',
                      style: theme.textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
