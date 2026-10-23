import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../quran/reader_screen.dart';

/// Bookmarks grouped into user collections.
class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  String? _collection;

  String _label(String c) => c == 'default' ? context.tr('collection_default') : c;

  Future<String?> _askName() async {
    final ctrl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('new_collection')),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: Text(context.tr('save'))),
        ],
      ),
    );
    disposeAfterDialog([ctrl]);
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(bookmarksProvider);
    final q = ref.watch(quranProvider).value;
    final collections = ref.read(bookmarksProvider.notifier).collections;
    final list = _collection == null ? all : all.where((b) => b.collection == _collection).toList();

    return Scaffold(
      appBar: AppBar(),
      body: Column(children: [
        PageTitle(context.tr('bookmarks'), subtitle: context.tr('bookmarks_sub')),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(label: Text(context.tr('all')), selected: _collection == null, onSelected: (_) => setState(() => _collection = null)),
            ),
            for (final c in collections)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(label: Text(_label(c)), selected: _collection == c, onSelected: (_) => setState(() => _collection = c)),
              ),
          ]),
        ),
        Expanded(
          child: list.isEmpty || q == null
              ? EmptyState(icon: Icons.favorite_border_rounded, title: context.tr('no_bookmarks'), body: context.tr('no_bookmarks_body'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final b = list[i];
                    return FadeSlideIn.indexed(
                      i,
                      child: Dismissible(
                        key: ValueKey(b.ref.key),
                        onDismissed: (_) => ref.read(bookmarksProvider.notifier).toggle(b.ref),
                        background: Container(
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(26)),
                          child: const Icon(Icons.delete_outline_rounded),
                        ),
                        child: AppCard(
                          onTap: () => push(context, ReaderScreen(surah: b.ref.surah, initialAyah: b.ref.ayah)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text('${q.surah(b.ref.surah).nameAr} · ${context.num(b.ref.ayah)}',
                                  style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Pill(_label(b.collection)),
                              PopupMenuButton<String>(
                                tooltip: context.tr('move_to'),
                                onSelected: (v) async {
                                  final target = v == '+' ? await _askName() : v;
                                  if (target != null) ref.read(bookmarksProvider.notifier).move(b.ref, target);
                                },
                                itemBuilder: (_) => [
                                  for (final c in collections) PopupMenuItem(value: c, child: Text(_label(c))),
                                  PopupMenuItem(value: '+', child: Text(context.tr('new_collection'))),
                                ],
                              ),
                            ]),
                            Text(q.textOf(b.ref),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 20, height: 1.9)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
