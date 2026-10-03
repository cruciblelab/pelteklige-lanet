// Ekran görüntüleri üretir (görsel kontrol için, CI'da çalışmaz).
// Çalıştırma: flutter test --update-goldens --tags render test/render
@Tags(['render'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelteklige_lanet/data/sounds.dart';
import 'package:pelteklige_lanet/data/stories.dart';
import 'package:pelteklige_lanet/screens/home_screen.dart';
import 'package:pelteklige_lanet/screens/meter_screen.dart';
import 'package:pelteklige_lanet/screens/minimal_pairs_screen.dart';
import 'package:pelteklige_lanet/screens/practice_screen.dart';
import 'package:pelteklige_lanet/screens/reading_screen.dart';
import 'package:pelteklige_lanet/screens/sound_detail_screen.dart';
import 'package:pelteklige_lanet/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  const dir = '/opt/sdk/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    roboto.addFont(
      Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())),
    );
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('$dir/MaterialIcons-Regular.otf').readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'seenIntro': true});
    await Settings.instance.load();
    await _loadFonts();
    // Eklenti kanallarını sustur (testte gerçek cihaz yok).
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in [
      'plugins.flutter.io/path_provider',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'com.llfbandit.record/messages',
      'flutter_tts',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      });
    }
  });

  final screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'detail_S': () => SoundDetailScreen(sound: soundById('S')),
    'practice_R': () => PracticeScreen(
      sound: soundById('R'),
      title: 'Kelime ortasında',
      items: soundById('R').wordsMiddle,
    ),
    'pairs': () => const MinimalPairsScreen(),
    'meter': () => const MeterScreen(),
    'reading': () => ReadingScreen(story: stories.first),
  };

  for (final e in screens.entries) {
    testWidgets('ekran ${e.key}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00897B),
            ),
          ),
          home: e.value(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));
      // Ses çalar olay kanalları testte yok; bu hatalar beklenen.
      while (tester.takeException() != null) {}
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/screen_${e.key}.png'),
      );
    });
  }
}
