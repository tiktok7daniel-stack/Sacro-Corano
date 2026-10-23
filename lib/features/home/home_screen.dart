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
import '../../domain/occasions.dart';
import '../azkar/azkar_screen.dart';
import '../favorites/favorites_screen.dart';
import '../hadith/hadith_screen.dart';
import '../hifz/hifz_screen.dart';
import '../khatma/khatma_screen.dart';
import '../kids/kids_screen.dart';
import '../mood/mood_screen.dart';
import '../mosque/mosque_mode_screen.dart';
import '../prayer/calendar_screens.dart';
import '../prayer/prayer_card.dart';
import '../prayer/prayer_screen.dart';
import '../prophets/prophets_screen.dart';
import '../qibla/qibla_screen.dart';
import '../quran/reader_screen.dart';
import '../radio/radio_screen.dart';
import '../reciters/reciters_screen.dart';
import '../ramadan/ramadan_screen.dart';
import '../recitation/recitation_screen.dart';
import '../sadaqa/sadaqa_screen.dart';
import '../settings/settings_screen.dart';
import '../sira/sira_screen.dart';
import '../stats/stats_screen.dart';
import '../tadabbur/tadabbur_screen.dart';
import '../tafsir/audio_tafsir_screen.dart';
import '../tasbih/tasbih_screen.dart';
import '../videos/videos_screen.dart';
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
    Widget box(Widget w) => SliverToBoxAdapter(
      child: stagger(Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: w)),
    );

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
                  RoundIconButton(icon: Icons.favorite_rounded, label: context.tr('favorites'), onTap: () => push(context, const FavoritesScreen())),
                  const SizedBox(width: 8),
                  RoundIconButton(icon: Icons.insights_rounded, label: context.tr('stats'), onTap: () => push(context, const StatsScreen())),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: Icons.settings_rounded,
                    label: context.tr('nav_settings'),
                    onTap: () => push(context, Scaffold(appBar: AppBar(), body: const SettingsScreen())),
                  ),
                ],
              ),
            ),
          ),
          box(const PrayerCard()),
          box(const _QuickRow()),
          box(const WeekCard()),
          SliverToBoxAdapter(child: SectionHeader(context.tr('section_lights'))),
          SliverToBoxAdapter(
            child: stagger(const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: DailyCards())),
          ),
          box(const TipsCard()),
          SliverToBoxAdapter(child: SectionHeader(context.tr('section_daily'))),
          _grid([
            GradientTile(
              label: context.tr('prayer_times'),
              icon: Icons.schedule_rounded,
              colors: Brand.gPrayer,
              onTap: () => push(context, const PrayerScreen(standalone: true)),
            ),
            GradientTile(
              label: context.tr('azkar'),
              icon: Icons.volunteer_activism_rounded,
              colors: Brand.gAzkar,
              onTap: () => push(context, const AzkarScreen(standalone: true)),
            ),
            GradientTile(
              label: context.tr('quran_duas'),
              icon: Icons.favorite_rounded,
              colors: Brand.gDua,
              onTap: () => push(context, const QuranicDuasScreen()),
            ),
          ]),
          SliverToBoxAdapter(child: SectionHeader(context.tr('section_listen'))),
          _grid([
            GradientTile(
              label: context.tr('reciters'),
              icon: Icons.record_voice_over_rounded,
              colors: Brand.gReciters,
              onTap: () => push(context, const RecitersScreen()),
            ),
            GradientTile(label: context.tr('radio'), icon: Icons.radio_rounded, colors: Brand.gHifz, onTap: () => push(context, const RadioScreen())),
            GradientTile(label: context.tr('tasbih'), icon: Icons.touch_app_rounded, colors: Brand.gTasbih, onTap: () => push(context, const TasbihScreen())),
          ]),
          SliverToBoxAdapter(
            child: SectionHeader(
              context.tr('section_today_azkar'),
              action: context.tr('all_azkar'),
              onAction: () => push(context, const AzkarScreen(standalone: true)),
            ),
          ),
          const SliverToBoxAdapter(child: AzkarCarousel()),
          SliverToBoxAdapter(child: SectionHeader(context.tr('section_when_needed'))),
          _grid([
            GradientTile(
              label: context.tr('sadaqa'),
              icon: Icons.volunteer_activism_rounded,
              colors: Brand.gKhatma,
              onTap: () => push(context, const SadaqaScreen()),
            ),
            GradientTile(label: context.tr('ram_title'), icon: Icons.nights_stay_rounded, colors: Brand.gMosque, onTap: () => push(context, const RamadanScreen())),
            GradientTile(label: context.tr('qibla'), icon: Icons.explore_rounded, colors: Brand.gQibla, onTap: () => push(context, const QiblaScreen())),
            GradientTile(
              label: context.tr('ruqya'),
              icon: Icons.shield_moon_rounded,
              colors: Brand.gAzkar,
              onTap: () => openMergedAzkar(context, ref, context.tr('ruqya'), AzkarData.ruqya),
            ),
          ]),
          SliverToBoxAdapter(child: SectionHeader(context.tr('section_read_watch'))),
          _grid([
            GradientTile(
              label: context.tr('hadiths'),
              icon: Icons.format_quote_rounded,
              colors: Brand.gStats,
              onTap: () => push(context, const HadithScreen()),
            ),
            GradientTile(
              label: context.tr('videos'),
              icon: Icons.play_circle_rounded,
              colors: const [Color(0xFFD32F2F), Color(0xFFEF7A7A)],
              onTap: () => push(context, const VideosScreen()),
            ),
            GradientTile(
              label: context.tr('mood_verses'),
              icon: Icons.spa_rounded,
              colors: Brand.gReciters.reversed.toList(),
              onTap: () => push(context, const MoodScreen()),
            ),
          ]),
          box(const VideosHomeCard()),
          SliverToBoxAdapter(child: SectionHeader(context.tr('section_reflect'))),
          _grid([
            GradientTile(
              label: context.tr('audio_tafsir'),
              icon: Icons.headphones_rounded,
              colors: Brand.gPrayer,
              onTap: () => push(context, const AudioTafsirScreen()),
            ),
            GradientTile(label: context.tr('sira'), icon: Icons.history_edu_rounded, colors: Brand.gMosque, onTap: () => push(context, const SiraScreen())),
            GradientTile(
              label: context.tr('prophets'),
              icon: Icons.auto_stories_rounded,
              colors: Brand.gProphets,
              onTap: () => push(context, const ProphetsScreen()),
            ),
            GradientTile(label: context.tr('hifz'), icon: Icons.psychology_rounded, colors: Brand.gHifz, onTap: () => push(context, const HifzScreen())),
            GradientTile(label: context.tr('rec_title'), icon: Icons.mic_rounded, colors: Brand.gDua, onTap: () => push(context, const RecitationScreen())),
            GradientTile(label: context.tr('khatma'), icon: Icons.flag_rounded, colors: Brand.gKhatma, onTap: () => push(context, const KhatmaScreen())),
            GradientTile(label: context.tr('tadabbur'), icon: Icons.hub_rounded, colors: Brand.gStats, onTap: () => push(context, const TadabburScreen())),
          ]),
          box(const HadithOfDayCard()),
          box(const OccasionCard()),
          SliverToBoxAdapter(child: SectionHeader(context.tr('section_family'))),
          _grid([
            GradientTile(label: context.tr('kids_mode'), icon: Icons.child_care_rounded, colors: Brand.gKids, onTap: () => push(context, const KidsScreen())),
            GradientTile(
              label: context.tr('mosque_mode'),
              icon: Icons.mosque_rounded,
              colors: Brand.gMosque,
              onTap: () => push(context, const MosqueModeScreen()),
            ),
            GradientTile(
              label: context.tr('hijri_calendar'),
              icon: Icons.calendar_month_rounded,
              colors: Brand.gProphets,
              onTap: () => push(context, const HijriCalendarScreen()),
            ),
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

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.label, required this.onTap});
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
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Brand.gold.withValues(alpha: 0.08),
          border: Border.all(color: Brand.gold.withValues(alpha: 0.45)),
        ),
        child: Icon(icon, color: Brand.gold, size: 22),
      ),
    ),
  );
}

