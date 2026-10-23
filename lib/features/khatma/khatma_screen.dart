import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../domain/khatma.dart';
import '../celebration/celebration.dart';
import '../quran/reader_screen.dart';
import '../share/share_card.dart';

/// Adaptive khatma: the daily target is recalculated from what is left, so
/// missed days are spread out and busy weekdays carry half the load.
class KhatmaScreen extends ConsumerWidget {
  const KhatmaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(khatmaProvider);
    return Scaffold(
      appBar: AppBar(actions: [
        if (plan != null)
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'restart') ref.read(khatmaProvider.notifier).restart();
              if (v == 'cancel') ref.read(khatmaProvider.notifier).cancel();
              if (v == 'busy') _editBusy(context, ref, plan.busyWeekdays);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'busy', child: Text(context.tr('busy_days'))),
              PopupMenuItem(value: 'restart', child: Text(context.tr('restart_khatma'))),
              PopupMenuItem(value: 'cancel', child: Text(context.tr('cancel_khatma'))),
            ],
          ),
      ]),
      body: plan == null ? const _NewPlan() : _PlanView(plan: plan),
    );
  }

  static Future<void> _editBusy(BuildContext context, WidgetRef ref, Set<int> current) async {
    final busy = {...current};
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.tr('busy_days')),
          content: Wrap(spacing: 6, children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(context.tr('weekday_$d')),
                selected: busy.contains(d),
                onSelected: (v) => setState(() => v ? busy.add(d) : busy.remove(d)),
              ),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('save')))],
        ),
      ),
    );
    if (ok == true) ref.read(khatmaProvider.notifier).updateBusy(busy);
  }
}

class _NewPlan extends ConsumerStatefulWidget {
  const _NewPlan();
  @override
  ConsumerState<_NewPlan> createState() => _NewPlanState();
}

class _NewPlanState extends ConsumerState<_NewPlan> {
  int _days = 30;
  final Set<int> _busy = {};

  @override
  Widget build(BuildContext context) {
    final perDay = (604 / _days).ceil();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
      PageTitle(context.tr('khatma'), subtitle: context.tr('khatma_sub')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in [7, 10, 15, 20, 30, 60, 90])
          ChoiceChip(label: Text(context.tr('days_n', {'n': d})), selected: _days == d, onSelected: (_) => setState(() => _days = d)),
      ]),
      const SizedBox(height: 20),
      AppCard(
        child: Column(children: [
          AnimatedCount(value: perDay, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: Brand.gold), format: (n) => context.num(n)),
          Text(context.tr('pages_per_day')),
          const SizedBox(height: 4),
          Text(context.tr('minutes_per_day', {'n': (perDay * 2.5).round()}), style: const TextStyle(color: Brand.textMid, fontSize: 12)),
        ]),
      ),
      SectionHeader(context.tr('busy_days')),
      Text(context.tr('busy_days_sub'), style: const TextStyle(color: Brand.textMid)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, children: [
        for (var d = 1; d <= 7; d++)
          FilterChip(label: Text(context.tr('weekday_$d')), selected: _busy.contains(d), onSelected: (v) => setState(() => v ? _busy.add(d) : _busy.remove(d))),
      ]),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => ref.read(khatmaProvider.notifier).start(_days, _busy),
        icon: const Icon(Icons.flag_rounded),
        label: Text(context.tr('start_khatma')),
      ),
    ]);
  }
}

class _PlanView extends ConsumerWidget {
  const _PlanView({required this.plan});
  final KhatmaPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final target = plan.todayTarget(now);
    final readToday = plan.readOn(now);
    final delta = plan.scheduleDelta(now);
    final q = ref.watch(quranProvider).value;
    final nextPage = math.min(plan.pagesRead + 1, 604);
    final nextRef = q?.ayahsOnPage(nextPage).first;

