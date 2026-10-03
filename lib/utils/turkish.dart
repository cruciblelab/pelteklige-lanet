/// Türkçe'ye özgü metin yardımcıları.
///
/// Dart'ın `toLowerCase()` fonksiyonu Türkçe'yi bilmez: "I" harfini "ı" yerine
/// "i" yapar, "İ" harfini de "i̇" (noktalı i + birleşik nokta) yapar. Bu yüzden
/// karşılaştırmalardan önce her zaman [trLower] kullanılmalı.
library;

String trLower(String s) =>
    s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

String trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

final _nonLetter = RegExp(r"[^a-zçğıöşüâîû0-9\s]");

/// Noktalama işaretlerini atar, şapkalı harfleri sadeleştirir, küçük harfe çevirir.
String normalizeText(String s) {
  var t = trLower(s)
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u')
      .replaceAll('’', "'");
  // Kesme işaretli ekler ("Ali'nin") tek kelime sayılır.
  t = t.replaceAll("'", '');
  t = t.replaceAll(_nonLetter, ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> tokenize(String s) {
  final n = normalizeText(s);
  return n.isEmpty ? const [] : n.split(' ');
}
