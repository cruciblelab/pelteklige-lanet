import '../models/sound.dart';

/// Uygulama için yazılmış özgün kısa metinler. Her biri belirli seslerin sık
/// geçtiği cümlelerden oluşur. Seviye 1 kısa cümleler, seviye 3 uzun paragraflar.
const stories = <Story>[
  Story(
    id: 'ruzgar',
    title: 'Rüzgâr ve Kırmızı Uçurtma',
    focus: 'R',
    level: 1,
    paragraphs: [
      'Rüya bir sabah erkenden uyandı. Dışarıda rüzgâr esiyordu.',
      'Kardeşi Barış kırmızı uçurtmayı getirdi. İkisi birlikte bahçeye koştular.',
      'Rüzgâr uçurtmayı yukarı, bulutlara doğru taşıdı. Rüya ipi sıkıca tuttu.',
      'Akşam olunca uçurtmayı indirdiler. Yarın yine uçuracaklardı.',
    ],
  ),
  Story(
    id: 'sincap',
    title: 'Sincabın Sepeti',
    focus: 'S, Z',
    level: 1,
    paragraphs: [
      'Ormanda Sesi adında küçük bir sincap yaşardı. Sesi her sabah sepetini alırdı.',
      'Sepetine ceviz, fıstık ve susam topladı. Sonra yorgun düşüp bir süre dinlendi.',
      'Yaz bitince kış geldi. Her yer buz ve kar oldu.',
      'Sesi sepetini açtı ve arkadaşlarıyla paylaştı. Hepsi çok sevindi.',
    ],
  ),
  Story(
    id: 'kus',
    title: 'Şakacı Kuş',
    focus: 'Ş, Ç',
    level: 2,
    paragraphs: [
      'Şenay’ın penceresine her sabah şakacı bir kuş konardı. Kuş şarkı söyler, cama gagasıyla vururdu.',
      'Bir gün Şenay pencereye bir kase su ve biraz çekirdek koydu. Kuş çekirdekleri çok beğendi.',
      'Ertesi sabah kuş yanında üç küçük kuşla geldi. Şenay şaşırdı ve güldü.',
      'Artık pencerenin önü her sabah şarkılarla doluyordu.',
    ],
  ),
  Story(
    id: 'kedi',
    title: 'Kedi Kuki’nin Gece Gezisi',
    focus: 'K, G',
    level: 2,
    paragraphs: [
      'Kuki adında gri bir kedi vardı. Gündüzleri uyur, geceleri gezerdi.',
      'Bir gece kapı aralık kaldı. Kuki sessizce bahçeye çıktı ve gökyüzüne baktı.',
      'Ağacın üstünde bir kukumav kuşu gördü. Kuş “guk guk” diye öttü.',
      'Kuki korkmadı, kuyruğunu salladı ve kuşa göz kırptı. Sonra yatağına dönüp uyudu.',
    ],
  ),
  Story(
    id: 'lale',
    title: 'Lale’nin Limonları',
    focus: 'L',
    level: 2,
    paragraphs: [
      'Lale’nin bahçesinde küçük bir limon ağacı vardı. Lale onu her gün sulardı.',
      'Bir sabah dallarda sarı limonlar belirdi. Lale sevinçle hepsini saydı: on altı limon!',
      'Limonlardan limonata yaptı ve komşularına dağıttı.',
      'Komşular da ona bal, elma ve lokum getirdi. Bahçe bir şölen yerine döndü.',
    ],
  ),
  Story(
    id: 'fener',
    title: 'Deniz Feneri',
    focus: 'Karışık',
    level: 3,
    paragraphs: [
      'Küçük bir adanın ucunda eski bir deniz feneri vardı. Fenerde Rıza Dede adında yaşlı bir bekçi yaşardı. '
          'Her akşam güneş batınca merdivenleri tek tek çıkar, büyük lambayı yakardı.',
      'Bir gece fırtına çıktı. Dalgalar kayalara çarpıyor, rüzgâr pencereleri sarsıyordu. '
          'Uzakta küçük bir balıkçı teknesi yolunu kaybetmişti.',
      'Rıza Dede lambanın ışığını daha da parlattı. Teknedeki balıkçılar ışığı görünce rotalarını düzelttiler '
          've sabaha karşı limana sağ salim vardılar.',
      'Ertesi gün balıkçılar fenere bir sepet taze balık ve sıcak ekmek getirdiler. '
          'Rıza Dede gülümsedi: “Işık yanıyorsa kimse kaybolmaz,” dedi.',
    ],
  ),
];

Story storyById(String id) => stories.firstWhere((s) => s.id == id);
