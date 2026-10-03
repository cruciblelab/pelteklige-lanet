import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordingEntry {
  final String path;
  final String label;
  final String category;
  final DateTime createdAt;
  final int durationMs;

  const RecordingEntry({
    required this.path,
    required this.label,
    required this.category,
    required this.createdAt,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'label': label,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
    'durationMs': durationMs,
  };

  factory RecordingEntry.fromJson(Map<String, dynamic> j) => RecordingEntry(
    path: j['path'] as String,
    label: j['label'] as String,
    category: j['category'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
  );
}

/// Kayıtları cihazda saklar. Hiçbir ses dosyası cihaz dışına gönderilmez.
class RecordingStore {
  RecordingStore._();
  static final instance = RecordingStore._();

  final _recorder = AudioRecorder();
  final player = AudioPlayer();
  final _changes = StreamController<void>.broadcast();
  Directory? _dir;
  List<RecordingEntry>? _cache;
  DateTime? _startedAt;
  String? _pendingLabel, _pendingCategory, _pendingPath;

  Stream<void> get changes => _changes.stream;

  Future<Directory> _root() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/kayitlar');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  Future<File> _indexFile() async => File('${(await _root()).path}/index.json');

  Future<List<RecordingEntry>> list() async {
    if (_cache != null) return _cache!;
    final f = await _indexFile();
    if (!await f.exists()) return _cache = [];
    try {
      final raw = jsonDecode(await f.readAsString()) as List;
      _cache = raw
          .map((e) => RecordingEntry.fromJson(e as Map<String, dynamic>))
          .where((e) => File(e.path).existsSync())
          .toList();
    } catch (_) {
      _cache = [];
    }
    return _cache!;
  }

  Future<void> _save() async {
    final f = await _indexFile();
    await f.writeAsString(jsonEncode(_cache!.map((e) => e.toJson()).toList()));
    _changes.add(null);
  }

  Future<List<RecordingEntry>> byLabel(String label) async =>
      (await list()).where((e) => e.label == label).toList();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> get isRecording => _recorder.isRecording();

  Stream<Amplitude> amplitude() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));

  Future<bool> start({required String label, required String category}) async {
    if (!await _recorder.hasPermission()) return false;
    await player.stop();
    final dir = await _root();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _pendingPath = '${dir.path}/$ts.m4a';
    _pendingLabel = label;
    _pendingCategory = category;
    _startedAt = DateTime.now();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 96000,
        numChannels: 1,
      ),
      path: _pendingPath!,
    );
    return true;
  }

  Future<RecordingEntry?> stop() async {
    final path = await _recorder.stop();
    if (path == null || _pendingPath == null) return null;
    final entry = RecordingEntry(
      path: path,
      label: _pendingLabel!,
      category: _pendingCategory!,
      createdAt: _startedAt!,
      durationMs: DateTime.now().difference(_startedAt!).inMilliseconds,
    );
    _pendingPath = null;
    // Yanlışlıkla dokunulan çok kısa kayıtları tutma.
    if (entry.durationMs < 400) {
      await _deleteFile(path);
      return null;
    }
    (await list()).insert(0, entry);
    await _save();
    return entry;
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    _pendingPath = null;
  }

  Future<void> delete(RecordingEntry e) async {
    await player.stop();
    await _deleteFile(e.path);
    (await list()).removeWhere((x) => x.path == e.path);
    await _save();
  }

  Future<void> _deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  Future<void> play(String path) async {
    await player.stop();
    await player.play(DeviceFileSource(path));
  }

  Future<void> stopPlayback() => player.stop();

  /// Ses ölçer için ham PCM akışı (dosyaya yazılmaz).
  Future<Stream<Uint8List>> startPcmStream({int sampleRate = 44100}) async {
    await player.stop();
    return _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        // Tanıma kaynağı gürültü bastırma uygulamaz, tiz frekansları korur.
        androidConfig: const AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
        ),
      ),
    );
  }

  Future<void> stopPcmStream() async {
    await _recorder.stop();
  }
}
