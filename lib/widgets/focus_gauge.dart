import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "R ←●→ L" ibresi: söyleyişin doğru sese mi, kişinin hatasına mı yakın
/// olduğunu gösterir. [ratio] 1 = tamamen doğru (solda), 0 = tamamen hata.
class FocusGauge extends StatelessWidget {
  final double ratio;
  final String correctLabel;
  final String errorLabel;
  final double errorBelow;
  final double correctFrom;

  const FocusGauge({
    super.key,
    required this.ratio,
    required this.correctLabel,
    required this.errorLabel,
    this.errorBelow = 0.2,
    this.correctFrom = 0.7,
  });

  static const good = Color(0xFF14A38B);
  static const bad = Color(0xFFE0663D);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: ratio.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.elasticOut,
      builder: (context, v, _) => SizedBox(
        height: 86,
        child: CustomPaint(
          painter: _GaugePainter(
            ratio: v,
            correctLabel: correctLabel,
            errorLabel: errorLabel,
            errorBelow: errorBelow,
            correctFrom: correctFrom,
            text: Theme.of(context).colorScheme.onSurface,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double ratio;
  final String correctLabel, errorLabel;
  final double errorBelow, correctFrom;
  final Color text;

  _GaugePainter({
    required this.ratio,
    required this.correctLabel,
    required this.errorLabel,
    required this.errorBelow,
    required this.correctFrom,
    required this.text,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const badge = 46.0;
    final left = badge + 10, right = size.width - badge - 10;
    final y = size.height / 2;
    final w = right - left;
    // Konum: soldan sağa = doğrudan hataya.
    double xAt(double r) => left + (1 - r) * w;

    // İz: yeşil → gri → turuncu
    final track = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, y - 9, right, y + 9),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..shader = LinearGradient(
          colors: [
            FocusGauge.good,
            FocusGauge.good.withValues(alpha: 0.75),
            const Color(0xFFB0BEC5),
            FocusGauge.bad.withValues(alpha: 0.75),
            FocusGauge.bad,
          ],
          stops: [0, 1 - correctFrom, 0.5, 1 - errorBelow, 1],
        ).createShader(track.outerRect),
    );
    // Bölge çizgileri
    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2;
    for (final r in [correctFrom, errorBelow]) {
      canvas.drawLine(Offset(xAt(r), y - 9), Offset(xAt(r), y + 9), tick);
    }

    _badge(
      canvas,
      Offset(badge / 2 + 2, y),
      correctLabel,
      FocusGauge.good,
      highlight: ratio >= correctFrom,
    );
    _badge(
      canvas,
      Offset(size.width - badge / 2 - 2, y),
      errorLabel,
      FocusGauge.bad,
      highlight: ratio < errorBelow,
    );

    // İbre
    final x = xAt(ratio);
    final c = Color.lerp(FocusGauge.bad, FocusGauge.good, ratio)!;
    canvas.drawCircle(
      Offset(x, y + 2),
      17,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(Offset(x, y), 16, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x, y), 11, Paint()..color = c);
    final tp = TextPainter(
      text: TextSpan(
        text: '$correctLabel %${(ratio * 100).round()}',
        style: TextStyle(
          fontFamily: 'Roboto',
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y + 20));
  }

  void _badge(
    Canvas canvas,
    Offset c,
    String label,
    Color color, {
    required bool highlight,
  }) {
    final r = highlight ? 23.0 : 20.0;
    if (highlight) {
      canvas.drawCircle(
        c,
        r + 6,
        Paint()..color = color.withValues(alpha: 0.25),
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()..color = highlight ? color : color.withValues(alpha: 0.18),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: highlight ? Colors.white : color,
          fontSize: label.length > 1 ? 16 : 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: r * 2);
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.ratio != ratio ||
      old.correctLabel != correctLabel ||
      old.errorLabel != errorLabel;
}

/// Büyük mikrofon düğmesi: dinlerken ses düzeyiyle nabız gibi atan halka,
/// incelerken dönen yay.
class MicButton extends StatefulWidget {
  final bool listening;
  final bool busy;
  final double level;
  final VoidCallback? onTap;
  final double size;

  const MicButton({
    super.key,
    required this.listening,
    required this.busy,
    required this.level,
    required this.onTap,
    this.size = 96,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didUpdateWidget(MicButton old) {
    super.didUpdateWidget(old);
    final animate = widget.busy || widget.listening;
    if (animate && !_spin.isAnimating) _spin.repeat();
    if (!animate && _spin.isAnimating) _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = widget.size;
    final color = widget.listening ? const Color(0xFFE53935) : scheme.primary;
    return SizedBox(
      width: s * 1.6,
      height: s * 1.6,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) => CustomPaint(
          painter: _MicRing(
            t: _spin.value,
            level: widget.level,
            listening: widget.listening,
            busy: widget.busy,
            color: color,
          ),
          child: Center(
            child: Material(
              color: color,
              shape: const CircleBorder(),
              elevation: widget.listening ? 8 : 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.busy ? null : widget.onTap,
                child: SizedBox(
                  width: s,
                  height: s,
                  child: Icon(
                    widget.busy
                        ? Icons.hourglass_top
                        : widget.listening
                        ? Icons.stop_rounded
                        : Icons.mic,
                    color: Colors.white,
                    size: s * 0.45,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MicRing extends CustomPainter {
  final double t, level;
  final bool listening, busy;
  final Color color;

  _MicRing({
    required this.t,
    required this.level,
    required this.listening,
    required this.busy,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.width / 1.6 / 2;
    if (listening) {
      for (var k = 0; k < 3; k++) {
        final p = (t + k / 3) % 1.0;
        canvas.drawCircle(
          c,
          base + 4 + p * (10 + 26 * level),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = color.withValues(alpha: (1 - p) * 0.5),
        );
      }
      canvas.drawCircle(
        c,
        base + 4 + 20 * level,
        Paint()..color = color.withValues(alpha: 0.18),
      );
    }
    if (busy) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: base + 8),
        t * 2 * math.pi,
        math.pi * 0.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MicRing old) => true;
}
