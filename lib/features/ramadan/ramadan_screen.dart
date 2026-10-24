import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/hijri.dart';
import '../../core/widgets/common.dart';
import '../../domain/khatma.dart';
import '../../domain/occasions.dart';
import '../../domain/prayer_times.dart';
import '../azkar/azkar_screen.dart';
import '../khatma/khatma_screen.dart';
import '../prayer/prayer_card.dart';

const _iftarDua = 'الدعاء عند إفطار الصائم - الصوم';

/// The days of the Ramadan that is running now, or of the next one.
List<DateTime> ramadanDays(DateTime now, {int offsetDays = 0}) {
  var d = DateUtils.dateOnly(now);
  final h = HijriDate.fromGregorian(d, offsetDays: offsetDays);
  if (h.month == 9) {
    d = d.subtract(Duration(days: h.day - 1));
  } else {
    final (_, days) = nextOccasion(d, offsetDays: offsetDays, only: const {'ramadan'});
    d = d.add(Duration(days: days));
  }
  return [
    for (var i = 0; i < 30; i++)
      if (HijriDate.fromGregorian(d.add(Duration(days: i)), offsetDays: offsetDays).month == 9) d.add(Duration(days: i)),
  ];
}

/// Suhoor ends at Fajr, iftar is at Maghrib: the next of the two from [now].
(String, DateTime)? nextFastingMoment(PrayerCalculator calc, DateTime now) {
  final today = calc.forDate(now);
  if (now.isBefore(today[PrayerName.fajr])) return ('suhoor_ends', today[PrayerName.fajr]);
  if (now.isBefore(today[PrayerName.maghrib])) return ('iftar_in', today[PrayerName.maghrib]);
  return ('suhoor_ends', calc.forDate(now.add(const Duration(days: 1)))[PrayerName.fajr]);
}

class RamadanScreen extends ConsumerWidget {
  const RamadanScreen({super.key});

  Future<void> _ramadanKhatma(BuildContext context, WidgetRef ref, int daysLeft) async {
    final existing = ref.read(khatmaProvider);
    if (existing != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(context.tr('replace_khatma')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('start'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    ref.read(khatmaProvider.notifier).start(daysLeft.clamp(1, 30), const {});
    if (context.mounted) push(context, const KhatmaScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final log = ref.watch(fastingProvider);
    final calc = ref.watch(prayerCalculatorProvider);
    final now = ref.watch(minuteProvider);
    final today = DateUtils.dateOnly(now);
    final days = ramadanDays(now, offsetDays: s.hijriOffset);
    final inRamadan = days.isNotEmpty && !today.isBefore(days.first) && !today.isAfter(days.last);
    final daysLeft = inRamadan ? days.last.difference(today).inDays + 1 : days.length;
    final until = days.isEmpty ? 0 : days.first.difference(today).inDays;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        PageTitle(context.tr('ramadan_fasting'), subtitle: context.tr('ramadan_fasting_sub')),
        if (inRamadan) const RamadanCard() else
          AppCard(
            gradient: const LinearGradient(colors: [Color(0xFF3A2F17), Color(0xFF221C10)]),
            borderColor: Brand.gold.withValues(alpha: 0.4),
            child: Row(children: [
              const Icon(Icons.nightlight_round, color: Brand.gold, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Text(context.tr('ramadan_in_days', {'n': until}), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Brand.gold)),
              ),
            ]),
          ),
        if (calc != null && inRamadan) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _TimeBox(icon: Icons.dark_mode_rounded, label: context.tr('suhoor_ends_at'), time: formatTime(context, calc.forDate(now)[PrayerName.fajr]))),
            const SizedBox(width: 12),
            Expanded(child: _TimeBox(icon: Icons.wb_twilight_rounded, label: context.tr('iftar_at'), time: formatTime(context, calc.forDate(now)[PrayerName.maghrib]))),
          ]),
        ],
        SectionHeader(context.tr('ramadan_days_log')),
        Text(context.tr('ramadan_days_hint'), style: const TextStyle(color: Brand.textMid, fontSize: 12)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final (i, d) in days.indexed)
              _DayDot(
                n: i + 1,
                status: log.days[dayKey(d)],
                today: d == today,
                future: d.isAfter(today),
                onTap: () {
                  haptic(ref, HapticKind.selection);
                  ref.read(fastingProvider.notifier).cycle(d);
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [
          _Legend(color: Brand.tealBright, label: context.tr('fast_fasted')),
          _Legend(color: const Color(0xFFFF6B6B), label: context.tr('fast_missed')),
          _Legend(color: Brand.gold, label: context.tr('fast_excused')),
        ]),
        SectionHeader(context.tr('qada_fasts')),
        AppCard(
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.num(log.qadaRemaining), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Brand.gold)),
                  Text(context.tr('qada_remaining'), style: const TextStyle(color: Brand.textMid)),
                ]),
              ),
              FilledButton.icon(
                onPressed: log.qadaRemaining == 0 ? null : () => ref.read(fastingProvider.notifier).addQadaDone(1),
                icon: const Icon(Icons.check_rounded),
                label: Text(context.tr('qada_fasted_one')),
              ),
            ]),
            const Divider(height: 24),
            Row(children: [
              Expanded(child: Text(context.tr('qada_previous_years'))),
              IconButton(tooltip: context.tr('less'), onPressed: () => ref.read(fastingProvider.notifier).addOwed(-1), icon: const Icon(Icons.remove_circle_outline)),
              Text(context.num(log.extraOwed)),
              IconButton(tooltip: context.tr('more_one'), onPressed: () => ref.read(fastingProvider.notifier).addOwed(1), icon: const Icon(Icons.add_circle_outline)),
            ]),
            Text(context.tr('qada_summary', {'f': log.fastedCount, 'm': log.missedCount, 'd': log.qadaDone}), style: const TextStyle(color: Brand.textLow, fontSize: 12)),
          ]),
        ),
        SectionHeader(context.tr('ramadan_tools')),
        AppCard(
          onTap: () => _ramadanKhatma(context, ref, daysLeft),
          child: Row(children: [
            const Icon(Icons.flag_rounded, color: Brand.gold, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('ramadan_khatma'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(context.tr('ramadan_khatma_sub', {'n': daysLeft}), style: const TextStyle(color: Brand.textMid, fontSize: 12)),
              ]),
            ),
            const Icon(Icons.chevron_left_rounded, color: Brand.textMid),
          ]),
        ),
        const SizedBox(height: 10),
        AppCard(
          onTap: () => openAzkarCategory(context, ref, _iftarDua),
          child: Row(children: [
            const Icon(Icons.restaurant_rounded, color: Brand.tealBright, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('iftar_dua'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            const Icon(Icons.chevron_left_rounded, color: Brand.textMid),
          ]),
        ),
        const SizedBox(height: 12),
        Text(context.tr('hijri_calc_note'), textAlign: TextAlign.center, style: const TextStyle(color: Brand.textLow, fontSize: 12)),
      ]),
    );
  }
}

