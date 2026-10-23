import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';
import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets/common.dart';
import '../../domain/settings.dart';

/// Opt-in reminders tied to the week and the Hijri month. Everything is
/// scheduled on the device; nothing is sent anywhere.
class SmartRemindersScreen extends ConsumerWidget {
  const SmartRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    void set(AppSettings Function(AppSettings) f) {
      ref.read(settingsProvider.notifier).update(f);
      Bootstrap.reschedule(context, ref);
    }

    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
        PageTitle(context.tr('smart_title'), subtitle: context.tr('smart_sub')),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            SwitchListTile(
              secondary: const Icon(Icons.menu_book_rounded),
              title: Text(context.tr('smart_kahf')),
              subtitle: Text(context.tr('smart_kahf_sub')),
              value: s.kahfReminder,
              onChanged: (v) => set((x) => x.copyWith(kahfReminder: v)),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.nightlight_round),
              title: Text(context.tr('smart_monthu')),
              subtitle: Text(context.tr('smart_monthu_sub')),
              value: s.fastMonThuReminder,
              onChanged: (v) => set((x) => x.copyWith(fastMonThuReminder: v)),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.brightness_2_rounded),
              title: Text(context.tr('smart_white')),
              subtitle: Text(context.tr('smart_white_sub')),
              value: s.fastWhiteReminder,
              onChanged: (v) => set((x) => x.copyWith(fastWhiteReminder: v)),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.favorite_rounded),
              title: Text(context.tr('smart_salawat')),
              subtitle: Text(context.tr('smart_salawat_sub')),
              value: s.salawatReminder,
              onChanged: (v) => set((x) => x.copyWith(salawatReminder: v)),
            ),
            if (s.salawatReminder)
              ListTile(
                leading: const Icon(Icons.alarm_rounded),
                title: Text(context.tr('smart_salawat_time')),
                trailing: TextButton(
                  child: Text(TimeOfDay(hour: s.salawatHour, minute: 0).format(context)),
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: s.salawatHour, minute: 0));
                    if (t != null && context.mounted) set((x) => x.copyWith(salawatHour: t.hour));
                  },
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(context.tr('smart_note'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5, height: 1.6)),
      ]),
    );
  }
}
