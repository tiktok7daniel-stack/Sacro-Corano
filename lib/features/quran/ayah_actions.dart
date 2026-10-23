import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../domain/quran_models.dart';
import '../../services/audio.dart';
import '../share/share_card.dart';
import '../tadabbur/reflection_editor.dart';
import 'tafsir_sheet.dart';

/// Long list of things one can do with a verse, in a bottom sheet.
Future<void> showAyahActions(BuildContext context, WidgetRef ref, AyahRef r) {
  haptic(ref, HapticKind.selection);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AyahActions(r),
  );
}

class _AyahActions extends ConsumerWidget {
  const _AyahActions(this.r);
  final AyahRef r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(quranProvider).value;
    if (q == null) return const Center(child: CircularProgressIndicator());
    final info = q.surah(r.surah);
    final bookmarked = ref.watch(bookmarksProvider).any((b) => b.ref == r);
    final reflections = ref.watch(reflectionsProvider).where((x) => x.ref == r).length;
    final text = q.text(r.surah, r.ayah);

    Widget action(IconData icon, String label, VoidCallback onTap, {Color? color}) => SizedBox(
          width: 88,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: (color ?? Brand.tealBright).withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, color: color ?? Brand.tealBright),
                ),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        );

    void close() => Navigator.of(context).pop();
    // Captured now: the sheet's context is gone once it closes.
    final messenger = ScaffoldMessenger.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${info.nameAr} · ${context.tr('ayah_n', {'n': r.ayah})}',
              style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Text(text,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 22, height: 1.9)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.center, children: [
            action(Icons.play_arrow_rounded, context.tr('play_from_here'), () {
              close();
              ref.read(audioProvider.notifier).playSurah(r.surah, from: r.ayah);
            }),
            action(Icons.repeat_one_rounded, context.tr('repeat_ayah'), () {
              close();
              ref.read(audioProvider.notifier).playSurah(r.surah, from: r.ayah, to: r.ayah, repeatEach: 5);
            }),
            action(Icons.menu_book_rounded, context.tr('tafsir'), () {
              close();
              showTafsir(context, ref, r);
            }),
            action(Icons.translate_rounded, context.tr('word_meanings'), () {
              close();
              showTafsir(context, ref, r, editionId: 'gharib');
            }),
            action(bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                bookmarked ? context.tr('bookmarked') : context.tr('bookmark'), () {
              haptic(ref, HapticKind.medium);
              ref.read(bookmarksProvider.notifier).toggle(r);
            }, color: Brand.gold),
            action(Icons.edit_note_rounded, reflections > 0 ? '${context.tr('reflect')} (${context.num(reflections)})' : context.tr('reflect'), () {
              close();
              showReflectionEditor(context, ref, r);
            }, color: Brand.gold),
            action(Icons.image_rounded, context.tr('share_image'), () {
              close();
              shareVerseImage(context, ref, AyahRange(r.surah, r.ayah, r.ayah));
            }),
            action(Icons.copy_rounded, context.tr('copy'), () {
              Clipboard.setData(ClipboardData(text: '$text ﴿${info.nameAr}: ${r.ayah}﴾'));
              final msg = context.tr('copied');
              close();
              messenger.showSnackBar(SnackBar(content: Text(msg)));
            }),
            action(Icons.psychology_rounded, context.tr('add_to_hifz'), () {
              ref.read(hifzProvider.notifier).addSurah(r.surah, info.ayahCount);
              final msg = context.tr('hifz_added', {'name': info.nameAr});
              close();
              messenger.showSnackBar(SnackBar(content: Text(msg)));
            }),
          ]),
        ]),
      ),
    );
  }
}