/// Continue reading · my day · next occasion.
class _QuickRow extends ConsumerWidget {
  const _QuickRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastReadProvider);
    final quran = ref.watch(quranProvider).value;
    final today = ref.watch(activityProvider)[dayKey(DateTime.now())];
    final khatma = ref.watch(khatmaProvider);
    final s = ref.watch(settingsProvider);
    final (occ, days) = nextOccasion(DateTime.now(), offsetDays: s.hijriOffset);
    final t = Theme.of(context).textTheme;

    Widget box({required List<Color> colors, required IconData icon, required String title, required String sub, VoidCallback? onTap}) => Expanded(
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
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(color: Colors.white70),
              ),
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
          sub: khatma != null ? context.tr('khatma_today', {'n': khatma.todayTarget(DateTime.now())}) : context.tr('prayed_n', {'n': prayed}),
          onTap: () => push(context, const DailyChecklistScreen()),
        ),
        const SizedBox(width: 12),
        box(
          colors: const [Color(0xFF2E2A20), Color(0xFF23201A)],
          icon: Icons.nightlight_round,
          title: occ.name(context.lang),
          sub: days == 0 ? context.tr('today') : context.tr('in_days', {'n': days}),
          onTap: () => push(context, const HijriCalendarScreen()),
        ),
      ],
    );
  }
}

