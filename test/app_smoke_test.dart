import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelteklige_lanet/data/minimal_pairs.dart';
import 'package:pelteklige_lanet/data/sounds.dart';
import 'package:pelteklige_lanet/data/stories.dart';
import 'package:pelteklige_lanet/main.dart';
import 'package:pelteklige_lanet/screens/sound_detail_screen.dart';
import 'package:pelteklige_lanet/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenIntro': true});
    await Settings.instance.load();
  });

  testWidgets('ana ekran açılır ve sesler listelenir', (tester) async {
    await tester.pumpWidget(const PeltekApp());
    expect(find.text('Sesler'), findsOneWidget);
    await tester.tap(find.text('Sesler'));
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
