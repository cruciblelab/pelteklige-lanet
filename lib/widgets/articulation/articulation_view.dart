import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'articulations.dart';

enum CompareMode { correct, error, both }

/// Ağız yan kesiti animasyonu: dil, damak, dişler, dudaklar, hava akışı,
/// ses telleri ve temas anı. İsteğe bağlı olarak kişinin hatası doğrusunun
/// üstüne "hayalet" olarak çizilir.
class ArticulationView extends StatefulWidget {
  final String correct;
  final String? error;
  final String? errorTitle;
  final bool labels;
  final bool controls;

  const ArticulationView({
    super.key,
    required this.correct,
    this.error,
    this.errorTitle,
    this.labels = true,
    this.controls = true,
  });

  @override
  State<ArticulationView> createState() => _ArticulationViewState();
}

class _ArticulationViewState extends State<ArticulationView>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 3200);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _cycle,
  )..repeat();
  bool _slow = false;
  late CompareMode _mode = widget.error == null
      ? CompareMode.correct
      : CompareMode.both;

  @override
  void didUpdateWidget(ArticulationView old) {
    super.didUpdateWidget(old);
    if (old.error != widget.error) {
      _mode = widget.error == null ? CompareMode.correct : CompareMode.both;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _togglePlay() => setState(() {
    if (_c.isAnimating) {
      _c.stop();
    } else {
      _c.repeat();
    }
  });

  void _toggleSlow() => setState(() {
    _slow = !_slow;
    _c.duration = _slow ? _cycle * 2.5 : _cycle;
    if (_c.isAnimating) _c.repeat();
  });

  Articulation get _main =>
      articulations[_mode == CompareMode.error
          ? widget.error!
          : widget.correct]!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: ArticulationPainter(
                    t: _c.value,
                    main: _main,
                    ghost: _mode == CompareMode.both && hasError
                        ? articulations[widget.error!]
                        : null,
                    mainIsError: _mode == CompareMode.error,
                    labels: widget.labels,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final step = stepAt(_main.motion, _c.value);
            return _StepCaption(
              step: step,
              text: _main.steps[step],
              color: _mode == CompareMode.error
                  ? const Color(0xFFD84343)
                  : theme.colorScheme.primary,
            );
          },
        ),
        if (widget.controls) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: _c.isAnimating ? 'Durdur' : 'Oynat',
                onPressed: _togglePlay,
                icon: Icon(_c.isAnimating ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Yavaş'),
                avatar: const Icon(Icons.slow_motion_video, size: 18),
                selected: _slow,
                onSelected: (_) => _toggleSlow(),
              ),
            ],
          ),
          if (hasError) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<CompareMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: CompareMode.correct,
                    label: Text('Doğrusu'),
                  ),
                  ButtonSegment(value: CompareMode.error, label: Text('Senin')),
                  ButtonSegment(
                    value: CompareMode.both,
                    label: Text('Üst üste'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
            ),
          ],
          if (hasError && _mode == CompareMode.both)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  _legendDot(theme.colorScheme.primary),
                  const Text(' doğrusu   '),
                  _legendDot(const Color(0xFFD84343), dashed: true),
                  Flexible(
                    child: Text(
                      ' senin (${widget.errorTitle ?? 'hata'})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _legendDot(Color c, {bool dashed = false}) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: dashed ? Colors.transparent : c,
      border: Border.all(color: c, width: 2),
    ),
  );
}

class _StepCaption extends StatelessWidget {
  final int step;
  final String text;
  final Color color;

  const _StepCaption({
    required this.step,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 4),
            width: i == step ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == step ? color : color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
            child: Text(
              '${step + 1}. $text',
              key: ValueKey(text),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
      ],
    );
  }
}

// --- Zaman çizelgesi ---------------------------------------------------------

double _ease(double x) => Curves.easeInOutCubic.transform(x.clamp(0.0, 1.0));

int stepAt(Motion m, double t) => switch (m) {
  Motion.tap => t < 0.36 ? 0 : (t < 0.52 ? 1 : 2),
  Motion.stop => t < 0.22 ? 0 : (t < 0.5 ? 1 : 2),
  Motion.hold => t < 0.22 ? 0 : (t < 0.48 ? 1 : 2),
};

class _Frame {
  final TonguePose pose;
  final double air; // 0..1
  final double contact; // temas yoğunluğu 0..1
  final double ripple; // dalga ilerlemesi 0..1, <0 yok
  final bool burst;
  final bool pressure; // kapanma sırasında hava basıncı
  const _Frame(
    this.pose,
    this.air,
    this.contact,
    this.ripple, {
    this.burst = false,
    this.pressure = false,
  });
}

