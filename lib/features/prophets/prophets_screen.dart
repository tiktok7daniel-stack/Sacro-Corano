import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/arabic.dart';
import '../../core/widgets/common.dart';
import '../../domain/prophets.dart';
import '../../domain/quran_models.dart';
import '../../services/audio.dart';

enum _Filter { all, ululAzm, messengers, prophets }

/// Stories of the prophets as a bookshelf of the 25 named in the Quran.
class ProphetsScreen extends ConsumerStatefulWidget {
  const ProphetsScreen({super.key});

  @override
  ConsumerState<ProphetsScreen> createState() => _ProphetsScreenState();
}

class _ProphetsScreenState extends ConsumerState<ProphetsScreen> {
  _Filter _filter = _Filter.all;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = prophets.where((p) {
      final f = switch (_filter) {
        _Filter.all => true,
        _Filter.ululAzm => p.ululAzm,
        _Filter.messengers => p.messenger,
        _Filter.prophets => !p.messenger,
      };
      final n = normalizeArabic(_q);
      return f && (n.isEmpty || normalizeArabic(p.nameAr).contains(n) || p.nameEn.toLowerCase().contains(_q.toLowerCase()));
    }).toList();

    return Scaffold(
      appBar: AppBar(),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: PageTitle(context.tr('prophets'), subtitle: context.tr('prophets_sub'))),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.tr('search_prophet')),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 60,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(context.tr('pf_${f.name}')),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 26, crossAxisSpacing: 14, childAspectRatio: 0.62),
            itemCount: list.length,
            itemBuilder: (context, i) => FadeSlideIn.indexed(i, child: _Book(prophet: list[i])),
          ),
        ),
      ]),
    );
  }
}

class _Book extends StatelessWidget {
  const _Book({required this.prophet});
  final Prophet prophet;

  @override
  Widget build(BuildContext context) {
    final color = Color(prophet.color);
    return Pressable(
      onTap: () => push(context, ProphetStoryScreen(prophet: prophet)),
      semanticLabel: prophet.title(context.lang),
      child: Hero(
        tag: 'book-${prophet.id}',
        child: Column(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadiusDirectional.horizontal(start: Radius.circular(6), end: Radius.circular(12)).resolve(Directionality.of(context)),
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [Color.lerp(color, Colors.black, 0.25)!, color, Color.lerp(color, Colors.white, 0.05)!],
                  stops: const [0, 0.12, 1],
                ),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(4, 6))],
              ),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: Brand.gold.withValues(alpha: 0.7), width: 1)),
                padding: const EdgeInsets.all(6),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.star_rounded, color: Brand.gold, size: 14),
                  const SizedBox(height: 6),
                  Text(
                    context.isAr ? 'قصة ${prophet.nameAr}\nعليه السلام' : prophet.nameEn,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: Brand.naskhFont, color: Color(0xFFF1DFB4), fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    prophet.ululAzm ? context.tr('pf_ululAzm') : context.tr('prophets'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                  ),
                ]),
              ),
            ),
          ),
          Container(height: 8, decoration: BoxDecoration(color: const Color(0xFF5B4632), borderRadius: BorderRadius.circular(3))),
        ]),
      ),
    );
  }
}

/// Story as a guided journey: each passage is a chapter; each verse is a
/// step that reveals the verse, then its Muyassar explanation.
class ProphetStoryScreen extends ConsumerStatefulWidget {
  const ProphetStoryScreen({super.key, required this.prophet});
  final Prophet prophet;

  @override
  ConsumerState<ProphetStoryScreen> createState() => _ProphetStoryScreenState();
}

class _ProphetStoryScreenState extends ConsumerState<ProphetStoryScreen> {
  final _pc = PageController();
  int _page = 0;

  List<AyahRef> _steps(int Function(int) ayahCount) => [
        for (final r in widget.prophet.ranges)
          for (var a = r.from; a <= (r.to < 0 ? ayahCount(r.surah) : r.to); a++) AyahRef(r.surah, a),
      ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    if (q == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final steps = _steps((s) => q.surah(s).ayahCount);
    final color = Color(widget.prophet.color);
    final m = Motion.of(context);

    return Scaffold(
      backgroundColor: Color.lerp(color, Brand.ink, 0.82),
      appBar: AppBar(
        title: Text(widget.prophet.title(context.lang)),
        actions: [
          IconButton(
            tooltip: context.tr('listen_passage'),
            icon: const Icon(Icons.headphones_rounded),
            onPressed: () {
              final r = steps[_page];
              final range = widget.prophet.ranges.firstWhere((x) => x.surah == r.surah && r.ayah >= x.from && (x.to < 0 || r.ayah <= x.to));
              ref.read(audioProvider.notifier).playSurah(r.surah, from: r.ayah, to: range.to < 0 ? null : range.to);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (_page + 1) / steps.length),
            duration: m.medium,
            builder: (_, v, _) => LinearProgressIndicator(value: v, color: Brand.gold, backgroundColor: Colors.transparent),
          ),
        ),
      ),
      body: Hero(
        tag: 'book-${widget.prophet.id}',
        child: Material(
          type: MaterialType.transparency,
          child: PageView.builder(
            controller: _pc,
            itemCount: steps.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (context, i) => _StoryStep(refAyah: steps[i], isFirstOfPassage: i == 0 || steps[i - 1].surah != steps[i].surah || steps[i - 1].ayah + 1 != steps[i].ayah),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            IconButton(
              onPressed: _page == 0 ? null : () => goToPage(context, _pc, _page - 1),
              icon: const Icon(Icons.arrow_forward_rounded),
              tooltip: context.tr('previous'),
            ),
            Expanded(child: Text('${context.num(_page + 1)} / ${context.num(steps.length)}', textAlign: TextAlign.center, style: const TextStyle(color: Brand.textMid))),
            IconButton(
              onPressed: _page == steps.length - 1 ? null : () => goToPage(context, _pc, _page + 1),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: context.tr('next'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StoryStep extends ConsumerWidget {
  const _StoryStep({required this.refAyah, required this.isFirstOfPassage});
  final AyahRef refAyah;
  final bool isFirstOfPassage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(quranProvider).value;
    if (q == null) return const Center(child: CircularProgressIndicator());
    final repo = ref.watch(contentRepoProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      if (isFirstOfPassage)
        FadeSlideIn(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(child: Pill('${context.tr('surah')} ${q.surah(refAyah.surah).nameAr}')),
          ),
        ),
      FadeSlideIn(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Brand.gold.withValues(alpha: 0.4)),
          ),
          child: Text(
            '${q.textOf(refAyah)} ${ayahMarker(refAyah.ayah)}',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 26, height: 2.0, color: Brand.textHigh),
          ),
        ),
      ),
      const SizedBox(height: 16),
      FadeSlideIn(
        delay: const Duration(milliseconds: 250),
        child: FutureBuilder<String>(
          future: repo.tafsir('muyassar', refAyah.surah, refAyah.ayah),
          builder: (context, snap) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('tafsir_muyassar'), style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              snap.data ?? '…',
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: Brand.naskhFont, fontSize: 19, height: 1.9, color: Brand.textHigh),
            ),
          ]),
        ),
      ),
    ]);
  }
}
