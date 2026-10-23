import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../domain/reciters.dart';
import '../../services/audio.dart';
import 'full_library_screen.dart';

/// Choose a reciter, play any surah, download surahs for offline listening.
class RecitersScreen extends ConsumerWidget {
  const RecitersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(tooltip: context.tr('storage'), icon: const Icon(Icons.sd_storage_outlined), onPressed: () => push(context, const AudioStorageScreen())),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 140), children: [
        PageTitle(context.tr('reciters'), subtitle: context.tr('reciters_sub')),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            gradient: const LinearGradient(colors: Brand.gReciters),
            borderColor: Colors.transparent,
            onTap: () => push(context, const FullLibraryScreen()),
            child: Row(children: [
              const Icon(Icons.library_music_rounded, color: Colors.white, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('full_card'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(context.tr('full_card_sub'), style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
                ]),
              ),
            ]),
          ),
        ),
        for (final (i, r) in reciters.indexed)
          FadeSlideIn.indexed(
            i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                borderColor: r.id == s.reciterId ? Brand.gold : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).update((x) => x.copyWith(reciterId: r.id));
                  push(context, ReciterSurahsScreen(reciter: r));
                },
                child: Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Brand.teal.withValues(alpha: 0.25),
                    child: Text(r.nameAr.characters.first, style: const TextStyle(fontSize: 20, color: Brand.tealBright)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.name(context.lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(context.tr('style_${r.style}'), style: const TextStyle(color: Brand.textMid, fontSize: 12)),
                    ]),
                  ),
                  if (r.id == s.reciterId) const Icon(Icons.check_circle_rounded, color: Brand.gold),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(context.tr('audio_source_note'), style: const TextStyle(color: Brand.textLow, fontSize: 12), textAlign: TextAlign.center),
      ]),
    );
  }
}

class ReciterSurahsScreen extends ConsumerStatefulWidget {
  const ReciterSurahsScreen({super.key, required this.reciter});
  final Reciter reciter;
  @override
  ConsumerState<ReciterSurahsScreen> createState() => _ReciterSurahsScreenState();
}

class _ReciterSurahsScreenState extends ConsumerState<ReciterSurahsScreen> {
  final Map<int, double> _progress = {};
  final Map<int, int> _downloaded = {};
  final Set<int> _cancel = {};

  Future<void> _refresh(int surah, int count) async {
    final n = await AudioDownloads.downloadedCount(widget.reciter, surah, count);
    if (mounted) setState(() => _downloaded[surah] = n);
  }

  Future<void> _download(int surah, int count) async {
    setState(() => _progress[surah] = 0);
    _cancel.remove(surah);
    try {
      // Include the basmala file (1:1) used before every surah.
      await AudioDownloads.downloadSurah(widget.reciter, 1, 1);
      await AudioDownloads.downloadSurah(
        widget.reciter,
        surah,
        count,
        onProgress: (p) {
          if (mounted) setState(() => _progress[surah] = p);
        },
        cancelled: () => _cancel.contains(surah),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('download_failed'))));
    }
    if (mounted) setState(() => _progress.remove(surah));
    await _refresh(surah, count);
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    if (q == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(widget.reciter.name(context.lang))),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 140),
        itemCount: 114,
        itemBuilder: (context, i) {
          final s = q.surahs[i];
          if (!_downloaded.containsKey(s.number)) {
            _downloaded[s.number] = 0;
            _refresh(s.number, s.ayahCount);
          }
          final n = _downloaded[s.number] ?? 0;
          final p = _progress[s.number];
          final complete = n >= s.ayahCount;
          return ListTile(
            leading: Text(context.num(s.number), style: const TextStyle(color: Brand.textMid)),
            title: Text(s.nameAr, style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 21)),
            subtitle: p != null ? LinearProgressIndicator(value: p) : (complete ? Text(context.tr('available_offline'), style: const TextStyle(color: Brand.tealBright, fontSize: 12)) : null),
            onTap: () => ref.read(audioProvider.notifier).playSurah(s.number),
            trailing: p != null
                ? IconButton(tooltip: context.tr('cancel'), icon: const Icon(Icons.close_rounded), onPressed: () => _cancel.add(s.number))
                : complete
                    ? IconButton(
                        tooltip: context.tr('delete'),
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () async {
                          await AudioDownloads.deleteSurah(widget.reciter, s.number, s.ayahCount);
                          await _refresh(s.number, s.ayahCount);
                        },
                      )
                    : IconButton(tooltip: context.tr('download_for_offline'), icon: const Icon(Icons.download_rounded), onPressed: () => _download(s.number, s.ayahCount)),
          );
        },
      ),
    );
  }
}

class AudioStorageScreen extends StatefulWidget {
  const AudioStorageScreen({super.key});
  @override
  State<AudioStorageScreen> createState() => _AudioStorageScreenState();
}

class _AudioStorageScreenState extends State<AudioStorageScreen> {
  late Future<Map<String, int>> _usage = AudioDownloads.usage();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('storage'))),
        body: FutureBuilder<Map<String, int>>(
          future: _usage,
          builder: (context, snap) {
            final u = snap.data ?? {};
            if (u.isEmpty) return EmptyState(icon: Icons.sd_storage_outlined, title: context.tr('no_downloads'));
            return ListView(children: [
              for (final e in u.entries)
                ListTile(
                  title: Text(reciterById(e.key).name(context.lang)),
                  subtitle: Text('${(e.value / 1048576).toStringAsFixed(1)} MB'),
                  trailing: IconButton(
                    tooltip: context.tr('delete'),
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await AudioDownloads.deleteReciter(e.key);
                      setState(() => _usage = AudioDownloads.usage());
                    },
                  ),
                ),
            ]);
          },
        ),
      );
}