_Frame _frameAt(Articulation a, double t) {
  final rest = restPose;
  switch (a.motion) {
    case Motion.hold:
      if (t < 0.22) {
        return _Frame(TonguePose.lerp(rest, a.pose, _ease(t / 0.22)), 0, 0, -1);
      }
      if (t < 0.74) {
        final c = a.contact != null ? 1.0 : 0.0;
        final rip = a.contact != null && t < 0.4 ? (t - 0.22) / 0.18 : -1.0;
        return _Frame(a.pose, _ease((t - 0.22) / 0.08), c, rip);
      }
      final r = _ease((t - 0.74) / 0.26);
      return _Frame(TonguePose.lerp(a.pose, rest, r), 1 - r, 0, -1);
    case Motion.tap:
      final pre = a.release!;
      if (t < 0.3) {
        return _Frame(
          TonguePose.lerp(rest, pre, _ease(t / 0.3)),
          _ease((t - 0.15) / 0.15),
          0,
          -1,
        );
      }
      if (t < 0.72) {
        // Vuruş: 0.38–0.48 arasında yarım sinüs (çok kısa temas).
        final u = ((t - 0.38) / 0.10).clamp(0.0, 1.0);
        final c = math.sin(math.pi * u);
        final rip = t >= 0.42 && t < 0.62 ? (t - 0.42) / 0.20 : -1.0;
        return _Frame(TonguePose.lerp(pre, a.pose, c), 1 - 0.85 * c, c, rip);
      }
      final r = _ease((t - 0.72) / 0.28);
      return _Frame(TonguePose.lerp(pre, rest, r), 1 - r, 0, -1);
    case Motion.stop:
      final rel = a.release ?? a.pose;
      if (t < 0.22) {
        return _Frame(TonguePose.lerp(rest, a.pose, _ease(t / 0.22)), 0, 0, -1);
      }
      if (t < 0.5) {
        final rip = t < 0.4 ? (t - 0.22) / 0.18 : -1.0;
        return _Frame(a.pose, 0, 1, rip, pressure: true);
      }
      if (t < 0.74) {
        final r = _ease((t - 0.5) / 0.08);
        return _Frame(
          TonguePose.lerp(a.pose, rel, r),
          1 - _ease((t - 0.62) / 0.12),
          1 - r,
          -1,
          burst: true,
        );
      }
      final r = _ease((t - 0.74) / 0.26);
      return _Frame(TonguePose.lerp(rel, rest, r), 0, 0, -1);
  }
}

// --- Geometri yardımcıları ----------------------------------------------------

