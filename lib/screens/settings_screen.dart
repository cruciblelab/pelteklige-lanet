import 'package:flutter/material.dart';

import '../services/settings.dart';
import '../services/tts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = Settings.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Konuşma tanımayı mümkünse telefonda yap'),
            subtitle: const Text(
              'Açıkken telefonun kendi (çevrimdışı) tanıyıcısı tercih edilir. Bunun için Türkçe '
              'çevrimdışı tanıma paketi gerekir (Ayarlar → Google → Ses → Çevrimdışı konuşma tanıma). '
              'Telefonda böyle bir tanıyıcı yoksa Android normal tanıyıcıyı kullanır ve ses Google '
              'sunucularına gidebilir. Kesin gizlilik istiyorsan tanımayı kullanmadan önce interneti kapat.',
            ),
            value: s.onDeviceOnly,
            onChanged: (v) => setState(() => s.onDeviceOnly = v),
          ),
          const Divider(),
          ListTile(
            title: const Text('Örnek söyleyiş hızı'),
            subtitle: Slider(
              value: s.speechRate,
              min: 0.2,
              max: 0.7,
              divisions: 10,
              label: s.speechRate.toStringAsFixed(2),
              onChanged: (v) => setState(() => s.speechRate = v),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.volume_up),
              onPressed: () =>
                  Tts.instance.speak('Kırmızı araba rüzgârda hızlı gitti.'),
            ),
          ),
          ListTile(
            title: const Text('Tıslama ölçer ses profili'),
            trailing: DropdownButton<VoiceProfile>(
              value: s.voiceProfile,
              items: [
                for (final v in VoiceProfile.values)
                  DropdownMenuItem(value: v, child: Text(v.label)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => s.voiceProfile = v);
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hakkında', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'Peltekliğe Lanet, artikülasyon (ses üretimi) alıştırmaları için hazırlanmış '
                  'açık kaynak bir uygulamadır. Tanı koymaz ve tedavi yerine geçmez.\n\n'
                  'Ne zaman bir uzmana gitmeli? 4–5 yaşından sonra hâlâ belirgin ses hataları '
                  'varsa, yanal S (hava yanlardan kaçıyorsa) varsa, kekemelik, sesin kısılması '
                  'ya da yutkunma güçlüğü eşlik ediyorsa bir dil ve konuşma terapistine (DKT) '
                  'danışmak gerekir.\n\n'
                  'Gizlilik: Kayıtlar yalnızca bu telefonda saklanır, hiçbir yere gönderilmez. '
                  'Tıslama ölçer tamamen telefonda çalışır. “Söyle, kontrol edeyim” özelliği '
                  'Android’in konuşma tanıyıcısını kullanır; telefonda çevrimdışı tanıma yoksa '
                  'bu tanıyıcı sesi Google sunucularına gönderebilir. “Ses analizi” ise '
                  'tamamen telefonda çalışır.\n\n'
                  'Ses analizi modeli: ZIPA (Jian Zhu ve ark., ACL 2025, '
                  'github.com/lingjzhu/zipa), lisans CC BY 4.0. '
                  'Gerçek insan sesinde doğru söyleyişe “yanlış” deme oranı yaklaşık %1; '
                  'çocuk sesinde henüz ölçülmedi. Sonuçları bir öneri olarak gör.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
