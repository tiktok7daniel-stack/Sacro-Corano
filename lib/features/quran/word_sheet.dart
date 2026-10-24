import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/brand.dart';
import '../../data/quran/word_data.dart';
import '../../domain/quran_models.dart';

/// Word meanings for one verse: the chosen word with its English meaning
/// and transliteration, every word of the verse to switch between, and the
/// verse's difficult words explained by "As-Siraj fi Bayan Gharib al-Quran"
/// (falling back to Tafsir al-Muyassar offline).
Future<void> showWordSheet(BuildContext context, AyahRef ref, {int word = 0}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, controller) => _WordSheet(refAyah: ref, initial: word, controller: controller),
      ),
    );

class _WordSheet extends ConsumerStatefulWidget {
  const _WordSheet({required this.refAyah, required this.initial, required this.controller});
  final AyahRef refAyah;
  final int initial;
  final ScrollController controller;

  @override
  ConsumerState<_WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends ConsumerState<_WordSheet> {
  late int _i = widget.initial;
  late final Future<(String, bool)> _gharib = _loadGharib();

  Future<(String, bool)> _loadGharib() async {
    final repo = ref.read(contentRepoProvider);
    final r = widget.refAyah;
    try {
      final g = await repo.tafsir('gharib', r.surah, r.ayah);
      if (g.trim().isNotEmpty) return (g, true);
    } catch (_) {
      // Not downloaded and offline: Muyassar is bundled.
    }
    return (await repo.tafsir('muyassar', r.surah, r.ayah), false);
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    final wbw = ref.watch(wordByWordProvider).value;
    if (q == null) return const SizedBox(height: 200);
    final r = widget.refAyah;
    final words = verseWords(q.text(r.surah, r.ayah));
    final gloss = wbw?.words(r.surah, r.ayah) ?? const <WordGloss>[];
    final i = _i.clamp(0, words.length - 1);
    final g = i < gloss.length ? gloss[i] : null;

    return ListView(controller: widget.controller, padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
      Text('${q.surah(r.surah).nameAr} · ${context.tr('ayah_n', {'n': r.ayah})}', style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Center(
        child: Text(words[i], textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 44, height: 1.8)),
      ),
      if (g != null) ...[
        Center(child: Text(g.translit, style: const TextStyle(color: Brand.gold, fontStyle: FontStyle.italic))),
        const SizedBox(height: 4),
        Center(child: Text(g.meaning, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
      ],
      const SizedBox(height: 14),
      Wrap(
        textDirection: TextDirection.rtl,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (k, w) in words.indexed)
            ChoiceChip(
              label: Text(w, style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 18)),
              selected: k == i,
              onSelected: (_) => setState(() => _i = k),
            ),
        ],
      ),
      const SizedBox(height: 18),
      FutureBuilder<(String, bool)>(
        future: _gharib,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          final (text, isGharib) = snap.data!;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr(isGharib ? 'gharib_title' : 'muyassar_title'), style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(text, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: Brand.naskhFont, fontSize: 18, height: 1.9)),
            if (!isGharib) Text(context.tr('gharib_offline'), style: const TextStyle(color: Brand.textLow, fontSize: 12)),
          ]);
        },
      ),
      if (gloss.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(context.tr('wbw_source'), style: const TextStyle(color: Brand.textLow, fontSize: 11)),
      ],
    ]);
  }
}