/// Home card during Ramadan: day N, countdown to iftar or end of suhoor,
/// and today's fast.
class RamadanCard extends ConsumerWidget {
  const RamadanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final now = ref.watch(minuteProvider);
    final calc = ref.watch(prayerCalculatorProvider);
    final h = HijriDate.fromGregorian(now, offsetDays: s.hijriOffset);
    if (h.month != 9) return const SizedBox.shrink();
    final status = ref.watch(fastingProvider).days[dayKey(now)];
    final moment = calc == null ? null : nextFastingMoment(calc, now);
    return AppCard(
      onTap: () => push(context, const RamadanScreen()),
      gradient: const LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [Color(0xFF4A3A16), Color(0xFF241C0E)]),
      borderColor: Brand.gold.withValues(alpha: 0.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.nightlight_round, color: Brand.gold),
          const SizedBox(width: 8),
          Text(context.tr('ramadan_day_n', {'n': h.day}), style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w800, fontSize: 17)),
          const Spacer(),
          const Icon(Icons.chevron_left_rounded, color: Brand.textMid),
        ]),
        if (moment != null) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(context.tr(moment.$1), style: const TextStyle(color: Colors.white70))),
            CountdownText(
              target: moment.$2,
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ]),
        ],
        const SizedBox(height: 10),
        Row(children: [
          FilterChip(
            label: Text(context.tr('i_fasted_today')),
            selected: status == 'fasted',
            onSelected: (v) => ref.read(fastingProvider.notifier).set(now, v ? 'fasted' : null),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: () => openAzkarCategory(context, ref, _iftarDua), child: Text(context.tr('iftar_dua'))),
        ]),
      ]),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.icon, required this.label, required this.time});
  final IconData icon;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Icon(icon, color: Brand.gold),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Brand.textMid, fontSize: 12)),
          Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.n, required this.status, required this.today, required this.future, required this.onTap});
  final int n;
  final String? status;
  final bool today;
  final bool future;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'fasted' => Brand.tealBright,
      'missed' => const Color(0xFFFF6B6B),
      'excused' => Brand.gold,
      _ => null,
    };
    return Semantics(
      button: true,
      label: '$n ${status ?? ''}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: future ? null : onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color?.withValues(alpha: 0.25) ?? Colors.white.withValues(alpha: future ? 0.02 : 0.06),
            border: Border.all(color: today ? Brand.gold : (color ?? Colors.transparent), width: today ? 2 : 1),
          ),
          child: Text(context.num(n), style: TextStyle(fontWeight: FontWeight.w700, color: future ? Brand.textLow : color)),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Brand.textMid)),
      ]);
}
