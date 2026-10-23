import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/arabic.dart';
import '../../core/widgets/common.dart';
import '../../domain/prophets.dart';
import '../quran/verse_journey.dart';

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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: PageTitle(context.tr('prophets'))),
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
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(label: Text(context.tr('pf_${f.name}')), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(context.tr('prophets_list'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Text(context.tr('prophets_n', {'n': list.length}), style: const TextStyle(color: Brand.textMid)),
                ],
              ),
            ),
          ),
          // Shelves of three books, each resting on a wooden plank.
          SliverList.builder(
            itemCount: (list.length / 3).ceil(),
            itemBuilder: (context, row) {
              final books = list.skip(row * 3).take(3).toList();
              return FadeSlideIn.indexed(
                row,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 176,
                        child: Row(
                          children: [
                            for (var i = 0; i < 3; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: i < books.length ? _Book(prophet: books[i]) : const SizedBox.shrink(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF7A5C42), Color(0xFF4A3727)],
                          ),
                          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
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
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadiusDirectional.horizontal(
                    start: Radius.circular(6),
                    end: Radius.circular(12),
                  ).resolve(Directionality.of(context)),
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A prophet's story: the generic verse journey with the book's colour.
class ProphetStoryScreen extends StatelessWidget {
  const ProphetStoryScreen({super.key, required this.prophet});
  final Prophet prophet;

  @override
  Widget build(BuildContext context) =>
      VerseJourneyScreen(title: prophet.title(context.lang), ranges: prophet.ranges, color: Color(prophet.color), heroTag: 'book-${prophet.id}');
}
