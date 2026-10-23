import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../domain/khatma.dart';
import '../celebration/celebration.dart';

/// Smart tasbih: presets and custom adhkar, round targets, a daily goal,
/// a streak, a 14-day history, haptics and a bead animation.
class TasbihScreen extends ConsumerStatefulWidget {
  const TasbihScreen({super.key});

  @override
  ConsumerState<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends ConsumerState<TasbihScreen> with TickerProviderStateMixin {
  late final AnimationController _bead = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late final AnimationController _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void dispose() {
    _bead.dispose();
    _ripple.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    final s = ref.read(settingsProvider);
    final before = ref.read(activityProvider.notifier).today().tasbih;
    final round = ref.read(tasbihProvider.notifier).increment();
    if (!Motion.of(context).reduced) {
      _bead.forward(from: 0);
      _ripple.forward(from: 0);
    }
    if (s.haptics) {
      if (round) {
        Vibration.vibrate(pattern: [0, 60, 80, 60]);
      } else {
        haptic(ref, HapticKind.light);
      }
    }
    if (before < s.tasbihGoal && before + 1 >= s.tasbihGoal && mounted) {
      showCelebration(context, title: context.tr('goal_reached'), subtitle: context.tr('tasbih_goal_n', {'n': s.tasbihGoal}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(tasbihProvider);
    final activity = ref.watch(activityProvider);
    final s = ref.watch(settingsProvider);
    final now = DateTime.now();
    final todayCount = activity[dayKey(now)]?.tasbih ?? 0;
    final days = {for (final e in activity.entries) if (e.value.tasbih > 0) e.key};
    final streak = currentStreak(days, now);
    final cur = st.current;
    final progress = st.count / cur.target;

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(tooltip: context.tr('reset'), onPressed: () => ref.read(tasbihProvider.notifier).reset(), icon: const Icon(Icons.restart_alt_rounded)),
        IconButton(tooltip: context.tr('add_dhikr'), onPressed: _addCustom, icon: const Icon(Icons.add_rounded)),
      ]),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final d in st.presets)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: GestureDetector(
                    onLongPress: () => ref.read(tasbihProvider.notifier).removeCustom(d.id),
                    child: ChoiceChip(
                      label: Text(d.text, style: const TextStyle(fontFamily: Brand.naskhFont)),
                      selected: d.id == st.selected,
                      onSelected: (_) => ref.read(tasbihProvider.notifier).select(d.id),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            child: Semantics(
              button: true,
              label: '${cur.text} ${st.count}',
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                AnimatedSwitcher(
                  duration: Motion.of(context).medium,
                  child: Text(cur.text,
                      key: ValueKey(cur.id),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontFamily: Brand.naskhFont, fontSize: 30, height: 1.6)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 260,
                  height: 260,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_bead, _ripple]),
                    builder: (context, _) => CustomPaint(
                      painter: _BeadRing(progress: progress, beadT: _bead.value, ripple: _ripple.value, beads: math.min(cur.target, 33)),
                      child: Center(
                        child: Transform.scale(
                          scale: 1 + 0.08 * math.sin(_bead.value * math.pi),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(context.num(st.count), style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700)),
                            Text('/ ${context.num(cur.target)}', style: const TextStyle(color: Brand.textMid)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(context.tr('rounds_n', {'n': st.rounds}), style: const TextStyle(color: Brand.gold)),
                const SizedBox(height: 6),
                Text(context.tr('tap_anywhere'), style: const TextStyle(color: Brand.textLow, fontSize: 12)),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Row(children: [
            Expanded(child: _Mini(icon: Icons.today_rounded, value: '${context.num(todayCount)}/${context.num(s.tasbihGoal)}', label: context.tr('today'), onTap: _editGoal)),
            const SizedBox(width: 10),
            Expanded(child: _Mini(icon: Icons.local_fire_department_rounded, value: context.num(streak), label: context.tr('streak_days'))),
            const SizedBox(width: 10),
            Expanded(child: _Mini(icon: Icons.bar_chart_rounded, value: '', label: context.tr('history'), onTap: () => _history(activity.map((k, v) => MapEntry(k, v.tasbih))))),
          ]),
        ),
      ]),
    );
  }

  Future<void> _addCustom() async {
    final text = TextEditingController();
    final target = TextEditingController(text: '33');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('add_dhikr')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: text, decoration: InputDecoration(labelText: context.tr('dhikr_text'))),
          const SizedBox(height: 12),
          TextField(controller: target, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.tr('target'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('save'))),
        ],
      ),
    );
    if (ok == true && text.text.trim().isNotEmpty) {
      ref.read(tasbihProvider.notifier).addCustom(text.text.trim(), int.tryParse(target.text)?.clamp(1, 100000) ?? 33);
    }
    disposeAfterDialog([text, target]);
  }

  Future<void> _editGoal() async {
    final s = ref.read(settingsProvider);
    final v = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('daily_goal')),
        children: [
          for (final g in [33, 100, 300, 500, 1000])
            SimpleDialogOption(onPressed: () => Navigator.pop(context, g), child: Text(context.num(g), style: TextStyle(color: g == s.tasbihGoal ? Brand.gold : null))),
        ],
      ),
    );
    if (v != null) ref.read(settingsProvider.notifier).update((x) => x.copyWith(tasbihGoal: v));
  }

  void _history(Map<String, int> perDay) {
    final now = DateTime.now();
    final days = [for (var i = 13; i >= 0; i--) now.subtract(Duration(days: i))];
    final values = days.map((d) => perDay[dayKey(d)] ?? 0).toList();
    final maxV = values.fold(1, math.max);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('history_14'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: values[i] / maxV),
                      duration: Motion.of(context).long + Duration(milliseconds: 30 * i),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Container(
                          height: math.max(4, 130 * v),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: Brand.gTasbih),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(context.num(days[i].day), style: const TextStyle(fontSize: 10, color: Brand.textMid)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.value, required this.label, this.onTap});
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        onTap: onTap,
        child: Column(children: [
          Icon(icon, color: Brand.gold),
          if (value.isNotEmpty) Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: Brand.textMid, fontSize: 12)),
        ]),
      );
}

/// Ring of beads; filled beads show progress, the newest bead pops.
class _BeadRing extends CustomPainter {
  _BeadRing({required this.progress, required this.beadT, required this.ripple, required this.beads});
  final double progress;
  final double beadT;
  final double ripple;
  final int beads;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 14;
    if (ripple > 0 && ripple < 1) {
      canvas.drawCircle(
        c,
        r * (0.6 + 0.5 * ripple),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Brand.gold.withValues(alpha: (1 - ripple) * 0.5),
      );
    }
    final filled = (progress * beads).floor();
    for (var i = 0; i < beads; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / beads;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      final isNewest = i == filled - 1 || (filled == 0 && i == beads - 1 && beadT > 0);
      final radius = 7.0 + (isNewest ? 4 * math.sin(beadT * math.pi) : 0);
      canvas.drawCircle(p, radius, Paint()..color = i < filled ? Brand.gold : Brand.outline);
    }
  }

  @override
  bool shouldRepaint(_BeadRing old) => old.progress != progress || old.beadT != beadT || old.ripple != ripple || old.beads != beads;
}
