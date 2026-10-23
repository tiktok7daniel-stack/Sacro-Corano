import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../domain/qibla.dart';
import '../prayer/prayer_screen.dart';

/// Compass-based qibla finder. Uses the fused rotation-vector sensor via
/// flutter_compass, smooths the heading on the circle, pulses and vibrates
/// once when aligned (±3°), and falls back to a static bearing dial when the
/// device has no magnetometer.
class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  StreamSubscription<CompassEvent>? _sub;
  double? _heading;

  /// Unwrapped heading for the dial animation (avoids spinning at 359°→0°).
  double _rotation = 0;
  double? _accuracy;
  bool _noSensor = false;
  bool _aligned = false;

  @override
  void initState() {
    super.initState();
    final events = FlutterCompass.events;
    if (events == null) {
      _noSensor = true;
    } else {
      _sub = events.listen((e) {
        final h = e.heading;
        if (h == null || h.isNaN) {
          setState(() => _noSensor = true);
          return;
        }
        final next = _heading == null ? h : smoothHeading(_heading!, h, factor: 0.2);
        setState(() {
          _rotation += _heading == null ? next : angleDelta(_heading!, next);
          _heading = (next + 360) % 360;
          _accuracy = e.accuracy;
        });
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    if (!s.hasLocation) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.location_off_rounded, title: context.tr('qibla_needs_location')),
        floatingActionButton: FloatingActionButton.extended(onPressed: () => pickCity(context, ref), label: Text(context.tr('choose_city'))),
      );
    }
    final bearing = qiblaBearing(s.lat!, s.lng!);
    final km = distanceToKaabaKm(s.lat!, s.lng!);
    final heading = _heading ?? 0;
    final delta = angleDelta(heading, bearing);
    final aligned = !_noSensor && _heading != null && delta.abs() <= 3;
    if (aligned && !_aligned && s.haptics) HapticFeedback.heavyImpact();
    _aligned = aligned;
    final m = Motion.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 40), children: [
        PageTitle(context.tr('qibla'), subtitle: s.placeName),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1,
          child: Stack(alignment: Alignment.center, children: [
            AnimatedContainer(
              duration: m.medium,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: aligned ? [BoxShadow(color: Brand.gold.withValues(alpha: 0.5), blurRadius: 60, spreadRadius: 8)] : [],
              ),
            ),
            // Dial rotates opposite to the heading so north stays north.
            TweenAnimationBuilder<double>(
              tween: Tween(end: _noSensor ? 0 : -_rotation),
              duration: m.short,
              builder: (_, v, child) => Transform.rotate(angle: v * math.pi / 180, child: child),
              child: CustomPaint(size: Size.infinite, painter: _DialPainter(bearing: bearing, northLabel: context.isAr ? 'ش' : 'N')),
            ),
            Icon(Icons.navigation_rounded, size: 64, color: aligned ? Brand.gold : Brand.textHigh),
          ]),
        ),
        const SizedBox(height: 20),
        Center(
          child: AnimatedSwitcher(
            duration: m.short,
            child: Text(
              _noSensor
                  ? context.tr('qibla_no_sensor', {'deg': bearing.round()})
                  : aligned
                      ? context.tr('qibla_aligned')
                      : context.tr(delta > 0 ? 'qibla_turn_right' : 'qibla_turn_left', {'deg': delta.abs().round()}),
              key: ValueKey('${aligned}_${delta.round()}'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: aligned ? Brand.gold : null),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Stat(label: context.tr('qibla_bearing'), value: '${context.num(bearing.toStringAsFixed(1))}°')),
          const SizedBox(width: 12),
          Expanded(child: _Stat(label: context.tr('distance_kaaba'), value: context.tr('km_n', {'n': km.round()}))),
        ]),
        const SizedBox(height: 12),
        if (!_noSensor && (_accuracy ?? 0) > 30)
          AppCard(
            color: Colors.orange.withValues(alpha: 0.12),
            child: Row(children: [
              const Icon(Icons.screen_rotation_alt_rounded, color: Colors.orangeAccent),
              const SizedBox(width: 12),
              Expanded(child: Text(context.tr('calibrate_hint'))),
            ]),
          ),
        const SizedBox(height: 12),
        Text(context.tr('qibla_tip'), style: const TextStyle(color: Brand.textLow, fontSize: 12), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Brand.gold)),
          Text(label, style: const TextStyle(color: Brand.textMid, fontSize: 12)),
        ]),
      );
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.bearing, required this.northLabel});
  final double bearing;
  final String northLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = Brand.surface);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Brand.outline,
    );
    final tick = Paint()..color = Brand.textLow;
    for (var i = 0; i < 72; i++) {
      final a = i * 5 * math.pi / 180;
      final len = i % 18 == 0 ? 18.0 : (i % 2 == 0 ? 10.0 : 5.0);
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(c + dir * (r - len), c + dir * r, tick..strokeWidth = i % 18 == 0 ? 3 : 1.2);
    }
    final tp = TextPainter(
      text: TextSpan(text: northLabel, style: const TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + Offset(-tp.width / 2, -r + 22));

    // Kaaba marker at the qibla bearing.
    final a = bearing * math.pi / 180;
    final dir = Offset(math.sin(a), -math.cos(a));
    canvas.drawLine(
      c,
      c + dir * (r - 34),
      Paint()
        ..color = Brand.gold.withValues(alpha: 0.6)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final k = c + dir * (r - 34);
    canvas.save();
    canvas.translate(k.dx, k.dy);
    canvas.rotate(a);
    final rect = Rect.fromCenter(center: Offset.zero, width: 30, height: 30);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = const Color(0xFF111111));
    canvas.drawRect(Rect.fromLTWH(-15, -8, 30, 5), Paint()..color = Brand.gold);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.bearing != bearing;
}
