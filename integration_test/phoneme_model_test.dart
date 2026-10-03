// Uçtan uca test: WAV → fbank → gerçek ONNX fonem modeli → puanlama.
// Model gerekir (tool/fetch_model.sh). Çalıştırma (Linux masaüstü):
//   flutter create --platforms linux .   (bir kez, linux/ klasörü git'e girmez)
//   xvfb-run flutter test integration_test -d linux
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pelteklige_lanet/audio/phoneme_model.dart';
import 'package:pelteklige_lanet/audio/pronunciation_scorer.dart';

Float32List readWav16k(String path) {
  final b = File(path).readAsBytesSync();
  final d = ByteData.sublistView(b);
  // Basit WAV okuyucu: "data" bloğunu bul.
  var o = 12;
  while (o < b.length - 8) {
    final id = String.fromCharCodes(b.sublist(o, o + 4));
    final len = d.getUint32(o + 4, Endian.little);
    if (id == 'data') {
      final n = len ~/ 2;
      return Float32List.fromList(
        List.generate(
          n,
          (i) => d.getInt16(o + 8 + i * 2, Endian.little) / 32768.0,
        ),
      );
    }
    o += 8 + len;
  }
  throw StateError('data yok');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const dir = 'integration_test/fixtures';

  testWidgets('model yüklenir ve R doğru/yanlış ayrılır', (tester) async {
    final m = PhonemeModel.instance;
    await m.load();

    Future<PronunciationResult> ev(String f, String word) =>
        m.evaluate(readWav16k('$dir/$f.wav'), word, 'R');

    final ok = await ev('radyo', 'radyo');
    // ignore: avoid_print
    print('radyo: ${ok.heardPhones} ${ok.checks.single.probs}');
    expect(ok.checks.single.verdict, Verdict.correct);

    final bad = await ev('yadyo', 'radyo');
    // ignore: avoid_print
    print('yadyo: ${bad.heardPhones} ${bad.checks.single.probs}');
    expect(bad.checks.single.verdict, Verdict.error);
    expect(bad.checks.single.topError.key, 'R yerine Y');

    final k1 = await ev('kirmizi', 'kırmızı');
    expect(k1.checks.single.verdict, Verdict.correct);
    final k2 = await ev('kilmizi', 'kırmızı');
    // ignore: avoid_print
    print('kılmızı: ${k2.heardPhones} ${k2.checks.single.probs}');
    expect(k2.checks.single.verdict, isNot(Verdict.correct));
  });

  testWidgets('minimal çift: kar / kay', (tester) async {
    final m = PhonemeModel.instance;
    final (p1, fit1) = await m.compare(readWav16k('$dir/kar.wav'), [
      'kar',
      'kay',
    ]);
    final (p2, _) = await m.compare(readWav16k('$dir/kay.wav'), ['kar', 'kay']);
    // ignore: avoid_print
    print('kar: $p1 fit=$fit1  kay: $p2');
    expect(p1['kar']!, greaterThan(0.8));
    expect(p2['kay']!, greaterThan(0.8));

    final (_, fitBad) = await m.compare(readWav16k('$dir/radyo.wav'), [
      'kalem',
      'kelam',
    ]);
    expect(fitBad, lessThan(PronunciationScorer.mismatchFit));
  });
}
