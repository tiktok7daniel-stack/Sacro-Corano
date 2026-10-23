import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/arabic.dart';
import '../../core/widgets/common.dart';
import '../../data/azkar_repository.dart';
import '../../domain/khatma.dart';
import '../celebration/celebration.dart';
import '../tasbih/tasbih_screen.dart';

Future<void> openAzkarCategory(BuildContext context, WidgetRef ref, String name) async {
  final data = await ref.read(azkarProvider.future);
  final cat = data.byName(name) ?? data.categories.first;
  if (context.mounted) await push(context, AzkarReaderScreen(category: cat));
}

Future<void> openMergedAzkar(BuildContext context, WidgetRef ref, String title, List<String> names) async {
  final data = await ref.read(azkarProvider.future);
  if (context.mounted) await push(context, AzkarReaderScreen(category: data.merged(title, names)));
}

/// Azkar tab: Hisn al-Muslim at a glance, the daily categories, the prayer
/// adhkar and the electronic tasbih.
class AzkarScreen extends ConsumerWidget {
  const AzkarScreen({super.key, this.standalone = false});
  final bool standalone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(azkarProvider);
    final today = ref.watch(activityProvider)[dayKey(DateTime.now())];
    final current = _nowCategory(DateTime.now());

    final body = AsyncView<AzkarData>(
      value: data,
      builder: (d) {
        final featured = [
          (AzkarData.morning, context.tr('morning_azkar'), Icons.wb_sunny_rounded, Brand.gKhatma),
          (AzkarData.evening, context.tr('evening_azkar'), Icons.nights_stay_rounded, Brand.gAzkar),
          (AzkarData.sleep, context.tr('sleep_azkar'), Icons.bedtime_rounded, Brand.gHifz),
          (AzkarData.waking, context.tr('waking_azkar'), Icons.alarm_rounded, Brand.gQibla),
          (AzkarData.distress, context.tr('distress_dua'), Icons.healing_rounded, Brand.gDua),
          (AzkarData.istighfar, context.tr('istighfar'), Icons.water_drop_rounded, Brand.gReciters),
        ];
        final prayer = [
          ('أذكار الآذان', context.tr('adhan_azkar'), Icons.campaign_rounded, Brand.gPrayer, null),
          (null, context.tr('in_prayer_azkar'), Icons.accessibility_new_rounded, Brand.gMosque, AzkarData.inPrayer),
          (AzkarData.afterPrayer, context.tr('after_prayer_azkar'), Icons.mosque_rounded, Brand.gReciters, null),
          ('دعاء قنوت الوتر', context.tr('witr_azkar'), Icons.nightlight_round, Brand.gHifz, null),
        ];
        Widget grid(List<Widget> children, {double ratio = 1.35}) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: ratio,
            children: [for (final (i, c) in children.indexed) FadeSlideIn.indexed(i, child: c)],
          ),
        );
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(context.tr('azkar'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: FadeSlideIn(child: _HisnHero(data: d)),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                context.tr('azkar_categories'),
                action: context.tr('show_all'),
                onAction: () => push(context, HisnIndexScreen(data: d)),
              ),
            ),
            grid([
              for (final (name, label, icon, colors) in featured)
                Stack(
                  children: [
                    Positioned.fill(
                      child: GradientTile(
                        label: label,
                        subtitle: d.byName(name) == null ? null : context.tr('items_n', {'n': d.byName(name)!.items.length}),
                        icon: icon,
                        colors: colors,
                        onTap: () => openAzkarCategory(context, ref, name),
                      ),
                    ),
                    if (today?.azkar.contains(name) ?? false)
                      const PositionedDirectional(top: 12, end: 12, child: Icon(Icons.check_circle_rounded, color: Colors.white))
                    else if (name == current)
                      PositionedDirectional(top: 12, end: 12, child: Pill(context.tr('its_time_now'), color: Colors.white)),
                  ],
                ),
            ]),
            SliverToBoxAdapter(child: SectionHeader(context.tr('prayer_azkar'))),
            grid([
              for (final (name, label, icon, colors, parts) in prayer)
                GradientTile(
                  label: label,
                  icon: icon,
                  colors: colors,
                  onTap: () => parts != null ? openMergedAzkar(context, ref, label, parts) : openAzkarCategory(context, ref, name!),
                ),
            ], ratio: 1.6),
            SliverToBoxAdapter(child: SectionHeader(context.tr('more'))),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.list(
                children: [
                  _WideCard(
                    icon: Icons.touch_app_rounded,
                    colors: Brand.gTasbih,
                    title: context.tr('electronic_tasbih'),
                    subtitle: context.tr('electronic_tasbih_sub'),
                    action: context.tr('start'),
                    onTap: () => push(context, const TasbihScreen()),
                  ),
                  const SizedBox(height: 12),
                  _WideCard(
                    icon: Icons.shield_moon_rounded,
                    colors: Brand.gAzkar,
                    title: context.tr('ruqya'),
                    subtitle: context.tr('items_n', {'n': d.merged('', AzkarData.ruqya).items.length}),
                    action: context.tr('open'),
                    onTap: () => openMergedAzkar(context, ref, context.tr('ruqya'), AzkarData.ruqya),
                  ),
                  const SizedBox(height: 12),
                  _WideCard(
                    icon: Icons.auto_awesome_rounded,
                    colors: Brand.gReciters,
                    title: context.tr('tasbih_tahmid'),
                    subtitle: context.tr('items_n', {'n': d.byName(AzkarData.tasbihCat)?.items.length ?? 0}),
                    action: context.tr('open'),
                    onTap: () => openAzkarCategory(context, ref, AzkarData.tasbihCat),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        );
      },
    );
    if (!standalone) return SafeArea(bottom: false, child: body);
    return Scaffold(appBar: AppBar(), body: body);
  }
}

