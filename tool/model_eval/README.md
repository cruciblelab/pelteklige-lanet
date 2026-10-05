# Fonem modeli değerlendirmesi (Python prototipi)

Uygulamadaki Dart kodunun (`lib/audio/fbank.dart`, `lib/audio/pronunciation_scorer.dart`)
Python karşılığı ve ölçüm betikleri. Sonuçlar: `docs/MODEL_DEGERLENDIRME.md`.

```bash
pip install onnxruntime kaldi-native-fbank numpy soundfile librosa piper-tts
../fetch_model.sh                       # modeli indir
# Piper Türkçe sesi (sentetik test seti için)
curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/tr/tr_TR/dfki/medium/tr_TR-dfki-medium.onnx
curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/tr/tr_TR/dfki/medium/tr_TR-dfki-medium.onnx.json
python3 evalset.py      # sentetik doğru/hatalı söyleyişler → results.json
python3 reeval.py       # eşiklere göre karışıklık tabloları
# Gerçek insan sesi (yanlış alarm oranı): FLEURS tr_tr dev seti ../fleurs/ altına
python3 fleurs_eval.py 60
```

- `feat.py`  : kaldi-native-fbank ile özellik + ONNX çıkarımı + açgözlü çözme
- `score.py` : Türkçe ses sınıfları, CTC hipotez yarıştırma (doğru vs. bilinen hatalar)
