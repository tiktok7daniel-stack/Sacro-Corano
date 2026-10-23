import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/hijri.dart';
import '../../core/widgets/common.dart';
import '../../domain/occasions.dart';
import '../../domain/prayer_times.dart';

/// A whole Gregorian month of prayer times in one table.
class PrayerMonthScreen extends ConsumerStatefulWidget {
  const PrayerMonthScreen({super.key});

  @override
  ConsumerState<PrayerMonthScreen> createState() => _PrayerMonthScreenState();
}

class _PrayerMonthScreenState extends ConsumerState<PrayerMonthScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final calc = ref.watch(prayerCalculatorProvider);
    final s = ref.watch(settingsProvider);
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final today = DateUtils.dateOnly(DateTime.now());
    String hm(DateTime t) => context.num('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('month_view'))),
      body: calc == null
          ? EmptyState(icon: Icons.location_off_rounded, title: context.tr('set_location_title'), body: context.tr('set_location_body'))
          : Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: context.tr('previous'),
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                    Expanded(
                      child: Text(
                        MaterialLocalizations.of(context).formatMonthYear(_month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('next'),
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                  ],
                ),
                if (s.placeName != null) Text(s.placeName!, style: const TextStyle(color: Brand.textMid, fontSize: 12)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(context.tr('day'), style: const TextStyle(color: Brand.gold, fontSize: 12)),
                      ),
                      for (final p in PrayerName.values)
                        Expanded(
                          child: Text(
                            context.tr('prayer_${p.name}'),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(color: Brand.gold, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
                    itemCount: days,
                    itemBuilder: (context, i) {
                      final d = DateTime(_month.year, _month.month, i + 1);
                      final t = calc.forDate(d);
                      final isToday = d == today;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isToday ? Brand.teal.withValues(alpha: 0.22) : (i.isEven ? Colors.white.withValues(alpha: 0.03) : null),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(context.num(i + 1), style: TextStyle(fontWeight: isToday ? FontWeight.w800 : FontWeight.w600)),
                            ),
                            for (final p in PrayerName.values)
                              Expanded(
                                child: Text(
                                  hm(t[p]),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// Hijri month grid with occasions, the white days and Monday/Thursday fasts.
class HijriCalendarScreen extends ConsumerStatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  ConsumerState<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends ConsumerState<HijriCalendarScreen> {
  int _monthShift = 0;

  @override
  Widget build(BuildContext context) {
    final offset = ref.watch(settingsProvider.select((s) => s.hijriOffset));
    final today = DateUtils.dateOnly(DateTime.now());

    // Walk to the first day of the shown Hijri month.
    var anchor = today;
    final todayH = HijriDate.fromGregorian(today, offsetDays: offset);
    anchor = anchor.subtract(Duration(days: todayH.day - 1));
    for (var k = 0; k < _monthShift.abs(); k++) {
      if (_monthShift > 0) {
        anchor = anchor.add(const Duration(days: 30));
        anchor = anchor.subtract(Duration(days: HijriDate.fromGregorian(anchor, offsetDays: offset).day - 1));
      } else {
        anchor = anchor.subtract(const Duration(days: 2));
        anchor = anchor.subtract(Duration(days: HijriDate.fromGregorian(anchor, offsetDays: offset).day - 1));
      }
    }
    final first = HijriDate.fromGregorian(anchor, offsetDays: offset);
    final monthDays = <DateTime>[];
    for (var d = anchor; HijriDate.fromGregorian(d, offsetDays: offset).month == first.month; d = d.add(const Duration(days: 1))) {
      monthDays.add(d);
    }
    // Saturday-first week, as on most Arabic calendars.
    final lead = (anchor.weekday + 1) % 7;
    final events = <(DateTime, HijriDate, Occasion)>[
      for (final d in monthDays)
        for (final o in occasionsOn(d, offsetDays: offset))
          if (HijriDate.fromGregorian(d, offsetDays: offset).day == o.day) (d, HijriDate.fromGregorian(d, offsetDays: offset), o),
    ];
    final weekdays = context.isAr ? const ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'] : const ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('hijri_calendar'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          Row(
            children: [
              IconButton(tooltip: context.tr('previous'), onPressed: () => setState(() => _monthShift--), icon: const Icon(Icons.chevron_right_rounded)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${first.monthName(context.lang)} ${context.num(first.year)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Brand.gold),
                    ),
                    Text(
                      '${MaterialLocalizations.of(context).formatMediumDate(monthDays.first)} – ${MaterialLocalizations.of(context).formatMediumDate(monthDays.last)}',
                      style: const TextStyle(color: Brand.textMid, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(tooltip: context.tr('next'), onPressed: () => setState(() => _monthShift++), icon: const Icon(Icons.chevron_left_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.82,
            children: [
              for (final w in weekdays)
                Center(
                  child: Text(w, style: const TextStyle(color: Brand.textMid, fontSize: 11)),
                ),
              for (var k = 0; k < lead; k++) const SizedBox.shrink(),
              for (final d in monthDays)
                _DayCell(
                  date: d,
                  hijri: HijriDate.fromGregorian(d, offsetDays: offset),
                  today: d == today,
                  offset: offset,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legend(color: Brand.gold, label: context.tr('occasion')),
              _Legend(color: Brand.tealBright, label: context.tr('white_days')),
              _Legend(color: Colors.white38, label: context.tr('mon_thu_fast')),
            ],
          ),
          SectionHeader(context.tr('occasions')),
          if (events.isEmpty)
            Text(context.tr('no_occasions_month'), style: const TextStyle(color: Brand.textMid))
          else
            for (final (d, h, o) in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Brand.gold.withValues(alpha: 0.15),
                        child: Text(
                          context.num(h.day),
                          style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.name(context.lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(MaterialLocalizations.of(context).formatFullDate(d), style: const TextStyle(color: Brand.textMid, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (!d.isBefore(today)) Pill(d == today ? context.tr('today') : context.tr('in_days', {'n': d.difference(today).inDays})),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Text(
            context.tr('hijri_calc_note'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.textLow, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.date, required this.hijri, required this.today, required this.offset});
  final DateTime date;
  final HijriDate hijri;
  final bool today;
  final int offset;

  @override
  Widget build(BuildContext context) {
    final occ = occasions.any((o) => o.month == hijri.month && o.day == hijri.day);
    final white = isWhiteDay(hijri);
    final sunnah = isSunnahFastWeekday(date) && hijri.month != 9;
    final color = occ ? Brand.gold : (white ? Brand.tealBright : null);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: today ? Brand.teal.withValues(alpha: 0.5) : (color?.withValues(alpha: 0.16) ?? Colors.white.withValues(alpha: 0.04)),
        border: Border.all(color: color ?? (today ? Brand.tealBright : Colors.transparent)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.num(hijri.day),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color),
          ),
          Text(context.num(date.day), style: const TextStyle(fontSize: 10, color: Brand.textMid)),
          if (sunnah)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 2),
              decoration: const BoxDecoration(color: Colors.white38, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: Brand.textMid)),
    ],
  );
}
