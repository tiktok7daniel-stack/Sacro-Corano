import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';
import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/hijri.dart';
import '../../core/widgets/common.dart';
import '../../domain/khatma.dart';
import '../../domain/prayer_times.dart';
import '../../services/location.dart';
import '../../services/notifications.dart';
import '../mosque/mosque_mode_screen.dart';
import '../qibla/qibla_screen.dart';
import 'calendar_screens.dart';
import 'prayer_card.dart';

/// Today's times, a 7-day view, prayer logging and calculation settings.
class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key, this.standalone = false});
  final bool standalone;

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  int _dayOffset = 0;

  @override
  Widget build(BuildContext context) {
    final calc = ref.watch(prayerCalculatorProvider);
    final s = ref.watch(settingsProvider);
    final now = ref.watch(minuteProvider);
    final day = DateTime(now.year, now.month, now.day).add(Duration(days: _dayOffset));
    final hijri = HijriDate.fromGregorian(day, offsetDays: s.hijriOffset);
    final log = ref.watch(activityProvider)[dayKey(day)];

    final times = calc?.forDate(day);
    final (next, nextAt) = calc?.next(now) ?? (null, null);
    final current = _dayOffset == 0 ? times?.currentAt(now) : null;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(context.tr('prayer_times'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            IconButton(tooltip: context.tr('qibla'), onPressed: () => push(context, const QiblaScreen()), icon: const Icon(Icons.explore_rounded)),
            IconButton(tooltip: context.tr('mosque_mode'), onPressed: () => push(context, const MosqueModeScreen()), icon: const Icon(Icons.tv_rounded)),
            IconButton(
              tooltip: context.tr('prayer_settings'),
              onPressed: () => push(context, const PrayerSettingsScreen()),
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showLocationSheet(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.place_rounded, color: Brand.gold, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    s.placeName ?? context.tr('set_location_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Brand.textMid),
              ],
            ),
          ),
        ),
        Row(
          children: [
            InkResponse(
              onTap: () => setState(() => _dayOffset--),
              child: Tooltip(
                message: context.tr('previous'),
                child: const Icon(Icons.chevron_right_rounded, color: Brand.textMid),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${context.num(hijri.day)} ${hijri.monthName(context.lang)} ${context.num(hijri.year)}',
                      style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(
                      text: '  |  ',
                      style: TextStyle(color: Brand.textLow),
                    ),
                    TextSpan(
                      text: MaterialLocalizations.of(context).formatFullDate(day),
                      style: const TextStyle(color: Brand.textMid),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            InkResponse(
              onTap: () => setState(() => _dayOffset++),
              child: Tooltip(
                message: context.tr('next'),
                child: const Icon(Icons.chevron_left_rounded, color: Brand.textMid),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (calc == null) const PrayerCard(),
        if (next != null && nextAt != null)
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [Color(0xFF1C6F7B), Color(0xFF155763)],
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('next_prayer'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        context.tr('prayer_${next.name}'),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      Text(formatTime(context, nextAt), style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(context.tr('remaining'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      CountdownText(
                        target: nextAt,
                        style: const TextStyle(color: Brand.gold, fontSize: 26, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        if (times != null)
          for (final (i, p) in PrayerName.values.indexed)
            FadeSlideIn.indexed(
              i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: !p.isFard
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Icon(_icon(p), size: 18, color: Brand.textMid),
                            const SizedBox(width: 10),
                            Text(context.tr('prayer_${p.name}'), style: const TextStyle(color: Brand.textMid)),
                            const Spacer(),
                            Text(formatTime(context, times[p]), style: const TextStyle(color: Brand.textMid)),
                          ],
                        ),
                      )
                    : AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        borderColor: _dayOffset == 0 && p == next ? Brand.gold : (p == current ? Brand.tealBright : null),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_dayOffset == 0 && p == next ? Brand.gold : Brand.tealBright).withValues(alpha: 0.15),
                              ),
                              child: Icon(_icon(p), color: _dayOffset == 0 && p == next ? Brand.gold : Brand.tealBright, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.tr('prayer_${p.name}'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                  Text(
                                    _dayOffset == 0 && p == next ? context.tr('upcoming_prayer') : context.tr(times[p].hour < 12 ? 'am_long' : 'pm_long'),
                                    style: TextStyle(fontSize: 12, color: _dayOffset == 0 && p == next ? Brand.gold : Brand.textMid),
                                  ),
                                ],
                              ),
                            ),
                            Text(formatTime(context, times[p]), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            IconButton(
                              tooltip: context.tr('notify'),
                              onPressed: () {
                                final m = Map<String, bool>.from(s.adhanEnabled)..[p.name] = !(s.adhanEnabled[p.name] ?? false);
                                ref.read(settingsProvider.notifier).update((x) => x.copyWith(adhanEnabled: m));
                                Bootstrap.reschedule(context, ref);
                              },
                              icon: Icon(
                                s.adhanEnabled[p.name] == true ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                                color: s.adhanEnabled[p.name] == true ? Brand.gold : Brand.textLow,
                              ),
                            ),
                            Checkbox(
                              value: log?.prayers.contains(p.name) ?? false,
                              onChanged: day.isAfter(now)
                                  ? null
                                  : (_) {
                                      haptic(ref);
                                      ref.read(activityProvider.notifier).togglePrayer(p.name, day);
                                    },
                            ),
                          ],
                        ),
                      ),
              ),
            ),
        if (times != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.tr('prayer_log_hint'),
              style: const TextStyle(color: Brand.textLow, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => push(context, const PrayerMonthScreen()),
            icon: const Icon(Icons.table_chart_rounded),
            label: Text(context.tr('month_view')),
          ),
        ],
        const SizedBox(height: 14),
        AppCard(
          onTap: () => push(context, const HijriCalendarScreen()),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: Brand.gold, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('hijri_calendar'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(context.tr('hijri_calendar_sub'), style: const TextStyle(color: Brand.textMid, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Brand.textMid),
            ],
          ),
        ),
      ],
    );

    if (!widget.standalone) return SafeArea(bottom: false, child: body);
    return Scaffold(appBar: AppBar(), body: body);
  }

  IconData _icon(PrayerName p) => switch (p) {
    PrayerName.fajr => Icons.wb_twilight_rounded,
    PrayerName.sunrise => Icons.wb_sunny_outlined,
    PrayerName.dhuhr => Icons.light_mode_rounded,
    PrayerName.asr => Icons.sunny_snowing,
    PrayerName.maghrib => Icons.nights_stay_outlined,
    PrayerName.isha => Icons.dark_mode_rounded,
  };
}

/// Location sheet: GPS or a city from the list.
Future<void> showLocationSheet(BuildContext context, WidgetRef ref) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(context.tr('location'), style: Theme.of(context).textTheme.titleLarge)),
          ListTile(leading: const Icon(Icons.my_location_rounded), title: Text(context.tr('use_my_location')), onTap: () => Navigator.pop(context, 'gps')),
          ListTile(leading: const Icon(Icons.location_city_rounded), title: Text(context.tr('choose_city')), onTap: () => Navigator.pop(context, 'city')),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'city') return pickCity(context, ref);
  final err = await useCurrentLocation(ref, context.lang);
  if (!context.mounted) return;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(err))));
  } else {
    await Bootstrap.reschedule(context, ref);
  }
}

