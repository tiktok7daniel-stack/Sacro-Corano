import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../domain/srs.dart';
import '../../services/audio.dart';
import '../celebration/celebration.dart';

/// Memorisation with spaced repetition (SM-2): surahs are split into short
/// units; each review is graded and rescheduled, mistakes are tracked.
class HifzScreen extends ConsumerWidget {
  const HifzScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(hifzProvider);
    final due = ref.read(hifzProvider.notifier).due();
    final q = ref.watch(quranProvider).value;
    final bySurah = <int, List<HifzCard>>{};
    for (final c in cards) {
      bySurah.putIfAbsent(c.surah, () => []).add(c);
    }
    final mature = cards.where((c) => c.stage == 3).length;
    final mistakes = cards.fold<int>(0, (s, c) => s + c.mistakes);

    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSurah(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('add_surah')),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
        PageTitle(context.tr('hifz'), subtitle: context.tr('hifz_sub')),
        AppCard(
          gradient: const LinearGradient(colors: Brand.gHifz),
          borderColor: Colors.transparent,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('due_today'), style: const TextStyle(color: Colors.white70)),
            AnimatedCount(value: due.length, style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700), format: (n) => context.num(n)),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.ink),
              onPressed: due.isEmpty ? null : () => push(context, const HifzSessionScreen()),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(due.isEmpty ? context.tr('all_caught_up') : context.tr('start_review')),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Stat(context.num(cards.length), context.tr('units'))),
          const SizedBox(width: 10),
          Expanded(child: _Stat(context.num(mature), context.tr('mature'))),
          const SizedBox(width: 10),
          Expanded(child: _Stat(context.num(mistakes), context.tr('mistakes'))),
        ]),
        if (cards.isEmpty)
          EmptyState(icon: Icons.psychology_rounded, title: context.tr('hifz_empty'), body: context.tr('hifz_empty_body'))
        else ...[
          SectionHeader(context.tr('my_surahs')),
          for (final e in bySurah.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(q?.surah(e.key).nameAr ?? '', style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 22)),
                    const Spacer(),
                    IconButton(
                      tooltip: context.tr('delete'),
                      onPressed: () => ref.read(hifzProvider.notifier).removeSurah(e.key),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Row(children: [
                      for (final c in e.value)
                        Expanded(
                          child: Tooltip(
                            message: '${c.from}–${c.to}',
                            child: Container(height: 12, margin: const EdgeInsets.symmetric(horizontal: 1), color: _stageColor(c.stage)),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 12, children: [
                    for (final st in [0, 1, 2, 3])
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: _stageColor(st), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('${context.tr('stage_$st')} ${context.num(e.value.where((c) => c.stage == st).length)}', style: const TextStyle(fontSize: 12)),
                      ]),
                  ]),
                ]),
              ),
            ),
        ],
      ]),
    );
  }

  static Color _stageColor(int s) => switch (s) {
        0 => Brand.outline,
        1 => const Color(0xFFE08A3C),
        2 => Brand.tealBright,
        _ => Brand.gold,
      };

  Future<void> _addSurah(BuildContext context, WidgetRef ref) async {
    final q = await ref.read(quranProvider.future);
    if (!context.mounted) return;
    var chunk = 5;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (context, controller) => Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Text(context.tr('unit_size')),
                const Spacer(),
                SegmentedButton<int>(
                  segments: [for (final n in [3, 5, 10]) ButtonSegment(value: n, label: Text(context.num(n)))],
                  selected: {chunk},
                  onSelectionChanged: (v) => setState(() => chunk = v.first),
                ),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: 114,
                itemBuilder: (context, i) {
                  // Suggest starting from the end (Juz Amma), as most do.
                  final s = q.surahs[113 - i];
                  return ListTile(
                    title: Text(s.nameAr, style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 20)),
                    subtitle: Text(context.tr('ayahs_n', {'n': s.ayahCount})),
                    onTap: () => Navigator.pop(context, s.number),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
    if (picked != null) ref.read(hifzProvider.notifier).addSurah(picked, q.surah(picked).ayahCount, chunk: chunk);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Brand.gold)),
          Text(label, style: const TextStyle(color: Brand.textMid, fontSize: 12)),
        ]),
      );
}

/// Review session: recite from memory, reveal verse by verse, count slips,
/// then grade. Grades map to SM-2 quality 1/3/4/5.
class HifzSessionScreen extends ConsumerStatefulWidget {
  const HifzSessionScreen({super.key});

  @override
  ConsumerState<HifzSessionScreen> createState() => _HifzSessionScreenState();
}

class _HifzSessionScreenState extends ConsumerState<HifzSessionScreen> {
  late final List<HifzCard> _queue = ref.read(hifzProvider.notifier).due();
  int _i = 0;
  int _revealed = 0;
  int _mistakes = 0;
  int _reviewed = 0;

  void _grade(int g) {
    final c = _queue[_i];
    ref.read(hifzProvider.notifier).review(c.id, g, _mistakes);
    _reviewed++;
    if (_i + 1 >= _queue.length) {
      showCelebration(context, title: context.tr('session_done'), subtitle: context.tr('reviewed_n', {'n': _reviewed})).then((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    setState(() {
      _i++;
      _revealed = 0;
      _mistakes = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    if (q == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_queue.isEmpty) return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.check_circle_rounded, title: context.tr('all_caught_up')));
    final c = _queue[_i];
    final total = c.to - c.from + 1;
    final m = Motion.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${q.surah(c.surah).nameAr} ${context.num(c.from)}–${context.num(c.to)}'),
        actions: [
          IconButton(
            tooltip: context.tr('listen'),
            icon: const Icon(Icons.headphones_rounded),
            onPressed: () => ref.read(audioProvider.notifier).playSurah(c.surah, from: c.from, to: c.to, repeatEach: 1),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_i + 1) / _queue.length, color: Brand.gold, backgroundColor: Colors.transparent),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text(context.tr('recite_prompt'), textAlign: TextAlign.center, style: const TextStyle(color: Brand.textMid)),
            const SizedBox(height: 12),
            // First words as a cue.
            Text(
              '${q.text(c.surah, c.from).split(' ').take(2).join(' ')} …',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 26, color: Brand.gold),
            ),
            const SizedBox(height: 16),
            for (var a = c.from; a < c.from + _revealed; a++)
              FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${q.text(c.surah, a)} ${ayahMarker(a)}',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 24, height: 2),
                  ),
                ),
              ),
            if (_revealed < total)
              OutlinedButton.icon(
                onPressed: () => setState(() => _revealed++),
                icon: const Icon(Icons.visibility_rounded),
                label: Text(context.tr('reveal_next')),
              ),
            if (_revealed < total)
              TextButton(onPressed: () => setState(() => _revealed = total), child: Text(context.tr('reveal_all'))),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(context.tr('mistakes')),
                const Spacer(),
                IconButton(onPressed: _mistakes > 0 ? () => setState(() => _mistakes--) : null, icon: const Icon(Icons.remove_circle_outline)),
                AnimatedSwitcher(
                  duration: m.short,
                  child: Text(context.num(_mistakes), key: ValueKey(_mistakes), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () {
                    haptic(ref);
                    setState(() => _mistakes++);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                for (final (g, key, color) in [
                  (1, 'grade_again', Colors.redAccent),
                  (3, 'grade_hard', const Color(0xFFE08A3C)),
                  (4, 'grade_good', Brand.tealBright),
                  (5, 'grade_easy', Brand.gold),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: color.withValues(alpha: 0.2), foregroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () => _grade(g),
                        child: Text(context.tr(key)),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
