import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'articulation_motion.dart';
import 'articulations.dart';
import 'sagittal_painter.dart';

/// Ağzın önden görünümü: aynada görülen. Dudaklar, dişler, dil ucu ve dilin
/// alt yüzü (damarlar, dil altı bağı), havanın çıktığı yer.
///
/// Yan kesitteki dil konumundan türetilir: dil ucu yüksekliği, dışarı
/// çıkması, dil sırtının yüksekliği, çene açıklığı ve dudak biçimi.
class MouthFrontPainter extends CustomPainter {
  final double t;
  final Articulation main;
  final Articulation? ghost;
  final bool mainIsError;
  final bool labels;

  MouthFrontPainter({
    required this.t,
    required this.main,
    required this.ghost,
    required this.mainIsError,
    required this.labels,
  });

  static const _cx = 200.0;
  static const _upperEdge = 150.0; // üst kesici dişlerin ucu

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 400, size.height / 300);
    canvas.save();
    canvas.translate((size.width - 400 * s) / 2, (size.height - 300 * s) / 2);
    canvas.scale(s);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 400, 300));
    // Ağza yakınlaş: burun ucu çerçevenin üstünde kalır.
    canvas.save();
    canvas.translate(200, 168);
    canvas.scale(_zoom);
    canvas.translate(-200, -168);

    final f = frameAt(main, t);
    final g = ghost == null ? null : frameAt(ghost!, t);
    final p = f.pose;
    final jaw = g == null ? p.jaw : math.max(p.jaw, g.pose.jaw);
    final m = _Mouth(jaw, p.lipRound, p.lipToTeeth);

    _face(canvas, m);
    final opening = m.opening();
    canvas.save();
    canvas.clipPath(opening);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 400, 300),
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0, (m.yC - 150) / 150),
          radius: 0.35,
          colors: const [Color(0xFF5E1A2A), Color(0xFF26070F)],
        ).createShader(const Rect.fromLTWH(0, 0, 400, 300)),
    );
    final tongue = _TongueFront(p, m);
    tongue.paintBody(canvas, mainIsError);
    _lowerTeeth(canvas, m);
    _upperTeeth(canvas, m);
    tongue.paintTipOut(canvas, mainIsError);
    if (g != null) _TongueFront(g.pose, m).paintGhost(canvas, mainIsError);
    _contact(canvas, f);
    if (f.air > 0.02) _air(canvas, m, f, tongue);
    canvas.restore();
    if (main.air == Air.nasal && f.air > 0.02) _nasalAir(canvas, f.air);

    _lips(canvas, m);
    canvas.restore();
    if (labels) _labels(canvas, m, tongue);
    canvas.restore();
  }

  void _face(Canvas canvas, _Mouth m) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 400, 300),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.1),
          radius: 0.9,
          colors: [Color(0xFFF8D9C7), Color(0xFFE6B39D)],
        ).createShader(const Rect.fromLTWH(0, 0, 400, 300)),
    );
    // Burun altı: burun delikleri ve kolumella
    final shade = Paint()
      ..color = const Color(0xFFB9826C).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(_cx, 10), width: 150, height: 34),
      shade,
    );
    for (final sx in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(_cx + sx * 25, 12);
      canvas.rotate(sx * 0.25);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 28, height: 12),
        Paint()..color = const Color(0xFF6E3A2E),
      );
      canvas.restore();
    }
    // Dudak üstü oluğu (philtrum): iki sırt ve arasındaki çukur
    final top = m.yU - 22 - 4 * m.round;
    canvas.drawPath(
      Path()
        ..moveTo(_cx - 11, 24)
        ..lineTo(_cx - 15, top)
        ..lineTo(_cx + 15, top)
        ..lineTo(_cx + 11, 24)
        ..close(),
      Paint()
        ..color = const Color(0xFFD9A28B).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final ridge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFBE3D6).withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawLine(Offset(_cx - 12, 26), Offset(_cx - 16, top - 2), ridge);
    canvas.drawLine(Offset(_cx + 12, 26), Offset(_cx + 16, top - 2), ridge);
    // Yanak–dudak çizgileri
    final fold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFC98E78).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final sx in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(_cx + sx * 64, 30)
          ..quadraticBezierTo(
            _cx + sx * (m.halfW + 34),
            m.yC - 10,
            _cx + sx * (m.halfW + 26),
            m.yC + 40,
          ),
        fold,
      );
    }
    // Çene altındaki gölge
    canvas.drawOval(
      Rect.fromCenter(center: Offset(_cx, m.yL + 48), width: 110, height: 18),
      Paint()
        ..color = const Color(0xFFC08A74).withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  /// Dişler: (merkezden uzaklık, genişlik, uç düşüklüğü, sivri mi, koyuluk)
  static const _upper = [
    (71.0, 16.0, -6.0, false, 0.4),
    (55.0, 18.0, -2.0, true, 0.25),
    (36.0, 20.0, -3.0, false, 0.15),
    (13.0, 26.0, 0.0, false, 0.0),
  ];
  static const _lower = [
    (62.0, 16.0, 5.0, false, 0.4),
    (45.0, 17.0, 2.0, true, 0.25),
    (27.0, 18.0, 0.5, false, 0.15),
    (9.0, 18.0, 0.0, false, 0.0),
  ];

  void _tooth(
    Canvas canvas,
    double cx,
    double w,
    double edge,
    double far,
    bool pointed,
    double shade, {
    required bool upper,
  }) {
    final l = cx - w / 2, r = cx + w / 2;
    final path = Path();
    if (upper) {
      path
        ..moveTo(l, far)
        ..lineTo(l, edge - 5)
        ..quadraticBezierTo(l, edge, l + 5, edge);
      if (pointed) path.lineTo(cx, edge + 2);
      path
        ..lineTo(r - 5, edge)
        ..quadraticBezierTo(r, edge, r, edge - 5)
        ..lineTo(r, far)
        ..close();
    } else {
      path
        ..moveTo(l, far)
        ..lineTo(l, edge + 4)
        ..quadraticBezierTo(l, edge, l + 4, edge);
      if (pointed) path.lineTo(cx, edge - 1.5);
      path
        ..lineTo(r - 4, edge)
        ..quadraticBezierTo(r, edge, r, edge + 4)
        ..lineTo(r, far)
        ..close();
    }
    final c0 = Color.lerp(Colors.white, const Color(0xFF8C7F70), shade)!;
    final c1 = Color.lerp(
      const Color(0xFFE6DDCD),
      const Color(0xFF6E6153),
      shade,
    )!;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: upper ? Alignment.bottomCenter : Alignment.topCenter,
          end: upper ? Alignment.topCenter : Alignment.bottomCenter,
          colors: [c0, c1],
        ).createShader(path.getBounds()),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF8F8373),
    );
    // Mine parlaklığı
    if (shade < 0.3) {
      canvas.drawLine(
        Offset(cx - w * 0.15, upper ? edge - 8 : edge + 8),
        Offset(cx - w * 0.2, upper ? edge - 22 : edge + 18),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.7),
      );
    }
  }

  void _upperTeeth(Canvas canvas, _Mouth m) {
    // Diş eti (yalnızca ağız çok açıksa ya da dudak kalkıksa görünür)
    canvas.drawRect(
      Rect.fromLTRB(_cx - 90, _upperEdge - 62, _cx + 90, _upperEdge - 30),
      Paint()..color = const Color(0xFFE48C99),
    );
    for (final (dx, w, drop, pointed, shade) in _upper) {
      for (final sx in [-1.0, 1.0]) {
        _tooth(
          canvas,
          _cx + sx * dx,
          w,
          _upperEdge + drop,
          _upperEdge - 34,
          pointed,
          shade,
          upper: true,
        );
      }
    }
  }

  void _lowerTeeth(Canvas canvas, _Mouth m) {
    canvas.drawRect(
      Rect.fromLTRB(_cx - 80, m.yLT + 26, _cx + 80, m.yLT + 60),
      Paint()..color = const Color(0xFFE48C99),
    );
    for (final (dx, w, drop, pointed, shade) in _lower) {
      for (final sx in [-1.0, 1.0]) {
        _tooth(
          canvas,
          _cx + sx * dx,
          w,
          m.yLT + drop,
          m.yLT + 30,
          pointed,
          shade,
          upper: false,
        );
      }
    }
  }

  void _contact(Canvas canvas, Frame f) {
    final cp = main.contact;
    // Önden yalnızca dil ucunun ön damaktaki teması görünür.
    if (cp == null || cp.dx < 270 || f.contact < 0.05) return;
    final c = mainIsError ? ArticulationPainter.bad : const Color(0xFFFFD54F);
    const at = Offset(_cx, _upperEdge - 4);
    canvas.drawOval(
      Rect.fromCenter(center: at, width: 80, height: 26),
      Paint()
        ..shader = RadialGradient(
          colors: [
            c.withValues(alpha: 0.75 * f.contact),
            c.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCenter(center: at, width: 80, height: 26)),
    );
    if (f.ripple >= 0 && f.ripple <= 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: at,
          width: 30 + 70 * f.ripple,
          height: 10 + 22 * f.ripple,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - f.ripple)
          ..color = c.withValues(alpha: 1 - f.ripple),
      );
    }
  }

  /// Hava bize doğru çıkar: büyüyüp sönen halkalar. L'de dilin iki yanından.
  void _air(Canvas canvas, _Mouth m, Frame f, _TongueFront tongue) {
    if (main.air == Air.nasal) return;
    final lateral = main.air == Air.lateral;
    final sources = lateral
        ? [
            Offset(_cx - tongue.tipHalfW - 10, m.mid),
            Offset(_cx + tongue.tipHalfW + 10, m.mid),
          ]
        : [Offset(_cx, m.mid)];
    final n = f.burst ? 4 : 3;
    for (final src in sources) {
      for (var i = 0; i < n; i++) {
        final u = ((t * (f.burst ? 6 : 3)) + i / n) % 1.0;
        final drift = lateral ? (src.dx < _cx ? -1 : 1) * 26 * u : 0.0;
        final rect = Rect.fromCenter(
          center: src + Offset(drift, 4 * u),
          width: 8 + 44 * u,
          height: 5 + 20 * u,
        );
        canvas.drawOval(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * (1 - u) + 0.6
            ..color = const Color(0xFF9EDCFF)
                .withValues(alpha: (f.air * (1 - u) * 0.9).clamp(0.0, 1.0)),
        );
      }
    }
  }

  void _nasalAir(Canvas canvas, double amount) {
    for (final sx in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final u = ((t * 3) + i / 3) % 1.0;
        final c = Offset(_cx + sx * (25 + 10 * u), 16 + 26 * u);
        canvas.drawCircle(
          c,
          3 + 6 * u,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF9EDCFF)
                .withValues(alpha: amount * (1 - u)),
        );
      }
    }
    pill(
      canvas,
      'hava burundan',
      const Offset(250, 30),
      const Color(0xFF7FD3FF),
    );
  }

  void _lips(Canvas canvas, _Mouth m) {
    final op = m.openingEdges();
    final lc = Offset(_cx - m.halfW - 7, m.yC);
    final rc = Offset(_cx + m.halfW + 7, m.yC);
    final bow = m.yU - 23 - 5 * m.round;
    final dip = m.yU - 18 - 5 * m.round;

    final upper = Path()
      ..moveTo(lc.dx, lc.dy)
      ..cubicTo(
        _cx - m.halfW * 0.75,
        m.yU - 8,
        _cx - 34 + 10 * m.round,
        bow,
        _cx - 15 + 5 * m.round,
        bow,
      )
      ..quadraticBezierTo(_cx - 5, bow, _cx, dip)
      ..quadraticBezierTo(_cx + 5, bow, _cx + 15 - 5 * m.round, bow)
      ..cubicTo(
        _cx + 34 - 10 * m.round,
        bow,
        _cx + m.halfW * 0.75,
        m.yU - 8,
        rc.dx,
        rc.dy,
      );
    op.addTopReversed(upper);
    upper.close();

    final lowBottom = m.yL + 27 - 6 * m.round;
    final lower = Path()..moveTo(lc.dx, lc.dy);
    op.addBottom(lower);
    lower
      ..lineTo(rc.dx, rc.dy)
      ..cubicTo(
        _cx + m.halfW * 0.8,
        lowBottom - 4,
        _cx + 34,
        lowBottom,
        _cx,
        lowBottom,
      )
      ..cubicTo(
        _cx - 34,
        lowBottom,
        _cx - m.halfW * 0.8,
        lowBottom - 4,
        lc.dx,
        lc.dy,
      )
      ..close();

    // Alt dudağın altındaki gölge
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(_cx, lowBottom + 4),
        width: m.halfW * 1.4,
        height: 12,
      ),
      Paint()
        ..color = const Color(0xFFA86A56).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      upper,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFC9636F), Color(0xFF9C3B4A)],
        ).createShader(Rect.fromLTRB(0, bow, 400, m.yU + 4)),
    );
    canvas.drawPath(
      lower,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFE48892), Color(0xFFC3606C)],
        ).createShader(Rect.fromLTRB(0, m.yL - 2, 400, lowBottom)),
    );
    // Dudak çizgileri (dikey kırışıklar), büzülünce belirginleşir
    final crease = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFF8A3040).withValues(alpha: 0.25 + 0.3 * m.round);
    canvas.save();
    canvas.clipPath(upper);
    for (var i = -6; i <= 6; i++) {
      final x = _cx + i * m.halfW / 7;
      canvas.drawLine(
        Offset(x, bow - 2),
        Offset(x * 0.98 + 4, m.yU + 2),
        crease,
      );
    }
    canvas.restore();
    canvas.save();
    canvas.clipPath(lower);
    for (var i = -6; i <= 6; i++) {
      final x = _cx + i * m.halfW / 7;
      canvas.drawLine(
        Offset(x, m.yL - 2),
        Offset(x, m.yL + (lowBottom - m.yL) * (0.45 + 0.25 * m.round)),
        crease,
      );
    }
    // Alt dudak parlaklığı
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(_cx - 12, m.yL + 9 + 2 * m.round),
        width: m.halfW * 0.7,
        height: 7,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.restore();
    // Dudak sınırı (açık renkli kenar)
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFFBE2D4);
    final upperBorder = Path()
      ..moveTo(lc.dx, lc.dy)
      ..cubicTo(
        _cx - m.halfW * 0.75,
        m.yU - 8,
        _cx - 34 + 10 * m.round,
        bow,
        _cx - 15 + 5 * m.round,
        bow,
      )
      ..quadraticBezierTo(_cx - 5, bow, _cx, dip)
      ..quadraticBezierTo(_cx + 5, bow, _cx + 15 - 5 * m.round, bow)
      ..cubicTo(
        _cx + 34 - 10 * m.round,
        bow,
        _cx + m.halfW * 0.75,
        m.yU - 8,
        rc.dx,
        rc.dy,
      );
    canvas.drawPath(upperBorder, border);
    // Ağız köşeleri
    for (final c in [lc, rc]) {
      canvas.drawCircle(
        c,
        3.5,
        Paint()
          ..color = const Color(0xFF7A3B36).withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF7D2F3C).withValues(alpha: 0.6);
    canvas.drawPath(m.opening(), outline);
  }

  /// Yakınlaştırılmış çizimdeki bir noktanın çerçevedeki yeri.
  static Offset _zoomed(Offset p) =>
      (p - const Offset(200, 168)) * _zoom + const Offset(200, 168);
  static const _zoom = 1.32;

  void _labels(Canvas canvas, _Mouth m, _TongueFront tongue) {
    final line = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: 0.75)
      ..strokeWidth = 1;
    void label(String text, Offset at, Offset target) {
      target = _zoomed(target);
      canvas.drawLine(at + const Offset(4, 6), target, line);
      canvas.drawCircle(target, 2.2, Paint()..color = line.color);
      pill(canvas, text, at, const Color(0xFF5D4037));
    }

    label(
      'üst dişler',
      const Offset(300, 70),
      const Offset(226, _upperEdge - 8),
    );
    label(
      'üst dudak',
      const Offset(18, 60),
      Offset(_cx - m.halfW * 0.45, m.yU - 10),
    );
    label(
      'alt dudak',
      const Offset(18, 250),
      Offset(_cx - m.halfW * 0.45, m.yL + 12),
    );
    if (tongue.tipUp > 0.3) {
      label(
        'dilin altı',
        const Offset(300, 250),
        Offset(_cx + 12, (tongue.tipTop + tongue.base) / 2 + 6),
      );
    } else if (tongue.tipOut > 0.3) {
      label('dil ucu', const Offset(300, 250), Offset(_cx + 14, m.mid + 4));
    } else {
      label(
        'dil',
        const Offset(300, 250),
        Offset(_cx + 20, tongue.bodyTop + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MouthFrontPainter old) =>
      old.t != t ||
      old.main != main ||
      old.ghost != ghost ||
      old.labels != labels ||
      old.mainIsError != mainIsError;
}

/// Ağız açıklığının ölçüleri.
class _Mouth {
  final double jaw, round, lipToTeeth;
  late final double halfW = 78 * (1 - 0.45 * round);
  late final double yU = 143 - 26 * jaw - 4 * round;
  late final double yLT = 148 + 56 * jaw; // alt dişlerin ucu
  late final double yL = () {
    var y = yLT + 7 + 10 * jaw;
    y = math.max(y, yU + 30 * round);
    // V/W: alt dudak üst dişlerin ucuna kalkar
    return y + (MouthFrontPainter._upperEdge + 2 - y) * lipToTeeth;
  }();
  late final double yC = (yU + yL) / 2 - 1;

  /// Dişlerin arasındaki boşluğun ortası.
  late final double mid = (MouthFrontPainter._upperEdge + yLT) / 2;

  _Mouth(this.jaw, this.round, this.lipToTeeth);

  _Edges openingEdges() => _Edges(this);

  Path opening() {
    final e = openingEdges();
    final p = Path()..moveTo(e.l.dx, e.l.dy);
    e.addTop(p);
    e.addBottomReversedFromRight(p);
    return p..close();
  }
}

/// Ağız açıklığının üst ve alt kenarları; yuvarlak dudakta elipse yaklaşır.
class _Edges {
  final _Mouth m;
  late final Offset l = Offset(200 - m.halfW, m.yC);
  late final Offset r = Offset(200 + m.halfW, m.yC);

  _Edges(this.m);

  (Offset, Offset) _ctrl(double y, double sx) {
    final k = m.round;
    final c1 = Offset(
      200 + sx * m.halfW * (1 - 0.45 * k) * (0.62 + 0.38 * k),
      y + (m.yC - y) * 0.55 * k + (1 - k) * (y - m.yC) * -0.05,
    );
    final c2 = Offset(200 + sx * m.halfW * (0.22 + 0.33 * k), y);
    return (c1, c2);
  }

  void addTop(Path p) {
    final (a1, a2) = _ctrl(m.yU, -1);
    p.cubicTo(a1.dx, a1.dy, a2.dx, a2.dy, 200, m.yU);
    final (b1, b2) = _ctrl(m.yU, 1);
    p.cubicTo(b2.dx, b2.dy, b1.dx, b1.dy, r.dx, r.dy);
  }

  void addTopReversed(Path p) {
    final (b1, b2) = _ctrl(m.yU, 1);
    p.cubicTo(b1.dx, b1.dy, b2.dx, b2.dy, 200, m.yU);
    final (a1, a2) = _ctrl(m.yU, -1);
    p.cubicTo(a2.dx, a2.dy, a1.dx, a1.dy, l.dx, l.dy);
  }

  /// Soldan sağa alt kenar.
  void addBottom(Path p) {
    final (a1, a2) = _ctrl(m.yL, -1);
    p.cubicTo(a1.dx, a1.dy, a2.dx, a2.dy, 200, m.yL);
    final (b1, b2) = _ctrl(m.yL, 1);
    p.cubicTo(b2.dx, b2.dy, b1.dx, b1.dy, r.dx, r.dy);
  }

  void addBottomReversedFromRight(Path p) {
    final (b1, b2) = _ctrl(m.yL, 1);
    p.cubicTo(b1.dx, b1.dy, b2.dx, b2.dy, 200, m.yL);
    final (a1, a2) = _ctrl(m.yL, -1);
    p.cubicTo(a2.dx, a2.dy, a1.dx, a1.dy, l.dx, l.dy);
  }
}

/// Dilin önden görünen parçaları.
class _TongueFront {
  final TonguePose p;
  final _Mouth m;

  late final double tipUp = ((150 - p.tip.dy) / 43).clamp(0.0, 1.0);
  late final double tipOut = ((p.tip.dx - 306) / 30).clamp(0.0, 1.0);
  late final double high = ((132 - p.dorsum.dy) / 40).clamp(0.0, 1.0);

  /// Dil sırtının görünen üst sınırı.
  late final double bodyTop =
      m.yLT - 2 + (MouthFrontPainter._upperEdge + 4 - (m.yLT - 2)) * high;

  /// Kalkan dil ucunun tepe noktası (üst dişlerin arkasına gider).
  late final double base = m.yLT + 6;
  late final double tipTop =
      base - 4 + (MouthFrontPainter._upperEdge - 18 - (base - 4)) * tipUp;
  double get tipHalfW => 30 - 6 * tipUp;

  _TongueFront(this.p, this.m);

  static const _cx = 200.0;

  Path _body() => Path()
    ..moveTo(_cx - 130, 300)
    ..lineTo(_cx - 130, bodyTop + 40)
    ..cubicTo(_cx - 110, bodyTop + 2, _cx - 50, bodyTop, _cx, bodyTop)
    ..cubicTo(
      _cx + 50,
      bodyTop,
      _cx + 110,
      bodyTop + 2,
      _cx + 130,
      bodyTop + 40,
    )
    ..lineTo(_cx + 130, 300)
    ..close();

  Path _tip() {
    final w = tipHalfW;
    return Path()
      ..moveTo(_cx - w - 8, base + 20)
      ..cubicTo(
        _cx - w - 4,
        base - 6,
        _cx - w,
        tipTop + 14,
        _cx - w * 0.7,
        tipTop + 4,
      )
      ..cubicTo(
        _cx - w * 0.4,
        tipTop - 2,
        _cx + w * 0.4,
        tipTop - 2,
        _cx + w * 0.7,
        tipTop + 4,
      )
      ..cubicTo(
        _cx + w,
        tipTop + 14,
        _cx + w + 4,
        base - 6,
        _cx + w + 8,
        base + 20,
      )
      ..close();
  }

  /// Dişlerin arasından dışarı çıkan dil ucu (peltek S): alt dudağın
  /// üstüne yaslanır, üst dişlerin ucuna kadar uzanır.
  Path _out() {
    const top = MouthFrontPainter._upperEdge + 1;
    final bottom = m.yL + 10;
    return Path()
      ..moveTo(_cx - 44, bottom)
      ..cubicTo(_cx - 46, m.mid + 4, _cx - 40, top + 2, _cx - 18, top)
      ..quadraticBezierTo(_cx, top - 2, _cx + 18, top)
      ..cubicTo(_cx + 40, top + 2, _cx + 46, m.mid + 4, _cx + 44, bottom)
      ..close();
  }

  void paintBody(Canvas canvas, bool error) {
    final top = error ? const Color(0xFFF59A9A) : const Color(0xFFF08A9C);
    final bottom = error ? const Color(0xFFBF4040) : const Color(0xFFBF4560);
    canvas.drawPath(
      _body(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Rect.fromLTRB(0, bodyTop, 400, bodyTop + 60)),
    );
    // Orta oluk
    canvas.drawLine(
      Offset(_cx, bodyTop + 4),
      Offset(_cx, bodyTop + 50),
      Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFF9E3A52).withValues(alpha: 0.45),
    );
    if (tipUp > 0.05) {
      final tip = _tip();
      // Alt yüz: koyu, iki damar ve ortada dil altı bağı
      canvas.drawPath(
        tip,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: error
                ? const [Color(0xFFD86A6A), Color(0xFFA03A3A)]
                : const [Color(0xFFD9667D), Color(0xFFA53C55)],
          ).createShader(tip.getBounds()),
      );
      canvas.save();
      canvas.clipPath(tip);
      final vein = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6A4FA0).withValues(alpha: 0.55 * tipUp);
      for (final sx in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(_cx + sx * 6, base + 18)
            ..quadraticBezierTo(
              _cx + sx * 16,
              (base + tipTop) / 2,
              _cx + sx * 12,
              tipTop + 12,
            ),
          vein,
        );
      }
      canvas.drawLine(
        Offset(_cx, base + 20),
        Offset(_cx, base - (base - tipTop) * 0.45),
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFF2A9B6).withValues(alpha: 0.8 * tipUp),
      );
      canvas.restore();
      canvas.drawPath(
        tip,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF7E2338).withValues(alpha: 0.7),
      );
    }
  }

  void paintTipOut(Canvas canvas, bool error) {
    if (tipOut < 0.05) return;
    final o = _out();
    canvas.drawPath(
      o,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: error
              ? const [Color(0xFFF7A5A5), Color(0xFFC24848)]
              : const [Color(0xFFF59AAA), Color(0xFFC9506A)],
        ).createShader(o.getBounds()),
    );
    canvas.drawLine(
      Offset(_cx, MouthFrontPainter._upperEdge + 6),
      Offset(_cx, m.yL + 6),
      Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFF9E3A52).withValues(alpha: 0.45),
    );
    canvas.drawPath(
      o,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF7E2338).withValues(alpha: 0.7 * tipOut),
    );
  }

  void paintGhost(Canvas canvas, bool mainIsError) {
    final color = mainIsError
        ? ArticulationPainter.good
        : ArticulationPainter.bad;
    final path = tipOut > 0.05 ? _out() : (tipUp > 0.05 ? _tip() : _body());
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.14));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 7, metric.length)),
          paint,
        );
        d += 12;
      }
    }
  }
}
