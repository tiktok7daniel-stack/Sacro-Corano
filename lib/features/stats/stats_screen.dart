import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../domain/achievements.dart';
import '../../domain/khatma.dart';
import '../../domain/prayer_times.dart';
import '../celebration/celebration.dart';
import '../share/share_card.dart';

AchievementInput achievementInput(WidgetRef ref) {
  final cards = ref.read(hifzProvider);
  return AchievementInput(
    days: ref.read(activityProvider),
    khatmasCompleted: (ref.read(khatmaProvider)?.completedCount ?? 0) + ((ref.read(khatmaProvider)?.done ?? false) ? 1 : 0),
    hifzCards: cards.length,
    matureCards: cards.where((c) => c.stage == 3).length,
    reflections: ref.read(reflectionsProvider).length,
    kidsStars: ref.read(kidsProvider.notifier).total,
  );
}

/// Celebrates achievements earned since the last check (once each).
Future<void> checkAchievements(BuildContext context, WidgetRef ref) async {
  final input = achievementInput(ref);
  final seen = ref.read(celebratedProvider);
  final fresh = achievements.where((a) => !seen.contains(a.id) && a.test(input)).toList();
  if (fresh.isEmpty) return;
  ref.read(celebratedProvider.notifier).add(fresh.map((a) => a.id));
  if (context.mounted) {
    await showCelebration(context, title: context.tr('new_badge'), subtitle: fresh.map((a) => a.title(context.lang)).join(' · '));
  }
}

/// Personal statistics, computed on-device only.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkAchievements(context, ref));
  }

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(activityProvider);
    ref.watch(hifzProvider);
    ref.watch(reflectionsProvider);
    final now = DateTime.now();
    final last30 = [for (var i = 29; i >= 0; i--) now.subtract(Duration(days: i))];
    final active = {
      for (final e in days.entries)
        if (e.value.active) e.key,
    };
    final streak = currentStreak(active, now);
    final longest = longestStreak(active);
    final logged30 = last30.where((d) => active.contains(dayKey(d))).length;
    final input = achievementInput(ref);
    final totalMinutes = days.values.fold<int>(0, (s, d) => s + d.secondsRead) ~/ 60;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: context.tr('share'),
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => shareWidgetAsImage(
              context,
              BrandedCard(
                title: context.tr('stats'),
                child: Column(
                  children: [
                    Text(
                      context.tr('streak_n', {'n': streak}),
                      style: const TextStyle(color: Brand.gold, fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text('${context.tr('ayahs_read')}: ${context.num(input.totalAyahs)}', style: const TextStyle(color: Brand.textHigh)),
                    Text('${context.tr('tasbih')}: ${context.num(input.totalTasbih)}', style: const TextStyle(color: Brand.textHigh)),
                  ],
                ),
              ),
              name: 'stats',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          PageTitle(context.tr('stats'), subtitle: context.tr('stats_sub')),
          Row(
            children: [
              Expanded(
                child: _Tile(icon: Icons.speed_rounded, value: '${context.num((logged30 * 100 / 30).round())}٪', label: context.tr('avg_days')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(icon: Icons.local_fire_department_rounded, value: context.num(streak), label: context.tr('current_streak')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(icon: Icons.emoji_events_rounded, value: context.num(longest), label: context.tr('longest_streak')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(context.tr('last_30_days'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    Text(context.tr('days_logged_n', {'n': logged30}), style: const TextStyle(color: Brand.tealBright, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(height: 140, child: _Bars(values: [for (final d in last30) (days[dayKey(d)]?.ayahsRead ?? 0).toDouble()])),
                const SizedBox(height: 6),
                Text(context.tr('ayahs_per_day'), style: const TextStyle(color: Brand.textLow, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('prayers_30'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),
                for (final p in PrayerName.values.where((p) => p.isFard))
                  () {
                    final n = last30.where((d) => days[dayKey(d)]?.prayers.contains(p.name) ?? false).length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 90, child: Text(context.tr('prayer_${p.name}'))),
                          Expanded(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: n / 30),
                              duration: Motion.of(context).long,
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => LinearProgressIndicator(
                                value: v,
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(8),
                                color: Brand.tealBright,
                                backgroundColor: Brand.outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${context.num(n)}/${context.num(30)}', style: const TextStyle(color: Brand.textMid, fontSize: 12)),
                        ],
                      ),
                    );
                  }(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              _Tile(icon: Icons.menu_book_rounded, value: context.num(input.totalAyahs), label: context.tr('ayahs_read')),
              _Tile(icon: Icons.timer_outlined, value: context.num(totalMinutes), label: context.tr('minutes_read')),
              _Tile(icon: Icons.fingerprint_rounded, value: context.num(input.totalTasbih), label: context.tr('tasbih_total')),
              _Tile(icon: Icons.psychology_rounded, value: context.num(input.hifzCards), label: context.tr('hifz_units')),
              _Tile(icon: Icons.volunteer_activism_rounded, value: context.num(ref.watch(dedicationsProvider).length), label: context.tr('deeds_dedicated')),
              _Tile(
                icon: Icons.favorite_rounded,
                value: context.num(ref.watch(favoritesProvider).length + ref.watch(bookmarksProvider).length),
                label: context.tr('favorites'),
              ),
            ],
          ),
          SectionHeader(context.tr('badges')),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.85),
            itemCount: achievements.length,
            itemBuilder: (context, i) {
              final a = achievements[i];
              final got = a.test(input);
              return Tooltip(
                message: a.desc(context.lang),
                child: AppCard(
                  padding: const EdgeInsets.all(10),
                  borderColor: got ? Brand.gold : null,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: got ? 1 : 0.85,
                        duration: Motion.of(context).medium,
                        child: Icon(got ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded, size: 36, color: got ? Brand.gold : Brand.textLow),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.title(context.lang),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(fontSize: 12, color: got ? null : Brand.textLow),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('stats_privacy'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.textLow, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    gradient: LinearGradient(colors: [Brand.teal.withValues(alpha: 0.85), Brand.tealDeep]),
    borderColor: Colors.transparent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Brand.gold, size: 22),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}

/// Animated bar chart drawn with a CustomPainter (no chart dependency).
class _Bars extends StatelessWidget {
  const _Bars({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Motion.of(context).long * 1.5,
    curve: Curves.easeOutCubic,
    builder: (_, t, _) => CustomPaint(size: Size.infinite, painter: _BarsPainter(values, t)),
  );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.values, this.t);
  final List<double> values;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = math.max(1.0, values.fold<double>(0, math.max));
    final w = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      // Stagger: later bars start slightly later.
      final local = ((t * 1.3) - i / values.length * 0.3).clamp(0.0, 1.0);
      final h = values[i] <= 0 ? 3.0 : math.max(3.0, size.height * values[i] / maxV * local);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(i * w + w * 0.2, size.height - h, w * 0.6, h), const Radius.circular(4));
      canvas.drawRRect(r, Paint()..color = values[i] <= 0 ? Brand.outline : (i == values.length - 1 ? Brand.gold : Brand.tealBright));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.t != t || old.values != values;
}
