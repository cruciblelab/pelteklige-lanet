import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/sound.dart';

/// Ağzın yandan kesit görünümü: dil, damak, dişler, dudaklar ve hava akışı.
///
/// Döngü: dinlenme → hedef konum → tutma (hava akar / dil titrer) → dinlenme.
class MouthAnimation extends StatefulWidget {
  final ArticulationPose pose;
  final Airflow airflow;
  final bool voiced;
  final bool showLabels;
  final Color? tongueColor;

  const MouthAnimation({
    super.key,
    required this.pose,
    required this.airflow,
    required this.voiced,
    this.showLabels = true,
    this.tongueColor,
  });

  @override
  State<MouthAnimation> createState() => _MouthAnimationState();
}

class _MouthAnimationState extends State<MouthAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  bool _paused = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        // Hedef konumda dondur, incelemek kolay olsun.
        _c.stop();
        _c.value = 0.45;
      } else {
        _c.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AspectRatio(
        aspectRatio: 320 / 240,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: _MouthPainter(
                    t: _c.value,
                    target: widget.pose,
                    airflow: widget.airflow,
                    voiced: widget.voiced,
                    showLabels: widget.showLabels,
                    tongueColor: widget.tongueColor ?? const Color(0xFFE5677A),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Icon(
                _paused ? Icons.play_circle : Icons.pause_circle,
                color: Colors.white70,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MouthPainter extends CustomPainter {
  final double t;
  final ArticulationPose target;
  final Airflow airflow;
  final bool voiced;
  final bool showLabels;
  final Color tongueColor;

  _MouthPainter({
    required this.t,
    required this.target,
    required this.airflow,
    required this.voiced,
    required this.showLabels,
    required this.tongueColor,
  });

  static const _tissue = Color(0xFFF7D9C9);
  static const _outline = Color(0xFFB9826F);
  static const _cavity = Color(0xFF6E2A36);
  static const _air = Color(0xFF7FD3FF);

  double _ease(double x) => Curves.easeInOut.transform(x.clamp(0.0, 1.0));

  /// Zaman çizelgesine göre o anki ağız konumu.
  (ArticulationPose pose, double airAmount) _frame() {
    final rest = ArticulationPose.rest;
    if (t < 0.22) {
      return (ArticulationPose.lerp(rest, target, _ease(t / 0.22)), 0);
    }
    if (t < 0.75) {
      final hold = (t - 0.22) / 0.53;
      var p = target;
      var air = 1.0;
      switch (airflow) {
        case Airflow.trill:
          // Dil ucu diş etine hızlı hızlı vurur.
          final tap = math.sin(hold * 2 * math.pi * 7);
          p = ArticulationPose(
            tipX: target.tipX,
            tipY: target.tipY + 7 * tap,
            bodyX: target.bodyX,
            bodyY: target.bodyY,
            jaw: target.jaw,
            lipRound: target.lipRound,
          );
          air = tap > 0 ? 1 : 0.3;
        case Airflow.burst:
          // Önce hava tutulur, sonra dil bırakılır ve hava patlar.
          if (hold < 0.45) {
            air = 0;
          } else {
            final r = _ease((hold - 0.45) / 0.25);
            p = ArticulationPose.lerp(target, rest, r * 0.45);
            air = 1;
          }
        case Airflow.central:
        case Airflow.lateral:
          break;
      }
      return (p, air);
    }
    return (ArticulationPose.lerp(target, rest, _ease((t - 0.75) / 0.25)), 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 320, size.height / 240);
    canvas.save();
    canvas.translate((size.width - 320 * s) / 2, (size.height - 240 * s) / 2);
    canvas.scale(s);

    final (pose, air) = _frame();
    final jo = pose.jaw * 40; // çene aşağı kayması
    final r = pose.lipRound * 12; // dudak öne uzaması

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _outline;

    // Baş dokusu
    final bg = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 320, 240),
      const Radius.circular(16),
    );
    canvas.drawRRect(bg, Paint()..color = _tissue);
    canvas.clipRRect(bg);

    // Ağız boşluğu
    final cavity = Path()
      ..moveTo(60, 240)
      ..lineTo(60, 120)
      ..quadraticBezierTo(62, 82, 100, 72)
      ..quadraticBezierTo(160, 58, 200, 72)
      ..quadraticBezierTo(214, 78, 222, 90)
      ..lineTo(238, 124)
      ..lineTo(262 + r, 121)
      ..lineTo(262 + r, 135 + jo)
      ..lineTo(236, 130 + jo)
      ..lineTo(226, 165 + jo)
      ..quadraticBezierTo(170, 200 + jo, 110, 215 + jo)
      ..lineTo(95, 240)
      ..close();
    canvas.drawPath(cavity, Paint()..color = _cavity);

    // Dil (ağız boşluğunun dışına taşmasın diye kırpılır)
    final tongue = Path()
      ..moveTo(78, 240)
      ..cubicTo(
        70,
        190,
        pose.bodyX - 60,
        pose.bodyY - 4,
        pose.bodyX,
        pose.bodyY,
      )
      ..cubicTo(
        pose.bodyX + 30,
        pose.bodyY,
        pose.tipX - 25,
        pose.tipY - 8,
        pose.tipX,
        pose.tipY,
      )
      ..quadraticBezierTo(
        pose.tipX + 5,
        pose.tipY + 7,
        pose.tipX - 5,
        pose.tipY + 13,
      )
      ..cubicTo(pose.tipX - 30, pose.tipY + 30, 200, 190 + jo, 170, 200 + jo)
      ..lineTo(130, 240)
      ..close();
    canvas.save();
    canvas.clipPath(cavity);
    canvas.drawPath(tongue, Paint()..color = tongueColor);
    canvas.drawPath(
      tongue,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.black.withValues(alpha: 0.25),
    );
    // Dil ortasındaki oluk çizgisi
    final groove = Path()
      ..moveTo(pose.bodyX - 30, pose.bodyY + 14)
      ..quadraticBezierTo(
        pose.bodyX + 20,
        pose.bodyY + 8,
        pose.tipX - 12,
        pose.tipY + 6,
      );
    canvas.drawPath(
      groove,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.15),
    );
    canvas.restore();

    // Dişler
    final teeth = Paint()..color = Colors.white;
    final upperTooth = Path()
      ..moveTo(222, 90)
      ..lineTo(232, 92)
      ..lineTo(239, 124)
      ..lineTo(230, 126)
      ..close();
    final lowerTooth = Path()
      ..moveTo(228, 131 + jo)
      ..lineTo(237, 129 + jo)
      ..lineTo(234, 160 + jo)
      ..lineTo(226, 160 + jo)
      ..close();
    for (final p in [upperTooth, lowerTooth]) {
      canvas.drawPath(p, teeth);
      canvas.drawPath(p, outline);
    }

    // Dudaklar
    final upperLip = Path()
      ..moveTo(236, 72)
      ..quadraticBezierTo(268 + r, 90, 262 + r, 120)
      ..quadraticBezierTo(250 + r / 2, 128, 238, 124)
      ..close();
    final lowerLip = Path()
      ..moveTo(237, 132 + jo)
      ..quadraticBezierTo(250 + r / 2, 128 + jo, 262 + r, 136 + jo)
      ..quadraticBezierTo(268 + r, 168 + jo, 236, 182 + jo)
      ..close();
    final lipPaint = Paint()..color = const Color(0xFFE9A79A);
    for (final p in [upperLip, lowerLip]) {
      canvas.drawPath(p, lipPaint);
      canvas.drawPath(p, outline);
    }

    // Hava akışı
    if (air > 0) _drawAir(canvas, pose, jo, r, air);

    // Ses telleri titreşimi
    if (voiced && t > 0.22 && t < 0.75) {
      final wave = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFD54F);
      for (var k = 0; k < 3; k++) {
        final path = Path();
        final y0 = 200.0 + k * 10;
        path.moveTo(14, y0);
        for (var x = 14.0; x <= 50; x += 2) {
          path.lineTo(x, y0 + 3 * math.sin((x / 6) + t * 2 * math.pi * 30 + k));
        }
        canvas.drawPath(path, wave);
      }
      if (showLabels) {
        _label(
          canvas,
          'titreşim',
          const Offset(12, 182),
          const Color(0xFF8D6E00),
        );
      }
    }

    if (showLabels) {
      _label(canvas, 'damak', const Offset(130, 44), _outline);
      _label(canvas, 'diş eti', const Offset(176, 30), _outline);
      canvas.drawLine(const Offset(198, 44), const Offset(212, 80), outline);
      _label(canvas, 'dudaklar', const Offset(256, 52), _outline);
      _label(
        canvas,
        'dil',
        Offset(pose.bodyX - 20, pose.bodyY + 26),
        Colors.white.withValues(alpha: 0.9),
      );
    }
    canvas.restore();
  }

  void _drawAir(
    Canvas canvas,
    ArticulationPose pose,
    double jo,
    double r,
    double amount,
  ) {
    final path = Path();
    switch (airflow) {
      case Airflow.central:
      case Airflow.trill:
        path
          ..moveTo(pose.bodyX + 10, pose.bodyY - 10)
          ..quadraticBezierTo(
            pose.tipX - 10,
            pose.tipY - 12,
            pose.tipX + 6,
            pose.tipY - 4,
          )
          ..quadraticBezierTo(238, 126 + jo / 3, 300 + r, 128 + jo / 2);
      case Airflow.lateral:
        // Dil ucu kapalı; hava yanlardan, dilin altından dolanır.
        path
          ..moveTo(pose.bodyX + 10, pose.bodyY - 2)
          ..quadraticBezierTo(pose.tipX - 20, pose.tipY + 30, 236, 127 + jo / 2)
          ..lineTo(300 + r, 128 + jo / 2);
      case Airflow.burst:
        path
          ..moveTo(pose.tipX - 4, pose.tipY + 4)
          ..quadraticBezierTo(238, 126 + jo / 3, 300 + r, 128 + jo / 2);
    }
    final dash = airflow == Airflow.lateral;
    final paint = Paint()
      ..color = _air.withValues(alpha: (dash ? 0.6 : 0.95) * amount);
    for (final metric in path.computeMetrics()) {
      const n = 9;
      for (var i = 0; i < n; i++) {
        final f = ((t * 6) + i / n) % 1.0;
        final tan = metric.getTangentForOffset(f * metric.length);
        if (tan == null) continue;
        canvas.drawCircle(tan.position, 2.2 + 1.6 * f, paint);
      }
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final pb =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(fontSize: 11, fontFamily: 'Roboto'),
          )
          ..pushStyle(ui.TextStyle(color: color, fontWeight: FontWeight.w600))
          ..addText(text);
    final p = pb.build()..layout(const ui.ParagraphConstraints(width: 120));
    canvas.drawParagraph(p, at);
  }

  @override
  bool shouldRepaint(covariant _MouthPainter old) =>
      old.t != t || old.target != target;
}
