import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../quran/reader_screen.dart';

/// Everything the user saved in one place: verses, hadiths and adhkar.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarksProvider);
    final favs = ref.watch(favoritesProvider);
    final quran = ref.watch(quranProvider).value;

    final entries = <(DateTime, String, Widget)>[
      if (quran != null)
        for (final b in bookmarks)
          (
            b.created,
            'ayah',
            _Entry(
              label: '${quran.surah(b.ref.surah).nameAr} · ${context.num(b.ref.ayah)}',
              icon: Icons.menu_book_rounded,
              text: quran.textOf(b.ref),
              quranFont: true,
              onTap: () => push(context, ReaderScreen(surah: b.ref.surah, initialAyah: b.ref.ayah)),
              onRemove: () => ref.read(bookmarksProvider.notifier).toggle(b.ref),
            ),
          ),
      for (final f in favs)
        (
          f.created,
          f.type,
          _Entry(
            label: f.source,
            icon: f.type == 'hadith' ? Icons.format_quote_rounded : Icons.volunteer_activism_rounded,
            text: f.text,
            onTap: () {
              Clipboard.setData(ClipboardData(text: '${f.text}\n— ${f.source}'));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('copied'))));
            },
            onRemove: () => ref.read(favoritesProvider.notifier).toggle(f.type, f.id, f.text, f.source),
          ),
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final shown = _filter == 'all' ? entries : entries.where((e) => e.$2 == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: context.tr('bookmark_collections'),
            onPressed: () => push(context, const BookmarksScreen()),
            icon: const Icon(Icons.folder_open_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          PageTitle(context.tr('favorites'), subtitle: context.tr('favorites_sub')),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in const ['all', 'ayah', 'hadith', 'zikr'])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(label: Text(context.tr('fav_$f')), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? EmptyState(icon: Icons.favorite_border_rounded, title: context.tr('no_favorites'), body: context.tr('no_favorites_body'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => FadeSlideIn.indexed(i, child: shown[i].$3),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.label, required this.icon, required this.text, required this.onTap, required this.onRemove, this.quranFont = false});
  final String label;
  final IconData icon;
  final String text;
  final bool quranFont;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Brand.tealBright),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: context.tr('remove'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.favorite_rounded, color: Brand.gold, size: 20),
              onPressed: onRemove,
            ),
          ],
        ),
        Text(
          text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: quranFont ? Brand.quranFont : Brand.naskhFont, fontSize: quranFont ? 20 : 18, height: 1.9),
        ),
      ],
    ),
  );
}
