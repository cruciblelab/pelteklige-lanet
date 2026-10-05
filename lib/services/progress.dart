import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/pronunciation_scorer.dart';
import '../data/minimal_pairs.dart';
import '../data/sounds.dart';
import '../utils/turkish.dart';
import '../models/sound.dart';

enum LevelKind { ear, bridge, pairs, practice }

/// Bir sesin çalışma basamağı (hazırlık → hece → kelime → cümle…).
class Level {
  final String id;
  final String title;
  final String hint;
  final LevelKind kind;
  final List<String> items;

  const Level({
    required this.id,
    required this.title,
    required this.hint,
    required this.kind,
    required this.items,
  });
}

/// Ses için sıralı basamaklar. Boş olanlar atlanır.
List<Level> levelsFor(SoundInfo s) {
  final l = s.letter;
  final pairsLevel = _pairsLevel(s);
  return [
    if (pairsLevel != null)
      Level(
        id: 'kulak',
        title: () {
          final p = pairsLevel.items.first.split('|');
          return 'Kulak: ${pairQuestion(p[0], p[1])}';
        }(),
        hint: 'Önce farkı duymayı öğren',
        kind: LevelKind.ear,
        items: pairsLevel.items,
      ),
    if (s.bridge.isNotEmpty)
      Level(
        id: 'kopru',
        title: 'Hazırlık: D’den $l’ye köprü',
        hint: '“ada”yı hızlandırınca “ara” olur',
        kind: LevelKind.bridge,
        items: [for (final b in s.bridge) b.$1],
      ),
    ?pairsLevel,
    Level(
      id: 'hece',
      title: 'Heceler',
      hint: s.syllables.take(4).join(', '),
      kind: LevelKind.practice,
      items: s.syllables,
    ),
    Level(
      id: 'bas',
      title: 'Kelime başında',
      hint: s.wordsStart.take(3).join(', '),
      kind: LevelKind.practice,
      items: s.wordsStart,
    ),
    Level(
      id: 'orta',
      title: 'Kelime ortasında',
      hint: s.wordsMiddle.take(3).join(', '),
      kind: LevelKind.practice,
      items: s.wordsMiddle,
    ),
    Level(
      id: 'son',
      title: 'Kelime sonunda',
      hint: s.wordsEnd.take(3).join(', '),
      kind: LevelKind.practice,
      items: s.wordsEnd,
    ),
    Level(
      id: 'kume',
      title: 'Kümeler',
      hint: s.wordsClusters.take(3).join(', '),
      kind: LevelKind.practice,
      items: s.wordsClusters,
    ),
    Level(
      id: 'cumle',
      title: 'Cümleler',
      hint: 'Akıcı konuşmaya geçiş',
      kind: LevelKind.practice,
      items: s.sentences,
    ),
    Level(
      id: 'tekerleme',
      title: 'Tekerlemeler',
      hint: 'Hız ve kontrol',
      kind: LevelKind.practice,
      items: s.tongueTwisters,
    ),
  ].where((lv) => lv.items.isNotEmpty).toList();
}

/// Kişinin hatası biliniyorsa "kar mı kal mı?" çiftleri basamağı.
Level? _pairsLevel(SoundInfo s) {
  final p = Progress.instance;
  if (!p.isLoaded) return null;
  final err = p.focusError(s.id);
  if (err == null) return null;
  final short = PronunciationScorer.errorShort(err);
  final pairs = pairsFor(s.letter, short);
  if (pairs.isEmpty) return null;
  return Level(
    id: 'cift',
    title: 'Çiftler: ${pairQuestion(pairs.first.$1, pairs.first.$2)}',
    hint: '${s.letter} ile $short arasındaki farkı söyle',
    kind: LevelKind.pairs,
    items: [for (final pr in pairs) '${pr.$1}|${pr.$2}'],
  );
}

/// Odak sesleri, başlangıç bilgisi ve basamak sonuçları. Hepsi cihazda.
///
/// Bir basamak, ses analizinin son [window] denemesinden en az [needed]
/// tanesini doğru bulmasıyla geçilir. Basamaklar kilitli değildir: kişi
/// istediği basamağa gidebilir, uygulama yalnızca sıradakini önerir.
class Progress extends ChangeNotifier {
  Progress._();
  static final instance = Progress._();

