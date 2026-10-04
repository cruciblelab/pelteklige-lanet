# Ses analizi modeli: ne yapıyor, ne kadar güvenilir?

## Neden yeni bir model?

Telefonun hazır konuşma tanıyıcısı (Google) **kelime** bulmak için eğitilmiştir.
İçindeki dil modeli “ayaba” duyunca “araba” yazar. R’yi söyleyemeyen biri
“radyo” dediğinde de çoğu zaman “radyo” yazar. Sessizlikte bile bazen bir
şey “duyar”. Telaffuz değerlendirmek için yanlış araç.

## Kullanılan model

| | |
|---|---|
| Model | **ZIPA small CR-CTC** (500k adım), int8 ONNX |
| Kaynak | [anyspeech/zipa-small-crctc-500k](https://huggingface.co/anyspeech/zipa-small-crctc-500k) (revizyon `a97a19e`) |
| Makale | Zhu ve ark., *ZIPA: A family of efficient models for multilingual phone recognition*, ACL 2025 — [github.com/lingjzhu/zipa](https://github.com/lingjzhu/zipa) |
| Lisans | Ağırlıklar **CC BY 4.0**, kod MIT |
| Boyut | 70 MB (APK’ya gömülü, internet gerekmez) |
| Çıktı | Her 40 ms için 127 IPA sesinin olasılığı (`r`, `ɾ`, `j`, `l`, `ʁ`, `θ`, `ɬ`, `ʃ`…) |

Model **sesleri** tanır, kelimeleri değil, ve dil modeli içermez. Duyduğunu
“düzeltmez”.

## Nasıl karar veriyor?

Okunacak kelime bilindiği için, kelimenin doğru hâli bilinen hatalı hâlleriyle
yarıştırılır. Örneğin “radyo” için:

| Hipotez | Ses dizisi |
|---|---|
| Doğru | r-a-d-y-o |
| R yerine Y | y-a-d-y-o |
| R yerine L | l-a-d-y-o |
| R yerine D | d-a-d-y-o |
| R yerine V/W | v-a-d-y-o |
| Gırtlaktan R | ʁ-a-d-y-o |
| R yutuldu | a-d-y-o |

Her biri için CTC olasılığı hesaplanır. Kelimenin geri kalanı hepsinde aynı
olduğundan fark yalnızca hedef sesten gelir.

**Karar kuralı:**
- Hata: doğru < %3 *ve* en olası hata ≥ %50
- Doğru: doğru ≥ %30
- Arada kalırsa: **“net değil, tekrar dene”**

Beş kural gerçek ve sentetik veride karşılaştırıldı. “En olası hata ≥ %90”
kuralı hipotez sayısı arttıkça (olasılık hatalar arasında bölündüğü için)
gerçek hataları “net değil”e düşürüyordu. Seçilen kural yanlış alarmı
artırmadan yakalamayı belirgin şekilde yükseltti (R→Y %55 → %70,
R→D %82 → %95, L yanlış alarmı %2,3 → %0,8).

Bu kural bilerek temkinli tutuldu: haksız yere “yanlış” demek, bir hatayı
kaçırmaktan daha zararlı (motivasyonu kırar).

Ek korumalar:
- **Sessizlik:** Ses enerjisi 200 ms’lik konuşma eşiğini geçmezse analiz
  yapılmaz, “ses duymadım” denir.
- **Alakasız söz:** Söylenen, hedef metne hiç benzemiyorsa (ortalama uyum
  < −0,3) “benzemedi” denir.

## Ölçümler

> **Düzeltme (2026-10-04):** Bu belgenin ilk sürümündeki yanlış alarm
> oranları (R %1,1, L %0,8) 0,95 eşiğiyle ölçülmüştü; uygulama ise 0,90
> eşiğini kullanıyordu. Aşağıdaki sayılar uygulamanın şu an kullandığı
> kuralla (yukarıda) ve R için eklenen D ve V/W hipotezleriyle yeniden ölçüldü.

### 1) Gerçek insan sesinde yanlış alarm (en önemli sayı)

Google FLEURS Türkçe dev seti, 60 cümle, yetişkin anadil konuşucuları
(yani sesleri doğru söyleyen insanlar). Her hedef ses, cümle içinde
değerlendirildi.

| Ses | Örnek | “Doğru” | “Net değil” | **Yanlış alarm** |
|---|---|---|---|---|
| R | 277 | %95,7 | %2,9 | **%1,4** |
| L | 261 | %92,3 | %6,9 | **%0,8** |
| K | 177 | %97,7 | %1,1 | **%1,1** |
| S | 104 | %100 | 0 | **0** |
| Ş | 42 | %100 | 0 | **0** |

### 2) Hata yakalama (sentetik)

Gerçek konuşma bozukluğu kaydı elimizde olmadığı için hatalı söyleyişler
Piper Türkçe TTS ile üretildi (ör. “radyo” yerine “yadyo”, “dadyo”,
“vadyo”). 2 hızda, R için 22, S için 19, K için 16, L için 14, Ş için 12 kelime.

| Gerçek durum | “Hata var” dedi | “Net değil” | Kaçırdı (“doğru” dedi) |
|---|---|---|---|
| R yerine Y | %70 | %30 | **%0** |
| R yerine D | %95 | %5 | **%0** |
| R yerine L | %59 | %34 | %7 |
| R yerine V/W | %41 | %36 | **%23** (zayıf) |
| R yutuldu | %20 | %64 | %16 |
| S yerine Ş | %92 | %5 | %3 |
| S yerine T | %55 | %24 | %21 |
| Ş yerine S | %96 | %4 | 0 |
| K yerine T | %59 | %22 | %19 |
| L yerine Y | %89 | %7 | %4 |

Okuma: R yerine Y ve R yerine D söylendiğinde model bunları hiç “doğru”
saymıyor. R yerine V/W en zayıf nokta; TTS'in ürettiği “v” sesi R'ye yakın
çıkıyor olabilir, gerçek seste ayrıca ölçülmeli.

### 3) Uçtan uca (telefondaki Dart kodu)

`integration_test/phoneme_model_test.dart`, gerçek Dart özellik çıkarımı ve
gerçek ONNX modeliyle çalışır:

- radyo → Doğru %98
- yadyo → R yerine Y %89 (doğru %1,4 → “hata”)
- kar / kay ayrımı → %99,9 / %93

## Dürüst sınırlar

1. **Çocuk sesi ölçülmedi.** Ölçümler yetişkin sesiyle yapıldı. Model çok
   dilli ve geniş veriyle eğitildiği için çocuk sesinde de çalışması
   beklenir, ama bu ölçülmeden bilinemez.
2. **Gerçek bozuk konuşma ölçülmedi.** Hata yakalama sayıları TTS ile
   üretilmiş “temiz” hatalara dayanıyor. Gerçek R bozuklukları çoğu zaman
   ikisinin arasında bir ses olur; o durumda en olası sonuç “net değil”dir.
3. **Peltek S (θ) ve yanal S (ɬ)** model sözlüğünde var ve hipotez olarak
   eklendi, ama Türkçe TTS bu sesleri üretemediği için ölçülemedi.
4. **Tek kelimede gürültü daha etkili.** Cümle içinde bağlam daha fazla
   olduğu için sonuçlar daha kararlı.
5. Ç, C, Z, G, T, D için hata hipotezleri tanımlı ama ölçülmedi.

## Nasıl iyileşir?

- Gerçek kullanıcılardan (izinli) R/S sorunu olan kayıtlar toplanıp bir dil ve
  konuşma terapistine etiketletilirse eşikler ses bazında ayarlanabilir.
- Bu kayıtlarla modelin son katmanı Türkçe için ince ayarlanabilir
  (fine-tune). Bkz. [YOL_HARITASI.md](YOL_HARITASI.md).

Betikler: `tool/model_eval/`.