/// Kapalı Catmull-Rom eğrisi (noktalardan geçen yumuşak kapalı şekil).
Path _closedSpline(List<Offset> p) {
  final path = Path()..moveTo(p[0].dx, p[0].dy);
  final n = p.length;
  for (var i = 0; i < n; i++) {
    final p0 = p[(i - 1 + n) % n], p1 = p[i];
    final p2 = p[(i + 1) % n], p3 = p[(i + 2) % n];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path..close();
}

/// Açık Catmull-Rom eğrisi; [path] zaten ilk noktada olmalı.
void _openSpline(Path path, List<Offset> p) {
  for (var i = 0; i < p.length - 1; i++) {
    final p0 = i == 0 ? p[0] : p[i - 1], p1 = p[i];
    final p2 = p[i + 1], p3 = i + 2 < p.length ? p[i + 2] : p[i + 1];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
}

// --- Çizim -------------------------------------------------------------------

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

  static const _air = Color(0xFFDCEFFF);
  static const _skin = Color(0xFFF6D3C1);
  static const _skinDark = Color(0xFFE8B49E);
  static const _outline = Color(0xFFB27A66);
  static const _cavityA = Color(0xFF6B2232);
  static const _cavityB = Color(0xFF3E111D);
  static const _gum = Color(0xFFE79AA6);
  static const _lip = Color(0xFFD9868A);
  static const _tongueTop = Color(0xFFF2899B);
  static const _tongueBottom = Color(0xFFC4475F);
  static const _flow = Color(0xFF7FD3FF);
  static const _good = Color(0xFF14A38B);
  static const _bad = Color(0xFFD84343);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 400, size.height / 300);
    canvas.save();
    canvas.translate((size.width - 400 * s) / 2, (size.height - 300 * s) / 2);
    canvas.scale(s);

    final f = _frameAt(main, t);
    final pose = f.pose;
    final g = ghost == null ? null : _frameAt(ghost!, t);
    // Çene kayması; hayalet varsa ikisinin de görünmesi için daha açık olanı.
    final jaw = g == null ? pose.jaw : math.max(pose.jaw, g.pose.jaw);
    final dy = (jaw - 0.25) * 30;

    _background(canvas);
    final cavity = _cavityPath(dy, pose);
    canvas.drawPath(
      cavity,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.2, -0.1),
          radius: 0.9,
          colors: [_cavityA, _cavityB],
        ).createShader(const Rect.fromLTWH(100, 70, 260, 230)),
    );

    if (main.air == Air.nasal && f.air > 0) _nasalFlow(canvas, f.air);

    // Dil(ler)
    canvas.save();
    canvas.clipPath(cavity);
    if (g != null) _tongue(canvas, g.pose, dy, ghost: true);
    _tongue(canvas, pose, dy);
    canvas.restore();

    _velum(canvas, nasal: main.air == Air.nasal);
    _teeth(canvas, dy);
    _lips(canvas, dy, pose);

    // Temas parlaması ve dalga
    final cp = main.contact;
    if (cp != null && f.contact > 0.05) {
      final glowColor = mainIsError ? _bad : const Color(0xFFFFD54F);
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
    if (cp != null && f.ripple >= 0 && f.ripple <= 1) {
      canvas.drawCircle(
        cp,
        6 + 22 * f.ripple,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - f.ripple)
          ..color = (mainIsError ? _bad : const Color(0xFFFFD54F)).withValues(
            alpha: 1 - f.ripple,
          ),
      );
    }
    if (f.pressure) _pressure(canvas, pose);

    if (f.air > 0.02 && main.air != Air.nasal) {
      _flowParticles(canvas, pose, dy, f.air, f.burst);
    }
    if (main.voiced && (f.air > 0.1 || f.pressure)) _voicing(canvas);
    if (main.name.startsWith('Gırtlaktan') && f.air > 0.1) _uvulaBuzz(canvas);

    if (labels) _labels(canvas, pose);
    canvas.restore();
  }

  void _background(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 400, 300),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF6FF), _air],
        ).createShader(const Rect.fromLTWH(0, 0, 400, 300)),
    );
    // Yüz profili (burun, dudaklar, çene) solda ten rengi.
    final face = Path()
      ..moveTo(0, 0)
      ..lineTo(338, 0)
      ..cubicTo(346, 22, 372, 44, 390, 62)
      ..cubicTo(396, 70, 386, 86, 372, 90)
      ..cubicTo(362, 93, 352, 92, 344, 96)
      ..lineTo(352, 104)
      ..lineTo(352, 190)
      ..cubicTo(362, 206, 360, 228, 340, 238)
      ..cubicTo(316, 250, 292, 262, 278, 300)
      ..lineTo(0, 300)
      ..close();
    canvas.drawPath(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_skinDark, _skin],
        ).createShader(const Rect.fromLTWH(0, 0, 400, 300)),
    );
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _outline.withValues(alpha: 0.6),
    );
    // Burun deliği ipucu
    canvas.drawOval(
      const Rect.fromLTWH(360, 80, 14, 6),
      Paint()..color = _outline.withValues(alpha: 0.35),
    );
  }

  Path _cavityPath(double dy, TonguePose pose) {
    final open = 142.0 + dy * 0.6 - pose.lipToTeeth * 6;
    final p = Path()..moveTo(112, 300);
    p.lineTo(112, 120);
    _openSpline(p, const [
      Offset(112, 120),
      Offset(128, 98),
      Offset(178, 84),
      Offset(232, 78),
      Offset(272, 86),
      Offset(292, 99),
      Offset(303, 106),
      Offset(311, 118),
    ]);
    p.lineTo(332, 142); // üst kesici diş ucu
    p.lineTo(352, 136 - pose.lipRound * 2); // dudak arası (üst)
    p.lineTo(354 + pose.lipRound * 8, open + 8);
    p.lineTo(332, 148 + dy); // alt kesici diş ucu
    p.lineTo(318, 182 + dy);
    _openSpline(p, [
      Offset(318, 182 + dy),
      Offset(262, 206 + dy * 0.8),
      Offset(200, 224 + dy * 0.5),
      Offset(150, 252),
      Offset(130, 300),
    ]);
    return p..close();
  }

  void _tongue(Canvas canvas, TonguePose p, double dy, {bool ghost = false}) {
    final pts = [
      const Offset(126, 296),
      p.back,
      p.dorsum,
      p.blade,
      p.tip,
      p.under,
      Offset(p.under.dx - 42, math.max(p.under.dy + 24, 192 + dy * 0.85)),
      Offset(205, 218 + dy * 0.6),
      Offset(150, 252),
    ];
    final path = _closedSpline(pts);
    if (ghost) {
      final color = mainIsError ? _good : _bad;
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.18));
      _dashed(canvas, path, color, 2.5);
      return;
    }
    // Gölge
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: mainIsError
              ? const [Color(0xFFF59A9A), Color(0xFFC24545)]
              : const [_tongueTop, _tongueBottom],
        ).createShader(const Rect.fromLTWH(120, 90, 230, 210)),
    );
    // Sırt parlaklığı
    final hl = Path()..moveTo(p.back.dx + 6, p.back.dy + 6);
    _openSpline(hl, [
      Offset(p.back.dx + 6, p.back.dy + 6),
      p.dorsum + const Offset(0, 5),
      p.blade + const Offset(0, 4),
      p.tip + const Offset(-6, 5),
    ]);
    canvas.drawPath(
      hl,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF8E2A40).withValues(alpha: 0.6),
    );
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

  void _velum(Canvas canvas, {required bool nasal}) {
    // Yumuşak damak ve küçük dil
    final lowered = nasal ? 10.0 : 0.0;
    final v = Path()
      ..moveTo(128, 98)
      ..cubicTo(150, 88, 170, 86, 182, 86)
      ..cubicTo(172, 96, 162, 110 + lowered, 156, 122 + lowered)
      ..cubicTo(153, 128 + lowered, 147, 128 + lowered, 146, 121 + lowered)
      ..cubicTo(144, 110, 136, 102, 128, 98)
      ..close();
    canvas.drawPath(v, Paint()..color = const Color(0xFFE08C98));
    canvas.drawPath(
      v,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _outline.withValues(alpha: 0.5),
    );
    // Sert damak çizgisi
    final palate = Path()..moveTo(182, 84);
    _openSpline(palate, const [
      Offset(182, 84),
      Offset(232, 78),
      Offset(272, 86),
      Offset(292, 99),
    ]);
    canvas.drawPath(
      palate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFF4B9C1),
    );
  }

  void _teeth(Canvas canvas, double dy) {
    // Diş eti (alveol çıkıntısı)
    final gum = Path()
      ..moveTo(290, 99)
      ..quadraticBezierTo(300, 98, 308, 104)
      ..quadraticBezierTo(320, 100, 326, 106)
      ..lineTo(316, 112)
      ..quadraticBezierTo(304, 110, 290, 99)
      ..close();
    canvas.drawPath(gum, Paint()..color = _gum);

    Paint enamel(Rect r) => Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFFE9E4DA), Colors.white],
      ).createShader(r);
    final upper = Path()
      ..moveTo(310, 110)
      ..quadraticBezierTo(318, 104, 326, 106)
      ..lineTo(336, 138)
      ..quadraticBezierTo(334, 144, 330, 143)
      ..quadraticBezierTo(320, 132, 310, 120)
      ..close();
    final lower = Path()
      ..moveTo(316, 184 + dy)
      ..lineTo(326, 180 + dy)
      ..quadraticBezierTo(334, 160 + dy, 334, 149 + dy)
      ..quadraticBezierTo(330, 145 + dy, 327, 148 + dy)
      ..quadraticBezierTo(318, 160 + dy, 316, 184 + dy)
      ..close();
    final o = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF9E9488);
    canvas.drawPath(upper, enamel(const Rect.fromLTWH(308, 104, 30, 42)));
    canvas.drawPath(upper, o);
    canvas.drawPath(lower, enamel(Rect.fromLTWH(314, 144 + dy, 22, 42)));
    canvas.drawPath(lower, o);
  }

  void _lips(Canvas canvas, double dy, TonguePose p) {
    final r = p.lipRound * 9;
    final up = Path()
      ..moveTo(340, 98)
      ..cubicTo(356 + r, 104, 364 + r, 116, 360 + r, 130)
      ..cubicTo(356 + r, 138, 346, 140, 336, 138)
      ..quadraticBezierTo(334, 118, 340, 98)
      ..close();
    final lt = p.lipToTeeth;
    final top = 146 + dy - lt * 8;
    final low = Path()
      ..moveTo(334 - lt * 4, top + 2)
      ..cubicTo(348, top - 2 - lt * 2, 362 + r, top + 2, 364 + r, top + 16)
      ..cubicTo(364 + r, top + 34, 352, top + 42, 340, top + 44)
      ..quadraticBezierTo(332, top + 22, 334 - lt * 4, top + 2)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE59A9C), _lip],
      ).createShader(const Rect.fromLTWH(330, 96, 40, 110));
    final o = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _outline;
    for (final l in [up, low]) {
      canvas.drawPath(l, paint);
      canvas.drawPath(l, o);
    }
  }

  /// Havanın ağız içindeki yolu, dilin o anki biçimine göre.
  Path _flowPath(TonguePose p, double dy, {required bool lateral}) {
    final path = Path()..moveTo(122, 292);
    if (lateral) {
      _openSpline(path, [
        const Offset(122, 292),
        const Offset(124, 200),
        Offset(170, p.back.dy - 40),
        Offset(p.dorsum.dx, p.dorsum.dy - 12),
        Offset(p.blade.dx, p.blade.dy + 16),
        Offset(p.tip.dx - 6, p.tip.dy + 30),
        Offset(334, 144 + dy * 0.5),
        Offset(398, 140 + dy * 0.5),
      ]);
    } else {
      _openSpline(path, [
        const Offset(122, 292),
        const Offset(124, 200),
        Offset(170, p.back.dy - 40),
        Offset(p.dorsum.dx, p.dorsum.dy - 12),
        Offset(p.blade.dx, p.blade.dy - 9),
        Offset(p.tip.dx + 6, p.tip.dy - 5),
        Offset(334, 144 + dy * 0.5),
        Offset(398, 140 + dy * 0.5),
      ]);
    }
    return path;
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
      _pill(
        canvas,
        'hava yanlardan',
        Offset(p.tip.dx - 20, p.tip.dy + 64),
        _flow,
      );
    }
  }

  void _nasalFlow(Canvas canvas, double amount) {
    final path = Path()..moveTo(122, 292);
    _openSpline(path, const [
      Offset(122, 292),
      Offset(122, 160),
      Offset(124, 92),
      Offset(170, 60),
      Offset(300, 56),
      Offset(368, 84),
      Offset(398, 96),
    ]);
    final m = path.computeMetrics().first;
    for (var i = 0; i < 12; i++) {
      final u = ((t * 3) + i / 12) % 1.0;
      final tan = m.getTangentForOffset(u * m.length);
      if (tan == null) continue;
      canvas.drawCircle(
        tan.position,
        2.6,
        Paint()
          ..color = _flow.withValues(alpha: amount * math.sin(math.pi * u)),
      );
    }
    _pill(canvas, 'hava burundan', const Offset(230, 40), _flow);
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

  void _voicing(Canvas canvas) {
    const c = Offset(126, 282);
    final pulse = (t * 14) % 1.0;
    for (var k = 0; k < 3; k++) {
      final r = 6.0 + 7 * ((pulse + k / 3) % 1.0);
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
    if (labels) {
      _pill(
        canvas,
        'ses telleri titrer',
        const Offset(18, 262),
        const Color(0xFFFFC107),
      );
    }
  }

  void _uvulaBuzz(Canvas canvas) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _bad;
    for (var k = 0; k < 3; k++) {
      final x = 132.0 - k * 6 + math.sin(t * 90 + k) * 2;
      canvas.drawLine(Offset(x, 118), Offset(x - 4, 130), p);
    }
  }

  void _labels(Canvas canvas, TonguePose p) {
    final line = Paint()
      ..color = const Color(0xFF6D4C41).withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    void label(String text, Offset at, Offset target) {
      canvas.drawLine(at, target, line);
      canvas.drawCircle(target, 2.5, Paint()..color = line.color);
      _pill(canvas, text, at, const Color(0xFF6D4C41));
    }

    label('damak', const Offset(214, 30), const Offset(232, 79));
    label('diş eti', const Offset(276, 24), const Offset(299, 101));
    label('küçük dil', const Offset(128, 52), const Offset(151, 120));
    label('dil ucu', Offset(p.tip.dx - 110, p.tip.dy + 40), p.tip);
  }

  void _pill(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.computeLuminance() > 0.5
              ? const Color(0xFF263238)
              : Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(at.dx - 6, at.dy - 3, tp.width + 12, tp.height + 6),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.9));
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant ArticulationPainter old) =>
      old.t != t ||
      old.main != main ||
      old.ghost != ghost ||
      old.labels != labels ||
      old.mainIsError != mainIsError;
}

/// Animasyonun tek bir karesi (küçük önizlemeler ve görsel testler için).
class ArticulationStill extends StatelessWidget {
  final String correct;
  final String? error;
  final double t;
  final bool labels;
  final bool showError;

  const ArticulationStill({
    super.key,
    required this.correct,
    this.error,
    required this.t,
    this.labels = false,
    this.showError = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          painter: ArticulationPainter(
            t: t,
            main: articulations[showError ? error! : correct]!,
            ghost: !showError && error != null ? articulations[error!] : null,
            mainIsError: showError,
            labels: labels,
          ),
        ),
      ),
    );
  }
}