String? _nowCategory(DateTime t) {
  final h = t.hour;
  if (h >= 4 && h < 11) return AzkarData.morning;
  if (h >= 15 && h < 20) return AzkarData.evening;
  if (h >= 21 || h < 2) return AzkarData.sleep;
  return null;
}

class _HisnHero extends StatelessWidget {
  const _HisnHero({required this.data});
  final AzkarData data;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => push(context, HisnIndexScreen(data: data)),
    semanticLabel: context.tr('hisn_muslim'),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFF1C6F7B), Color(0xFF134C57)],
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(end: -8, bottom: -8, child: Icon(Icons.menu_book_rounded, size: 110, color: Colors.white.withValues(alpha: 0.08))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('hisn_muslim'),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Text(context.tr('hisn_author'), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _count(context, data.categories.length, context.tr('chapters')),
                  const SizedBox(width: 24),
                  _count(context, data.itemCount, context.tr('adhkar_word')),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Brand.gold, foregroundColor: Brand.ink),
                    onPressed: () => push(context, HisnIndexScreen(data: data)),
                    icon: const Icon(Icons.auto_stories_rounded, size: 18),
                    label: Text(context.tr('open_book')),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _count(BuildContext context, int n, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.num(n),
        style: const TextStyle(color: Brand.gold, fontSize: 22, fontWeight: FontWeight.w800),
      ),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );
}

class _WideCard extends StatelessWidget {
  const _WideCard({required this.icon, required this.colors, required this.title, required this.subtitle, required this.action, required this.onTap});
  final IconData icon;
  final List<Color> colors;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: colors),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(subtitle, style: const TextStyle(color: Brand.textMid, fontSize: 12)),
            ],
          ),
        ),
        FilledButton.tonal(onPressed: onTap, child: Text(action)),
      ],
    ),
  );
}

/// The full Hisn al-Muslim index, searchable.
class HisnIndexScreen extends StatefulWidget {
  const HisnIndexScreen({super.key, required this.data});
  final AzkarData data;

  @override
  State<HisnIndexScreen> createState() => _HisnIndexScreenState();
}

