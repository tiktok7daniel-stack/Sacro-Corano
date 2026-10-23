import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/brand.dart';

/// The Mishkah mark: a mihrab niche (مِشكاة) holding a lamp whose light is an
/// eight-pointed star. Geometry matches branding/logo.svg (1024 grid).
///
/// [progress] 0..1 drives the splash animation: the niche is drawn, the lamp
/// glass fades in, then the star turns and blooms.
class MishkahLogo extends StatelessWidget {
  const MishkahLogo({super.key, this.size = 96, this.progress = 1, this.background = true});
  final double size;
  final double progress;
  final bool background;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Mishkah',
        image: true,
        child: CustomPaint(
          size: Size.square(size),
          painter: _LogoPainter(progress, background),
        ),
      );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.t, this.background);
  final double t;
  final bool background;

  static double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 1024;
    canvas.scale(s);

    if (background) {
      final rrect = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 1024, 1024), const Radius.circular(232));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -0.1),
            radius: 0.85,
            colors: [Color(0xFF15404A), Color(0xFF0C1A22), Brand.ink],
            stops: [0, 0.6, 1],
          ).createShader(const Rect.fromLTWH(0, 0, 1024, 1024)),
      );
    }

    final gold = Paint()
      ..color = Brand.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1) Niche outline, drawn progressively.
    final arch = Path()
      ..moveTo(300, 830)
      ..lineTo(300, 480)
      ..cubicTo(300, 330, 410, 240, 512, 182)
      ..cubicTo(614, 240, 724, 330, 724, 480)
      ..lineTo(724, 830);
    final archT = _seg(t, 0, 0.45);
    for (final m in arch.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * archT), gold);
    }
    final baseT = _seg(t, 0.3, 0.5);
    if (baseT > 0) {
      canvas.drawLine(Offset(512 - 250 * baseT, 830), Offset(512 + 250 * baseT, 830), gold);
    }

    // 2) Lamp chain + glass.
    final glassT = _seg(t, 0.4, 0.7);
    if (glassT > 0) {
      final chain = Paint()
        ..color = Brand.gold.withValues(alpha: glassT)
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(512, 300), Offset(512, 300 + 105 * glassT), chain);

      final glass = Path()
        ..moveTo(462, 420)
        ..lineTo(562, 420)
        ..cubicTo(660, 452, 668, 650, 512, 704)
        ..cubicTo(356, 650, 364, 452, 462, 420)
        ..close();
      canvas.drawPath(
        glass,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Brand.tealBright.withValues(alpha: 0.35 * glassT),
              Brand.teal.withValues(alpha: 0.75 * glassT),
            ],
          ).createShader(const Rect.fromLTWH(360, 420, 304, 284)),
      );
      canvas.drawPath(
        glass,
        Paint()
          ..color = Brand.gold.withValues(alpha: glassT)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 3) Star of light: glow + eight-pointed star (two squares).
    final starT = _seg(t, 0.6, 1.0);
    if (starT > 0) {
      const c = Offset(512, 568);
      final eased = Curves.easeOutBack.transform(starT);
      canvas.drawCircle(
        c,
        150 * eased,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFE6A8).withValues(alpha: 0.55 * starT),
            const Color(0x00FFE6A8),
          ]).createShader(Rect.fromCircle(center: c, radius: 150)),
      );
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate((1 - starT) * math.pi / 2);
      canvas.scale(eased);
      final star = Paint()..color = const Color(0xFFF3D58F);
      const r = 82.0;
      final sq = Path()..addRect(Rect.fromCenter(center: Offset.zero, width: r * 1.42, height: r * 1.42));
      canvas.drawPath(sq, star);
      canvas.rotate(math.pi / 4);
      canvas.drawPath(sq, star);
      canvas.drawCircle(Offset.zero, 24, Paint()..color = Brand.teal);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.t != t || old.background != background;
}
