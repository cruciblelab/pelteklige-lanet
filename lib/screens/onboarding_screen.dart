import 'package:flutter/material.dart';

import '../data/sounds.dart';
import '../services/progress.dart';
import '../services/settings.dart';
import 'screening_screen.dart';

/// İlk açılış: kim çalışacak + hangi sesler zor. İki dokunuşta biter.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final Set<String> _selected = {...Progress.instance.focusSounds};

  void _finish(List<String> focus) {
    final p = Progress.instance;
    p.focusSounds = focus.isEmpty ? ['R'] : focus;
    p.onboarded = true;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _step == 0 ? _who(theme) : _which(theme),
        ),
      ),
    );
  }

  Widget _who(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      Text('Kim çalışacak?', style: theme.textTheme.headlineMedium),
      const SizedBox(height: 4),
      Text(
        'Tıslama ölçerin ayarları ses perdesine göre yapılır.',
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
      for (final (v, icon) in [
        (VoiceProfile.child, Icons.child_care),
        (VoiceProfile.woman, Icons.face_3),
        (VoiceProfile.man, Icons.face),
      ])
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Icon(icon, size: 36),
            title: Text(v.label, style: theme.textTheme.titleLarge),
            onTap: () {
              Settings.instance.voiceProfile = v;
              setState(() => _step = 1);
            },
          ),
        ),
      const Spacer(),
      Text(
        'Bu uygulama tanı koymaz ve bir dil ve konuşma terapistinin yerine geçmez. '
        'Kayıtlar yalnızca bu telefonda kalır.',
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _which(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: () => setState(() => _step = 0),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      Text(
        'Hangi seslerde zorlanıyorsun?',
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 4),
      Text('Birden fazla seçebilirsin.', style: theme.textTheme.bodyMedium),
      const SizedBox(height: 20),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final s in sounds)
            FilterChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  s.letter,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              selected: _selected.contains(s.id),
              onSelected: (v) => setState(
                () => v ? _selected.add(s.id) : _selected.remove(s.id),
              ),
            ),
        ],
      ),
      const Spacer(),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: _selected.isEmpty
            ? null
            : () => _finish(
                sounds.map((s) => s.id).where(_selected.contains).toList(),
              ),
        child: const Text('Başla'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScreeningScreen(
              soundIds: _selected.isEmpty
                  ? sounds.map((s) => s.id).toList()
                  : sounds.map((s) => s.id).where(_selected.contains).toList(),
              onDone: _finish,
            ),
          ),
        ),
        icon: const Icon(Icons.hearing),
        label: Text(
          _selected.isEmpty
              ? 'Emin değilim, beni dinle'
              : 'Önce seçtiklerimi dinleyerek kontrol et',
        ),
      ),
      if (_selected.isNotEmpty)
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScreeningScreen(
                soundIds: sounds.map((s) => s.id).toList(),
                onDone: _finish,
              ),
            ),
          ),
          child: const Text('Bütün sesleri test et'),
        ),
    ],
  );
}
