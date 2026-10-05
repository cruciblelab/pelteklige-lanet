import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart';

import 'articulations.dart';

// --- Zaman çizelgesi ---------------------------------------------------------

double ease(double x) => Curves.easeInOutCubic.transform(x.clamp(0.0, 1.0));

int stepAt(Motion m, double t) => switch (m) {
  Motion.tap => t < 0.36 ? 0 : (t < 0.52 ? 1 : 2),
  Motion.stop => t < 0.22 ? 0 : (t < 0.5 ? 1 : 2),
  Motion.hold => t < 0.22 ? 0 : (t < 0.48 ? 1 : 2),
};

class Frame {
  final TonguePose pose;
  final double air; // 0..1
  final double contact; // temas yoğunluğu 0..1
  final double ripple; // dalga ilerlemesi 0..1, <0 yok
  final bool burst;
  final bool pressure; // kapanma sırasında hava basıncı
  const Frame(
    this.pose,
    this.air,
    this.contact,
    this.ripple, {
    this.burst = false,
    this.pressure = false,
  });
}

Frame frameAt(Articulation a, double t) {
  final rest = restPose;
  switch (a.motion) {
    case Motion.hold:
      if (t < 0.22) {
        return Frame(TonguePose.lerp(rest, a.pose, ease(t / 0.22)), 0, 0, -1);
      }
      if (t < 0.74) {
        final c = a.contact != null ? 1.0 : 0.0;
        final rip = a.contact != null && t < 0.4 ? (t - 0.22) / 0.18 : -1.0;
        return Frame(a.pose, ease((t - 0.22) / 0.08), c, rip);
      }
      final r = ease((t - 0.74) / 0.26);
      return Frame(TonguePose.lerp(a.pose, rest, r), 1 - r, 0, -1);
    case Motion.tap:
      final pre = a.release!;
      if (t < 0.3) {
        return Frame(
          TonguePose.lerp(rest, pre, ease(t / 0.3)),
          ease((t - 0.15) / 0.15),
          0,
          -1,
        );
      }
      if (t < 0.72) {
        // Vuruş: 0.38–0.48 arasında yarım sinüs (çok kısa temas).
        final u = ((t - 0.38) / 0.10).clamp(0.0, 1.0);
        final c = math.sin(math.pi * u);
        final rip = t >= 0.42 && t < 0.62 ? (t - 0.42) / 0.20 : -1.0;
        return Frame(TonguePose.lerp(pre, a.pose, c), 1 - 0.85 * c, c, rip);
      }
      final r = ease((t - 0.72) / 0.28);
      return Frame(TonguePose.lerp(pre, rest, r), 1 - r, 0, -1);
    case Motion.stop:
      final rel = a.release ?? a.pose;
      if (t < 0.22) {
        return Frame(TonguePose.lerp(rest, a.pose, ease(t / 0.22)), 0, 0, -1);
      }
      if (t < 0.5) {
        final rip = t < 0.4 ? (t - 0.22) / 0.18 : -1.0;
        return Frame(a.pose, 0, 1, rip, pressure: true);
      }
      if (t < 0.74) {
        final r = ease((t - 0.5) / 0.08);
        return Frame(
          TonguePose.lerp(a.pose, rel, r),
          1 - ease((t - 0.62) / 0.12),
          1 - r,
          -1,
          burst: true,
        );
      }
      final r = ease((t - 0.74) / 0.26);
      return Frame(TonguePose.lerp(rel, rest, r), 0, 0, -1);
  }
}

// --- Geometri yardımcıları ----------------------------------------------------

/// Kapalı Catmull-Rom eğrisi (noktalardan geçen yumuşak kapalı şekil).
Path closedSpline(List<Offset> p) {
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
void openSpline(Path path, List<Offset> p) {
  for (var i = 0; i < p.length - 1; i++) {
    final p0 = i == 0 ? p[0] : p[i - 1], p1 = p[i];
    final p2 = p[i + 1], p3 = i + 2 < p.length ? p[i + 2] : p[i + 1];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
}
