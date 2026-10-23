import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/hijri.dart';
import '../../core/widgets/common.dart';
import '../../data/azkar_repository.dart';
import '../../domain/khatma.dart';
import '../azkar/azkar_screen.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../hifz/hifz_screen.dart';
import '../khatma/khatma_screen.dart';
import '../kids/kids_screen.dart';
import '../mood/mood_screen.dart';
import '../mosque/mosque_mode_screen.dart';
import '../prayer/prayer_card.dart';
import '../prayer/prayer_screen.dart';
import '../prophets/prophets_screen.dart';
import '../qibla/qibla_screen.dart';
import '../quran/reader_screen.dart';
import '../reciters/reciters_screen.dart';
import '../stats/stats_screen.dart';
import '../tadabbur/tadabbur_screen.dart';
import '../tasbih/tasbih_screen.dart';
import 'daily_cards.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 4) return context.tr('greet_night');
    if (h < 12) return context.tr('greet_morning');
    if (h < 17) return context.tr('greet_afternoon');
    return context.tr('greet_evening');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final s = ref.watch(settingsProvider);
    final hijri = HijriDate.fromGregorian(DateTime.now(), offsetDays: s.hijriOffset);
    var i = 0;
    Widget stagger(Widget w) => FadeSlideIn.indexed(i++, child: w);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('salam'), style: t.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        Text(_greeting(context), style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '${context.num(hijri.day)} ${hijri.monthName(context.lang)} ${context.num(hijri.year)} ${context.tr('hijri_suffix')}',
                          style: t.bodySmall?.copyWith(color: Brand.gold),
                        ),
                      ],
                    ),
                  ),
                  _RoundIcon(icon: Icons.favorite_rounded, label: context.tr('bookmarks'), onTap: () => push(context, const BookmarksScreen())),
                  const SizedBox(width: 10),
                  _RoundIcon(icon: Icons.insights_rounded, label: context.tr('stats'), onTap: () => push(context, const StatsScreen())),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: stagger(const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: PrayerCard()))),
          SliverToBoxAdapter(child: stagger(const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: _QuickRow()))),
          SliverToBoxAdapter(child: stagger(const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: DailyCards()))),
          SliverToBoxAdapter(child: SectionHeader(context.tr('section_daily'))),
          _grid([
            GradientTile(label: context.tr('prayer_times'), icon: Icons.schedule_rounded, colors: Brand.gPrayer, onTap: () => push(context, const PrayerScreen(standalone: true))),
            GradientTile(label: context.tr('azkar'), icon: Icons.volunteer_activism_rounded, colors: Brand.gAzkar, onTap: () => push(context, const AzkarScreen(standalone: true))),
            GradientTile(label: context.tr('quran_duas'), icon: Icons.favorite_rounded, colors: Brand.gDua, onTap: () => push(context, const QuranicDuasScreen())),
          ]),
          SliverToBoxAdapter(child: SectionHeader(context.tr('section_listen'))),
          _grid([
            GradientTile(label: context.tr('reciters'), icon: Icons.record_voice_over_rounded, colors: Brand.gReciters, onTap: () => push(context, const RecitersScreen())),
            GradientTile(label: context.tr('tasbih'), icon: Icons.touch_app_rounded, colors: Brand.gTasbih, onTap: () => push(context, const TasbihScreen())),
            GradientTile(label: context.tr('qibla'), icon: Icons.explore_rounded, colors: Brand.gQibla, onTap: () => push(context, const QiblaScreen())),
          ]),
          SliverToBoxAdapter(child: SectionHeader(context.tr('section_reflect'))),
          _grid([
            GradientTile(label: context.tr('prophets'), icon: Icons.auto_stories_rounded, colors: Brand.gProphets, onTap: () => push(context, const ProphetsScreen())),
            GradientTile(label: context.tr('hifz'), icon: Icons.psychology_rounded, colors: Brand.gHifz, onTap: () => push(context, const HifzScreen())),
            GradientTile(label: context.tr('khatma'), icon: Icons.flag_rounded, colors: Brand.gKhatma, onTap: () => push(context, const KhatmaScreen())),
            GradientTile(label: context.tr('tadabbur'), icon: Icons.hub_rounded, colors: Brand.gStats, onTap: () => push(context, const TadabburScreen())),
            GradientTile(label: context.tr('mood_verses'), icon: Icons.spa_rounded, colors: Brand.gReciters.reversed.toList(), onTap: () => push(context, const MoodScreen())),
            GradientTile(label: context.tr('stats'), icon: Icons.insights_rounded, colors: Brand.gStats.reversed.toList(), onTap: () => push(context, const StatsScreen())),
          ]),
          SliverToBoxAdapter(child: SectionHeader(context.tr('section_family'))),
          _grid([
            GradientTile(label: context.tr('kids_mode'), icon: Icons.child_care_rounded, colors: Brand.gKids, onTap: () => push(context, const KidsScreen())),
            GradientTile(label: context.tr('mosque_mode'), icon: Icons.mosque_rounded, colors: Brand.gMosque, onTap: () => push(context, const MosqueModeScreen())),
            GradientTile(label: context.tr('morning_azkar'), icon: Icons.wb_sunny_rounded, colors: Brand.gKhatma, onTap: () => openAzkarCategory(context, ref, AzkarData.morning)),
          ]),
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ),
    );
  }

  Widget _grid(List<Widget> tiles) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid.count(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.84,
          children: [for (var i = 0; i < tiles.length; i++) FadeSlideIn.indexed(i, child: tiles[i])],
        ),
      );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: Pressable(
          onTap: onTap,
          semanticLabel: label,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Brand.gold.withValues(alpha: 0.08),
              border: Border.all(color: Brand.gold.withValues(alpha: 0.45)),
            ),
            child: Icon(icon, color: Brand.gold),
          ),
        ),
      );
}

