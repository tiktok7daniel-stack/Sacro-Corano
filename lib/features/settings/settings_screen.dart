import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/bootstrap.dart';
import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/logo.dart';
import '../../data/quran/content_repository.dart';
import '../../domain/reciters.dart';
import '../../domain/settings.dart';
import '../../services/backup.dart';
import '../prayer/prayer_screen.dart';
import '../reciters/reciters_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    void set(AppSettings Function(AppSettings) f) => ctrl.update(f);

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 140), children: [
        Row(children: [
          const MishkahLogo(size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('nav_settings'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(context.tr('app_tagline'), style: const TextStyle(color: Brand.textMid)),
            ]),
          ),
        ]),
        SectionHeader(context.tr('appearance')),
        _Group(children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.tr('theme')),
            trailing: DropdownButton<AppThemeKind>(
              value: s.theme,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: AppThemeKind.system, child: Text(context.tr('theme_system'))),
                DropdownMenuItem(value: AppThemeKind.night, child: Text(context.tr('theme_night'))),
                DropdownMenuItem(value: AppThemeKind.light, child: Text(context.tr('theme_light'))),
                DropdownMenuItem(value: AppThemeKind.sepia, child: Text(context.tr('theme_sepia'))),
              ],
              onChanged: (v) => set((x) => x.copyWith(theme: v)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(context.tr('language')),
            trailing: SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('English'))],
              selected: {s.lang},
              onSelectionChanged: (v) {
                set((x) => x.copyWith(lang: v.first));
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) Bootstrap.reschedule(context, ref);
                });
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.contrast_rounded),
            title: Text(context.tr('high_contrast')),
            value: s.highContrast,
            onChanged: (v) => set((x) => x.copyWith(highContrast: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.animation_rounded),
            title: Text(context.tr('reduce_motion')),
            subtitle: Text(context.tr('reduce_motion_sub')),
            value: s.reduceMotion,
            onChanged: (v) => set((x) => x.copyWith(reduceMotion: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded),
            title: Text(context.tr('haptics')),
            value: s.haptics,
            onChanged: (v) => set((x) => x.copyWith(haptics: v)),
          ),
        ]),
        SectionHeader(context.tr('quran')),
        _Group(children: [
          ListTile(
            leading: const Icon(Icons.format_size_rounded),
            title: Text(context.tr('font_size')),
            subtitle: Slider(
              value: s.quranFontSize,
              min: 20,
              max: 52,
              divisions: 16,
              onChanged: (v) => set((x) => x.copyWith(quranFontSize: v)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: Text(context.tr('reciter')),
            subtitle: Text(reciterById(s.reciterId).name(context.lang)),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => push(context, const RecitersScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(context.tr('translation')),
            trailing: DropdownButton<String>(
              value: s.translationId,
              underline: const SizedBox(),
              items: [for (final e in Editions.translations) DropdownMenuItem(value: e.id, child: Text(e.lang.toUpperCase()))],
              onChanged: (v) => set((x) => x.copyWith(translationId: v)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: Text(context.tr('offline_content')),
            subtitle: Text(context.tr('offline_content_sub')),
            onTap: () => push(context, const OfflineContentScreen()),
          ),
        ]),
        SectionHeader(context.tr('prayer_and_reminders')),
        _Group(children: [
          ListTile(
            leading: const Icon(Icons.mosque_outlined),
            title: Text(context.tr('prayer_settings')),
            subtitle: Text(s.placeName ?? context.tr('not_set')),
            onTap: () => push(context, const PrayerSettingsScreen()),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: Text(context.tr('azkar_reminders')),
            subtitle: Text(context.tr('azkar_reminders_sub')),
            value: s.azkarReminders,
            onChanged: (v) {
              set((x) => x.copyWith(azkarReminders: v));
              Bootstrap.reschedule(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.alarm_rounded),
            title: Text(context.tr('wird_reminder')),
            trailing: TextButton(
              child: Text(TimeOfDay(hour: s.wirdReminderHour, minute: 0).format(context)),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: s.wirdReminderHour, minute: 0));
                if (t == null || !context.mounted) return;
                set((x) => x.copyWith(wirdReminderHour: t.hour));
                Bootstrap.reschedule(context, ref);
              },
            ),
          ),
        ]),
        SectionHeader(context.tr('backup_sync')),
        _Group(children: [
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: Text(context.tr('export_backup')),
            subtitle: Text(context.tr('export_backup_sub')),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: Text(context.tr('import_backup')),
            onTap: () => _import(context, ref),
          ),
        ]),
        SectionHeader(context.tr('about')),
        _Group(children: [
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(context.tr('about_app')),
            onTap: () => push(context, const AboutScreen()),
          ),
        ]),
      ]),
    );
  }

  Future<String?> _askPass(BuildContext context, {required bool confirm}) async {
    final a = TextEditingController();
    final b = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('backup_pass')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr('backup_pass_hint'), style: const TextStyle(fontSize: 13, color: Brand.textMid)),
          TextField(controller: a, obscureText: true, autofocus: true, decoration: InputDecoration(labelText: context.tr('passphrase'))),
          if (confirm) TextField(controller: b, obscureText: true, decoration: InputDecoration(labelText: context.tr('confirm'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (a.text.length < 6 || (confirm && a.text != b.text)) return;
              Navigator.pop(context, a.text);
            },
            child: Text(context.tr('ok')),
          ),
        ],
      ),
    );
    disposeAfterDialog([a, b]);
    return v;
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final pass = await _askPass(context, confirm: true);
    if (pass == null || !context.mounted) return;
    final storage = ref.read(storageProvider);
    final data = storage.exportAll();
    final payload = await compute((List<Object> a) => Backup.encryptJson(a[0] as Map<String, dynamic>, a[1] as String), <Object>[data, pass]);
    final file = File('${Directory.systemTemp.path}/mishkah-backup.mishkah');
    await file.writeAsString(payload);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Mishkah backup'));
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles();
    final path = picked.isEmpty ? null : picked.single.path;
    if (path == null || !context.mounted) return;
    final pass = await _askPass(context, confirm: false);
    if (pass == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = context.tr('backup_restored');
    try {
      final raw = await File(path).readAsString();
      final data = await compute((List<String> a) => Backup.decryptJson(a[0], a[1]), [raw, pass]);
      await ref.read(storageProvider).importAll(data);
      ref.invalidate(settingsProvider);
      ref.invalidate(bookmarksProvider);
      ref.invalidate(reflectionsProvider);
      ref.invalidate(activityProvider);
      ref.invalidate(khatmaProvider);
      ref.invalidate(hifzProvider);
      ref.invalidate(tasbihProvider);
      ref.invalidate(kidsProvider);
      ref.invalidate(lastReadProvider);
      messenger.showSnackBar(SnackBar(content: Text(ok)));
    } on BackupException catch (e) {
      if (context.mounted) messenger.showSnackBar(SnackBar(content: Text(context.tr(e.code))));
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => FadeSlideIn(
        child: AppCard(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: children)),
      );
}

