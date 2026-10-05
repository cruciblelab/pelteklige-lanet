import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelteklige_lanet/audio/pronunciation_scorer.dart';
import 'package:pelteklige_lanet/data/minimal_pairs.dart';
import 'package:pelteklige_lanet/data/sounds.dart';
import 'package:pelteklige_lanet/data/stories.dart';
import 'package:pelteklige_lanet/main.dart';
import 'package:pelteklige_lanet/screens/sound_detail_screen.dart';
import 'package:pelteklige_lanet/services/progress.dart';
import 'package:pelteklige_lanet/services/settings.dart';
import 'package:pelteklige_lanet/utils/turkish.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    await Settings.instance.load();
    await Progress.instance.load();
  });

  testWidgets('ana ekran açılır ve sesler listelenir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const PeltekApp());
    expect(find.text('Senin planın'), findsOneWidget);
    await tester.tap(find.text('Tüm sesler'));
    await tester.pumpAndSettle();
    expect(find.text('R'), findsOneWidget);
    expect(find.text('Ş'), findsOneWidget);
  });

  testWidgets('ses detayı telefon genişliğinde taşmadan açılır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: SoundDetailScreen(sound: soundById('S'))),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Nasıl söylenir?'), findsOneWidget);
    expect(find.text('Ben nasıl söylüyorum?'), findsOneWidget);
    expect(find.text('Basamaklar'), findsOneWidget);
  });

  test('R basamakları köprü ve kümelerle başlar/ilerler', () {
    final ids = levelsFor(soundById('R')).map((l) => l.id).toList();
    expect(ids, [
      'kopru',
      'hece',
      'bas',
      'orta',
      'son',
      'kume',
      'cumle',
      'tekerleme',
    ]);
    // C sesinde kelime sonu ve köprü yok
    expect(levelsFor(soundById('C')).map((l) => l.id), isNot(contains('son')));
  });

  test('basamak son 8 denemenin 6sı doğruysa geçilir', () {
    final p = Progress.instance;
    for (var i = 0; i < 5; i++) {
      expect(p.record('R', 'hece', true), isFalse);
    }
    expect(p.record('R', 'hece', false), isFalse);
    expect(p.record('R', 'hece', true), isTrue); // 6. doğru
    expect(p.isPassed('R', 'hece'), isTrue);
    expect(p.currentLevelIndex(soundById('R')), 0); // köprü hâlâ önerilen
  });

  test('içerik tutarlı', () {
    for (final s in sounds) {
      expect(s.syllables, isNotEmpty, reason: s.letter);
      expect(s.wordsStart, isNotEmpty, reason: s.letter);
      expect(s.sentences, isNotEmpty, reason: s.letter);
    }
    for (final p in minimalPairs) {
      expect(p.a, isNot(p.b));
    }
    for (final st in stories) {
      expect(st.sentences.length, greaterThanOrEqualTo(4), reason: st.id);
    }
  });

  test('hata seçilince çiftler basamağı eklenir (R yerine L → kar/kal)', () {
    final p = Progress.instance;
    final r = soundById('R');
    expect(levelsFor(r).map((l) => l.id), isNot(contains('cift')));
    p.setFocusError('R', 'R yerine L');
    final levels = levelsFor(r);
    final pairs = levels.firstWhere((l) => l.id == 'cift');
    expect(pairs.items, contains('kar|kal'));
    expect(pairs.items, isNot(contains('kar|kay')));
    // Kulak → köprü → çiftler
    expect(levels.take(3).map((l) => l.id), ['kulak', 'kopru', 'cift']);
    expect(levels.first.title, 'Kulak: kar mı kal mı?');
    p.setFocusError('R', null);
  });

  test('çiftler hedef kelimeyi doğru taraftan seçer', () {
    expect(pairsFor('Ş', 'S'), contains(('şu', 'su')));
    expect(pairsFor('S', 'Ş'), contains(('su', 'şu')));
    expect(pairsFor('R', 'Y'), contains(('kara', 'kaya')));
  });

  test('odaklı mod: R ile L arası "arada" sayılır', () {
    SoundCheck c(double pc, double pl, double py) => SoundCheck(
      position: 0,
      word: 'kar',
      indexInWord: 2,
      probs: {'Doğru': pc, 'R yerine L': pl, 'R yerine Y': py},
    );
    expect(c(0.9, 0.05, 0.05).focus('R yerine L').verdict, Verdict.correct);
    expect(c(0.05, 0.9, 0.05).focus('R yerine L').verdict, Verdict.error);
    expect(c(0.4, 0.5, 0.1).focus('R yerine L').verdict, Verdict.unsure);
    // Seçilen hata dışında Y baskınsa ayrıca bildirilir
    expect(c(0.05, 0.05, 0.9).focus('R yerine L').otherError, 'R yerine Y');
    // Odak yanlış seçilmişse (Y), açık bir L yine de hata sayılır ve L
    // olarak gösterilir. Eskiden bu durum "%50 R" gibi görünüyordu.
    final wrongFocus = c(0.06, 0.9, 0.04).focus('R yerine Y');
    expect(wrongFocus.verdict, Verdict.error);
    expect(wrongFocus.shownLabel, 'R yerine L');
    // Diğer hata doğrudan daha olası değilse hesaba girmez
    expect(c(0.8, 0.05, 0.15).focus('R yerine L').otherError, isNull);
  });

  test('hata örnekleri', () {
    expect(
      PronunciationScorer.errorExample('araba', 'R', 'R yerine L'),
      'alaba',
    );
    expect(PronunciationScorer.errorExample('araba', 'R', 'R yutuldu'), 'aaba');
    expect(PronunciationScorer.errorShort('R yerine V/W'), 'V');
  });

  test('soru eki ünlü uyumuna uyar', () {
    expect(pairQuestion('kar', 'kal'), 'kar mı kal mı?');
    expect(pairQuestion('yer', 'yel'), 'yer mi yel mi?');
    expect(pairQuestion('kol', 'koy'), 'kol mu koy mu?');
    expect(pairQuestion('göl', 'döl'), 'göl mü döl mü?');
  });

  test('kulak eğitimi istatistiği ve oran kategorileri', () {
    final p = Progress.instance;
    for (final b in [true, true, false, true]) {
      p.recordEar('own', b);
    }
    expect(p.earAccuracy('own'), 0.75);
    expect(FocusResult.categoryOf(0.9), 0);
    expect(FocusResult.categoryOf(0.5), 1);
    expect(FocusResult.categoryOf(0.1), 2);
  });
}