  static const window = 8;
  static const needed = 6;

  SharedPreferences? _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
  }

  SharedPreferences get _prefs => _p!;

  bool get isLoaded => _p != null;

  bool get onboarded => _prefs.getBool('onboarded') ?? false;
  set onboarded(bool v) {
    _prefs.setBool('onboarded', v);
    notifyListeners();
  }

  List<String> get focusSounds {
    final l = _prefs.getStringList('focusSounds');
    return (l ?? const ['R'])
        .where((id) => sounds.any((s) => s.id == id))
        .toList();
  }

  set focusSounds(List<String> v) {
    _prefs.setStringList('focusSounds', v);
    notifyListeners();
  }

  /// Kişinin bu seste yaptığı hata (ör. "R yerine L"). Seçildiyse analiz ve
  /// alıştırmalar bu ayrıma odaklanır. null = bilinmiyor (tüm hatalara bakılır).
  String? focusError(String soundId) {
    final m = _focusErrors;
    return m[soundId];
  }

  void setFocusError(String soundId, String? label) {
    final m = _focusErrors;
    if (label == null) {
      m.remove(soundId);
    } else {
      m[soundId] = label;
    }
    _prefs.setString('focusErrors', jsonEncode(m));
    notifyListeners();
  }

  Map<String, String> get _focusErrors {
    final raw = _prefs.getString('focusErrors');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
  }

  /// Kulak eğitimi sonuçları: 'tts' (telefonun sesi) ve 'own' (kendi sesin,
  /// modelle uyuşma). Son 50 tutulur.
  List<bool> earResults(String kind) =>
      (_prefs.getStringList('ear_$kind') ?? const [])
          .map((e) => e == '1')
          .toList();

  void recordEar(String kind, bool correct) {
    final l = [...earResults(kind), correct];
    final keep = l.length > 50 ? l.sublist(l.length - 50) : l;
    _prefs.setStringList('ear_$kind', [for (final b in keep) b ? '1' : '0']);
    notifyListeners();
  }

  /// Son [n] kulak denemesinde doğru oranı (yoksa null).
  double? earAccuracy(String kind, {int n = 20}) {
    final r = earResults(kind);
    if (r.isEmpty) return null;
    final last = r.length > n ? r.sublist(r.length - n) : r;
    return last.where((x) => x).length / last.length;
  }

  Map<String, List<bool>> get _results {
    final raw = _prefs.getString('levelResults');
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, (v as List).cast<bool>()));
  }

  static String _key(String soundId, String levelId) => '$soundId/$levelId';

  List<bool> resultsFor(String soundId, String levelId) =>
      _results[_key(soundId, levelId)] ?? const [];

  /// Bir ses analizi sonucunu kaydeder. Basamak bu denemeyle geçildiyse true döner.
  bool record(String soundId, String levelId, bool correct) {
    final wasPassed = isPassed(soundId, levelId);
    final all = _results;
    final list = [...(all[_key(soundId, levelId)] ?? <bool>[]), correct];
    all[_key(soundId, levelId)] = list.length > 30
        ? list.sublist(list.length - 30)
        : list;
    _prefs.setString('levelResults', jsonEncode(all));
    notifyListeners();
    return !wasPassed && isPassed(soundId, levelId);
  }

  /// Son [window] denemedeki doğru sayısı.
  int recentCorrect(String soundId, String levelId) {
    final r = resultsFor(soundId, levelId);
    final last = r.length > window ? r.sublist(r.length - window) : r;
    return last.where((x) => x).length;
  }

  bool isPassed(String soundId, String levelId) =>
      recentCorrect(soundId, levelId) >= needed;

  /// Önerilen basamak: geçilmemiş ilk basamak (hepsi geçildiyse sonuncusu).
  int currentLevelIndex(SoundInfo s) {
    final levels = levelsFor(s);
    for (var i = 0; i < levels.length; i++) {
      if (!isPassed(s.id, levels[i].id)) return i;
    }
    return levels.length - 1;
  }

  int passedCount(SoundInfo s) =>
      levelsFor(s).where((lv) => isPassed(s.id, lv.id)).length;

  @visibleForTesting
  void debugSetPrefs(SharedPreferences p) => _p = p;
}
