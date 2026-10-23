import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';
import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../domain/prayer_times.dart';
import 'prayer_screen.dart';

String formatTime(BuildContext context, DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final suffix = context.isAr ? (t.hour < 12 ? 'ص' : 'م') : (t.hour < 12 ? 'AM' : 'PM');
  return '${context.num('${h.toString().padLeft(2, '0')}:$m')} $suffix';
}

String formatCountdown(BuildContext context, Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return context.num('$h:$m:$s');
}

/// Live hh:mm:ss to [target]; the only widget that rebuilds every second.
class CountdownText extends ConsumerWidget {
  const CountdownText({super.key, required this.target, this.style});
  final DateTime target;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final d = target.difference(now);
    return Text(formatCountdown(context, d.isNegative ? Duration.zero : d), style: style);
  }
}

/// Home card: next prayer with a live countdown and the day's timeline.
class PrayerCard extends ConsumerWidget {
  const PrayerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calc = ref.watch(prayerCalculatorProvider);
    final s = ref.watch(settingsProvider);
    if (calc == null) return const _NoLocationCard();
    final now = ref.watch(minuteProvider);
    final today = calc.forDate(now);
    final (next, at) = calc.next(now);
    final t = Theme.of(context).textTheme;

    return Pressable(
      onTap: () => push(context, const PrayerScreen(standalone: true)),
      semanticLabel: '${context.tr('next_prayer')} ${context.tr('prayer_${next.name}')}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [Color(0xFF1C6F7B), Color(0xFF2A9AA6), Color(0xFF1B5E69)]),
          boxShadow: [BoxShadow(color: Brand.teal.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Stack(children: [
          PositionedDirectional(end: -10, bottom: -14, child: Icon(Icons.mosque_rounded, size: 120, color: Colors.white.withValues(alpha: 0.07))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const _Pulse(),
              const SizedBox(width: 8),
              Text(context.tr('next_prayer'), style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              Flexible(
                child: Text(s.placeName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(context.tr('prayer_${next.name}'), style: t.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(context.tr('remaining'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                CountdownText(
                  target: at,
                  style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ]),
            ]),
            const SizedBox(height: 10),
            Divider(color: Colors.white.withValues(alpha: 0.25), height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final p in PrayerName.values.where((p) => p.isFard))
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _TimeDot(name: context.tr('prayer_${p.name}'), time: formatTime(context, today[p]), active: p == next, past: today[p].isBefore(now)),
                    ),
                  ),
              ],
            ),
          ]),
        ]),
      ),
    );
  }
}

class _TimeDot extends StatelessWidget {
  const _TimeDot({required this.name, required this.time, required this.active, required this.past});
  final String name;
  final String time;
  final bool active;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final color = active ? Brand.gold : (past ? Colors.white54 : Colors.white);
    return Column(children: [
      Text(name, style: TextStyle(color: color, fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
      const SizedBox(height: 6),
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: active ? 14 : 8,
        height: active ? 14 : 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      const SizedBox(height: 6),
      Text(time, style: TextStyle(color: color, fontSize: 11)),
    ]);
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Motion.of(context).reduced ? _c.value = 0.5 : _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
        child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
      );
}

class _NoLocationCard extends ConsumerStatefulWidget {
  const _NoLocationCard();
  @override
  ConsumerState<_NoLocationCard> createState() => _NoLocationCardState();
}

class _NoLocationCardState extends ConsumerState<_NoLocationCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(colors: [Color(0xFF1C6F7B), Color(0xFF1B5E69)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('set_location_title'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(context.tr('set_location_body'), style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Brand.gold, foregroundColor: Brand.ink),
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final err = await useCurrentLocation(ref, context.lang);
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(err))));
                      } else {
                        Bootstrap.reschedule(context, ref);
                      }
                    },
              icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded),
              label: Text(context.tr('use_my_location')),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              onPressed: () => pickCity(context, ref),
              child: Text(context.tr('choose_city')),
            ),
          ]),
        ]),
      );
}
