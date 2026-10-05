import 'package:flutter_test/flutter_test.dart';
import 'package:pelteklige_lanet/utils/text_align.dart';
import 'package:pelteklige_lanet/utils/turkish.dart';

void main() {
  group('Türkçe küçük harf', () {
    test('I ve İ doğru çevrilir', () {
      expect(trLower('IRMAK İNCİR'), 'ırmak incir');
      expect(
        normalizeText("Ali'nin  KIRMIZI, rüzgâr!"),
        'alinin kırmızı rüzgar',
      );
    });
  });

  group('Harf farkları', () {
    test('r → y dönüşümü bulunur', () {
      expect(charEdits('araba', 'ayaba'), [const CharEdit('r', 'y')]);
    });
    test('atlanan harf bulunur', () {
      expect(charEdits('kar', 'ka'), [const CharEdit('r', '')]);
    });
  });

  group('Kelime hizalama', () {
    test('tam doğru okuma', () {
      final r = alignTexts(
        'Kar yağınca arabalar yavaş gider.',
        'kar yağınca arabalar yavaş gider',
      );
      expect(r.accuracy, 1);
      expect(r.missedCount, 0);
      expect(r.words.first.display, 'Kar');
    });

    test('yutulan kelime ve harf dönüşümü', () {
      final r = alignTexts('Kırmızı araba hızlı gitti', 'kılmızı hızlı gitti');
      expect(r.words.map((w) => w.status).toList(), [
        WordStatus.close,
        WordStatus.missed,
        WordStatus.correct,
        WordStatus.correct,
      ]);
      expect(r.substitutions.first.key, 'r → l');
    });

    test('kısaltılmış kelime işaretlenir', () {
      final r = alignTexts('geliyorum', 'geliyom');
      expect(r.words.single.shortened, isTrue);
    });

    test('minimal çift: su / şu yanlış sayılır', () {
      final r = alignTexts('şu', 'su');
      expect(r.words.single.status, WordStatus.wrong);
      expect(r.words.single.edits, [const CharEdit('ş', 's')]);
    });

    test('fazladan kelimeler ayrılır', () {
      final r = alignTexts('bir kedi', 'bir şey kedi');
      expect(r.accuracy, 1);
      expect(r.extraWords, ['şey']);
    });
  });
}
