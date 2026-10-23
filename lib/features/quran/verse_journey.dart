import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../domain/quran_models.dart';
import '../../services/audio.dart';

/// A guided journey through Quran passages: each passage is a chapter and
/// each verse a step that reveals the verse, then its Muyassar explanation.
/// Used by the prophets' stories and the Sira.
class VerseJourneyScreen extends ConsumerStatefulWidget {
  const VerseJourneyScreen({super.key, required this.title, required this.ranges, required this.color, this.heroTag});
  final String title;
  final List<AyahRange> ranges;
  final Color color;
  final Object? heroTag;

  @override
  ConsumerState<VerseJourneyScreen> createState() => _VerseJourneyScreenState();
}

class _VerseJourneyScreenState extends ConsumerState<VerseJourneyScreen> {
  final _pc = PageController();
  int _page = 0;

  List<AyahRef> _steps(int Function(int) ayahCount) => [
    for (final r in widget.ranges)
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
    final color = widget.color;
    final m = Motion.of(context);

    return Scaffold(
      backgroundColor: Color.lerp(color, Brand.ink, 0.82),
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: context.tr('listen_passage'),
            icon: const Icon(Icons.headphones_rounded),
            onPressed: () {
              final r = steps[_page];
              final range = widget.ranges.firstWhere((x) => x.surah == r.surah && r.ayah >= x.from && (x.to < 0 || r.ayah <= x.to));
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
      body: () {
        final pages = Material(
          type: MaterialType.transparency,
          child: PageView.builder(
            controller: _pc,
            itemCount: steps.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (context, i) =>
                _StoryStep(refAyah: steps[i], isFirstOfPassage: i == 0 || steps[i - 1].surah != steps[i].surah || steps[i - 1].ayah + 1 != steps[i].ayah),
          ),
        );
        return widget.heroTag == null ? pages : Hero(tag: widget.heroTag!, child: pages);
      }(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: _page == 0 ? null : () => goToPage(context, _pc, _page - 1),
                icon: const Icon(Icons.arrow_forward_rounded),
                tooltip: context.tr('previous'),
              ),
              Expanded(
                child: Text(
                  '${context.num(_page + 1)} / ${context.num(steps.length)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Brand.textMid),
                ),
              ),
              IconButton(
                onPressed: _page == steps.length - 1 ? null : () => goToPage(context, _pc, _page + 1),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: context.tr('next'),
              ),
            ],
          ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
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
            builder: (context, snap) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('tafsir_muyassar'),
                  style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  snap.data ?? '…',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: Brand.naskhFont, fontSize: 19, height: 1.9, color: Brand.textHigh),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
