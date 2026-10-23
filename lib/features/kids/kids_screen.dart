import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../services/audio.dart';
import '../celebration/celebration.dart';

const _kidColors = [
  [Color(0xFFFF8A5B), Color(0xFFFFC37A)],
  [Color(0xFF4FC3F7), Color(0xFF81E6D9)],
  [Color(0xFFA78BFA), Color(0xFFF0ABFC)],
  [Color(0xFF34D399), Color(0xFFA3E635)],
  [Color(0xFFF472B6), Color(0xFFFDA4AF)],
];

/// Kids mode: Juz ʿAmma with big text, listening on repeat and stars a
/// parent awards (1 = listened, 2 = recited along, 3 = from memory).
/// An optional parent PIN guards leaving the mode.
class KidsScreen extends ConsumerWidget {
  const KidsScreen({super.key});

  Future<bool> _confirmExit(BuildContext context, WidgetRef ref) async {
    final pin = ref.read(settingsProvider).kidsPin;
    if (pin == null) return true;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('parent_pin')),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, obscureText: true, autofocus: true, maxLength: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text == pin), child: Text(context.tr('ok'))),
        ],
      ),
    );
    disposeAfterDialog([ctrl]);
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(quranProvider).value;
    final stars = ref.watch(kidsProvider);
    final total = ref.read(kidsProvider.notifier).total;

    return PopScope(
      canPop: ref.watch(settingsProvider).kidsPin == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit(context, ref) && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1B1F3B),
        appBar: AppBar(
          foregroundColor: Colors.white,
          title: Row(children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFD54F)),
            const SizedBox(width: 6),
            AnimatedCount(value: total, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22), format: (n) => context.num(n)),
          ]),
          actions: [
            IconButton(tooltip: context.tr('parent_pin'), icon: const Icon(Icons.lock_outline_rounded), onPressed: () => _setPin(context, ref)),
          ],
        ),
        body: q == null
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.1),
                itemCount: 37,
                itemBuilder: (context, i) {
                  final n = 114 - i;
                  final s = q.surah(n);
                  final colors = _kidColors[i % _kidColors.length];
                  final got = stars['$n'] ?? 0;
                  return FadeSlideIn.indexed(
                    i,
                    child: Pressable(
                      onTap: () => push(context, KidsSurahScreen(surah: n)),
                      semanticLabel: s.nameAr,
                      child: Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: LinearGradient(colors: colors)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(s.nameAr, style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 30, color: Colors.white)),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            for (var k = 1; k <= 3; k++)
                              Icon(k <= got ? Icons.star_rounded : Icons.star_border_rounded, color: k <= got ? const Color(0xFFFFF176) : Colors.white70, size: 28),
                          ]),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('set_parent_pin')),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, maxLength: 4, autofocus: true, decoration: InputDecoration(helperText: context.tr('pin_help'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(context.tr('remove'))),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: Text(context.tr('save'))),
        ],
      ),
    );
    disposeAfterDialog([ctrl]);
    if (v == null) return;
    ref.read(settingsProvider.notifier).update((s) => v.length == 4 ? s.copyWith(kidsPin: v) : s.copyWith(clearKidsPin: true));
  }
}

class KidsSurahScreen extends ConsumerWidget {
  const KidsSurahScreen({super.key, required this.surah});
  final int surah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(quranProvider).value;
    if (q == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final info = q.surah(surah);
    final playing = ref.watch(audioProvider.select((p) => p.current));
    final m = Motion.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(foregroundColor: const Color(0xFF3B2F1E), title: Text(info.nameAr, style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 26))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 140), children: [
        if (surah != 1 && surah != 9)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ', textAlign: TextAlign.center, style: TextStyle(fontFamily: Brand.quranFont, fontSize: 28, color: Color(0xFF3B2F1E))),
          ),
        for (var a = 1; a <= info.ayahCount; a++)
          AnimatedContainer(
            duration: m.medium,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: playing?.surah == surah && playing?.ayah == a ? const Color(0xFFFFE08A) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Text(
              '${q.text(surah, a)} ${ayahMarker(a)}',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 32, height: 2, color: Color(0xFF2D2416)),
            ),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4FC3F7), padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () => ref.read(audioProvider.notifier).playSurah(surah, repeatEach: 2),
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(context.tr('kids_listen')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFB300), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () => _award(context, ref),
                icon: const Icon(Icons.star_rounded),
                label: Text(context.tr('kids_stars')),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _award(BuildContext context, WidgetRef ref) async {
    final n = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('kids_award_title')),
        children: [
          for (final (k, key) in [(1, 'kids_star_1'), (2, 'kids_star_2'), (3, 'kids_star_3')])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, k),
              child: Row(children: [
                for (var i = 0; i < k; i++) const Icon(Icons.star_rounded, color: Color(0xFFFFB300)),
                const SizedBox(width: 8),
                Expanded(child: Text(context.tr(key))),
              ]),
            ),
        ],
      ),
    );
    if (n == null || !context.mounted) return;
    ref.read(kidsProvider.notifier).award(surah, n);
    await showCelebration(context, title: context.tr('kids_bravo'), subtitle: context.tr('stars_n', {'n': n}));
  }
}
