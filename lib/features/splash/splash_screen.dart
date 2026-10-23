import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/logo.dart';
import '../shell/home_shell.dart';

/// Animated splash: the niche is drawn, the lamp lights, the name fades in
/// over a slowly drifting star field. The mushaf loads in parallel, so the
/// animation never adds waiting time beyond what loading needs.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logo = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logo.status == AnimationStatus.dismissed) {
      if (Motion.of(context).reduced) {
        _logo.value = 1;
        _drift.stop();
      } else {
        _logo.forward();
      }
      _go();
    }
  }

  Future<void> _go() async {
    final started = DateTime.now();
    final minShow = Motion.of(context).reduced ? Duration.zero : const Duration(milliseconds: 1700);
    await ref.read(quranProvider.future);
    final left = minShow - DateTime.now().difference(started);
    if (left > Duration.zero) await Future<void>.delayed(left);
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, _, _) => const HomeShell(),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _logo.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _drift,
            builder: (_, _) => CustomPaint(painter: _StarField(_drift.value)),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _logo,
              builder: (context, _) {
                final nameT = Curves.easeOut.transform(((_logo.value - 0.55) / 0.45).clamp(0.0, 1.0));
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MishkahLogo(size: 168, progress: _logo.value, background: false),
                    const SizedBox(height: 28),
                    Opacity(
                      opacity: nameT,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - nameT)),
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (r) => const LinearGradient(
                                colors: [Brand.gold, Color(0xFFF3DDA8), Brand.gold],
                              ).createShader(r),
                              child: const Text(
                                'مِشكاة',
                                style: TextStyle(fontFamily: Brand.naskhFont, fontSize: 52, color: Colors.white, height: 1.1),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'MISHKAH',
                              style: TextStyle(
                                fontFamily: Brand.uiFont,
                                letterSpacing: 8,
                                fontSize: 13,
                                color: Brand.textMid.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _logo, curve: const Interval(0.7, 1)),
              child: const Text(
                '﴿ ٱللَّهُ نُورُ ٱلسَّمَٰوَٰتِ وَٱلۡأَرۡضِۚ ﴾',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: Brand.quranFont, fontSize: 20, color: Brand.textMid),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarField extends CustomPainter {
  _StarField(this.t);
  final double t;
  static final _rand = math.Random(7);
  static final _stars = List.generate(70, (_) => (_rand.nextDouble(), _rand.nextDouble(), _rand.nextDouble()));

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(colors: [Brand.teal.withValues(alpha: 0.28), Colors.transparent])
          .createShader(Rect.fromCircle(center: size.center(Offset.zero), radius: size.width * 0.8));
    canvas.drawRect(Offset.zero & size, glow);
    for (final (x, y, z) in _stars) {
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin((t + z) * 2 * math.pi));
      final dy = (y + t * 0.04 * (0.5 + z)) % 1.0;
      canvas.drawCircle(
        Offset(x * size.width, dy * size.height),
        0.6 + z * 1.4,
        Paint()..color = Brand.gold.withValues(alpha: 0.15 + 0.45 * twinkle * z),
      );
    }
  }

  @override
  bool shouldRepaint(_StarField old) => old.t != t;
}
