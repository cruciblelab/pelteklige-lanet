# Yol haritası: telefonda çalışan telaffuz modeli

## Sorun

Hazır konuşma tanıyıcılar (Google, Whisper vb.) **ne söylendiğini** bulmak için
eğitilir, **nasıl söylendiğini** değil. İçlerindeki dil modeli “ayaba” duyduğunda
“araba” yazmayı tercih eder. Bu, sıradan kullanıcı için iyi, bizim için kötü:
tam yakalamak istediğimiz hatayı gizliyor.

Gerçek çözüm, **sesleri (fonemleri) dil modeli olmadan** tanıyan bir model ve
okunacak metni bildiğimiz için her ses için bir **doğruluk puanı**
(GOP — Goodness of Pronunciation) hesaplamaktır.

## Seçenekler

| Seçenek | Boyut | Telefonda | Telaffuz tespiti | Not |
|---|---|---|---|---|
| Android SpeechRecognizer (bugün) | 0 (sistemde) | Var | Zayıf | Kelime atlama ve minimal çiftler için yeterli |
| Whisper tiny/base (sherpa-onnx ile) | ~40–150 MB | Orta | Zayıf | Güçlü dil modeli hataları düzeltir, bazen uydurur |
| Çok dilli fonem modeli (wav2vec2 XLSR espeak) | ~300 MB (int8) | Yalnızca güçlü telefonlar | Orta | Hazır, Türkçe doğruluğu orta |
| **Kendi Türkçe fonem modelimiz (CTC)** | **15–30 MB (int8)** | **Ucuz telefonlarda bile** | **İyi (hedef)** | Eğitim + veri gerekir |

## Önerilen plan

### Aşama 1 — Bu sürüm (tamamlandı)
- Android tanıyıcı + metin hizalama (yutulan kelime, harf farkı)
- Minimal çiftler
- FFT tabanlı tıslama ölçer
- Kayıt / dinleme / öz-değerlendirme

### Aşama 2 — Kendi fonem modelimiz
1. **Veri:** Common Voice Türkçe (açık lisans) + diğer açık Türkçe konuşma
   verileri. Metinler `espeak-ng` ya da kural tabanlı bir Türkçe
   harf→fonem dönüştürücüyle fonem dizisine çevrilir (Türkçe yazım sese çok
   yakın olduğu için bu kısım kolaydır).
2. **Model:** Küçük bir Conformer/Zipformer, CTC çıkışlı, ~20–30M parametre,
   yaklaşık 40 Türkçe fonem + boşluk. **Dil modeli yok.**
3. **Eğitim:** Tek bir GPU’da (ör. RTX 4090 / A100) birkaç yüz saat veriyle
   1–3 gün.
4. **Telefona taşıma:** ONNX’e çevir, int8 nicemle, Flutter’da
   [`sherpa_onnx`](https://pub.dev/packages/sherpa_onnx) paketiyle çalıştır
   (Android’de çevrimdışı, gerçek zamanlıdan hızlı).
5. **Puanlama:** Hedef metnin fonemleri bilindiği için zorunlu hizalama
   (forced alignment) + her fonem için GOP. Örnek çıktı: “*araba* kelimesinde
   2. ses: R bekleniyordu, %70 olasılıkla Y duyuldu.”
6. **Bonus:** Kendi modelimiz dosya da işleyebildiği için kitap okuma
   kayıtları okuma bittikten sonra analiz edilebilir. Bugünkü “aynı anda hem
   kayıt hem tanıma yok” sınırı kalkar.

### Aşama 3 — Doğrulama (atlanırsa her şey boşa gider)
- Yetişkin, sağlıklı konuşma verisiyle eğitilen model **çocuk sesinde ve
  bozuk konuşmada** daha kötü çalışır. Bunu ölçmeden “tespit ediyor” demek
  yanıltıcı olur.
- Gerekli: hedef kullanıcılardan (çocuklar, R/S sorunu olanlar), bir DKT’nin
  doğru/yanlış diye etiketlediği birkaç yüz kayıt. Bunlarla modelin
  yanlış alarm ve kaçırma oranları ölçülür, eşikler ayarlanır.
- **Gizlilik:** Çocuk sesi KVKK kapsamında hassas veridir. Açık rıza (çocuklar
  için veli izni), anonimleştirme ve verinin nerede tutulacağı baştan
  planlanmalı. Uygulama içinde “kaydımı araştırmaya bağışla” gibi bir seçenek
  ancak bunlar hazır olduğunda eklenmeli.

## Gerçekçi beklenti

- Aşama 2’nin teknik kısmı (veri hazırlama, eğitim, entegrasyon) tek kişi için
  birkaç haftalık iş.
- Modelin çocuklarda **ne kadar iyi** çalışacağı, Aşama 3’teki gerçek
  kayıtlarla ölçülene kadar bilinmez. En belirsiz ve en önemli kısım burası.
