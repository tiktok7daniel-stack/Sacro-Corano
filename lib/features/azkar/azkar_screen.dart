import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/arabic.dart';
import '../../core/widgets/common.dart';
import '../../data/azkar_repository.dart';
import '../celebration/celebration.dart';

Future<void> openAzkarCategory(BuildContext context, WidgetRef ref, String name) async {
  final data = await ref.read(azkarProvider.future);
  final cat = data.byName(name) ?? data.categories.first;
  if (context.mounted) await push(context, AzkarReaderScreen(category: cat));
}

/// Hisn al-Muslim: featured daily adhkar plus all 130+ situations.
class AzkarScreen extends ConsumerStatefulWidget {
  const AzkarScreen({super.key, this.standalone = false});
  final bool standalone;

  @override
  ConsumerState<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends ConsumerState<AzkarScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(azkarProvider);
    final today = ref.watch(activityProvider.notifier).today();
    ref.watch(activityProvider);

    final body = AsyncView<AzkarData>(
      value: data,
      builder: (d) {
        final featured = [
          (AzkarData.morning, context.tr('morning_azkar'), Icons.wb_sunny_rounded, Brand.gKhatma),
          (AzkarData.evening, context.tr('evening_azkar'), Icons.nights_stay_rounded, Brand.gAzkar),
          (AzkarData.afterPrayer, context.tr('after_prayer_azkar'), Icons.mosque_rounded, Brand.gReciters),
          (AzkarData.sleep, context.tr('sleep_azkar'), Icons.bedtime_rounded, Brand.gHifz),
          (AzkarData.waking, context.tr('waking_azkar'), Icons.alarm_rounded, Brand.gQibla),
          (AzkarData.distress, context.tr('distress_dua'), Icons.healing_rounded, Brand.gDua),
        ];
        final f = normalizeArabic(_filter);
        final cats = d.categories.where((c) => f.isEmpty || normalizeArabic(c.name).contains(f)).toList();
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(context.tr('azkar'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.35,
              children: [
                for (final (i, (name, label, icon, colors)) in featured.indexed)
                  FadeSlideIn.indexed(
                    i,
                    child: Stack(children: [
                      Positioned.fill(
                        child: GradientTile(
                          label: label,
                          subtitle: d.byName(name) == null ? null : context.tr('items_n', {'n': d.byName(name)!.items.length}),
                          icon: icon,
                          colors: colors,
                          onTap: () => openAzkarCategory(context, ref, name),
                        ),
                      ),
                      if (today.azkar.contains(name))
                        const PositionedDirectional(top: 12, end: 12, child: Icon(Icons.check_circle_rounded, color: Colors.white)),
                    ]),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _filter = v),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.tr('search_azkar')),
              ),
            ),
          ),
          SliverList.builder(
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
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ]);
      },
    );
    if (!widget.standalone) return SafeArea(bottom: false, child: body);
    return Scaffold(appBar: AppBar(), body: body);
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: done / items.length),
            duration: Motion.of(context).medium,
            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 4, color: Brand.gold, backgroundColor: Colors.transparent),
          ),
        ),
      ),
      body: Column(children: [
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
                    child: Column(children: [
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
                        child: Stack(alignment: Alignment.center, children: [
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
                                : Text(context.num(_left[i]), key: ValueKey(_left[i]), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    ]),
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
      ]),
    );
  }
}
