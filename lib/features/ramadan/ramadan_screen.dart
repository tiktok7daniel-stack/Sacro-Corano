import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';
import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/hijri.dart';
import '../../core/widgets/common.dart';
import '../../domain/prayer_times.dart';
import '../../domain/ramadan.dart';
import '../quran/reader_screen.dart';

/// Ramadan companion: suhoor / iftar countdown, a one-juz-a-day khatma
/// plan, a fasting log and a tracker for days still to be made up (qada).
class RamadanScreen extends ConsumerWidget {
  const RamadanScreen({super.key});

  String _clock(BuildContext context, Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    String two(int n) => n.toString().padLeft(2, '0');
    return context.num('${two(s ~/ 3600)}:${two(s % 3600 ~/ 60)}:${two(s % 60)}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rd = ramadanDay(today, offsetDays: s.hijriOffset);
    final calc = ref.watch(prayerCalculatorProvider);
    final ledger = ref.watch(fastingProvider);
    final juzLog = ref.watch(ramadanJuzProvider);
    final theme = Theme.of(context);

    Widget header() {
      if (rd == null) {
        final n = daysUntilRamadan(today, offsetDays: s.hijriOffset);
        return AppCard(
          gradient: const LinearGradient(colors: Brand.gKhatma),
          borderColor: Colors.transparent,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('ramadan'), style: const TextStyle(color: Colors.white70)),
            Text(context.tr('in_days', {'n': n}), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(context.tr('ram_prepare'), style: const TextStyle(color: Colors.white70, height: 1.5)),
          ]),
        );
      }
      String? label;
      Duration? left;
      if (calc != null) {
        final t = calc.forDate(today);
        final fajr = t[PrayerName.fajr], maghrib = t[PrayerName.maghrib];
        if (now.isBefore(fajr)) {
          label = context.tr('ram_suhoor_left');
          left = fajr.difference(now);
        } else if (now.isBefore(maghrib)) {
          label = context.tr('ram_iftar_left');
          left = maghrib.difference(now);
        } else {
          label = context.tr('ram_suhoor_next');
          left = calc.forDate(today.add(const Duration(days: 1)))[PrayerName.fajr].difference(now);
        }
      }
      return AppCard(
        gradient: const LinearGradient(colors: Brand.gKhatma),
        borderColor: Colors.transparent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('ram_day', {'n': rd.day}), style: const TextStyle(color: Colors.white70)),
          if (left != null) ...[
            Text(label!, style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text(_clock(context, left), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 8),
            Row(children: [
              _TimeChip(context.tr('ram_suhoor_ends'), calc!.forDate(today)[PrayerName.fajr].toLocal(), context),
              const SizedBox(width: 10),
              _TimeChip(context.tr('ram_iftar'), calc.forDate(today)[PrayerName.maghrib].toLocal(), context),
            ]),
          ] else
            Text(context.tr('ram_need_location'), style: const TextStyle(color: Colors.white, height: 1.5)),
        ]),
      );
    }

    Widget fastToday() {
      if (rd == null) return const SizedBox.shrink();
      final status = ledger.days[FastingLedger.key(rd.year, rd.day)];
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('ram_fast_today'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              ChoiceChip(
                label: Text(context.tr('ram_fasted')),
                selected: status == 'f',
                onSelected: (_) => ref.read(fastingProvider.notifier).mark(rd.year, rd.day, status == 'f' ? null : 'f'),
              ),
              ChoiceChip(
                label: Text(context.tr('ram_missed')),
                selected: status == 'm',
                onSelected: (_) => ref.read(fastingProvider.notifier).mark(rd.year, rd.day, status == 'm' ? null : 'm'),
              ),
            ]),
          ]),
        ),
      );
    }

    Widget plan() {
      if (rd == null) return const SizedBox.shrink();
      final range = juzForRamadanDay(rd.day, length: ramadanLength(rd.year));
      final read = (juzLog['${rd.year}'] ?? const <int>[]);
      final q = ref.watch(quranProvider).value;
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('ram_plan'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              range.from == range.to
                  ? context.tr('ram_today_juz', {'n': range.from})
                  : context.tr('ram_today_juz2', {'a': range.from, 'b': range.to}),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: read.length / 30, minHeight: 8, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 4),
            Text(context.tr('ram_juz_done', {'n': read.length}), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: q == null
                    ? null
                    : () {
                        final start = q.juzStart(range.from);
                        push(context, ReaderScreen(surah: start.surah, initialAyah: start.ayah));
                      },
                icon: const Icon(Icons.menu_book_rounded),
                label: Text(context.tr('ram_open_juz')),
              ),
              for (var j = range.from; j <= range.to; j++)
                FilterChip(
                  label: Text(context.tr('ram_mark_juz', {'n': j})),
                  selected: read.contains(j),
                  onSelected: (_) => ref.read(ramadanJuzProvider.notifier).toggle(rd.year, j),
                ),
            ]),
          ]),
        ),
      );
    }

    Widget log() {
      if (rd == null) return const SizedBox.shrink();
      final len = ramadanLength(rd.year);
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(context.tr('ram_log'), style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(context.tr('ram_log_count', {'f': ledger.fasted(rd.year), 'm': ledger.missed(rd.year)}), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var d = 1; d <= len; d++)
                _DayDot(
                  day: d,
                  label: context.num(d),
                  status: ledger.days[FastingLedger.key(rd.year, d)],
                  isToday: d == rd.day,
                  enabled: d <= rd.day,
                  onTap: () {
                    final cur = ledger.days[FastingLedger.key(rd.year, d)];
                    ref.read(fastingProvider.notifier).mark(rd.year, d, switch (cur) { null => 'f', 'f' => 'm', _ => null });
                  },
                ),
            ]),
            const SizedBox(height: 8),
            Text(context.tr('ram_log_hint'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5)),
          ]),
        ),
      );
    }

    Widget qada() => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('qada_title'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(context.tr('qada_sub'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5, fontSize: 13)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Stat(context.num(ledger.qadaOwed), context.tr('qada_owed'))),
                const SizedBox(width: 8),
                Expanded(child: _Stat(context.num(ledger.qadaDone), context.tr('qada_done'))),
                const SizedBox(width: 8),
                Expanded(child: _Stat(context.num(ledger.qadaRemaining), context.tr('qada_left'), highlight: true)),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: ledger.qadaRemaining > 0 ? ref.read(fastingProvider.notifier).completeQada : null,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(context.tr('qada_fasted_one')),
                ),
                OutlinedButton(onPressed: ledger.qadaDone > 0 ? ref.read(fastingProvider.notifier).undoQada : null, child: Text(context.tr('qada_undo'))),
                OutlinedButton.icon(
                  onPressed: () => _editOwed(context, ref, ledger.qadaOwedExtra),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(context.tr('qada_add_old')),
                ),
              ]),
            ]),
          ),
        );

    Widget reminders() => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_rounded),
                title: Text(context.tr('ram_reminders')),
                subtitle: Text(context.tr('ram_reminders_sub')),
                value: s.ramadanReminders,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).update((x) => x.copyWith(ramadanReminders: v));
                  Bootstrap.reschedule(context, ref);
                },
              ),
              if (s.ramadanReminders)
                ListTile(
                  leading: const Icon(Icons.alarm_rounded),
                  title: Text(context.tr('ram_suhoor_lead')),
                  trailing: DropdownButton<int>(
                    value: const [20, 30, 45, 60, 90].contains(s.suhoorLeadMinutes) ? s.suhoorLeadMinutes : 45,
                    underline: const SizedBox(),
                    items: [for (final m in const [20, 30, 45, 60, 90]) DropdownMenuItem(value: m, child: Text(context.tr('ram_minutes', {'n': m})))],
                    onChanged: (v) {
                      if (v == null) return;
                      ref.read(settingsProvider.notifier).update((x) => x.copyWith(suhoorLeadMinutes: v));
                      Bootstrap.reschedule(context, ref);
                    },
                  ),
                ),
            ]),
          ),
        );

    final hijri = HijriDate.fromGregorian(today, offsetDays: s.hijriOffset);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), children: [
        PageTitle(context.tr('ram_title'), subtitle: '${context.num(hijri.day)} ${hijri.monthName(context.lang)} ${context.num(hijri.year)}'),
        header(),
        fastToday(),
        plan(),
        log(),
        qada(),
        reminders(),
      ]),
    );
  }

  Future<void> _editOwed(BuildContext context, WidgetRef ref, int current) async {
    final c = TextEditingController(text: current == 0 ? '' : '$current');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('qada_add_old')),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(labelText: context.tr('qada_old_label')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('save'))),
        ],
      ),
    );
    if (ok == true) ref.read(fastingProvider.notifier).setOwedExtra(int.tryParse(c.text.trim()) ?? 0);
    disposeAfterDialog([c]);
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip(this.label, this.time, this.ctx);
  final String label;
  final DateTime time;
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(TimeOfDay.fromDateTime(time).format(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.label, required this.status, required this.isToday, required this.enabled, required this.onTap});
  final int day;
  final String label;
  final String? status;
  final bool isToday;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) { 'f' => const Color(0xFF3DBE8B), 'm' => const Color(0xFFE5484D), _ => scheme.outline };
    return Semantics(
      button: enabled,
      label: '$label ${status == 'f' ? "✓" : status == 'm' ? "✗" : ""}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: status == null ? null : color.withValues(alpha: 0.2),
            border: Border.all(color: isToday ? Brand.gold : color, width: isToday ? 2 : 1),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, color: enabled ? null : scheme.outline, fontWeight: status == null ? FontWeight.w400 : FontWeight.w700)),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {this.highlight = false});
  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: (highlight ? Brand.gold : Theme.of(context).colorScheme.outline).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: highlight ? Brand.gold : null)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      );
}
