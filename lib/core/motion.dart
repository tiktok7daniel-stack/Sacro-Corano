import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Central animation policy. All animated widgets ask [Motion.of] for
/// durations so "reduce motion" (app setting or Android's "remove
/// animations") turns movement into instant state changes.
class Motion {
  const Motion._(this.reduced);
  final bool reduced;

  static Motion of(BuildContext context) {
    final system = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    var user = false;
    try {
      user = ProviderScope.containerOf(context, listen: false).read(settingsProvider).reduceMotion;
    } on StateError {
      // Outside a ProviderScope (isolated widget previews): system setting only.
    }
    return Motion._(system || user);
  }

  Duration get short => reduced ? Duration.zero : const Duration(milliseconds: 180);
  Duration get medium => reduced ? Duration.zero : const Duration(milliseconds: 320);
  Duration get long => reduced ? Duration.zero : const Duration(milliseconds: 600);
  Duration scale(Duration d) => reduced ? Duration.zero : d;

  static const emphasized = Cubic(0.2, 0.0, 0, 1.0);
}

/// Light haptic tick honouring the user's setting.
void haptic(WidgetRef ref, [HapticKind kind = HapticKind.light]) {
  if (!ref.read(settingsProvider).haptics) return;
  switch (kind) {
    case HapticKind.light:
      HapticFeedback.lightImpact();
    case HapticKind.medium:
      HapticFeedback.mediumImpact();
    case HapticKind.heavy:
      HapticFeedback.heavyImpact();
    case HapticKind.selection:
      HapticFeedback.selectionClick();
  }
}

enum HapticKind { light, medium, heavy, selection }

/// Shared-axis style route: fade + slight horizontal slide (RTL aware).
Route<T> fadeThrough<T>(Widget page, {bool fullscreenDialog = false}) => PageRouteBuilder<T>(
      fullscreenDialog: fullscreenDialog,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, secondary, child) {
        if (Motion.of(context).reduced) return child;
        final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
        final curved = CurvedAnimation(parent: animation, curve: Motion.emphasized, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: Offset(0.08 * dir, 0), end: Offset.zero).animate(curved),
            child: FadeTransition(
              opacity: Tween(begin: 1.0, end: 0.6).animate(secondary),
              child: child,
            ),
          ),
        );
      },
    );

Future<T?> push<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(fadeThrough(page));

/// Fades and lifts its child in, optionally after a staggered [delay].
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero, this.offset = 24});
  final Widget child;
  final Duration delay;
  final double offset;

  /// Convenience for list items: delay grows with [index], capped.
  factory FadeSlideIn.indexed(int index, {Key? key, required Widget child}) => FadeSlideIn(
        key: key,
        delay: Duration(milliseconds: 40 * (index.clamp(0, 10))),
        child: child,
      );

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Motion.emphasized);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context).reduced) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        child: widget.child,
        builder: (_, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(offset: Offset(0, (1 - _a.value) * widget.offset), child: child),
        ),
      );
}

/// Scales down slightly while pressed and fires a haptic on tap.
class Pressable extends ConsumerStatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  ConsumerState<Pressable> createState() => _PressableState();
}

class _PressableState extends ConsumerState<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                haptic(ref, HapticKind.selection);
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down && !m.reduced ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Number that rolls to its new value.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({super.key, required this.value, required this.style, this.format});
  final int value;
  final TextStyle? style;
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value.toDouble()),
        duration: Motion.of(context).medium,
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Text(format?.call(v.round()) ?? '${v.round()}', style: style),
      );
}

/// Moves a [PageController], jumping instead of animating under reduced
/// motion (PageController rejects zero-length animations).
Future<void> goToPage(BuildContext context, PageController pc, int page) {
  final d = Motion.of(context).medium;
  if (d == Duration.zero) {
    pc.jumpToPage(page);
    return Future.value();
  }
  return pc.animateToPage(page, duration: d, curve: Motion.emphasized);
}