    return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
      PageTitle(context.tr('khatma'), subtitle: context.tr('khatma_progress', {'n': plan.pagesRead})),
      Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: plan.progress),
            duration: Motion.of(context).long * 2,
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CustomPaint(
              painter: _Ring(v),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${context.num((v * 100).round())}٪', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700)),
                  Text(context.tr('days_left_n', {'n': plan.daysLeft(now)}), style: const TextStyle(color: Brand.textMid)),
                ]),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _Box(context.num('$readToday/$target'), context.tr('today_pages'))),
        const SizedBox(width: 10),
        Expanded(
          child: _Box(
            delta >= 0 ? '+${context.num(delta)}' : context.num(delta),
            delta >= 0 ? context.tr('ahead') : context.tr('behind'),
            color: delta >= 0 ? Brand.tealBright : const Color(0xFFE08A3C),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _Box(context.num(plan.completedCount), context.tr('khatmas_done'))),
      ]),
      const SizedBox(height: 16),
      if (nextRef != null && !plan.done)
        FilledButton.icon(
          onPressed: () => push(context, ReaderScreen(surah: nextRef.surah, initialAyah: nextRef.ayah)),
          icon: const Icon(Icons.menu_book_rounded),
          label: Text(context.tr('continue_page', {'n': nextPage})),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () async {
          final v = await _askPage(context, plan.pagesRead);
          if (v == null) return;
          ref.read(khatmaProvider.notifier).markRead(v);
          if (v >= 604 && context.mounted) {
            showCelebration(context, title: context.tr('khatma_complete'), subtitle: context.tr('khatma_dua'));
          }
        },
        icon: const Icon(Icons.edit_rounded),
        label: Text(context.tr('update_progress')),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () => shareWidgetAsImage(
          context,
          BrandedCard(
            title: context.tr('khatma'),
            child: Column(children: [
              Text('${context.num((plan.progress * 100).round())}٪', style: const TextStyle(color: Brand.gold, fontSize: 40, fontWeight: FontWeight.w700)),
              Text(context.tr('khatma_progress', {'n': plan.pagesRead}), style: const TextStyle(color: Brand.textHigh)),
            ]),
          ),
          name: 'khatma',
        ),
        icon: const Icon(Icons.ios_share_rounded),
        label: Text(context.tr('share_progress')),
      ),
      SectionHeader(context.tr('last_14_days')),
      SizedBox(
        height: 120,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 13; i >= 0; i--)
            () {
              final d = now.subtract(Duration(days: i));
              final v = plan.readOn(d);
              final maxV = math.max(1, plan.log.values.fold(0, math.max));
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: v / maxV),
                      duration: Motion.of(context).long,
                      builder: (_, t, _) => Container(
                        height: math.max(3, 90 * t),
                        decoration: BoxDecoration(color: Brand.gold.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(context.num(d.day), style: const TextStyle(fontSize: 10, color: Brand.textMid)),
                  ]),
                ),
              );
            }(),
        ]),
      ),
    ]);
  }

  Future<int?> _askPage(BuildContext context, int current) async {
    final ctrl = TextEditingController(text: '${math.min(current + 1, 604)}');
    final v = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('reached_page')),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)?.clamp(1, 604)), child: Text(context.tr('save'))),
        ],
      ),
    );
    disposeAfterDialog([ctrl]);
    return v;
  }
}

class _Box extends StatelessWidget {
  const _Box(this.value, this.label, {this.color = Brand.gold});
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Brand.textMid, fontSize: 12)),
        ]),
      );
}

class _Ring extends CustomPainter {
  _Ring(this.v);
  final double v;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(10), 0, 2 * math.pi, false, stroke..color = Brand.outline);
    canvas.drawArc(
      rect.deflate(10),
      -math.pi / 2,
      2 * math.pi * v,
      false,
      stroke..shader = const SweepGradient(colors: [Brand.tealBright, Brand.gold, Brand.tealBright]).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_Ring old) => old.v != v;
}
