import '../models/sound.dart';
import '../utils/turkish.dart';

/// Tek bir sesle ayrılan gerçek kelime çiftleri.
///
/// Neden önemli: hazır konuşma tanıyıcılar yanlış söylenen sesi çoğu zaman
/// en olası kelimeye "düzeltir". Çiftin iki tarafı da gerçek kelime olunca
/// tanıyıcı duyduğunu yazmak zorunda kalır; böylece "kar" yerine "kay"
/// söylendiğini yakalayabiliriz.
const minimalPairs = <MinimalPair>[
  // R / Y
  MinimalPair('kara', 'kaya', 'R / Y'),
  MinimalPair('sor', 'soy', 'R / Y'),
  MinimalPair('dur', 'duy', 'R / Y'),
  MinimalPair('yar', 'yay', 'R / Y'),
  MinimalPair('kar', 'kay', 'R / Y'),
  MinimalPair('sarı', 'sayı', 'R / Y'),
  MinimalPair('yara', 'yaya', 'R / Y'),
  // R / L
  MinimalPair('kar', 'kal', 'R / L'),
  MinimalPair('dar', 'dal', 'R / L'),
  MinimalPair('sarı', 'salı', 'R / L'),
  MinimalPair('bar', 'bal', 'R / L'),
  MinimalPair('kır', 'kıl', 'R / L'),
  MinimalPair('yer', 'yel', 'R / L'),
  MinimalPair('kara', 'kala', 'R / L'),
  MinimalPair('kor', 'kol', 'R / L'),
  MinimalPair('para', 'pala', 'R / L'),
  // R / D
  MinimalPair('ara', 'ada', 'R / D'),
  MinimalPair('arı', 'adı', 'R / D'),
  MinimalPair('karı', 'kadı', 'R / D'),
  // S / Ş
  MinimalPair('su', 'şu', 'S / Ş'),
  MinimalPair('kas', 'kaş', 'S / Ş'),
  MinimalPair('tas', 'taş', 'S / Ş'),
  MinimalPair('sık', 'şık', 'S / Ş'),
  MinimalPair('sal', 'şal', 'S / Ş'),
  // S / Z
  MinimalPair('sor', 'zor', 'S / Z'),
  MinimalPair('saman', 'zaman', 'S / Z'),
  MinimalPair('kas', 'kaz', 'S / Z'),
  MinimalPair('as', 'az', 'S / Z'),
  // S / T
  MinimalPair('sık', 'tık', 'S / T'),
  MinimalPair('sel', 'tel', 'S / T'),
  MinimalPair('sat', 'tat', 'S / T'),
  // Ç / Ş
  MinimalPair('çok', 'şok', 'Ç / Ş'),
  MinimalPair('çal', 'şal', 'Ç / Ş'),
  MinimalPair('aç', 'aş', 'Ç / Ş'),
  MinimalPair('çiş', 'şiş', 'Ç / Ş'),
  // K / T
  MinimalPair('kaş', 'taş', 'K / T'),
  MinimalPair('kel', 'tel', 'K / T'),
  MinimalPair('kek', 'tek', 'K / T'),
  MinimalPair('kat', 'tat', 'K / T'),
  // G / D
  MinimalPair('göl', 'döl', 'G / D'),
  MinimalPair('gel', 'del', 'G / D'),
  // L / Y
  MinimalPair('bal', 'bay', 'L / Y'),
  MinimalPair('ol', 'oy', 'L / Y'),
  MinimalPair('kol', 'koy', 'L / Y'),
];

List<String> get contrasts =>
    minimalPairs.map((p) => p.contrast).toSet().toList();

/// Kişinin hatasına uygun çiftler: (hedef kelime, hatalı söylenince olan kelime).
/// Ör. R ve "R yerine L" için [("kar", "kal"), ("dar", "dal"), …].
List<(String, String)> pairsFor(String targetLetter, String errorShort) {
  final t = trLower(targetLetter), e = trLower(errorShort);
  final out = <(String, String)>[];
  for (final p in minimalPairs) {
    final letters = p.contrast.split(' / ').map(trLower).toSet();
    if (!letters.containsAll({t, e})) continue;
    // Farklı olan harfi bul; hedef harfi taşıyan kelime hedeftir.
    final a = p.a.split(''), b = p.b.split('');
    if (a.length != b.length) continue;
    final i = List.generate(
      a.length,
      (k) => k,
    ).firstWhere((k) => a[k] != b[k], orElse: () => -1);
    if (i < 0) continue;
    if (a[i] == t && b[i] == e) out.add((p.a, p.b));
    if (b[i] == t && a[i] == e) out.add((p.b, p.a));
  }
  return out;
}
