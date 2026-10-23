import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../services/wake.dart';
import '../../core/widgets/common.dart';
import '../../domain/quran_models.dart';
import '../../domain/reciters.dart';
import '../../services/audio.dart';

/// "Focused listening": nothing on screen but the verse being recited,
/// cross-fading as the reciter moves on. The screen stays awake.
class FocusListenScreen extends ConsumerStatefulWidget {
  const FocusListenScreen({super.key, required this.start});
  final AyahRef start;

  @override
  ConsumerState<FocusListenScreen> createState() => _FocusListenScreenState();
}

class _FocusListenScreenState extends ConsumerState<FocusListenScreen> {
  @override
  void initState() {
    super.initState();
    keepScreenOn(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = ref.read(audioProvider);
      if (!p.active || p.current?.surah != widget.start.surah) {
        ref.read(audioProvider.notifier).playSurah(widget.start.surah, from: widget.start.ayah < 1 ? 1 : widget.start.ayah);
      }
    });
  }

  @override
  void dispose() {
    keepScreenOn(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    if (q == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final p = ref.watch(audioProvider);
    final s = ref.watch(settingsProvider);
    final cur = p.current ?? widget.start;
    final m = Motion.of(context);
    final showBasmala = cur.ayah == 0;

    return Scaffold(
      backgroundColor: Brand.ink,
      appBar: AppBar(foregroundColor: Brand.textMid),
      body: SafeArea(
        child: Column(children: [
          Text(q.surah(cur.surah).nameAr, style: const TextStyle(fontFamily: Brand.quranFont, color: Brand.gold, fontSize: 24)),
          Text(reciterById(s.reciterId).name(context.lang), style: const TextStyle(color: Brand.textLow)),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: m.long,
                switchInCurve: Curves.easeOut,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
                ),
                child: SingleChildScrollView(
                  key: ValueKey(cur),
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    showBasmala ? 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ' : '${q.textOf(cur)} ${ayahMarker(cur.ayah)}',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: Brand.quranFont, fontSize: s.quranFontSize * 1.15, height: 2.1, color: Brand.textHigh),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(iconSize: 34, color: Brand.textMid, tooltip: context.tr('next'), onPressed: () => ref.read(audioProvider.notifier).next(), icon: const Icon(Icons.skip_previous_rounded)),
              const SizedBox(width: 20),
              Pressable(
                onTap: () => ref.read(audioProvider.notifier).toggle(),
                semanticLabel: p.playing ? context.tr('pause') : context.tr('play'),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Brand.teal),
                  child: p.loading
                      ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(width: 20),
              IconButton(iconSize: 34, color: Brand.textMid, tooltip: context.tr('previous'), onPressed: () => ref.read(audioProvider.notifier).previous(), icon: const Icon(Icons.skip_next_rounded)),
            ]),
          ),
        ]),
      ),
    );
  }
}
