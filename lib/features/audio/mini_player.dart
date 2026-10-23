import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../domain/reciters.dart';
import '../../services/audio.dart';
import '../quran/focus_listen_screen.dart';

/// Floating playback bar shown whenever a recitation is active.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.inReader = false});
  final bool inReader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(audioProvider);
    final q = ref.watch(quranProvider).value;
    final s = ref.watch(settingsProvider);
    final m = Motion.of(context);
    final cur = p.current;

    return AnimatedSwitcher(
      duration: m.medium,
      transitionBuilder: (child, a) => SlideTransition(
        position: Tween(begin: const Offset(0, 1.2), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Motion.emphasized)),
        child: child,
      ),
      child: !p.active || q == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Padding(
              key: const ValueKey('player'),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Material(
                color: Brand.surfaceHigh,
                elevation: 8,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: cur == null ? null : () => push(context, FocusListenScreen(start: cur)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: Brand.gReciters),
                          ),
                          child: Icon(cur == null ? Icons.radio_rounded : Icons.graphic_eq_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cur == null
                                    ? (p.stream ?? '')
                                    : '${q.surah(cur.surah).nameAr}${cur.ayah > 0 ? ' · ${context.tr('ayah_n', {'n': cur.ayah})}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Brand.textHigh, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                cur == null ? context.tr('radio') : reciterById(s.reciterId).name(context.lang),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Brand.textMid, fontSize: 12),
                              ),
                              if (p.error != null) Text(context.tr('audio_error'), style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr('speed'),
                          color: Brand.textMid,
                          onPressed: () {
                            const speeds = [0.75, 1.0, 1.25, 1.5];
                            final i = speeds.indexOf(p.speed);
                            ref.read(audioProvider.notifier).setSpeed(speeds[(i + 1) % speeds.length]);
                          },
                          icon: Text('${p.speed}×', style: const TextStyle(color: Brand.textMid, fontSize: 12)),
                        ),
                        IconButton(
                          tooltip: p.playing ? context.tr('pause') : context.tr('play'),
                          color: Brand.gold,
                          iconSize: 32,
                          onPressed: () => ref.read(audioProvider.notifier).toggle(),
                          icon: p.loading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(p.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                        ),
                        IconButton(
                          tooltip: context.tr('stop'),
                          color: Brand.textMid,
                          onPressed: () => ref.read(audioProvider.notifier).stop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
