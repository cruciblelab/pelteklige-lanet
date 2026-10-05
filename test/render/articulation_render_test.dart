// Ağız animasyonundan kareler (görsel kontrol için).
// Çalıştırma: flutter test --update-goldens --tags render test/render
@Tags(['render'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelteklige_lanet/widgets/articulation/articulation_view.dart';

Future<void> _fonts() async {
  const dir = '/opt/sdk/flutter/bin/cache/artifacts/material_fonts';
  final f = FontLoader('Roboto');
  for (final n in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    f.addFont(
      Future.value(ByteData.sublistView(File('$dir/$n').readAsBytesSync())),
    );
  }
  await f.load();
}

void main() {
  setUpAll(_fonts);
  // (doğru, hata, hatayı göster, önden)
  final cases = <String, (String, String?, bool, bool)>{
    'r_vs_l': ('r', 'l', false, false),
    'r_only': ('r', null, false, false),
    'l_error': ('r', 'l', true, false),
    's_vs_th': ('s', 'θ', false, false),
    'k': ('k', null, false, false),
    'r_vs_y': ('r', 'y', false, false),
    'n': ('n', null, false, false),
    'front_r_vs_l': ('r', 'l', false, true),
    'front_l_error': ('r', 'l', true, true),
    'front_s_vs_th': ('s', 'θ', false, true),
    'front_sh_v': ('ş', 'v', false, true),
  };
  for (final e in cases.entries) {
    testWidgets('kareler ${e.key}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 680));
      final (c, err, showErr, front) = e.value;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Wrap(
              children: [
                for (final t in [0.1, 0.3, 0.43, 0.6])
                  SizedBox(
                    width: 450,
                    child: ArticulationStill(
                      correct: c,
                      error: err,
                      t: t,
                      labels: t == 0.43,
                      showError: showErr,
                      front: front,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(Wrap),
        matchesGoldenFile('goldens/art_${e.key}.png'),
      );
    });
  }
}