/// "Your week": prayers logged out of 35, active days out of 7.
class WeekCard extends ConsumerWidget {
  const WeekCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final act = ref.watch(activityProvider);
    final now = DateUtils.dateOnly(DateTime.now());
    // The week starts on Saturday, as on most Arabic calendars.
    final start = now.subtract(Duration(days: (now.weekday + 1) % 7));
    final days = [for (var k = 0; k < 7; k++) start.add(Duration(days: k))];
    final prayers = days.fold<int>(0, (a, d) => a + (act[dayKey(d)]?.prayers.length ?? 0));
    final active = days.where((d) => act[dayKey(d)]?.active ?? false).length;
    final elapsed = now.difference(start).inDays + 1;
    final avg = (prayers / elapsed).toStringAsFixed(1);
    final names = context.isAr ? const ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'] : const ['S', 'S', 'M', 'T', 'W', 'T', 'F'];

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Brand.gold),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Brand.textMid),
          ),
        ],
      ),
    );

    return AppCard(
      onTap: () => push(context, const StatsScreen()),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.date_range_rounded, color: Brand.tealBright, size: 20),
              const SizedBox(width: 8),
              Text(context.tr('your_week'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              const Icon(Icons.chevron_left_rounded, color: Brand.textMid),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('${context.num(prayers)}/${context.num(35)}', context.tr('prayers')),
              stat('${context.num(active)}/${context.num(7)}', context.tr('active_days')),
              stat(context.num(avg), context.tr('daily_average')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final (k, d) in days.indexed)
                Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (act[dayKey(d)]?.active ?? false) ? Brand.tealBright : Colors.white.withValues(alpha: 0.06),
                        border: d == now ? Border.all(color: Brand.gold, width: 2) : null,
                      ),
                      child: Text(context.num(act[dayKey(d)]?.prayers.length ?? 0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Text(names[k], style: const TextStyle(fontSize: 11, color: Brand.textMid)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Did you know?" — rotating tips about what the app can do.
class TipsCard extends StatefulWidget {
  const TipsCard({super.key});

  @override
  State<TipsCard> createState() => _TipsCardState();
}

class _TipsCardState extends State<TipsCard> {
  late int _i = DateTime.now().day % _tips.length;

  static final _tips = <(String, IconData, Widget Function())>[
    ('tip_tafsir', Icons.headphones_rounded, () => const AudioTafsirScreen()),
    ('tip_hifz', Icons.psychology_rounded, () => const HifzScreen()),
    ('tip_radio', Icons.radio_rounded, () => const RadioScreen()),
    ('tip_sira', Icons.history_edu_rounded, () => const SiraScreen()),
    ('tip_khatma', Icons.flag_rounded, () => const KhatmaScreen()),
    ('tip_sadaqa', Icons.volunteer_activism_rounded, () => const SadaqaScreen()),
    ('tip_calendar', Icons.calendar_month_rounded, () => const HijriCalendarScreen()),
    ('tip_hadith', Icons.format_quote_rounded, () => const HadithScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final (key, icon, page) = _tips[_i];
    return AppCard(
      gradient: const LinearGradient(colors: [Color(0xFF2B2440), Color(0xFF1D1A2B)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: Brand.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                context.tr('did_you_know'),
                style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text('${context.num(_i + 1)}/${context.num(_tips.length)}', style: const TextStyle(color: Brand.textLow, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: Motion.of(context).short,
            child: Row(
              key: ValueKey(_i),
              children: [
                Icon(icon, color: Brand.tealBright, size: 34),
                const SizedBox(width: 12),
                Expanded(child: Text(context.tr(key), style: const TextStyle(height: 1.6))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonal(onPressed: () => push(context, page()), child: Text(context.tr('open'))),
              const Spacer(),
              IconButton(
                tooltip: context.tr('next'),
                onPressed: () => setState(() => _i = (_i + 1) % _tips.length),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The adhkar of the day, with the one whose time it is flagged.
class AzkarCarousel extends ConsumerWidget {
  const AzkarCarousel({super.key});

  static String? nowCategory(DateTime t) {
    final h = t.hour;
    if (h >= 4 && h < 11) return AzkarData.morning;
    if (h >= 15 && h < 20) return AzkarData.evening;
    if (h >= 21 || h < 2) return AzkarData.sleep;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(activityProvider)[dayKey(DateTime.now())]?.azkar ?? const {};
    final current = nowCategory(DateTime.now());
    final items = [
      (AzkarData.morning, 'morning_azkar', Icons.wb_sunny_rounded, Brand.gKhatma),
      (AzkarData.evening, 'evening_azkar', Icons.nights_stay_rounded, Brand.gAzkar),
      (AzkarData.afterPrayer, 'after_prayer_azkar', Icons.mosque_rounded, Brand.gReciters),
      (AzkarData.sleep, 'sleep_azkar', Icons.bedtime_rounded, Brand.gHifz),
      (AzkarData.waking, 'waking_azkar', Icons.alarm_rounded, Brand.gQibla),
    ]..sort((a, b) => (b.$1 == current ? 1 : 0) - (a.$1 == current ? 1 : 0));
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final (name, label, icon, colors) = items[i];
          return SizedBox(
            width: 150,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GradientTile(label: context.tr(label), icon: icon, colors: colors, onTap: () => openAzkarCategory(context, ref, name)),
                ),
                if (name == current && !done.contains(name))
                  PositionedDirectional(top: 10, end: 10, child: Pill(context.tr('its_time_now'), color: Colors.white)),
                if (done.contains(name)) const PositionedDirectional(top: 10, end: 10, child: Icon(Icons.check_circle_rounded, color: Colors.white)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Countdown to Ramadan (or the occasion in progress).
class OccasionCard extends ConsumerWidget {
  const OccasionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset = ref.watch(settingsProvider.select((s) => s.hijriOffset));
    final now = DateTime.now();
    final current = occasionsOn(now, offsetDays: offset);
    final (o, days) = current.isNotEmpty ? (current.first, 0) : nextOccasion(now, offsetDays: offset, only: const {'ramadan'});
    return AppCard(
      onTap: () => push(context, const HijriCalendarScreen()),
      gradient: const LinearGradient(colors: [Color(0xFF3A2F17), Color(0xFF221C10)]),
      borderColor: Brand.gold.withValues(alpha: 0.4),
      child: Row(
        children: [
          const Icon(Icons.nightlight_round, color: Brand.gold, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.name(context.lang),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Brand.gold),
                ),
                Text(days == 0 ? context.tr('occasion_now') : context.tr('days_left', {'n': days}), style: const TextStyle(color: Brand.textMid)),
              ],
            ),
          ),
          if (days > 0)
            Column(
              children: [
                Text(context.num(days), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                Text(context.tr('day_unit'), style: const TextStyle(color: Brand.textMid, fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }
}
