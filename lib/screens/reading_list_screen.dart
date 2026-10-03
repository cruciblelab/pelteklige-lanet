import 'package:flutter/material.dart';

import '../data/stories.dart';
import 'reading_screen.dart';

class ReadingListScreen extends StatelessWidget {
  const ReadingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kitap okuma')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final s in stories)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${s.level}')),
                title: Text(s.title),
                subtitle: Text(
                  'Odak: ${s.focus} · ${s.sentences.length} cümle',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReadingScreen(story: s)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Kendi metnini oku'),
              subtitle: const Text(
                'Elindeki kitaptan bir paragrafı yapıştır ya da yaz',
              ),
              onTap: () => _customText(context),
            ),
          ),
        ],
      ),
    );
  }

  void _customText(BuildContext context) {
    final c = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kendi metnin'),
        content: TextField(
          controller: c,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Okumak istediğin metni buraya yaz…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final text = c.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReadingScreen.custom(text)),
              );
            },
            child: const Text('Oku'),
          ),
        ],
      ),
    );
  }
}
