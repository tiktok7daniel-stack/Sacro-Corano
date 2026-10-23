import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/arabic.dart';
import '../../core/widgets/common.dart';
import '../../data/hadith_repository.dart';
import '../share/share_card.dart';

/// Hadith collections: the two forties are bundled; Bukhari and Muslim are
/// one-time downloads (public-domain dataset by fawazahmed0/hadith-api).
class HadithScreen extends ConsumerStatefulWidget {
  const HadithScreen({super.key});

  @override
  ConsumerState<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends ConsumerState<HadithScreen> {
  final Map<String, bool> _downloaded = {};
  String? _downloading;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final repo = ref.read(hadithRepoProvider);
    for (final c in hadithCollections) {
      final d = await repo.isDownloaded(c.id);
      if (mounted) setState(() => _downloaded[c.id] = d);
    }
  }

  Future<void> _download(HadithCollectionInfo c) async {
    setState(() => _downloading = c.id);
    try {
      await ref.read(hadithRepoProvider).download(c.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('download_failed'))));
    }
    if (mounted) setState(() => _downloading = null);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          PageTitle(context.tr('hadiths'), subtitle: context.tr('hadiths_sub')),
          const HadithOfDayCard(),
          SectionHeader(context.tr('collections')),
          for (final (i, c) in hadithCollections.indexed)
            FadeSlideIn.indexed(
              i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: _downloaded[c.id] == true ? () => push(context, HadithListScreen(collection: c)) : null,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: Brand.teal.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.menu_book_rounded, color: Brand.gold),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name(context.lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              c.bundled
                                  ? context.tr('bundled')
                                  : (_downloaded[c.id] == true ? context.tr('available_offline') : context.tr('download_size_mb', {'n': c.approxMb})),
                              style: const TextStyle(color: Brand.textMid, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (_downloading == c.id)
                        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      else if (_downloaded[c.id] != true)
                        IconButton(tooltip: context.tr('download_for_offline'), onPressed: () => _download(c), icon: const Icon(Icons.download_rounded))
                      else
                        const Icon(Icons.chevron_left_rounded, color: Brand.textMid),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            context.tr('hadith_source_note'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.textLow, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class HadithListScreen extends ConsumerStatefulWidget {
  const HadithListScreen({super.key, required this.collection});
  final HadithCollectionInfo collection;

  @override
  ConsumerState<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends ConsumerState<HadithListScreen> {
  late final Future<List<Hadith>> _future = ref.read(hadithRepoProvider).collection(widget.collection.id);
  String _q = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.collection.name(context.lang))),
    body: FutureBuilder<List<Hadith>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final n = normalizeArabic(_q);
        final list = n.isEmpty
            ? snap.data!
            : snap.data!.where((h) => normalizeArabic(h.ar).contains(n) || h.en.toLowerCase().contains(_q.toLowerCase())).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.tr('search_hadith')),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                itemCount: list.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: HadithCard(hadith: list[i]),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// One hadith with copy / share / favourite.
class HadithCard extends ConsumerWidget {
  const HadithCard({super.key, required this.hadith, this.maxLines});
  final Hadith hadith;
  final int? maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = collectionInfo(hadith.collection);
    final fav = ref.watch(favoritesProvider).any((f) => f.type == 'hadith' && f.id == hadith.id);
    final source = '${info.name(context.lang)} · ${context.num(hadith.number)}';
    final showEn = !context.isAr && hadith.en.isNotEmpty;
    return AppCard(
      onTap: maxLines == null ? null : () => push(context, HadithDetailScreen(hadith: hadith)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Pill(source, color: Brand.tealBright),
              if (info.authentic) ...[const SizedBox(width: 6), Pill(context.tr('sahih'))],
              if (hadith.chapter != null && hadith.chapter!.isNotEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: Text(
                      hadith.chapter!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Brand.textLow, fontSize: 11),
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            showEn ? hadith.en : hadith.ar,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            textDirection: showEn ? TextDirection.ltr : TextDirection.rtl,
            style: TextStyle(fontFamily: showEn ? null : Brand.naskhFont, fontSize: showEn ? 15 : 19, height: showEn ? 1.6 : 1.9),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: context.tr('copy'),
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${hadith.ar}\n— $source'));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('copied'))));
                },
              ),
              IconButton(
                tooltip: context.tr('share'),
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                onPressed: () => shareWidgetAsImage(
                  context,
                  BrandedCard(
                    title: source,
                    child: Text(
                      hadith.ar,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontFamily: Brand.naskhFont, fontSize: 18, height: 1.9, color: Brand.textHigh),
                    ),
                  ),
                  name: 'hadith',
                ),
              ),
              IconButton(
                tooltip: context.tr('bookmark'),
                icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 20, color: fav ? Brand.gold : null),
                onPressed: () => ref.read(favoritesProvider.notifier).toggle('hadith', hadith.id, hadith.ar, source),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HadithDetailScreen extends StatelessWidget {
  const HadithDetailScreen({super.key, required this.hadith});
  final Hadith hadith;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [HadithCard(hadith: hadith)],
    ),
  );
}

/// Rotates daily through the bundled forties (all well-known, graded texts).
final hadithOfDayProvider = FutureProvider<Hadith>((ref) async {
  final repo = ref.watch(hadithRepoProvider);
  final all = [...await repo.collection('nawawi'), ...await repo.collection('qudsi')];
  final day = DateTime.now().difference(DateTime(2024)).inDays;
  return all[day % all.length];
});

class HadithOfDayCard extends ConsumerWidget {
  const HadithOfDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(hadithOfDayProvider).value;
    if (h == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.format_quote_rounded, color: Brand.tealBright),
              const SizedBox(width: 6),
              Text(
                context.tr('hadith_of_day'),
                style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        HadithCard(hadith: h, maxLines: 6),
      ],
    );
  }
}