/// Continue reading · daily checklist · next occasion.
class _QuickRow extends ConsumerWidget {
  const _QuickRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastReadProvider);
    final quran = ref.watch(quranProvider).value;
    final today = ref.watch(activityProvider)[dayKey(DateTime.now())];
    final khatma = ref.watch(khatmaProvider);
    final s = ref.watch(settingsProvider);
    final ramadan = HijriDate.daysUntil(9, 1, offsetDays: s.hijriOffset);
    final t = Theme.of(context).textTheme;

    Widget box({required List<Color> colors, required IconData icon, required String title, required String sub, VoidCallback? onTap}) =>
        Expanded(
          child: Pressable(
            onTap: onTap,
            semanticLabel: title,
            child: Container(
              height: 138,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: Brand.gold, size: 22),
                  ),
                  const Spacer(),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
          ),
        );

    final prayed = today?.prayers.length ?? 0;
    return Row(
      children: [
        box(
          colors: const [Color(0xFF145E6B), Color(0xFF0F4652)],
          icon: Icons.bookmark_rounded,
          title: last != null && quran != null ? quran.surah(last.surah).nameAr : context.tr('start_reading'),
          sub: last != null ? context.tr('continue_from', {'n': last.ayah}) : context.tr('from_fatiha'),
          onTap: () => push(context, ReaderScreen(surah: last?.surah ?? 1, initialAyah: last?.ayah ?? 1)),
        ),
        const SizedBox(width: 12),
        box(
          colors: const [Color(0xFF1C2A33), Color(0xFF16222A)],
          icon: Icons.task_alt_rounded,
          title: context.tr('my_day'),
          sub: khatma != null
              ? context.tr('khatma_today', {'n': khatma.todayTarget(DateTime.now())})
              : context.tr('prayed_n', {'n': prayed}),
          onTap: () => push(context, const DailyChecklistScreen()),
        ),
        const SizedBox(width: 12),
        box(
          colors: const [Color(0xFF2E2A20), Color(0xFF23201A)],
          icon: Icons.nightlight_round,
          title: context.tr('ramadan'),
          sub: ramadan == 0 ? context.tr('ramadan_today') : context.tr('in_days', {'n': ramadan}),
          onTap: () => openAzkarCategory(context, ref, 'الدعاء عند إفطار الصائم - الصوم'),
        ),
      ],
    );
  }
}
