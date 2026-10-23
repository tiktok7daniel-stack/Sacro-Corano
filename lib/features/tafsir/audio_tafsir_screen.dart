import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/arabic.dart';
import '../../core/widgets/common.dart';
import '../../data/quran/quran_data.dart';
import '../../services/tafsir_reader.dart';

/// Audio tafsir: Tafsir al-Muyassar read aloud by the device's Arabic voice.
class AudioTafsirScreen extends ConsumerStatefulWidget {
  const AudioTafsirScreen({super.key});

  @override
  ConsumerState<AudioTafsirScreen> createState() => _AudioTafsirScreenState();
}

class _AudioTafsirScreenState extends ConsumerState<AudioTafsirScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final quran = ref.watch(quranProvider);
    final st = ref.watch(tafsirReaderProvider);
    final reader = ref.read(tafsirReaderProvider.notifier);
    return Scaffold(
      appBar: AppBar(),
      body: AsyncView<QuranData>(
        value: quran,
        builder: (q) {
          final n = normalizeArabic(_q);
          final list = q.surahs
              .where((s) => n.isEmpty || normalizeArabic(s.nameAr).contains(n) || s.translit.toLowerCase().contains(_q.toLowerCase()))
              .toList();
          return Column(
            children: [
              PageTitle(context.tr('audio_tafsir'), subtitle: context.tr('audio_tafsir_sub')),
              if (st.unavailable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: AppCard(
                    borderColor: Colors.orange,
                    child: Text(context.tr('tts_unavailable'), style: const TextStyle(height: 1.5)),
                  ),
                ),
              if (st.current != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: AppCard(
                    gradient: const LinearGradient(colors: [Color(0xFF145E6B), Color(0xFF0F4652)]),
                    borderColor: Colors.transparent,
                    child: Row(
                      children: [
                        const Icon(Icons.record_voice_over_rounded, color: Brand.gold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${q.surah(st.current!.surah).nameAr} · ${context.tr('ayah_n', {'n': st.current!.ayah})}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr('previous'),
                          onPressed: () => reader.skip(-1),
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                        ),
                        IconButton(
                          tooltip: st.speaking ? context.tr('stop') : context.tr('play'),
                          onPressed: () => st.speaking ? reader.stop() : reader.start(st.current!.surah, from: st.current!.ayah),
                          icon: Icon(st.speaking ? Icons.stop_circle_rounded : Icons.play_circle_rounded, color: Brand.gold, size: 36),
                        ),
                        IconButton(
                          tooltip: context.tr('next'),
                          onPressed: () => reader.skip(1),
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.tr('search_surah')),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final s = list[i];
                    final on = st.speaking && st.current?.surah == s.number;
                    return FadeSlideIn.indexed(
                      i,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Brand.teal.withValues(alpha: 0.18),
                          child: Text(context.num(s.number), style: const TextStyle(fontSize: 12, color: Brand.tealBright)),
                        ),
                        title: Text(s.nameAr, style: const TextStyle(fontFamily: Brand.naskhFont, fontSize: 19)),
                        subtitle: Text('${s.translit} · ${context.tr('ayahs_n', {'n': s.ayahCount})}'),
                        trailing: Icon(on ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded, color: on ? Brand.gold : Brand.tealBright),
                        onTap: () => on ? reader.stop() : reader.start(s.number),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