/// Manage downloadable tafsir editions.
class OfflineContentScreen extends ConsumerStatefulWidget {
  const OfflineContentScreen({super.key});
  @override
  ConsumerState<OfflineContentScreen> createState() => _OfflineContentScreenState();
}

class _OfflineContentScreenState extends ConsumerState<OfflineContentScreen> {
  final Map<String, double> _progress = {};

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(contentRepoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('offline_content'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(context.tr('offline_bundled'), style: const TextStyle(color: Brand.textMid)),
        const SizedBox(height: 12),
        for (final e in Editions.tafsirs)
          FutureBuilder<int>(
            future: repo.downloadedSurahCount(e.id),
            builder: (context, snap) {
              final n = snap.data ?? 0;
              final p = _progress[e.id];
              return ListTile(
                title: Text(e.name(context.lang)),
                subtitle: p != null
                    ? LinearProgressIndicator(value: p)
                    : Text(e.bundled ? context.tr('bundled') : context.tr('downloaded_n', {'n': n})),
                trailing: e.bundled
                    ? const Icon(Icons.check_circle_rounded, color: Brand.tealBright)
                    : n >= 114
                        ? IconButton(
                            tooltip: context.tr('delete'),
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              await repo.deleteEdition(e.id);
                              setState(() {});
                            },
                          )
                        : IconButton(
                            tooltip: context.tr('download_for_offline'),
                            icon: const Icon(Icons.download_rounded),
                            onPressed: p != null
                                ? null
                                : () async {
                                    setState(() => _progress[e.id] = 0);
                                    try {
                                      await repo.downloadAll(e.id, onProgress: (v) => setState(() => _progress[e.id] = v));
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('download_failed'))));
                                      }
                                    }
                                    if (mounted) setState(() => _progress.remove(e.id));
                                  },
                          ),
              );
            },
          ),
      ]),
    );
  }
}
