import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/brand.dart';
import '../../services/wake.dart';
import '../../core/utils/hijri.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/logo.dart';
import '../../domain/prayer_times.dart';
import '../prayer/prayer_card.dart';

/// Mosque / TV mode: a full-screen board with the clock, today's times,
/// the next adhan countdown and an iqama countdown after each adhan.
/// Keeps the screen on; designed for a tablet or a TV box in landscape.
class MosqueModeScreen extends ConsumerStatefulWidget {
  const MosqueModeScreen({super.key});

  @override
  ConsumerState<MosqueModeScreen> createState() => _MosqueModeScreenState();
}

class _MosqueModeScreenState extends ConsumerState<MosqueModeScreen> {
  static const _iqamaMinutes = {'fajr': 20, 'dhuhr': 15, 'asr': 15, 'maghrib': 7, 'isha': 15};

  @override
  void initState() {
    super.initState();
    keepScreenOn(true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    keepScreenOn(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calc = ref.watch(prayerCalculatorProvider);
    final s = ref.watch(settingsProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    if (calc == null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.location_off_rounded, title: context.tr('set_location_title')));
    }
    final today = calc.forDate(now);
    final (next, at) = calc.next(now);
    final current = today.currentAt(now);
    final hijri = HijriDate.fromGregorian(now, offsetDays: s.hijriOffset);

    // Iqama window right after an adhan.
    Duration? iqama;
    if (current != null && current.isFard) {
      final end = today[current].add(Duration(minutes: _iqamaMinutes[current.name]!));
      if (now.isBefore(end)) iqama = end.difference(now);
    }

    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: Brand.ink,
      body: GestureDetector(
        onDoubleTap: () => Navigator.pop(context),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > c.maxHeight;
            final scale = (c.maxWidth / (wide ? 1100 : 500)).clamp(0.6, 2.2);
            final timeline = [
              for (final p in PrayerName.values)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: EdgeInsets.symmetric(vertical: 14 * scale),
                    decoration: BoxDecoration(
                      color: p == next ? Brand.teal : Brand.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p == next ? Brand.gold : Brand.outline),
                    ),
                    child: Column(children: [
                      Text(context.tr('prayer_${p.name}'), style: TextStyle(color: Brand.textMid, fontSize: 18 * scale)),
                      FittedBox(child: Text(formatTime(context, today[p]), style: TextStyle(color: Colors.white, fontSize: 28 * scale, fontWeight: FontWeight.w700))),
                    ]),
                  ),
                ),
            ];
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  MishkahLogo(size: 40 * scale),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s.placeName ?? '', style: TextStyle(color: Brand.textMid, fontSize: 18 * scale)),
                  ),
                  Text(
                    '${context.num(hijri.day)} ${hijri.monthName(context.lang)} ${context.num(hijri.year)}  ·  ${MaterialLocalizations.of(context).formatMediumDate(now)}',
                    style: TextStyle(color: Brand.gold, fontSize: 18 * scale),
                  ),
                ]),
                Expanded(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      FittedBox(
                        child: Text(context.num('$hh:$mm'),
                            style: TextStyle(color: Colors.white, fontSize: 150 * scale, fontWeight: FontWeight.w700, height: 1, fontFeatures: const [FontFeature.tabularFigures()])),
                      ),
                      Text(context.num(ss), style: TextStyle(color: Brand.textLow, fontSize: 28 * scale)),
                      SizedBox(height: 12 * scale),
                      if (iqama != null)
                        Text('${context.tr('iqama_in')} ${formatCountdown(context, iqama)}', style: TextStyle(color: Brand.gold, fontSize: 40 * scale, fontWeight: FontWeight.w700))
                      else
                        Text('${context.tr('prayer_${next.name}')} ${context.tr('after')} ${formatCountdown(context, at.difference(now))}',
                            style: TextStyle(color: Brand.tealBright, fontSize: 36 * scale, fontWeight: FontWeight.w700)),
                      if (iqama != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(context.tr('silence_phones'), style: TextStyle(color: Brand.textMid, fontSize: 22 * scale)),
                        ),
                    ]),
                  ),
                ),
                wide ? Row(children: timeline) : Column(children: [Row(children: timeline.sublist(0, 3)), Row(children: timeline.sublist(3))]),
              ]),
            );
          }),
        ),
      ),
    );
  }
}
