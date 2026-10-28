import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../data/quran/content_repository.dart';
import '../../domain/reciters.dart';
import 'widgets/tajweed_text.dart';

Future<void> showReadingSettings(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReadingSettings(),
    );

class _ReadingSettings extends ConsumerWidget {
  const _ReadingSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    Widget swatch(AppThemeKind k, Color bg, Color fg, String label) => Expanded(
          child: GestureDetector(
            onTap: () => ctrl.update((x) => x.copyWith(readingTheme: k)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: s.readingTheme == k ? Brand.gold : Colors.transparent, width: 2.5),
              ),
              alignment: Alignment.center,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('بِسۡمِ', style: TextStyle(fontFamily: Brand.quranFont, color: fg, fontSize: 18)),
                Text(label, style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11)),
              ]),
            ),
          ),
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(context.tr('reading_settings'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.reading.page, borderRadius: BorderRadius.circular(18)),
            child: Text(
              'ٱلۡحَمۡدُ لِلَّهِ رَبِّ ٱلۡعَٰلَمِينَ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: Brand.quranFont, fontSize: s.quranFontSize, color: context.reading.ink, height: 2),
            ),
          ),
          Row(children: [
            const Icon(Icons.text_decrease_rounded),
            Expanded(
              child: Slider(
                value: s.quranFontSize,
                min: 20,
                max: 52,
                divisions: 16,
                label: s.quranFontSize.round().toString(),
                onChanged: (v) => ctrl.update((x) => x.copyWith(quranFontSize: v)),
              ),
            ),
            const Icon(Icons.text_increase_rounded),
          ]),
          const SizedBox(height: 8),
          Text(context.tr('reading_theme')),
          const SizedBox(height: 8),
          Row(children: [
            swatch(AppThemeKind.system, Theme.of(context).scaffoldBackgroundColor, Theme.of(context).colorScheme.onSurface, context.tr('theme_match')),
            swatch(AppThemeKind.night, Brand.night, Brand.textHigh, context.tr('theme_night')),
            swatch(AppThemeKind.light, Colors.white, Colors.black, context.tr('theme_paper')),
            swatch(AppThemeKind.sepia, Brand.sepia, Brand.sepiaInk, context.tr('theme_sepia')),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('tajweed_colors')),
            subtitle: Text(context.tr('tajweed_colors_sub')),
            value: s.tajweed,
            onChanged: (v) => ctrl.update((x) => x.copyWith(tajweed: v)),
            secondary: IconButton(
              tooltip: context.tr('legend'),
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => showTajweedLegend(context, dark: context.reading.page.computeLuminance() < 0.3),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('page_mode')),
            subtitle: Text(context.tr('page_mode_sub')),
            value: s.pageMode,
            onChanged: (v) => ctrl.update((x) => x.copyWith(pageMode: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('show_translation')),
            value: s.showTranslation,
            onChanged: (v) => ctrl.update((x) => x.copyWith(showTranslation: v)),
          ),
          if (s.showTranslation)
            DropdownButtonFormField<String>(
              initialValue: s.translationId,
              decoration: InputDecoration(labelText: context.tr('translation')),
              items: [for (final e in Editions.translations) DropdownMenuItem(value: e.id, child: Text(e.name(context.lang)))],
              onChanged: (v) => ctrl.update((x) => x.copyWith(translationId: v)),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: s.reciterId,
            decoration: InputDecoration(labelText: context.tr('reciter')),
            items: [for (final r in reciters) DropdownMenuItem(value: r.id, child: Text(r.name(context.lang)))],
            onChanged: (v) => ctrl.update((x) => x.copyWith(reciterId: v)),
          ),
        ],
      ),
    );
  }
}
