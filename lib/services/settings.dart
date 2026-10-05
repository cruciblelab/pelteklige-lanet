import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tıslama ölçerinin eşikleri sesin perdesine göre değişir.
enum VoiceProfile {
  child('Çocuk', 2800, 5600),
  woman('Yetişkin kadın', 2500, 5000),
  man('Yetişkin erkek', 2200, 4400);

  final String label;
  final double shMinHz;
  final double sMinHz;
  const VoiceProfile(this.label, this.shMinHz, this.sMinHz);
}

class SoundStats {
  int attempts;
  int good;
  SoundStats(this.attempts, this.good);

  Map<String, int> toJson() => {'a': attempts, 'g': good};
}

/// Ayarlar ve ilerleme. Hepsi cihazda, SharedPreferences içinde durur.
class Settings extends ChangeNotifier {
  Settings._();
  static final instance = Settings._();

  late SharedPreferences _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
  }

  /// Konuşma tanımayı mümkünse telefonun içinde yap.
  ///
  /// Garanti değildir: Android 12+ telefonda cihaz içi tanıyıcı yoksa eklenti
  /// normal tanıyıcıya geçer ve o da sesi Google sunucularına gönderebilir.
  bool get onDeviceOnly => _p.getBool('onDeviceOnly') ?? true;
  set onDeviceOnly(bool v) {
    _p.setBool('onDeviceOnly', v);
    notifyListeners();
  }

  double get speechRate => _p.getDouble('speechRate') ?? 0.4;
  set speechRate(double v) {
    _p.setDouble('speechRate', v);
    notifyListeners();
  }

  VoiceProfile get voiceProfile =>
      VoiceProfile.values[_p.getInt('voiceProfile') ?? 0];
  set voiceProfile(VoiceProfile v) {
    _p.setInt('voiceProfile', v.index);
    notifyListeners();
  }

  /// Ses analizinden önce kişinin kendi tahminini sor (öz-değerlendirme).
  bool get selfEvalFirst => _p.getBool('selfEvalFirst') ?? false;
  set selfEvalFirst(bool v) {
    _p.setBool('selfEvalFirst', v);
    notifyListeners();
  }

  /// Günlük deneme hedefi (araştırmalarda doz belirleyici; docs/ARASTIRMA.md).
  int get dailyGoal => _p.getInt('dailyGoal') ?? 100;
  set dailyGoal(int v) {
    _p.setInt('dailyGoal', v);
    notifyListeners();
  }

  bool get seenIntro => _p.getBool('seenIntro') ?? false;
  set seenIntro(bool v) => _p.setBool('seenIntro', v);

  // --- İlerleme ---

  Map<String, SoundStats> get _stats {
    final raw = _p.getString('stats');
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) {
      final j = v as Map<String, dynamic>;
      return MapEntry(k, SoundStats(j['a'] as int, j['g'] as int));
    });
  }

  SoundStats statsFor(String soundId) => _stats[soundId] ?? SoundStats(0, 0);

  /// Bir alıştırma denemesini kaydeder. [good]: kişi kendi kaydını dinleyip
  /// "doğru söyledim" dediyse ya da tanıyıcı doğru duyduysa.
  void logAttempt(String soundId, {required bool good}) {
    final s = _stats;
    final cur = s[soundId] ?? SoundStats(0, 0);
    cur.attempts++;
    if (good) cur.good++;
    s[soundId] = cur;
    _p.setString('stats', jsonEncode(s.map((k, v) => MapEntry(k, v.toJson()))));
    _markToday();
    notifyListeners();
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _markToday() {
    final days = (_p.getStringList('days') ?? []).toSet();
    final today = _day(DateTime.now());
    days.add(today);
    _p.setStringList('days', days.toList());
    final key = 'count_$today';
    _p.setInt(key, (_p.getInt(key) ?? 0) + 1);
  }

  int get todayCount => _p.getInt('count_${_day(DateTime.now())}') ?? 0;

  /// Bugünden geriye kesintisiz çalışılan gün sayısı.
  int get streak {
    final days = (_p.getStringList('days') ?? []).toSet();
    var d = DateTime.now();
    if (!days.contains(_day(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(_day(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }
}
