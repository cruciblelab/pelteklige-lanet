import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'articulation_motion.dart';
import 'articulations.dart';

/// Başın ortadan (orta sagital düzlemde) kesilmiş yan görünümü.
///
/// Katmanlar: omurlar, kafa tabanı, burun boşluğu ve kıvrımları, sert damak
/// kemiği ve damak kıvrımları, yumuşak damak ve küçük dil, kökleriyle
/// kesici dişler ve diş etleri, çene kemiği (simfiz), dil kemiği, gırtlak
/// kapağı ve ses telleri, dudaklar (kırmızı kısım, deri, halka kas) ve
/// dil (kas lifleri, sırt tümsekleri, alt yüzündeki bağ).
///
/// Koordinatlar 400×300 tasarım alanındadır; yüz sağa bakar. Dilin konumları
/// [TonguePose] ile aynı alanda tanımlıdır.
class ArticulationPainter extends CustomPainter {
  final double t;
  final Articulation main;
  final Articulation? ghost;
  final bool mainIsError;
  final bool labels;

  ArticulationPainter({
    required this.t,
    required this.main,
    required this.ghost,
    required this.mainIsError,
    required this.labels,
  });

  // Renkler
  static const _airA = Color(0xFFEFF7FF);
  static const _airB = Color(0xFFD9ECFB);
  static const _tissueA = Color(0xFFF3CDB9);
  static const _tissueB = Color(0xFFE9B49F);
  static const _skinLine = Color(0xFFB07862);
  static const _bone = Color(0xFFF5EAD6);
  static const _boneLine = Color(0xFFC9AE86);
  static const _boneDot = Color(0xFFE2CFAD);
  static const _cartilage = Color(0xFFDDE7EE);
  static const _cartilageLine = Color(0xFF9CB0BF);
  static const _disc = Color(0xFFCFDCE6);
  static const _cavityA = Color(0xFF6E2434);
  static const _cavityB = Color(0xFF3A0F1A);
  static const _nasalA = Color(0xFF5A1D2B);
  static const _nasalB = Color(0xFF2E0A13);
  static const _mucosa = Color(0xFFE59AA5);
  static const _mucosaDark = Color(0xFFC86F7E);
  static const _gum = Color(0xFFEE9FAA);
  static const _muscle = Color(0xFFC25467);
  static const _vermilionA = Color(0xFFE4838A);
  static const _vermilionB = Color(0xFFB64D5A);
  static const _enamelA = Color(0xFFFFFFFF);
  static const _enamelB = Color(0xFFE8E1D3);
  static const _dentin = Color(0xFFF0DFC0);
  static const _tongueTop = Color(0xFFF08A9C);
  static const _tongueBottom = Color(0xFFBF4560);
  static const _flow = Color(0xFF7FD3FF);
  static const good = Color(0xFF14A38B);
  static const bad = Color(0xFFD84343);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 400, size.height / 300);
    canvas.save();
    canvas.translate((size.width - 400 * s) / 2, (size.height - 300 * s) / 2);
    canvas.scale(s);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 400, 300));

    final f = frameAt(main, t);
    final pose = f.pose;
    final g = ghost == null ? null : frameAt(ghost!, t);
    // Çene kayması; hayalet varsa ikisinin de görünmesi için daha açık olanı.
    final jaw = g == null ? pose.jaw : math.max(pose.jaw, g.pose.jaw);
    final dy = (jaw - 0.25) * 30;
    final nasal = main.air == Air.nasal;

    _background(canvas);
    _head(canvas, dy);
    _spine(canvas);
    _skullBase(canvas);
    _nasalCavity(canvas);
    _maxilla(canvas);
    _mandible(canvas, dy);
    _larynx(canvas);

    final cavity = _cavityPath(dy, pose);
    canvas.drawPath(
      cavity,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.25, -0.2),
          radius: 0.95,
          colors: [_cavityA, _cavityB],
        ).createShader(const Rect.fromLTWH(100, 70, 270, 230)),
    );

    if (nasal && f.air > 0) _nasalFlow(canvas, f.air);

    canvas.save();
    canvas.clipPath(cavity);
    _mouthFloor(canvas, dy);
    if (g != null) _tongue(canvas, g.pose, dy, ghost: true);
    _tongue(canvas, pose, dy);
    canvas.restore();

    _epiglottis(canvas);
    _velum(canvas, lowered: nasal ? 1 : 0);
    _palateSurface(canvas);
    _upperIncisor(canvas);
    _lowerIncisor(canvas, dy);
    _lips(canvas, dy, pose);

    _contact(canvas, f);
    if (f.pressure) _pressure(canvas, pose);
    if (f.air > 0.02 && !nasal) {
      _flowParticles(canvas, pose, dy, f.air, f.burst);
    }
    final voicedNow = main.voiced && (f.air > 0.1 || f.pressure);
    _vocalFolds(canvas, voicedNow);
    if (main.name.startsWith('Gırtlaktan') && f.air > 0.1) _uvulaBuzz(canvas);

    if (labels) _labels(canvas, pose, voicedNow);
    canvas.restore();
  }

  // --- Arka plan ve baş ------------------------------------------------------

  void _background(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 400, 300),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_airA, _airB],
        ).createShader(const Rect.fromLTWH(0, 0, 400, 300)),
    );
  }

  /// Yüz profili: alın, burun, dudak üstü, çene, boyun.
  Path _profile(double dy) => Path()
    ..moveTo(0, 0)
    ..lineTo(332, 0)
    ..cubicTo(336, 10, 340, 18, 346, 24) // burun kökü
    ..cubicTo(358, 38, 380, 50, 391, 61) // burun sırtı
    ..cubicTo(399, 69, 396, 81, 385, 84) // burun ucu
    ..cubicTo(374, 87, 360, 87, 350, 92) // burun altı
    ..lineTo(345, 100)
    ..lineTo(343, 140)
    ..lineTo(341, 180 + dy)
    ..cubicTo(350, 188 + dy, 360, 204 + dy, 355, 220 + dy) // çene ucu
    ..cubicTo(350, 234 + dy, 334, 241 + dy, 314, 243 + dy) // çene altı
    ..cubicTo(290, 246 + dy, 262, 250, 250, 262)
    ..cubicTo(242, 272, 236, 288, 234, 300) // boyun
    ..lineTo(0, 300)
    ..close();

  void _head(Canvas canvas, double dy) {
    final face = _profile(dy);
    canvas.drawPath(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_tissueB, _tissueA],
        ).createShader(const Rect.fromLTWH(0, 0, 400, 300)),
    );
    // Deri katmanı: dışta ince, açık bir bant.
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFFF8DCCB),
    );
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = _skinLine.withValues(alpha: 0.75),
    );
    // Burun deliği kenarı (burun kanadı)
    canvas.drawPath(
      Path()
        ..moveTo(370, 80)
        ..cubicTo(362, 74, 352, 76, 352, 84),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _skinLine.withValues(alpha: 0.45),
    );
  }

  Paint _boneFill(Rect r) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFBF3E4), _bone],
    ).createShader(r);

  final _boneStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = _boneLine;

  /// Süngerimsi kemik dokusu için seyrek noktalar.
  void _trabecular(Canvas canvas, Path clip, Rect area, int seed) {
    canvas.save();
    canvas.clipPath(clip);
    final p = Paint()..color = _boneDot;
    final rnd = math.Random(seed);
    final n = (area.width * area.height / 45).round();
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
        Offset(
          area.left + rnd.nextDouble() * area.width,
          area.top + rnd.nextDouble() * area.height,
        ),
        0.5 + rnd.nextDouble() * 0.9,
        p,
      );
    }
    canvas.restore();
  }

  /// Boyun omurları (C1–C5) ve aralarındaki diskler, arkada omurilik.
  void _spine(Canvas canvas) {
    // Omurilik kanalı
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 70, 24, 240),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFE6B8A6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 70, 12, 240),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFF7EFE0),
    );
    final bodies = [
      const Rect.fromLTWH(60, 106, 38, 58), // C2 (dens yukarıda)
      const Rect.fromLTWH(60, 172, 38, 40),
      const Rect.fromLTWH(60, 220, 38, 40),
      const Rect.fromLTWH(60, 268, 38, 40),
    ];
    for (var i = 0; i < bodies.length - 1; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(62, bodies[i].bottom - 1, 96, bodies[i + 1].top + 1),
          const Radius.circular(3),
        ),
        Paint()..color = _disc,
      );
    }
    // C1 ön kemeri ve C2 dişi (dens)
    final c1 = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(92, 96), width: 14, height: 12),
      );
    final dens = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(68, 80, 18, 34),
          const Radius.circular(8),
        ),
      );
    for (final b in [c1, dens]) {
      canvas.drawPath(b, _boneFill(b.getBounds()));
      canvas.drawPath(b, _boneStroke);
    }
    for (var i = 0; i < bodies.length; i++) {
      final b = Path()
        ..addRRect(
          RRect.fromRectAndRadius(bodies[i], const Radius.circular(6)),
        );
      canvas.drawPath(b, _boneFill(bodies[i]));
      _trabecular(canvas, b, bodies[i], 11 + i);
      canvas.drawPath(b, _boneStroke);
    }
  }

  /// Kafa tabanı: burun boşluğunun üstündeki kemik bant.
  void _skullBase(Canvas canvas) {
    final p = Path()
      ..moveTo(0, 40)
      ..cubicTo(40, 48, 80, 58, 104, 64)
      ..cubicTo(112, 52, 132, 34, 158, 30)
      ..cubicTo(204, 22, 272, 22, 316, 32)
      ..cubicTo(328, 30, 336, 22, 340, 16) // burun kemiği
      ..lineTo(346, 24)
      ..cubicTo(340, 30, 330, 40, 318, 40)
      ..cubicTo(270, 30, 204, 30, 158, 38)
      ..cubicTo(136, 42, 118, 56, 110, 72)
      ..cubicTo(80, 66, 40, 58, 0, 52)
      ..close();
    canvas.drawPath(p, _boneFill(p.getBounds()));
    canvas.drawPath(p, _boneStroke);
  }

  void _nasalCavity(Canvas canvas) {
    final nasal = Path()
      ..moveTo(112, 104)
      ..lineTo(112, 74)
      ..cubicTo(120, 58, 136, 44, 158, 40)
      ..cubicTo(204, 32, 270, 32, 316, 42)
      ..cubicTo(336, 48, 352, 62, 362, 76) // burun girişi
      ..cubicTo(366, 81, 368, 87, 368, 92) // burun deliği
      ..lineTo(360, 92)
      ..cubicTo(356, 86, 344, 84, 330, 84) // burun tabanı
      ..cubicTo(306, 80, 272, 74, 232, 68)
      ..cubicTo(210, 66, 192, 68, 182, 72)
      ..cubicTo(160, 78, 132, 88, 112, 104)
      ..close();
    canvas.drawPath(
      nasal,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_nasalB, _nasalA],
        ).createShader(nasal.getBounds()),
    );
    // Burun kıvrımları (konkalar)
    canvas.save();
    canvas.clipPath(nasal);
    final concha = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD98A98), Color(0xFFA9505F)],
      ).createShader(const Rect.fromLTWH(150, 36, 200, 40));
    for (final (y, x0, x1, h) in [
      (44.0, 196.0, 292.0, 6.0),
      (54.0, 176.0, 312.0, 8.0),
      (64.0, 168.0, 300.0, 7.0),
    ]) {
      final c = Path()
        ..moveTo(x1, y - 2)
        ..cubicTo(x1 - 30, y - 6, x0 + 30, y - 6, x0, y + h * 0.4)
        ..cubicTo(x0 + 6, y + h, x0 + 40, y + h, x0 + 70, y + h * 0.6)
        ..cubicTo(x1 - 40, y + h * 0.3, x1 - 10, y + 2, x1, y - 2)
        ..close();
      canvas.drawPath(c, concha);
    }
    canvas.restore();
    canvas.drawPath(
      nasal,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF8E3A4A).withValues(alpha: 0.6),
    );
  }

  /// Üst çene: sert damak kemiği ve kesici dişi tutan kemik çıkıntı.
  void _maxilla(Canvas canvas) {
    final bone = Path()..moveTo(182, 84);
    openSpline(bone, const [
      Offset(182, 84),
      Offset(232, 77),
      Offset(272, 85),
      Offset(292, 98),
      Offset(302, 104),
    ]);
    bone
      ..lineTo(312, 104)
      ..cubicTo(318, 98, 326, 98, 332, 100) // dişin önünde kemik ucu
      ..lineTo(338, 88) // ön burun dikeni
      ..cubicTo(334, 86, 330, 85, 326, 85)
      ..cubicTo(306, 81, 272, 75, 232, 69)
      ..cubicTo(210, 67, 192, 69, 182, 73)
      ..close();
    canvas.drawPath(bone, _boneFill(bone.getBounds()));
    _trabecular(canvas, bone, bone.getBounds(), 3);
    canvas.drawPath(bone, _boneStroke);
  }

  /// Alt çene kemiğinin ortadan kesiti (simfiz) ve dil kemiği.
  void _mandible(Canvas canvas, double dy) {
    final m = Path()
      ..moveTo(318, 182 + dy)
      ..cubicTo(308, 194 + dy, 304, 208 + dy, 306, 220 + dy)
      ..cubicTo(306, 232 + dy, 316, 239 + dy, 330, 238 + dy)
      ..cubicTo(342, 236 + dy, 348, 224 + dy, 347, 208 + dy)
      ..cubicTo(346, 196 + dy, 342, 186 + dy, 336, 178 + dy)
      ..lineTo(326, 176 + dy)
      ..close();
    canvas.drawPath(m, _boneFill(m.getBounds()));
    _trabecular(canvas, m, m.getBounds(), 7);
    canvas.drawPath(
      m,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _boneLine,
    );
    // Çene altı kasları: çeneden dil kemiğine uzanan bant
    final band = Path()
      ..moveTo(308, 222 + dy)
      ..cubicTo(280, 228 + dy * 0.6, 236, 240, 206, 252)
      ..lineTo(204, 260)
      ..cubicTo(236, 250, 282, 240 + dy * 0.6, 312, 232 + dy)
      ..close();
    canvas.drawPath(band, Paint()..color = _muscle.withValues(alpha: 0.55));
    _fibers(canvas, band, const Offset(308, 226), const Offset(204, 256), 4);
    // Dil kemiği (hyoid)
    final hyoid = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: const Offset(196, 258),
            width: 22,
            height: 10,
          ),
          const Radius.circular(5),
        ),
      );
    canvas.drawPath(hyoid, _boneFill(hyoid.getBounds()));
    canvas.drawPath(hyoid, _boneStroke);
  }

  void _fibers(Canvas canvas, Path clip, Offset a, Offset b, int n) {
    canvas.save();
    canvas.clipPath(clip);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF8F2E42).withValues(alpha: 0.35);
    for (var i = -n; i <= n; i++) {
      canvas.drawLine(a + Offset(0, i * 2.2), b + Offset(0, i * 2.2), p);
    }
    canvas.restore();
  }

  /// Gırtlak: kalkan kıkırdak ve soluk borusu girişi.
  void _larynx(Canvas canvas) {
    final thyroid = Path()
      ..moveTo(150, 262)
      ..cubicTo(158, 258, 168, 258, 174, 264)
      ..lineTo(176, 300)
      ..lineTo(148, 300)
      ..cubicTo(146, 286, 146, 272, 150, 262)
      ..close();
    canvas.drawPath(thyroid, Paint()..color = _cartilage);
    canvas.drawPath(
      thyroid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _cartilageLine,
    );
  }

  // --- Ağız boşluğu ----------------------------------------------------------

  Path _cavityPath(double dy, TonguePose pose) {
    final r = pose.lipRound * 9;
    final lt = pose.lipToTeeth;
    final p = Path()..moveTo(112, 300);
    p.lineTo(112, 98);
    openSpline(p, const [
      Offset(112, 98),
      Offset(140, 88),
      Offset(182, 84),
      Offset(232, 78),
      Offset(272, 86),
      Offset(292, 99),
      Offset(303, 106),
      Offset(311, 116),
    ]);
    p.lineTo(331, 143); // üst kesici diş ucu
    p.lineTo(350 + r, 138); // dudak arası (üst)
    p.lineTo(350 + r, 142 + dy - lt * 8);
    p.lineTo(332, 148 + dy); // alt kesici diş ucu
    p.lineTo(320, 180 + dy);
    openSpline(p, [
      Offset(320, 180 + dy),
      Offset(262, 206 + dy * 0.8),
      Offset(200, 224 + dy * 0.5),
      Offset(158, 248),
      Offset(146, 260),
      Offset(140, 276),
      Offset(138, 300),
    ]);
    return p..close();
  }

  /// Dilin altındaki ağız tabanı mukozası.
  void _mouthFloor(Canvas canvas, double dy) {
    final floor = Path()..moveTo(320, 180 + dy);
    openSpline(floor, [
      Offset(320, 180 + dy),
      Offset(262, 206 + dy * 0.8),
      Offset(200, 224 + dy * 0.5),
    ]);
    canvas.drawPath(
      floor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = _mucosaDark,
    );
  }

  List<Offset> _tonguePoints(TonguePose p, double dy) => [
    const Offset(134, 266),
    p.back,
    p.dorsum,
    p.blade,
    p.tip,
    p.under,
    Offset(p.under.dx - 42, math.max(p.under.dy + 24, 194 + dy * 0.85)),
    Offset(205, 220 + dy * 0.6),
    const Offset(160, 250),
  ];

  void _tongue(Canvas canvas, TonguePose p, double dy, {bool ghost = false}) {
    final path = closedSpline(_tonguePoints(p, dy));
    if (ghost) {
      final color = mainIsError ? good : bad;
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.18));
      _dashed(canvas, path, color, 2.5);
      return;
    }
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: mainIsError
              ? const [Color(0xFFF59A9A), Color(0xFFBF4040)]
              : const [_tongueTop, _tongueBottom],
        ).createShader(const Rect.fromLTWH(120, 90, 230, 190)),
    );

    canvas.save();
    canvas.clipPath(path);
    // Kas lifleri: çenenin arkasından dil sırtına yelpaze gibi açılır
    // (genioglossus).
    final origin = Offset(304, 214 + dy);
    final fiber = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF8E2A40).withValues(alpha: 0.16);
    final ridge = [p.back, p.dorsum, p.blade, p.tip];
    for (var i = 0; i < 14; i++) {
      final u = i / 13 * 3;
      final k = math.min(u.floor(), 2);
      final target = Offset.lerp(ridge[k], ridge[k + 1], u - k)!;
      final ctrl = Offset.lerp(origin, target, 0.5)! + const Offset(-10, 6);
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, target.dx, target.dy),
        fiber,
      );
    }
    // Enine lifler (dilin içindeki yatay kas)
    for (var i = 0; i < 4; i++) {
      final a =
          Offset.lerp(p.back, p.dorsum, 0.4 + i * 0.15)! +
          Offset(0, 10.0 + i * 4);
      final b =
          Offset.lerp(p.dorsum, p.blade, 0.2 + i * 0.2)! +
          Offset(0, 10.0 + i * 3);
      canvas.drawLine(a, b, fiber);
    }
    // Alt yüz: daha koyu ve damarlı (dil ucu kalkınca görünür)
    final underShade = Path()
      ..addOval(Rect.fromCenter(center: p.under, width: 46, height: 26));
    canvas.drawPath(
      underShade,
      Paint()
        ..color = const Color(0xFF9E2E48).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.restore();

    // Sırt tümsekleri (papillalar)
    final pap = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i < 26; i++) {
      final u = 0.1 + i / 25 * 2.75;
      final k = math.min(u.floor(), 2);
      final pt = Offset.lerp(ridge[k], ridge[k + 1], u - k)!;
      canvas.drawCircle(pt + Offset(0, 3.5 + (i % 2) * 1.6), 0.9, pap);
    }
    // Orta çizgi parlaklığı
    final hl = Path()..moveTo(p.back.dx + 6, p.back.dy + 8);
    openSpline(hl, [
      Offset(p.back.dx + 6, p.back.dy + 8),
      p.dorsum + const Offset(0, 6),
      p.blade + const Offset(0, 5),
      p.tip + const Offset(-6, 5),
    ]);
    canvas.drawPath(
      hl,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF8E2A40).withValues(alpha: 0.65),
    );
    // Dil altı bağı (frenulum)
    final fr = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF4B3BE).withValues(alpha: 0.8);
    final floorY = 196 + dy * 0.85;
    if (floorY - p.under.dy > 6 && floorY - p.under.dy < 34) {
      canvas.drawLine(
        p.under + const Offset(-8, 2),
        Offset(p.under.dx - 18, floorY),
        fr,
      );
    }
  }

  void _dashed(Canvas canvas, Path path, Color color, double width) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 7, m.length)), paint);
        d += 12;
      }
    }
  }

  void _epiglottis(Canvas canvas) {
    final e = Path()
      ..moveTo(141, 274)
      ..cubicTo(134, 264, 124, 252, 123, 238)
      ..cubicTo(124, 234, 129, 235, 131, 240)
      ..cubicTo(134, 252, 141, 262, 147, 268)
      ..close();
    canvas.drawPath(e, Paint()..color = const Color(0xFFEBB0B6));
    canvas.drawPath(
      e,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF9A5260),
    );
  }

  /// Ses telleri; titrerken hafifçe sallanır.
  void _vocalFolds(Canvas canvas, bool vibrating) {
    final w = vibrating ? math.sin(t * math.pi * 60) * 1.6 : 0.0;
    final fold = Path()
      ..moveTo(139, 282)
      ..cubicTo(132, 284, 126, 286 + w, 120, 289 + w)
      ..cubicTo(126, 291 + w, 133, 292, 139, 294)
      ..close();
    canvas.drawPath(fold, Paint()..color = const Color(0xFFF2C2C8));
    canvas.drawPath(
      fold,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF9A5260),
    );
    if (!vibrating) return;
    const c = Offset(126, 289);
    final pulse = (t * 14) % 1.0;
    for (var k = 0; k < 3; k++) {
      final r = 6.0 + 8 * ((pulse + k / 3) % 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi * 0.85,
        math.pi * 0.7,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFC107)
              .withValues(alpha: 1 - ((pulse + k / 3) % 1.0)),
      );
    }
  }

  /// Yumuşak damak ve küçük dil. [lowered] 1 iken iner, burun yolu açılır.
  void _velum(Canvas canvas, {required double lowered}) {
    // Kalkık (konuşma) ve inik (N, M: burun yolu açık) hâllerin noktaları.
    Offset l(double ax, double ay, double bx, double by) =>
        Offset(ax + (bx - ax) * lowered, ay + (by - ay) * lowered);
    final pts = [
      l(168, 72, 166, 77), // burun yüzü: konuşurken yukarı kalkar
      l(144, 71, 146, 86),
      l(125, 79, 132, 98),
      l(114, 89, 126, 104), // arka duvara dayanan diz
      l(112, 96, 126, 110),
      l(116, 101, 130, 114),
      l(122, 106, 136, 118), // arka yüz
      l(132, 108, 142, 124),
      l(138, 112, 146, 128),
      l(142, 118, 148, 134), // küçük dil
      l(144, 126, 149, 141),
      l(149, 130, 152, 144),
      l(153, 132, 155, 146), // küçük dil ucu
      l(156, 128, 158, 142),
      l(155, 122, 157, 136),
      l(154, 114, 157, 126), // ağız yüzü
      l(156, 106, 162, 114),
      l(162, 100, 168, 104),
      l(170, 93, 174, 96),
      l(178, 88, 180, 90),
    ];
    final v = Path()
      ..moveTo(188, 74)
      ..cubicTo(
        pts[0].dx,
        pts[0].dy,
        pts[1].dx,
        pts[1].dy,
        pts[2].dx,
        pts[2].dy,
      )
      ..cubicTo(
        pts[3].dx,
        pts[3].dy,
        pts[4].dx,
        pts[4].dy,
        pts[5].dx,
        pts[5].dy,
      )
      ..cubicTo(
        pts[6].dx,
        pts[6].dy,
        pts[7].dx,
        pts[7].dy,
        pts[8].dx,
        pts[8].dy,
      )
      ..cubicTo(
        pts[9].dx,
        pts[9].dy,
        pts[10].dx,
        pts[10].dy,
        pts[11].dx,
        pts[11].dy,
      )
      ..cubicTo(
        pts[12].dx,
        pts[12].dy,
        pts[13].dx,
        pts[13].dy,
        pts[14].dx,
        pts[14].dy,
      )
      ..cubicTo(
        pts[15].dx,
        pts[15].dy,
        pts[16].dx,
        pts[16].dy,
        pts[17].dx,
        pts[17].dy,
      )
      ..cubicTo(pts[18].dx, pts[18].dy, pts[19].dx, pts[19].dy, 188, 86)
      ..close();
    canvas.drawPath(
      v,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD27A89), Color(0xFFE99AA6)],
        ).createShader(const Rect.fromLTWH(110, 74, 76, 74)),
    );
    // İçindeki kas
    canvas.save();
    canvas.clipPath(v);
    canvas.drawPath(
      Path()
        ..moveTo(184, 81)
        ..cubicTo(
          160,
          82,
          l(136, 90, 142, 100).dx,
          l(136, 90, 142, 100).dy,
          l(122, 96, 134, 108).dx,
          l(122, 96, 134, 108).dy,
        ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _muscle.withValues(alpha: 0.45),
    );
    canvas.restore();
    final outline = Path();
    for (final metric in v.computeMetrics()) {
      // Kapanış kenarı kemiğe yapışık: çizgisi çizilmez.
      outline.addPath(metric.extractPath(0, metric.length - 11), Offset.zero);
    }
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF9A5260).withValues(alpha: 0.8),
    );
  }

  /// Damağın ağız tarafı: mukoza, damak kıvrımları ve diş eti çıkıntısı.
  void _palateSurface(Canvas canvas) {
    final roof = Path()..moveTo(182, 85);
    openSpline(roof, const [
      Offset(182, 85),
      Offset(232, 79),
      Offset(272, 87),
      Offset(292, 100),
      Offset(303, 107),
      Offset(311, 116),
    ]);
    canvas.drawPath(
      roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..color = _mucosa,
    );
    // Damak kıvrımları (rugae)
    final rug = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF7C4CC);
    for (final x in [262.0, 272.0, 281.0]) {
      final y = 82 + (x - 262) * 0.75;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, y + 4), width: 8, height: 6),
        math.pi * 0.1,
        math.pi * 0.8,
        false,
        rug,
      );
    }
    // Diş eti (alveol) çıkıntısı: dilin dokunduğu yer
    final gum = Path()
      ..moveTo(288, 96)
      ..cubicTo(298, 98, 306, 102, 312, 106)
      ..lineTo(314, 114)
      ..cubicTo(308, 112, 300, 108, 292, 102)
      ..close();
    canvas.drawPath(gum, Paint()..color = _gum);
  }

  void _upperIncisor(Canvas canvas) {
    final root = Path()
      ..moveTo(313, 111)
      ..cubicTo(307, 102, 306, 90, 312, 84)
      ..cubicTo(318, 82, 326, 94, 328, 106)
      ..close();
    canvas.drawPath(root, Paint()..color = _dentin);
    canvas.drawPath(
      root,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = _boneLine,
    );
    // Kök kanalı
    canvas.drawLine(
      const Offset(319, 107),
      const Offset(314, 88),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0xFFE5A9A9),
    );
    final crown = Path()
      ..moveTo(312, 109)
      ..cubicTo(318, 104, 324, 103, 329, 105)
      ..cubicTo(335, 112, 339, 126, 336, 140) // ön yüz
      ..cubicTo(335, 144, 331, 145, 329, 143) // kesici kenar
      ..cubicTo(324, 134, 318, 126, 315, 120) // arka yüz
      ..cubicTo(313, 117, 311, 113, 312, 109) // boyun çıkıntısı
      ..close();
    _enamel(canvas, crown);
    // Ön diş eti
    final labialGum = Path()
      ..moveTo(328, 100)
      ..cubicTo(332, 100, 336, 102, 337, 106)
      ..lineTo(333, 112)
      ..cubicTo(331, 108, 330, 106, 328, 104)
      ..close();
    canvas.drawPath(labialGum, Paint()..color = _gum);
  }

  void _lowerIncisor(Canvas canvas, double dy) {
    final root = Path()
      ..moveTo(321, 175 + dy)
      ..cubicTo(318, 186 + dy, 318, 200 + dy, 322, 208 + dy)
      ..cubicTo(328, 202 + dy, 332, 188 + dy, 331, 175 + dy)
      ..close();
    canvas.drawPath(root, Paint()..color = _dentin);
    canvas.drawPath(
      root,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = _boneLine,
    );
    final crown = Path()
      ..moveTo(320, 177 + dy)
      ..cubicTo(322, 166 + dy, 326, 156 + dy, 330, 148 + dy) // arka yüz
      ..cubicTo(331, 145 + dy, 335, 145 + dy, 335, 149 + dy) // kesici kenar
      ..cubicTo(336, 158 + dy, 335, 168 + dy, 332, 177 + dy) // ön yüz
      ..close();
    _enamel(canvas, crown);
    // Diş etleri
    final g = Paint()..color = _gum;
    canvas.drawPath(
      Path()
        ..moveTo(316, 184 + dy)
        ..cubicTo(317, 178 + dy, 320, 174 + dy, 323, 172 + dy)
        ..lineTo(322, 180 + dy)
        ..close(),
      g,
    );
    canvas.drawPath(
      Path()
        ..moveTo(331, 172 + dy)
        ..cubicTo(335, 172 + dy, 338, 175 + dy, 339, 180 + dy)
        ..lineTo(332, 180 + dy)
        ..close(),
      g,
    );
  }

  void _enamel(Canvas canvas, Path crown) {
    canvas.drawPath(
      crown,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_enamelB, _enamelA, _enamelB],
          stops: [0, 0.55, 1],
        ).createShader(crown.getBounds()),
    );
    canvas.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF9E9488),
    );
  }

  /// Dudaklar: deri, kırmızı kısım (vermilion), içte mukoza ve halka kas.
  void _lips(Canvas canvas, double dy, TonguePose p) {
    final r = p.lipRound * 9;
    final lt = p.lipToTeeth;

    final upper = Path()
      ..moveTo(346, 92)
      ..cubicTo(349, 98, 354, 103, 357 + r * 0.6, 108)
      ..cubicTo(362 + r, 113, 364 + r, 122, 361 + r, 130)
      ..cubicTo(358 + r, 135, 354 + r, 138, 349 + r * 0.8, 138)
      ..cubicTo(344, 138, 340, 135, 338, 129)
      ..lineTo(335, 110)
      ..cubicTo(336, 102, 340, 96, 346, 92)
      ..close();
    final upperRed = Path()
      ..moveTo(357 + r * 0.6, 107.5)
      ..cubicTo(362 + r, 113, 364 + r, 122, 361 + r, 130)
      ..cubicTo(358 + r, 135, 354 + r, 138, 349 + r * 0.8, 138)
      ..cubicTo(346, 138, 343, 136, 342, 133)
      ..cubicTo(346, 124, 350, 114, 357 + r * 0.6, 107.5)
      ..close();

    // Alt dudak: çeneyle iner; V/W'de üst dişlere doğru kalkar.
    final ox = -lt * 9;
    final oy = dy - lt * 7;
    Offset q(double x, double y, {bool front = true}) =>
        Offset(x + (front ? ox : ox * 0.5) + (front ? r : 0), y + oy);
    final a = q(349, 142), b = q(356, 142), c = q(363, 148), d = q(364, 156);
    final e = q(365, 166), f = q(359, 174), g = q(351, 176);
    final h = q(347, 178, front: false), i = q(341, 182, front: false);
    final j = q(337, 172, front: false), k = q(335, 160, front: false);
    final m = q(337, 150, front: false), n = q(341, 144, front: false);
    final lower = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(b.dx, b.dy, c.dx, c.dy, d.dx, d.dy)
      ..cubicTo(e.dx, e.dy, f.dx, f.dy, g.dx, g.dy)
      ..cubicTo(h.dx, h.dy, i.dx, i.dy, i.dx, i.dy)
      ..lineTo(j.dx, j.dy)
      ..cubicTo(k.dx, k.dy, m.dx, m.dy, n.dx, n.dy)
      ..lineTo(a.dx, a.dy)
      ..close();
    final lowerRed = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(b.dx, b.dy, c.dx, c.dy, d.dx, d.dy)
      ..cubicTo(e.dx, e.dy, f.dx, f.dy, g.dx, g.dy)
      ..cubicTo(g.dx - 4, g.dy - 6, n.dx + 2, n.dy + 8, n.dx + 2, n.dy + 2)
      ..lineTo(a.dx, a.dy)
      ..close();

    // Deri kısmı yüzle aynı renkte: dudak yüzden kopuk durmasın.
    final skin = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [_tissueB, _tissueA],
      ).createShader(const Rect.fromLTWH(0, 0, 400, 300));
    final red = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_vermilionA, _vermilionB],
      ).createShader(const Rect.fromLTWH(336, 100, 36, 90));
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = _skinLine.withValues(alpha: 0.85);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _mucosaDark;
    final upperOuter = Path()
      ..moveTo(346, 92)
      ..cubicTo(349, 98, 354, 103, 357 + r * 0.6, 108)
      ..cubicTo(362 + r, 113, 364 + r, 122, 361 + r, 130)
      ..cubicTo(358 + r, 135, 354 + r, 138, 349 + r * 0.8, 138);
    final upperInner = Path()
      ..moveTo(349 + r * 0.8, 138)
      ..cubicTo(344, 138, 340, 135, 338, 129)
      ..lineTo(335, 110);
    final lowerOuter = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(b.dx, b.dy, c.dx, c.dy, d.dx, d.dy)
      ..cubicTo(e.dx, e.dy, f.dx, f.dy, g.dx, g.dy)
      ..cubicTo(h.dx, h.dy, i.dx, i.dy, i.dx, i.dy);
    final lowerInner = Path()
      ..moveTo(j.dx, j.dy)
      ..cubicTo(k.dx, k.dy, m.dx, m.dy, n.dx, n.dy)
      ..lineTo(a.dx, a.dy);
    for (final (whole, redPart, muscleCenter, o, inn) in [
      (upper, upperRed, Offset(345 + r * 0.5, 120), upperOuter, upperInner),
      (
        lower,
        lowerRed,
        Offset(347 + ox + r * 0.5, 161 + oy),
        lowerOuter,
        lowerInner,
      ),
    ]) {
      canvas.drawPath(whole, skin);
      canvas.drawPath(redPart, red);
      // Halka kas (orbicularis oris) kesiti
      canvas.save();
      canvas.clipPath(whole);
      canvas.drawOval(
        Rect.fromCenter(center: muscleCenter, width: 9, height: 16),
        Paint()
          ..color = _muscle.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      canvas.restore();
      canvas.drawPath(o, outer);
      canvas.drawPath(inn, inner);
    }
    // Dudak parlaklıkları
    final shine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.45);
    canvas.drawLine(Offset(360 + r, 116), Offset(362 + r, 123), shine);
    canvas.drawLine(d + const Offset(-1, -3), d + const Offset(0, 4), shine);
  }

  // --- Hareket göstergeleri --------------------------------------------------

  void _contact(Canvas canvas, Frame f) {
    final cp = main.contact;
    if (cp == null) return;
    final glowColor = mainIsError ? bad : const Color(0xFFFFD54F);
    if (f.contact > 0.05) {
      canvas.drawCircle(
        cp,
        14,
        Paint()
          ..shader = RadialGradient(
            colors: [
              glowColor.withValues(alpha: 0.85 * f.contact),
              glowColor.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: cp, radius: 14)),
      );
    }
    if (f.ripple >= 0 && f.ripple <= 1) {
      canvas.drawCircle(
        cp,
        6 + 22 * f.ripple,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - f.ripple)
          ..color = glowColor.withValues(alpha: 1 - f.ripple),
      );
    }
  }

  /// Havanın ağız içindeki yolu, dilin o anki biçimine göre.
  Path _flowPath(TonguePose p, double dy, {required bool lateral}) {
    final path = Path()..moveTo(124, 300);
    _flowSpline(path, p, dy, lateral);
    return path;
  }

  void _flowSpline(Path path, TonguePose p, double dy, bool lateral) {
    openSpline(path, [
      const Offset(124, 300),
      const Offset(124, 210),
      Offset(168, p.back.dy - 40),
      Offset(p.dorsum.dx, p.dorsum.dy - 12),
      lateral
          ? Offset(p.blade.dx, p.blade.dy + 16)
          : Offset(p.blade.dx, p.blade.dy - 9),
      lateral
          ? Offset(p.tip.dx - 6, p.tip.dy + 30)
          : Offset(p.tip.dx + 6, p.tip.dy - 5),
      Offset(340, 143 + dy * 0.5),
      Offset(398, 140 + dy * 0.5),
    ]);
  }

  void _flowParticles(
    Canvas canvas,
    TonguePose p,
    double dy,
    double amount,
    bool burst,
  ) {
    final lateral = main.air == Air.lateral;
    final path = _flowPath(p, dy, lateral: lateral);
    final metric = path.computeMetrics().first;
    final n = burst ? 18 : 14;
    final speed = burst ? 2.2 : 1.0;
    for (var i = 0; i < n; i++) {
      final seed = i * 0.6180339;
      var u = ((t * 3 * speed) + i / n) % 1.0;
      if (burst) u = 0.55 + u * 0.45; // patlama yalnızca ağızdan dışarı
      final tan = metric.getTangentForOffset(u * metric.length);
      if (tan == null) continue;
      final jitter = math.sin((t * 40 + seed * 10)) * 2.2;
      final pos = tan.position + Offset(-tan.vector.dy, tan.vector.dx) * jitter;
      final fade = math.sin(math.pi * u);
      final r = (lateral ? 2.0 : 2.4) + 1.6 * u;
      final c = (lateral ? const Color(0xFFB8E4FF) : _flow).withValues(
        alpha: (0.85 * fade * amount).clamp(0.0, 1.0),
      );
      canvas.drawCircle(
        pos,
        r + 2,
        Paint()..color = c.withValues(alpha: c.a * 0.3),
      );
      canvas.drawCircle(pos, r, Paint()..color = c);
    }
    if (lateral) {
      pill(
        canvas,
        'hava yanlardan',
        Offset(p.tip.dx - 20, p.tip.dy + 64),
        _flow,
      );
    }
  }

  void _nasalFlow(Canvas canvas, double amount) {
    final path = Path()..moveTo(124, 300);
    openSpline(path, const [
      Offset(124, 300),
      Offset(122, 160),
      Offset(120, 96),
      Offset(150, 62),
      Offset(240, 50),
      Offset(330, 62),
      Offset(364, 90),
      Offset(372, 110),
    ]);
    final m = path.computeMetrics().first;
    for (var i = 0; i < 14; i++) {
      final u = ((t * 3) + i / 14) % 1.0;
      final tan = m.getTangentForOffset(u * m.length);
      if (tan == null) continue;
      canvas.drawCircle(
        tan.position,
        2.6,
        Paint()
          ..color = _flow.withValues(alpha: amount * math.sin(math.pi * u)),
      );
    }
    pill(canvas, 'hava burundan', const Offset(206, 8), _flow);
  }

  void _pressure(Canvas canvas, TonguePose p) {
    final paint = Paint()
      ..color = const Color(0xFFFFB74D)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 24);
    final base = main.contact ?? p.tip;
    for (var k = 0; k < 3; k++) {
      final o = base + Offset(-26.0 - k * 9 - pulse * 3, 14.0 + k * 4);
      canvas.drawLine(o, o + const Offset(8, -4), paint);
    }
  }

  void _uvulaBuzz(Canvas canvas) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = bad;
    for (var k = 0; k < 3; k++) {
      final x = 136.0 - k * 6 + math.sin(t * 90 + k) * 2;
      canvas.drawLine(Offset(x, 122), Offset(x - 4, 134), p);
    }
  }

  void _labels(Canvas canvas, TonguePose p, bool voiced) {
    final line = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: 0.75)
      ..strokeWidth = 1;
    void label(String text, Offset at, Offset target) {
      canvas.drawLine(at + const Offset(4, 6), target, line);
      canvas.drawCircle(target, 2.2, Paint()..color = line.color);
      pill(canvas, text, at, const Color(0xFF5D4037));
    }

    label('burun boşluğu', const Offset(160, 6), const Offset(200, 50));
    label('sert damak', const Offset(214, 104), const Offset(236, 80));
    label('diş eti', const Offset(272, 4), const Offset(300, 103));
    label('yumuşak damak', const Offset(34, 30), const Offset(150, 92));
    label('küçük dil', const Offset(40, 60), const Offset(150, 128));
    label('dudaklar', const Offset(334, 276), const Offset(362, 150));
    label('dil ucu', Offset(p.tip.dx - 104, p.tip.dy + 42), p.tip);
    label('dil sırtı', Offset(p.dorsum.dx - 66, p.dorsum.dy + 58), p.dorsum);
    label('ses telleri', const Offset(158, 284), const Offset(128, 289));
    label('çene kemiği', const Offset(226, 262), const Offset(318, 222));
  }

  @override
  bool shouldRepaint(covariant ArticulationPainter old) =>
      old.t != t ||
      old.main != main ||
      old.ghost != ghost ||
      old.labels != labels ||
      old.mainIsError != mainIsError;
}

/// Çizim üstüne küçük etiket.
void pill(Canvas canvas, String text, Offset at, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: color.computeLuminance() > 0.5
            ? const Color(0xFF263238)
            : Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(at.dx - 5, at.dy - 2, tp.width + 10, tp.height + 4),
    const Radius.circular(9),
  );
  canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.88));
  tp.paint(canvas, at);
}
