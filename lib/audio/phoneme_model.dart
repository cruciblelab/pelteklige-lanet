import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'fbank.dart';
import 'pronunciation_scorer.dart';

/// Telefonda çalışan fonem (ses birimi) tanıma modeli.
///
/// Model: ZIPA small CR-CTC (Zhu ve ark., 2025), int8 ONNX, ~70 MB,
/// lisans CC BY 4.0. Çok dilli IPA sesleri tanır; dil modeli yoktur, yani
/// duyduğunu "düzeltmez". İnternet gerekmez, ses telefondan çıkmaz.
class PhonemeModel {
  PhonemeModel._();
  static final instance = PhonemeModel._();

  static const modelAsset = 'assets/models/zipa-small-crctc-500k.int8.onnx';
  static const tokensAsset = 'assets/models/tokens.txt';

  OrtSession? _session;
  List<String>? _tokens;
  PronunciationScorer? _scorer;
  Future<void>? _loading;
  final _fbank = Fbank();

  bool get isLoaded => _session != null;

  /// Model APK'ya eklenmiş mi? (Yerel geliştirmede tool/fetch_model.sh gerekir.)
  static Future<bool> isBundled() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets().contains(modelAsset);
    } catch (_) {
      return false;
    }
  }

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final tokens = await rootBundle.loadString(tokensAsset);
      _scorer = PronunciationScorer.fromTokensFile(tokens);
      _tokens = _scorer!.tokens;
      _session = await OnnxRuntime().createSessionFromAsset(
        modelAsset,
        options: OrtSessionOptions(intraOpNumThreads: 2),
      );
    } catch (e) {
      _loading = null;
      rethrow;
    }
  }

  /// 16 kHz mono örnekler → (log-olasılıklar [kare × sözlük], kare sayısı).
  Future<(Float32List, int)> logProbs(Float32List samples) async {
    await load();
    final feats = _fbank.compute(samples);
    final frames = feats.length ~/ Fbank.numBins;
    final x = await OrtValue.fromList(feats, [1, frames, Fbank.numBins]);
    final xLens = await OrtValue.fromList(Int64List.fromList([frames]), [1]);
    try {
      final out = await _session!.run({'x': x, 'x_lens': xLens});
      final lpVal = out['log_probs']!;
      final lenVal = out['log_probs_len']!;
      final flat = await lpVal.asFlattenedList();
      final len = ((await lenVal.asFlattenedList()).first as num).toInt();
      await lpVal.dispose();
      await lenVal.dispose();
      final lp = Float32List(flat.length);
      for (var i = 0; i < flat.length; i++) {
        lp[i] = (flat[i] as num).toDouble();
      }
      return (lp, len);
    } finally {
      await x.dispose();
      await xLens.dispose();
    }
  }

  /// Söyleyişi değerlendirir. Ağır CTC hesabı ayrı bir isolate'te yapılır.
  Future<PronunciationResult> evaluate(
    Float32List samples,
    String text,
    String targetLetter,
  ) async {
    final (lp, frames) = await logProbs(samples);
    final tokens = _tokens!;
    return Isolate.run(
      () =>
          PronunciationScorer(tokens).evaluate(lp, frames, text, targetLetter),
    );
  }

  /// Birkaç aday kelimeden hangisinin söylendiğini olasılıkla verir;
  /// ikinci değer uyum puanı (bkz. [PronunciationScorer.mismatchFit]).
  Future<(Map<String, double>, double)> compare(
    Float32List samples,
    List<String> candidates,
  ) async {
    final (lp, frames) = await logProbs(samples);
    final tokens = _tokens!;
    return Isolate.run(
      () => PronunciationScorer(tokens).compareWords(lp, frames, candidates),
    );
  }
}
