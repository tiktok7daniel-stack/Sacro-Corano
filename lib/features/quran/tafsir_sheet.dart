import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../data/quran/content_repository.dart';
import '../../domain/quran_models.dart';
import '../../domain/translation_helpers.dart';

Future<void> showTafsir(BuildContext context, WidgetRef ref, AyahRef r, {String? editionId}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TafsirSheet(start: r, editionId: editionId ?? ref.read(settingsProvider).tafsirId),
    );

/// Tafsir + translations for one verse, with edition switching and
/// next/previous verse navigation.
class TafsirSheet extends ConsumerStatefulWidget {
  const TafsirSheet({super.key, required this.start, required this.editionId});
  final AyahRef start;
  final String editionId;

  @override
  ConsumerState<TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends ConsumerState<TafsirSheet> {
  late AyahRef _r = widget.start;
  late String _edition = widget.editionId;
  int _reload = 0;
  double? _downloadProgress;

  void _step(int d) {
    final q = ref.read(quranProvider).value;
    if (q == null) return;
    final idx = q.absoluteIndex(_r.surah, _r.ayah) + d;
    if (idx < 1 || idx > 6236) return;
    setState(() => _r = q.refAt(idx));
  }

  Future<void> _downloadAll() async {
    final repo = ref.read(contentRepoProvider);
    setState(() => _downloadProgress = 0);
    try {
      await repo.downloadAll(_edition, onProgress: (p) {
        if (mounted) setState(() => _downloadProgress = p);
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('download_failed'))));
    }
    if (mounted) setState(() => _downloadProgress = null);
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    if (q == null) return const Center(child: CircularProgressIndicator());
    final repo = ref.watch(contentRepoProvider);
    final ed = Editions.tafsir(_edition);
    final s = ref.watch(settingsProvider);
    final translation = ref.watch(translationProvider(s.translationId)).value;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final e in Editions.tafsirs)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(e.name(context.lang)),
                    selected: e.id == _edition,
                    onSelected: (_) {
                      setState(() => _edition = e.id);
                      if (e.id != 'gharib') ref.read(settingsProvider.notifier).update((x) => x.copyWith(tafsirId: e.id));
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(children: [
                IconButton(onPressed: () => _step(-1), icon: const Icon(Icons.chevron_right_rounded), tooltip: context.tr('previous')),
                Expanded(
                  child: Text('${q.surah(_r.surah).nameAr} · ${context.tr('ayah_n', {'n': _r.ayah})}',
                      textAlign: TextAlign.center, style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w700)),
                ),
                IconButton(onPressed: () => _step(1), icon: const Icon(Icons.chevron_left_rounded), tooltip: context.tr('next')),
              ]),
              AnimatedSwitcher(
                duration: Motion.of(context).short,
                child: Text(
                  q.text(_r.surah, _r.ayah),
                  key: ValueKey(_r),
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 24, height: 2),
                ),
              ),
              if (translation != null) ...[
                const SizedBox(height: 8),
                Text(
                  cleanTranslation(translation.of(_r.surah, _r.ayah)),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6),
                ),
                Text('— ${translation.name}', style: const TextStyle(fontSize: 11, color: Brand.textLow)),
              ],
              const Divider(height: 32),
              Text(ed.name(context.lang), style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              FutureBuilder<String>(
                key: ValueKey('$_edition$_r$_reload'),
                future: repo.tafsir(_edition, _r.surah, _r.ayah),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snap.hasError) {
                    return Column(children: [
                      const SizedBox(height: 12),
                      const Icon(Icons.cloud_off_rounded, size: 36, color: Brand.textMid),
                      const SizedBox(height: 8),
                      Text(context.tr('tafsir_offline'), textAlign: TextAlign.center),
                      TextButton(onPressed: () => setState(() => _reload++), child: Text(context.tr('retry'))),
                    ]);
                  }
                  final text = snap.data!.trim();
                  return SelectableText(
                    text.isEmpty ? context.tr('tafsir_empty') : text,
                    textDirection: ed.lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: ed.lang == 'ar' ? Brand.naskhFont : null,
                      fontSize: ed.lang == 'ar' ? 19 : 16,
                      height: ed.lang == 'ar' ? 1.9 : 1.6,
                    ),
                  );
                },
              ),
              if (_r.ayah == 1 && _edition == 'muyassar')
                FutureBuilder<String>(
                  future: repo.surahIntro(_r.surah),
                  builder: (context, snap) => (snap.data ?? '').isEmpty
                      ? const SizedBox.shrink()
                      : ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(context.tr('surah_intro')),
                          children: [
                            Text(snap.data!, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: Brand.naskhFont, fontSize: 17, height: 1.8)),
                          ],
                        ),
                ),
              if (!ed.bundled) ...[
                const SizedBox(height: 20),
                if (_downloadProgress != null)
                  LinearProgressIndicator(value: _downloadProgress)
                else
                  OutlinedButton.icon(
                    onPressed: _downloadAll,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(context.tr('download_for_offline')),
                  ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}
