# Yapılacaklar / açık sorunlar

Son güncelleme: 2026-10-03

## 1. Konuşunca uygulama çöküyor (ÖNCELİKLİ)

**Ne oldu:** Mikrofon izni verildi, konuşuldu, uygulama birden kapandı.

**Henüz bilinmeyenler (öğrenince buraya yaz):**
- [ ] Hangi APK? (Actions çalıştırma numarası: #1 eski sürüm / #3 ve sonrası ses modelli sürüm)
- [ ] Hangi ekran ve hangi düğme?
  - Alıştırma → “Söyle, sesimi incele” (yeni ses modeli)
  - Alıştırma → mikrofon (kendi kaydın)
  - Alıştırma/okuma → “Söyle, kontrol edeyim” (Google tanıyıcısı)
  - Benzer kelimeler → “Söyle”
  - Tıslama ölçer → “Başlat”
- [ ] Hemen mi çöktü, yoksa konuşma bitip “İnceliyorum…” yazısından sonra mı?
- [ ] Her seferinde mi oluyor?
- [ ] Telefon modeli ve Android sürümü, RAM (ör. 3 GB / 4 GB / 8 GB)

**Olası sebepler (kod incelemesine göre, doğrulanmadı):**
1. **Bellek:** Ses modeli (70 MB) ilk kullanımda belleğe tamamen okunup
   geçici klasöre yazılıyor (`flutter_onnxruntime` → `createSessionFromAsset`),
   ardından ONNX Runtime oturumu açılıyor. Kısa sürede ~200 MB'a çıkan bellek
   kullanımı, düşük RAM'li telefonlarda Android'in uygulamayı öldürmesine yol
   açabilir. Dışarıdan bu bir çökme gibi görünür.
   *Çözüm fikri:* Modeli asset'ten parça parça (stream) kalıcı bir klasöre bir
   kez kopyalamak ve oturumu dosya yolundan açmak.
2. **Yerel (native) çökme:** ONNX Runtime Android, kayıt eklentisi (`record`,
   16 kHz akış + `voiceRecognition` kaynağı) ya da Google tanıyıcısı. Bunlar
   Dart tarafında yakalanamaz.
3. **Mikrofon çakışması:** Aynı anda iki özelliğin mikrofonu açmaya çalışması.

**Yapılacak:**
- [ ] Uygulama içine hata günlüğü ekle (Dart hataları bir dosyaya yazılsın,
      Ayarlar'dan görülüp kopyalanabilsin), böylece çökme ayrıntısı gelsin
- [ ] Model yüklemeyi bellek dostu yap (yukarıdaki 1. madde)
- [ ] Mümkünse `adb logcat` çıktısı al (telefon bilgisayara bağlıyken):
      `adb logcat -d | grep -iE "flutter|onnx|record|AndroidRuntime|FATAL" > cokme.txt`

## 2. Ses analizini gerçek seste dene

Model şimdiye kadar yalnızca yetişkin sesi ve TTS ile ölçüldü. Çökme
çözülünce:

- [ ] “radyo”, “araba”, “kırmızı” kelimelerini “Söyle, sesimi incele” ile söyle
- [ ] Her biri için yaz: sonuç (doğru / hata / net değil ve yüzdesi) ve altındaki
      **“Duyulan sesler: /…/”** satırı
- [ ] Mümkünse aynı kelimeyi bir de bilerek doğru (ya da birine doğru
      söyleterek) dene. Karşılaştırma, eşikleri ayarlamak için gerekli.

## Diğer (tek seferlik kurulum)

- [ ] **Kalıcı imza anahtarı:** README → “Kalıcı imza” bölümündeki 4 GitHub
      secret'ını ekle. Eklenmezse her yeni APK için eskisini silmek gerekir ve
      bu, telefondaki kayıtları da siler.
