import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/recordings.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final _store = RecordingStore.instance;
  List<RecordingEntry> _items = [];
  String? _playingPath;
  String _filter = 'hepsi';
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = _store.player.onPlayerStateChanged.listen((s) {
      if (s != PlayerState.playing && mounted) {
        setState(() => _playingPath = null);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _store.stopPlayback();
    super.dispose();
  }

  Future<void> _load() async {
    final l = await _store.list();
    if (mounted) setState(() => _items = List.of(l));
  }

  Future<void> _toggle(RecordingEntry e) async {
    if (_playingPath == e.path) {
      await _store.stopPlayback();
      setState(() => _playingPath = null);
    } else {
      await _store.play(e.path);
      setState(() => _playingPath = e.path);
    }
  }

  Future<void> _delete(RecordingEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı sil?'),
        content: Text('“${e.label}” kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _store.delete(e);
      _load();
    }
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _share(List<RecordingEntry> entries) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${entries.length} kaydı paylaş'),
        content: const Text(
          'Kayıtlar senin sesin. Telefonun paylaşma menüsü açılır; nereye ve '
          'kime göndereceğine sen karar verirsin. Uygulama hiçbir yere kendisi '
          'göndermez.\n\nDosya adlarında kelime ve ses analizinin sonucu '
          'yazar (ör. 003_R-ara_L-%60.wav), yanında bir özet tablosu gider.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Paylaş'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final files = await _store.exportCopies(entries);
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final f in files) XFile(f)],
        subject: 'Peltek kayıtları',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filter == 'hepsi'
        ? _items
        : _items.where((e) => e.category == _filter).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıtlarım'),
        actions: [
          IconButton(
            tooltip: 'Paylaş',
            onPressed: shown.isEmpty ? null : () => _share(shown),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'hepsi', label: Text('Hepsi')),
                ButtonSegment(value: 'alistirma', label: Text('Alıştırma')),
                ButtonSegment(value: 'okuma', label: Text('Okuma')),
              ],
              selected: {_filter},
              onSelectionChanged: (v) => setState(() => _filter = v.first),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Henüz kayıt yok.\nAlıştırmalarda ya da okumada mikrofon düğmesine bas.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final e = shown[i];
                      final playing = _playingPath == e.path;
                      return ListTile(
                        leading: IconButton.filledTonal(
                          onPressed: () => _toggle(e),
                          icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                        ),
                        title: Text(e.label),
                        subtitle: Text(
                          '${_date(e.createdAt)} · ${(e.durationMs / 1000).toStringAsFixed(1)} sn',
                        ),
                        trailing: IconButton(
                          onPressed: () => _delete(e),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'İpucu: Aynı kelimenin bir hafta önceki ve bugünkü kaydını art arda dinlemek ilerlemeyi en net gösterir.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
