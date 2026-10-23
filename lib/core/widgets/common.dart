import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../motion.dart';
import '../theme/brand.dart';

/// Section title with the brand accent bar (as on the home screen).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.accent = Brand.tealBright});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Container(width: 5, height: 26, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 12),
          Expanded(child: Semantics(header: true, child: Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)))),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(color: Brand.gold))),
        ],
      ),
    );
  }
}

/// Gradient feature tile with a large watermark icon (home grid).
class GradientTile extends StatelessWidget {
  const GradientTile({
    super.key,
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.subtitle,
    this.heroTag,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: colors),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PositionedDirectional(
            end: -18,
            bottom: -18,
            child: Icon(icon, size: 110, color: Colors.white.withValues(alpha: 0.14)),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const Spacer(),
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, height: 1.2)),
                if (subtitle != null)
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: heroTag == null ? tile : Hero(tag: heroTag!, child: Material(type: MaterialType.transparency, child: tile)),
    );
  }
}

/// Rounded surface card with optional tap.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(18), this.color, this.gradient, this.borderColor});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(26);
    // Material + Ink (not a coloured Container) so ListTiles and InkWells
    // inside the card still show their splashes.
    final box = Material(
      type: MaterialType.transparency,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? (color ?? scheme.surface) : null,
          gradient: gradient,
          borderRadius: radius,
          border: Border.all(color: borderColor ?? scheme.outline.withValues(alpha: 0.55)),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = Brand.gold});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(40)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body});
  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: FadeSlideIn(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(color: Brand.gold.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 44, color: Brand.gold),
              ),
              const SizedBox(height: 20),
              Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(body!, style: t.bodyMedium?.copyWith(color: t.bodySmall?.color), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Large page title used by feature screens (matches the reference design).
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: t.displaySmall?.copyWith(fontWeight: FontWeight.w700))),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle!, style: t.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

/// Renders a Riverpod [AsyncValue]: spinner, error with retry, or data.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        data: builder,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded, size: 40),
              const SizedBox(height: 12),
              Text(context.tr('error_generic'), textAlign: TextAlign.center),
              if (onRetry != null) TextButton(onPressed: onRetry, child: Text(context.tr('retry'))),
            ]),
          ),
        ),
      );
}

/// Ornamental end-of-verse marker (U+06DD + Arabic-Indic digits), rendered
/// by Amiri Quran as the familiar circled number.
String ayahMarker(int n) => '۝${_arabicNum(n)}';

String _arabicNum(int n) {
  const d = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

/// Disposes dialog controllers after the dialog's exit animation, which
/// still rebuilds its text fields for a few frames after it returns.
void disposeAfterDialog(List<ChangeNotifier> controllers) {
  Future<void>.delayed(const Duration(milliseconds: 500), () {
    for (final c in controllers) {
      c.dispose();
    }
  });
}
