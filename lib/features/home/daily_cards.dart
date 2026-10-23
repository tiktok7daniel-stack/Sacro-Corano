import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../data/azkar_repository.dart';
import '../../domain/daily_content.dart';
import '../../domain/khatma.dart';
import '../../domain/prayer_times.dart';
import '../azkar/azkar_screen.dart';
import '../hifz/hifz_screen.dart';
import '../khatma/khatma_screen.dart';
import '../quran/reader_screen.dart';
import '../share/share_card.dart';
import '../../domain/quran_models.dart';

/// Verse, dua and dhikr of the day, in a horizontally swipeable row.
class DailyCards extends ConsumerWidget {
  const DailyCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quran = ref.watch(quranProvider).value;
    final azkar = ref.watch(azkarProvider).value;
    if (quran == null) return const SizedBox(height: 180);
    final now = DateTime.now();
    final verse = verseOfTheDay(now);
    final dua = duaOfTheDay(now);
    final morning = azkar?.byName(AzkarData.afterPrayer) ?? azkar?.categories.first;
    final zikr = morning == null ? null : morning.items[dailyIndex(now, morning.items.length, salt: 3)];

    Widget card({required String label, required IconData icon, required String body, required String foot, required List<Color> colors, required VoidCallback onTap, VoidCallback? onShare, bool quranFont = true}) =>
        SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.78,
          child: AppCard(
            onTap: onTap,
            gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: colors),
            borderColor: colors.last.withValues(alpha: 0.6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, color: Brand.tealBright, size: 20),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (onShare != null)
                    InkResponse(onTap: onShare, child: const Icon(Icons.ios_share_rounded, size: 18, color: Brand.textMid)),
                ]),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: quranFont ? Brand.quranFont : Brand.naskhFont,
                      fontSize: 20,
                      height: 1.9,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(foot, style: const TextStyle(color: Brand.textMid, fontSize: 12)),
              ],
            ),
          ),
        );

    return SizedBox(
      height: 210,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          card(
            label: context.tr('verse_of_day'),
            icon: Icons.auto_awesome_rounded,
            body: quran.textOf(verse),
            foot: '${quran.surah(verse.surah).nameAr} · ${context.num(verse.ayah)}',
            colors: const [Color(0xFF123F48), Color(0xFF0E2A33)],
            onTap: () => push(context, ReaderScreen(surah: verse.surah, initialAyah: verse.ayah)),
            onShare: () => shareVerseImage(context, ref, AyahRange(verse.surah, verse.ayah, verse.ayah)),
          ),
          const SizedBox(width: 12),
          card(
            label: context.tr('dua_of_day'),
            icon: Icons.front_hand_rounded,
            body: quran.textOf(dua),
            foot: '${quran.surah(dua.surah).nameAr} · ${context.num(dua.ayah)}',
            colors: const [Color(0xFF1B2F3A), Color(0xFF14212A)],
            onTap: () => push(context, ReaderScreen(surah: dua.surah, initialAyah: dua.ayah)),
            onShare: () => shareVerseImage(context, ref, AyahRange(dua.surah, dua.ayah, dua.ayah)),
          ),
          if (zikr != null) ...[
            const SizedBox(width: 12),
            card(
              label: context.tr('zikr_of_day'),
              icon: Icons.verified_rounded,
              body: zikr.text,
              foot: '${zikr.reference}${zikr.count > 1 ? ' · ${context.tr('times', {'n': zikr.count})}' : ''}',
              colors: const [Color(0xFF1E2A26), Color(0xFF151F1C)],
              quranFont: false,
              onTap: () => openAzkarCategory(context, ref, morning!.name),
            ),
          ],
        ],
      ),
    );
  }
}

/// "My day": everything due today on one checklist.
class DailyChecklistScreen extends ConsumerWidget {
  const DailyChecklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(activityProvider)[dayKey(DateTime.now())];
    final khatma = ref.watch(khatmaProvider);
    final hifzDue = ref.watch(hifzProvider.notifier).due().length;
    ref.watch(hifzProvider);
    final s = ref.watch(settingsProvider);
    final calc = ref.watch(prayerCalculatorProvider);
    final times = calc?.forDate(DateTime.now());

    Widget tile(String title, bool done, {String? sub, VoidCallback? onTap}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            onTap: onTap,
            child: Row(children: [
              AnimatedSwitcher(
                duration: Motion.of(context).short,
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(
                  done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  key: ValueKey(done),
                  color: done ? Brand.tealBright : Brand.textLow,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  if (sub != null) Text(sub, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                ]),
              ),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          PageTitle(context.tr('my_day'), subtitle: context.tr('my_day_sub')),
          SectionHeader(context.tr('prayers')),
          for (final p in PrayerName.values.where((p) => p.isFard))
            tile(
              context.tr('prayer_${p.name}'),
              today?.prayers.contains(p.name) ?? false,
              sub: times == null ? null : TimeOfDay.fromDateTime(times[p]).format(context),
              onTap: () {
                haptic(ref);
                ref.read(activityProvider.notifier).togglePrayer(p.name);
              },
            ),
          SectionHeader(context.tr('azkar')),
          tile(context.tr('morning_azkar'), today?.azkar.contains(AzkarData.morning) ?? false,
              onTap: () => openAzkarCategory(context, ref, AzkarData.morning)),
          tile(context.tr('evening_azkar'), today?.azkar.contains(AzkarData.evening) ?? false,
              onTap: () => openAzkarCategory(context, ref, AzkarData.evening)),
          SectionHeader(context.tr('quran')),
          tile(
            context.tr('khatma'),
            khatma != null && khatma.readOn(DateTime.now()) >= khatma.todayTarget(DateTime.now()),
            sub: khatma == null ? context.tr('khatma_none') : context.tr('khatma_today', {'n': khatma.todayTarget(DateTime.now())}),
            onTap: () => push(context, const KhatmaScreen()),
          ),
          tile(context.tr('hifz_review'), hifzDue == 0,
              sub: context.tr('hifz_due_n', {'n': hifzDue}), onTap: () => push(context, const HifzScreen())),
          tile(context.tr('tasbih'), (today?.tasbih ?? 0) >= s.tasbihGoal,
              sub: '${context.num(today?.tasbih ?? 0)} / ${context.num(s.tasbihGoal)}'),
        ],
      ),
    );
  }
}
