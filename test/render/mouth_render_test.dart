// Animasyon karelerini PNG olarak üretir (görsel kontrol için).
// Çalıştırma: flutter test --update-goldens test/render
@Tags(['render'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelteklige_lanet/data/sounds.dart';
import 'package:pelteklige_lanet/widgets/mouth_animation.dart';

void main() {
  for (final id in ['R', 'S', 'Ş', 'L', 'K']) {
    testWidgets('ağız $id', (tester) async {
      final s = soundById(id);
      await tester.binding.setSurfaceSize(const Size(640, 480));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: MouthAnimation(
                    pose: s.pose,
                    airflow: s.airflow,
                    voiced: s.voiced,
                  ),
                ),
                if (s.errorPose != null)
                  Expanded(
                    child: MouthAnimation(
                      pose: s.errorPose!,
                      airflow: s.airflow,
                      voiced: s.voiced,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/mouth_${id == 'Ş' ? 'SH' : id}.png'),
      );
    });
  }
}
