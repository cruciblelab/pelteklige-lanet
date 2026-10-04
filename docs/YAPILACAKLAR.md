# Yapılacaklar / açık sorunlar

Son güncelleme: 2026-10-04

## 1. Konuşunca uygulama çöküyor — SEBEP BULUNDU, DÜZELTİLDİ (telefonda doğrulanacak)

**Ne oldu:** Mikrofon izni verildi, konuşuldu, uygulama kapandı
(POCO, Android 16, HyperOS 3).

**Log:**
```
JNI DETECTED ERROR IN APPLICATION: java_class == null
  in call to GetMethodID
  from boolean[] ai.onnxruntime.OrtSession.run(...)
  ... convertToTensorInfo ...
```

**Sebep:** Release derlemesinde Android'in kod küçültücüsü (R8), ONNX
Runtime'ın Java sınıflarını (`TensorInfo`, `OrtException`, `OnnxSequence`…)
kullanılmıyor sanıp sildi. Modelin yerel (C++) kodu bu sınıflara isimle
erişiyor. Sınıf bulunamayınca, model ilk kez çalıştırıldığında (yani
konuşma bitince) uygulama çöktü. Masaüstü testlerinde görünmedi, çünkü orada
ne Java ne de R8 var.

**Düzeltme:**
- [x] `android/app/proguard-rules.pro`: `ai.onnxruntime.**` korunuyor
- [x] APK'da sınıfların durduğu doğrulandı (önce `TensorInfo` ve
      `OrtException` yoktu, şimdi var)
- [x] CI'a koruma adımı eklendi: bu sınıflar APK'da yoksa derleme kırmızıya düşer
- [ ] **Telefonda doğrula:** yeni APK'yı kur, “Söyle, sesimi incele”ye bas,
      konuş. Çökmeden sonuç çıkıyor mu?

**Hâlâ yapılabilecekler (çökme devam ederse):**
- [ ] Uygulama içine hata günlüğü (Dart hataları dosyaya, Ayarlar'dan kopyalanabilir)
- [ ] Model yüklemeyi bellek dostu yap: 70 MB'lık asset şu an belleğe tamamen
      okunup geçici klasöre yazılıyor; düşük RAM'li telefonlarda sorun olabilir
- [ ] Yeni log: `adb logcat -d | grep -iE "flutter|onnx|AndroidRuntime|FATAL|DEBUG" > cokme.txt`

## 2. Ses analizini gerçek seste dene

Model şimdiye kadar yalnızca yetişkin sesi ve TTS ile ölçüldü. Çökme
çözülünce:

- [ ] İlk açılıştaki kısa testi yap (“Emin değilim, beni dinle”); önerdiği
      sesler doğru mu?
- [ ] R → “Hazırlık: D’den R’ye köprü”: “ada”dan “ara”ya geçerken R/D/Y/L
      yüzdeleri mantıklı değişiyor mu?
- [ ] “radyo”, “araba”, “kırmızı” kelimelerini “Söyle, sesimi incele” ile söyle
- [ ] Her biri için yaz: sonuç (doğru / hata / net değil ve yüzdesi) ve altındaki
      **“Duyulan sesler: /…/”** satırı
- [ ] Mümkünse aynı kelimeyi bir de bilerek doğru (ya da birine doğru
      söyleterek) dene. Karşılaştırma, eşikleri ayarlamak için gerekli.

## 3. Bilinen zayıf noktalar (ölçümle görüldü)

- [ ] **R yerine V/W** sentetik testte %23 kaçırılıyor. Gerçek seste ölç; gerekirse
      ayrı bir dudak/dil ipucu (ör. R'yi söylerken dudakları parmakla tutma) ekle.
- [ ] **R yutma** çoğunlukla “net değil” çıkıyor (%64). Kelime içinde R'nin
      süresine bakan ek bir ölçüt düşünülebilir.
- [ ] Çocuk sesi hiç ölçülmedi.

## Diğer (tek seferlik kurulum)

- [ ] **Kalıcı imza anahtarı:** README → “Kalıcı imza” bölümündeki 4 GitHub
      secret'ını ekle. Eklenmezse her yeni APK için eskisini silmek gerekir ve
      bu, telefondaki kayıtları da siler.
