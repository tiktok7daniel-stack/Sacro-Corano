import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/motion.dart';
import '../../../core/theme/brand.dart';
import '../../../core/widgets/common.dart';
import '../../../domain/quran_models.dart';
import '../../share/share_card.dart';
import '../reader_screen.dart';

/// A verse (or contiguous range) rendered from the mushaf text, with its
/// reference, optional tafsir and quick actions.
class VerseCard extends ConsumerWidget {
  const VerseCard({super.key, required this.range, this.showTafsir = false, this.compact = false});
  final AyahRange range;
  final bool showTafsir;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quran = ref.watch(quranProvider).value;
    if (quran == null) return const SizedBox(height: 80);
    final info = quran.surah(range.surah);
    final to = range.to < 0 ? info.ayahCount : range.to;
    final s = ref.watch(settingsProvider);
    final buf = StringBuffer();
    for (var a = range.from; a <= to; a++) {
      buf
        ..write(quran.text(range.surah, a))
        ..write(' ')
        ..write(ayahMarker(a))
        ..write(' ');
    }
    final label = '${info.nameAr} ${context.num(range.from)}${to != range.from ? '–${context.num(to)}' : ''}';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      onTap: () => push(context, ReaderScreen(surah: range.surah, initialAyah: range.from)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            buf.toString().trim(),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontFamily: Brand.quranFont,
              fontSize: compact ? s.quranFontSize * 0.75 : s.quranFontSize * 0.85,
              height: 2.0,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (showTafsir) _TafsirSnippet(range: AyahRange(range.surah, range.from, to)),
          const SizedBox(height: 6),
          Row(
            children: [
              Pill(label, color: Brand.tealBright),
              const Spacer(),
              IconButton(
                tooltip: context.tr('share'),
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                onPressed: () => shareVerseImage(context, ref, AyahRange(range.surah, range.from, to)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TafsirSnippet extends ConsumerWidget {
  const _TafsirSnippet({required this.range});
  final AyahRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(contentRepoProvider);
    return FutureBuilder<List<String>>(
      future: Future.wait([for (var a = range.from; a <= range.to; a++) repo.tafsir('muyassar', range.surah, a)]),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Brand.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('tafsir_muyassar'), style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                snap.data!.join(' '),
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: Brand.naskhFont, fontSize: 17, height: 1.8),
              ),
            ],
          ),
        );
      },
    );
  }
}
