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
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day).add(Duration(days: _dayOffset));
    final hijri = HijriDate.fromGregorian(day, offsetDays: s.hijriOffset);
    final log = ref.watch(activityProvider)[dayKey(day)];

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
      children: [
        Row(children: [
          Expanded(child: Text(context.tr('prayer_times'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700))),
          IconButton(tooltip: context.tr('qibla'), onPressed: () => push(context, const QiblaScreen()), icon: const Icon(Icons.explore_rounded)),
          IconButton(tooltip: context.tr('mosque_mode'), onPressed: () => push(context, const MosqueModeScreen()), icon: const Icon(Icons.tv_rounded)),
          IconButton(tooltip: context.tr('prayer_settings'), onPressed: () => push(context, const PrayerSettingsScreen()), icon: const Icon(Icons.tune_rounded)),
        ]),
        const SizedBox(height: 8),
        const PrayerCard(),
        const SizedBox(height: 16),
        Row(children: [
          IconButton(onPressed: () => setState(() => _dayOffset--), icon: const Icon(Icons.chevron_right_rounded), tooltip: context.tr('previous')),
          Expanded(
            child: Column(children: [
              Text(MaterialLocalizations.of(context).formatFullDate(day), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${context.num(hijri.day)} ${hijri.monthName(context.lang)} ${context.num(hijri.year)}', style: const TextStyle(color: Brand.gold, fontSize: 13)),
            ]),
          ),
          IconButton(onPressed: () => setState(() => _dayOffset++), icon: const Icon(Icons.chevron_left_rounded), tooltip: context.tr('next')),
        ]),
        const SizedBox(height: 8),
        if (calc != null)
          ...() {
            final times = calc.forDate(day);
            final current = _dayOffset == 0 ? times.currentAt(now) : null;
            return [
              for (final (i, p) in PrayerName.values.indexed)
                FadeSlideIn.indexed(
                  i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      borderColor: p == current ? Brand.gold : null,
                      child: Row(children: [
                        Icon(_icon(p), color: p == current ? Brand.gold : Brand.tealBright),
                        const SizedBox(width: 14),
                        Expanded(child: Text(context.tr('prayer_${p.name}'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                        Text(formatTime(context, times[p]), style: const TextStyle(fontSize: 16)),
                        if (p.isFard) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: context.tr('notify'),
                            onPressed: () {
                              final m = Map<String, bool>.from(s.adhanEnabled)..[p.name] = !(s.adhanEnabled[p.name] ?? false);
                              ref.read(settingsProvider.notifier).update((x) => x.copyWith(adhanEnabled: m));
                              Bootstrap.reschedule(context, ref);
                            },
                            icon: Icon(s.adhanEnabled[p.name] == true ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                                color: s.adhanEnabled[p.name] == true ? Brand.gold : Brand.textLow),
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
                        ] else
                          const SizedBox(width: 96),
                      ]),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(context.tr('prayer_log_hint'), style: const TextStyle(color: Brand.textLow, fontSize: 12), textAlign: TextAlign.center),
              ),
            ];
          }(),
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
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        SectionHeader(context.tr('location')),
        ListTile(
          leading: const Icon(Icons.place_rounded),
          title: Text(s.placeName ?? context.tr('not_set')),
          subtitle: s.hasLocation ? Text('${s.lat!.toStringAsFixed(4)}, ${s.lng!.toStringAsFixed(4)}') : null,
        ),
        Wrap(spacing: 10, children: [
          FilledButton.tonalIcon(
            onPressed: () async {
              final err = await useCurrentLocation(ref, context.lang);
              if (!context.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(context.tr(err)),
                  action: err == 'loc_denied_forever' ? SnackBarAction(label: context.tr('open_settings'), onPressed: LocationService.openSettings) : null,
                ));
              } else {
                changed();
              }
            },
            icon: const Icon(Icons.my_location_rounded),
            label: Text(context.tr('use_my_location')),
          ),
          OutlinedButton(onPressed: () => pickCity(context, ref), child: Text(context.tr('choose_city'))),
        ]),
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
          items: [for (final m in prayerMethods) DropdownMenuItem(value: m.id, child: Text(context.isAr ? m.nameAr : m.nameEn, overflow: TextOverflow.ellipsis))],
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
          Row(children: [
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
          ]),
        SectionHeader(context.tr('notifications')),
        ListTile(
          title: Text(context.tr('pre_adhan')),
          trailing: DropdownButton<int>(
            value: s.preAdhanMinutes,
            items: [for (final m in [0, 5, 10, 15, 20, 30]) DropdownMenuItem(value: m, child: Text(m == 0 ? context.tr('off') : context.tr('minutes_n', {'n': m})))],
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
        Row(children: [
          Expanded(child: Text(context.tr('hijri_adjust_sub'))),
          IconButton(onPressed: () => ctrl.update((x) => x.copyWith(hijriOffset: (s.hijriOffset - 1).clamp(-2, 2))), icon: const Icon(Icons.remove_circle_outline)),
          Text(context.num(s.hijriOffset)),
          IconButton(onPressed: () => ctrl.update((x) => x.copyWith(hijriOffset: (s.hijriOffset + 1).clamp(-2, 2))), icon: const Icon(Icons.add_circle_outline)),
        ]),
      ]),
    );
  }
}
