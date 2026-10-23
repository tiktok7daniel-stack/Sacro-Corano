import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';

const deeds = ['khatma', 'surah', 'tasbih', 'dua', 'other'];

/// Sadaqa jariya: dedicate deeds (a khatma, a surah, tasbih, a dua) to a
/// loved one and keep a private log, and share the app as ongoing charity.
class SadaqaScreen extends ConsumerWidget {
  const SadaqaScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final note = TextEditingController();
    var deed = deeds.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.tr('dedicate_deed')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: context.tr('dedicate_to')),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in deeds) ChoiceChip(label: Text(context.tr('deed_$d')), selected: deed == d, onSelected: (_) => setState(() => deed = d)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  decoration: InputDecoration(labelText: context.tr('note_optional')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('save'))),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      ref.read(dedicationsProvider.notifier).add(name.text.trim(), deed, note.text.trim());
    }
    disposeAfterDialog([name, note]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(dedicationsProvider);
    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('dedicate_deed')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          PageTitle(context.tr('sadaqa'), subtitle: context.tr('sadaqa_sub')),
          AppCard(
            gradient: const LinearGradient(colors: Brand.gQibla),
            borderColor: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  context.tr('sadaqa_share_title'),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(context.tr('sadaqa_share_body'), style: const TextStyle(color: Colors.white70, height: 1.5)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.ink),
                  onPressed: () => SharePlus.instance.share(ShareParams(text: context.tr('share_app_text'))),
                  icon: const Icon(Icons.share_rounded),
                  label: Text(context.tr('share_app')),
                ),
              ],
            ),
          ),
          SectionHeader(context.tr('my_dedications')),
          if (list.isEmpty)
            EmptyState(icon: Icons.favorite_border_rounded, title: context.tr('no_dedications'), body: context.tr('no_dedications_body'))
          else
            for (final (i, d) in list.indexed)
              FadeSlideIn.indexed(
                i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.spa_rounded, color: Brand.gold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                '${context.tr('deed_${d.deed}')}${d.note.isEmpty ? '' : ' · ${d.note}'}',
                                style: const TextStyle(color: Brand.textMid, fontSize: 13),
                              ),
                              Text(MaterialLocalizations.of(context).formatMediumDate(d.created), style: const TextStyle(color: Brand.textLow, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr('delete'),
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          onPressed: () => ref.read(dedicationsProvider.notifier).remove(d.id),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