Future<void> pickCity(BuildContext context, WidgetRef ref) async {
  final c = await showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => ListView(
        controller: controller,
        children: [
          ListTile(title: Text(context.tr('choose_city'), style: Theme.of(context).textTheme.titleLarge)),
          for (final c in cities)
            ListTile(
              title: Text(c.name(context.lang)),
              subtitle: Text('${c.lat.toStringAsFixed(2)}, ${c.lng.toStringAsFixed(2)}'),
              onTap: () => Navigator.pop(context, c),
            ),
        ],
      ),
    ),
  );
  if (c == null || !context.mounted) return;
  ref.read(settingsProvider.notifier).update((s) => s.copyWith(lat: c.lat, lng: c.lng, placeName: c.name(context.lang), autoLocation: false));
  await Bootstrap.reschedule(context, ref);
}

class PrayerSettingsScreen extends ConsumerWidget {
  const PrayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    void changed() => Bootstrap.reschedule(context, ref);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('prayer_settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          SectionHeader(context.tr('location')),
          ListTile(
            leading: const Icon(Icons.place_rounded),
            title: Text(s.placeName ?? context.tr('not_set')),
            subtitle: s.hasLocation ? Text('${s.lat!.toStringAsFixed(4)}, ${s.lng!.toStringAsFixed(4)}') : null,
          ),
          Wrap(
            spacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: () async {
                  final err = await useCurrentLocation(ref, context.lang);
                  if (!context.mounted) return;
                  if (err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr(err)),
                        action: err == 'loc_denied_forever'
                            ? SnackBarAction(label: context.tr('open_settings'), onPressed: LocationService.openSettings)
                            : null,
                      ),
                    );
                  } else {
                    changed();
                  }
                },
                icon: const Icon(Icons.my_location_rounded),
                label: Text(context.tr('use_my_location')),
              ),
              OutlinedButton(onPressed: () => pickCity(context, ref), child: Text(context.tr('choose_city'))),
            ],
          ),
          SwitchListTile(
            title: Text(context.tr('travel_mode')),
            subtitle: Text(context.tr('travel_mode_sub')),
            value: s.autoLocation,
            onChanged: (v) => ctrl.update((x) => x.copyWith(autoLocation: v)),
          ),
          SectionHeader(context.tr('calculation')),
          DropdownButtonFormField<String>(
            initialValue: s.calcMethod,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('calc_method')),
            items: [
              for (final m in prayerMethods)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(context.isAr ? m.nameAr : m.nameEn, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              ctrl.update((x) => x.copyWith(calcMethod: v));
              changed();
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'shafi', label: Text(context.tr('asr_standard'))),
              ButtonSegment(value: 'hanafi', label: Text(context.tr('asr_hanafi'))),
            ],
            selected: {s.madhab},
            onSelectionChanged: (v) {
              ctrl.update((x) => x.copyWith(madhab: v.first));
              changed();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: s.highLatRule,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('high_lat')),
            items: [
              DropdownMenuItem(value: 'middle_of_the_night', child: Text(context.tr('hl_middle'))),
              DropdownMenuItem(value: 'seventh_of_the_night', child: Text(context.tr('hl_seventh'))),
              DropdownMenuItem(value: 'twilight_angle', child: Text(context.tr('hl_angle'))),
            ],
            onChanged: (v) {
              ctrl.update((x) => x.copyWith(highLatRule: v));
              changed();
            },
          ),
          SectionHeader(context.tr('manual_adjust')),
          for (final p in PrayerName.values)
            Row(
              children: [
                Expanded(child: Text(context.tr('prayer_${p.name}'))),
                IconButton(
                  onPressed: () {
                    final m = Map<String, int>.from(s.prayerOffsets)..[p.name] = (s.prayerOffsets[p.name] ?? 0) - 1;
                    ctrl.update((x) => x.copyWith(prayerOffsets: m));
                    changed();
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(width: 56, child: Text(context.tr('minutes_n', {'n': s.prayerOffsets[p.name] ?? 0}), textAlign: TextAlign.center)),
                IconButton(
                  onPressed: () {
                    final m = Map<String, int>.from(s.prayerOffsets)..[p.name] = (s.prayerOffsets[p.name] ?? 0) + 1;
                    ctrl.update((x) => x.copyWith(prayerOffsets: m));
                    changed();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          SectionHeader(context.tr('notifications')),
          ListTile(
            title: Text(context.tr('pre_adhan')),
            trailing: DropdownButton<int>(
              value: s.preAdhanMinutes,
              items: [
                for (final m in [0, 5, 10, 15, 20, 30]) DropdownMenuItem(value: m, child: Text(m == 0 ? context.tr('off') : context.tr('minutes_n', {'n': m}))),
              ],
              onChanged: (v) {
                ctrl.update((x) => x.copyWith(preAdhanMinutes: v));
                changed();
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(context.tr('allow_notifications')),
            subtitle: Text(context.tr('allow_notifications_sub')),
            onTap: () async {
              await Notifications.instance.requestPermissions();
              if (context.mounted) changed();
            },
          ),
          SectionHeader(context.tr('hijri_adjust')),
          Row(
            children: [
              Expanded(child: Text(context.tr('hijri_adjust_sub'))),
              IconButton(
                onPressed: () => ctrl.update((x) => x.copyWith(hijriOffset: (s.hijriOffset - 1).clamp(-2, 2))),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(context.num(s.hijriOffset)),
              IconButton(
                onPressed: () => ctrl.update((x) => x.copyWith(hijriOffset: (s.hijriOffset + 1).clamp(-2, 2))),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
