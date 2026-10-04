import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelteklige_lanet/data/minimal_pairs.dart';
import 'package:pelteklige_lanet/data/sounds.dart';
import 'package:pelteklige_lanet/data/stories.dart';
import 'package:pelteklige_lanet/main.dart';
import 'package:pelteklige_lanet/screens/sound_detail_screen.dart';
import 'package:pelteklige_lanet/services/progress.dart';
import 'package:pelteklige_lanet/services/settings.dart';
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
    expect(find.text('Sık hata'), findsOneWidget);
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
      expect(s.errorPose == null, s.errorLabel == null, reason: s.letter);
    }
    for (final p in minimalPairs) {
      expect(p.a, isNot(p.b));
    }
    for (final st in stories) {
      expect(st.sentences.length, greaterThanOrEqualTo(4), reason: st.id);
    }
  });
}