class _HisnIndexScreenState extends State<HisnIndexScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final f = normalizeArabic(_filter);
    final cats = widget.data.categories.where((c) => f.isEmpty || normalizeArabic(c.name).contains(f)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('hisn_muslim'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.tr('search_azkar')),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 40),
              itemCount: cats.length,
              itemBuilder: (context, i) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: CircleAvatar(
                  backgroundColor: Brand.teal.withValues(alpha: 0.18),
                  child: Text(context.num(cats[i].id + 1), style: const TextStyle(fontSize: 12, color: Brand.tealBright)),
                ),
                title: Text(cats[i].name),
                trailing: Text(context.num(cats[i].items.length), style: const TextStyle(color: Brand.textMid)),
                onTap: () => push(context, AzkarReaderScreen(category: cats[i])),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(widget.data.source, style: const TextStyle(color: Brand.textLow, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

/// One zikr per page with a tap-to-count card; advances automatically
/// when a zikr's count is complete and celebrates the end of the set.
class AzkarReaderScreen extends ConsumerStatefulWidget {
  const AzkarReaderScreen({super.key, required this.category});
  final AzkarCategory category;

  @override
  ConsumerState<AzkarReaderScreen> createState() => _AzkarReaderScreenState();
}

class _AzkarReaderScreenState extends ConsumerState<AzkarReaderScreen> {
  final _pc = PageController();
  late final List<int> _left = [for (final z in widget.category.items) z.count];
  int _page = 0;
  bool _celebrated = false;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _tap(int i) {
    if (_left[i] == 0) return;
    haptic(ref);
    setState(() => _left[i]--);
    if (_left[i] == 0) {
      haptic(ref, HapticKind.medium);
      if (_left.every((x) => x == 0)) {
        _finish();
      } else if (i < _left.length - 1) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) goToPage(context, _pc, i + 1);
        });
      }
    }
  }

  void _finish() {
    if (_celebrated) return;
    _celebrated = true;
    ref.read(activityProvider.notifier).completeAzkar(widget.category.name);
    showCelebration(context, title: context.tr('azkar_done'), subtitle: widget.category.name);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.category.items;
    final done = _left.where((x) => x == 0).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Builder(
            builder: (context) {
              final z = items[_page];
              final id = '${widget.category.name}#$_page';
              final fav = ref.watch(favoritesProvider).any((f) => f.type == 'zikr' && f.id == id);
              return IconButton(
                tooltip: context.tr('bookmark'),
                icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? Brand.gold : null),
                onPressed: () => ref.read(favoritesProvider.notifier).toggle('zikr', id, z.text, widget.category.name),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: done / items.length),
            duration: Motion.of(context).medium,
            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 4, color: Brand.gold, backgroundColor: Colors.transparent),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: items.length,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (context, i) {
                final z = items[i];
                final progress = z.count == 0 ? 1.0 : 1 - _left[i] / z.count;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Pressable(
                    onTap: () => _tap(i),
                    semanticLabel: context.tr('tap_to_count'),
                    child: AppCard(
                      padding: const EdgeInsets.all(22),
                      borderColor: _left[i] == 0 ? Brand.tealBright : null,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                z.text,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: Brand.naskhFont, fontSize: 23, height: 2.0),
                              ),
                            ),
                          ),
                          if (z.reference.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(z.reference, style: const TextStyle(color: Brand.textMid, fontSize: 13)),
                            ),
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(end: progress),
                                  duration: Motion.of(context).short,
                                  builder: (_, v, _) => CircularProgressIndicator(
                                    value: v,
                                    strokeWidth: 7,
                                    color: _left[i] == 0 ? Brand.tealBright : Brand.gold,
                                    backgroundColor: Brand.outline,
                                    constraints: const BoxConstraints.tightFor(width: 96, height: 96),
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: Motion.of(context).short,
                                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                                  child: _left[i] == 0
                                      ? const Icon(Icons.check_rounded, key: ValueKey('ok'), size: 40, color: Brand.tealBright)
                                      : Text(
                                          context.num(_left[i]),
                                          key: ValueKey(_left[i]),
                                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text('${context.num(_page + 1)} / ${context.num(items.length)}', style: const TextStyle(color: Brand.textMid)),
          ),
        ],
      ),
    );
  }
}
