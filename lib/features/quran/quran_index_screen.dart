import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../data/quran/quran_data.dart';
import '../bookmarks/bookmarks_screen.dart';
import 'reader_screen.dart';
import 'search_screen.dart';

class QuranIndexScreen extends ConsumerStatefulWidget {
  const QuranIndexScreen({super.key});

  @override
  ConsumerState<QuranIndexScreen> createState() => _QuranIndexScreenState();
}

class _QuranIndexScreenState extends ConsumerState<QuranIndexScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quran = ref.watch(quranProvider);
    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(children: [
                Expanded(child: Text(context.tr('nav_quran'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700))),
                IconButton(tooltip: context.tr('search'), icon: const Icon(Icons.search_rounded), onPressed: () => push(context, const SearchScreen())),
                IconButton(tooltip: context.tr('bookmarks'), icon: const Icon(Icons.bookmarks_outlined), onPressed: () => push(context, const BookmarksScreen())),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Pressable(
                onTap: () => push(context, const SearchScreen()),
                semanticLabel: context.tr('search_hint'),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                  ),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, color: Brand.textMid),
                    const SizedBox(width: 12),
                    Text(context.tr('search_hint'), style: const TextStyle(color: Brand.textMid)),
                  ]),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: TabBar(
              controller: _tabs,
              indicatorColor: Brand.gold,
              labelColor: Brand.gold,
              dividerColor: Colors.transparent,
              tabs: [Tab(text: context.tr('surahs')), Tab(text: context.tr('juz')), Tab(text: context.tr('hizb'))],
            ),
          ),
        ],
        body: AsyncView<QuranData>(
          value: quran,
          builder: (q) => TabBarView(
            controller: _tabs,
            children: [_SurahList(q), _JuzList(q), _HizbList(q)],
          ),
        ),
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  const _SurahList(this.q);
  final QuranData q;

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
        itemCount: q.surahs.length,
        itemBuilder: (context, i) {
          final s = q.surahs[i];
          return FadeSlideIn.indexed(
            i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () => push(context, ReaderScreen(surah: s.number)),
                child: Row(children: [
                  _NumberBadge(s.number),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.isAr ? s.nameAr : s.translit, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                      Text(
                        '${s.meccan ? context.tr('meccan') : context.tr('medinan')} · ${context.tr('ayahs_n', {'n': s.ayahCount})} · ${context.tr('page_n', {'n': q.firstPageOfSurah(s.number)})}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ]),
                  ),
                  Text(s.nameAr, style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 24, color: Brand.gold)),
                ]),
              ),
            ),
          );
        },
      );
}

class _JuzList extends StatelessWidget {
  const _JuzList(this.q);
  final QuranData q;

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.05),
        itemCount: 30,
        itemBuilder: (context, i) {
          final start = q.juzStart(i + 1);
          return FadeSlideIn.indexed(
            i,
            child: AppCard(
              padding: const EdgeInsets.all(10),
              onTap: () => push(context, ReaderScreen(surah: start.surah, initialAyah: start.ayah)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(context.tr('juz_n', {'n': i + 1}), style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.gold)),
                const SizedBox(height: 6),
                Text(q.surah(start.surah).nameAr, style: const TextStyle(fontSize: 13)),
                Text(context.tr('ayah_n', {'n': start.ayah}), style: const TextStyle(fontSize: 11, color: Brand.textMid)),
              ]),
            ),
          );
        },
      );
}

class _HizbList extends StatelessWidget {
  const _HizbList(this.q);
  final QuranData q;

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
        itemCount: 240,
        itemBuilder: (context, i) {
          final r = q.rubStart(i + 1);
          final quarter = i % 4;
          final text = q.textOf(r);
          return ListTile(
            onTap: () => push(context, ReaderScreen(surah: r.surah, initialAyah: r.ayah)),
            leading: SizedBox(
              width: 44,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(context.num(i ~/ 4 + 1), style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.gold)),
                Text(['', '¼', '½', '¾'][quarter], style: const TextStyle(color: Brand.textMid)),
              ]),
            ),
            title: Text(
              text.replaceAll('۞', '').split(' ').take(6).join(' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 18),
            ),
            subtitle: Text('${q.surah(r.surah).nameAr} · ${context.tr('ayah_n', {'n': r.ayah})}'),
          );
        },
      );
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 42,
        height: 42,
        child: Stack(alignment: Alignment.center, children: [
          Transform.rotate(
            angle: 0.785,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(border: Border.all(color: Brand.gold.withValues(alpha: 0.7), width: 1.5), borderRadius: BorderRadius.circular(6)),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(border: Border.all(color: Brand.gold.withValues(alpha: 0.7), width: 1.5), borderRadius: BorderRadius.circular(6)),
          ),
          Text(context.num(n), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}
