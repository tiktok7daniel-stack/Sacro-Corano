import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/arabic.dart';
import '../../core/widgets/common.dart';
import '../../domain/mp3quran.dart';
import '../../services/audio.dart';

/// Reciters of MP3Quran.net, fetched when the screen opens and cached so the
/// list (and anything already downloaded) is there offline.
final fullRecitersProvider = FutureProvider<List<FullReciter>>((ref) async {
  final storage = ref.read(storageProvider);
  final lang = ref.read(settingsProvider).lang == 'ar' ? 'ar' : 'eng';
  final key = 'fullReciters_$lang';
  try {
    final res = await http.get(Uri.parse('https://mp3quran.net/api/v3/reciters?language=$lang')).timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      final list = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['reciters'] as List;
      final parsed = parseFullReciters(list);
      if (parsed.isNotEmpty) {
        await storage.write(key, list);
        return parsed;
      }
    }
  } catch (_) {
    // Offline: use the cached list below.
  }
  final cached = parseFullReciters(storage.readList(key));
  if (cached.isEmpty) throw StateError('offline');
  return cached;
});

/// Whole-surah recitations by well-known reciters, one gapless file per
/// surah, playable from the internet or saved for offline listening.
class FullLibraryScreen extends ConsumerStatefulWidget {
  const FullLibraryScreen({super.key});
  @override
  ConsumerState<FullLibraryScreen> createState() => _FullLibraryScreenState();
}

class _FullLibraryScreenState extends ConsumerState<FullLibraryScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(fullRecitersProvider);
    return Scaffold(
      appBar: AppBar(),
      body: Column(children: [
        PageTitle(context.tr('full_title'), subtitle: context.tr('full_sub')),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.tr('full_search')),
          ),
        ),
        Expanded(
          child: AsyncView<List<FullReciter>>(
            value: list,
            onRetry: () => ref.invalidate(fullRecitersProvider),
            builder: (all) {
              final n = normalizeArabic(_q);
              final shown = n.isEmpty ? all : all.where((r) => normalizeArabic(r.name).contains(n) || r.name.toLowerCase().contains(_q.toLowerCase())).toList();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final r = shown[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      onTap: () => push(context, FullReciterScreen(reciter: r)),
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor: Brand.teal.withValues(alpha: 0.25),
                          child: Text(r.name.characters.first, style: const TextStyle(color: Brand.tealBright)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text(context.tr('full_sets', {'n': r.moshafs.length}), style: const TextStyle(color: Brand.textMid, fontSize: 12)),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// One reciter: pick a recording set, then play or download any surah.
class FullReciterScreen extends ConsumerStatefulWidget {
  const FullReciterScreen({super.key, required this.reciter});
  final FullReciter reciter;
  @override
  ConsumerState<FullReciterScreen> createState() => _FullReciterScreenState();
}

class _FullReciterScreenState extends ConsumerState<FullReciterScreen> {
  int _set = 0;
  Set<int> _saved = {};
  final Map<int, double> _progress = {};
  bool _failed = false;

  Moshaf get _moshaf => widget.reciter.moshafs[_set];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await FullDownloads.downloaded(_moshaf.id);
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _play(int surah, String title) async {
    final f = _saved.contains(surah) ? (await FullDownloads.file(_moshaf.id, surah)).path : null;
    await ref.read(audioProvider.notifier).playStream(_moshaf.url(surah).toString(), title, artist: widget.reciter.name, localPath: f);
  }

  Future<void> _download(int surah) async {
    final moshaf = _moshaf;
    setState(() {
      _progress[surah] = 0;
      _failed = false;
    });
    try {
      await FullDownloads.download(moshaf.id, surah, moshaf.url(surah), onProgress: (p) {
        if (mounted) setState(() => _progress[surah] = p);
      });
      if (moshaf.id == _moshaf.id) await _loadSaved();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _progress.remove(surah));
    }
  }

  Future<void> _remove(int surah) async {
    await FullDownloads.delete(_moshaf.id, surah);
    await _loadSaved();
  }

  @override
  Widget build(BuildContext context) {
    final quran = ref.watch(quranProvider);
    final playing = ref.watch(audioProvider.select((p) => p.stream));
    final sets = widget.reciter.moshafs;
    return Scaffold(
      appBar: AppBar(),
      body: AsyncView(
        value: quran,
        builder: (q) {
          final surahs = [for (final s in q.surahs) if (_moshaf.has(s.number)) s];
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 140), children: [
            PageTitle(widget.reciter.name, subtitle: context.tr('full_count', {'n': surahs.length})),
            if (sets.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (i, m) in sets.indexed)
                    ChoiceChip(
                      label: Text(m.name),
                      selected: i == _set,
                      onSelected: (_) {
                        setState(() => _set = i);
                        _loadSaved();
                      },
                    ),
                ]),
              ),
            if (_failed)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(context.tr('full_failed'), style: const TextStyle(color: Colors.redAccent))),
            for (final s in surahs)
              Builder(builder: (context) {
                final title = s.nameAr;
                final on = playing == title;
                final p = _progress[s.number];
                final saved = _saved.contains(s.number);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    borderColor: on ? Brand.gold : null,
                    child: ListTile(
                      dense: true,
                      leading: Text(context.num(s.number), style: const TextStyle(color: Brand.textMid)),
                      title: Text(s.nameAr, style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 21)),
                      subtitle: p != null
                          ? LinearProgressIndicator(value: p == 0 ? null : p)
                          : (saved ? Text(context.tr('available_offline'), style: const TextStyle(color: Brand.tealBright, fontSize: 12)) : null),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (p == null)
                          IconButton(
                            tooltip: saved ? context.tr('delete') : context.tr('download'),
                            icon: Icon(saved ? Icons.delete_outline_rounded : Icons.download_for_offline_outlined),
                            onPressed: () => saved ? _remove(s.number) : _download(s.number),
                          ),
                        IconButton(
                          tooltip: on ? context.tr('stop') : context.tr('play'),
                          icon: Icon(on ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: Brand.gold, size: 32),
                          onPressed: () => on ? ref.read(audioProvider.notifier).stop() : _play(s.number, title),
                        ),
                      ]),
                    ),
                  ),
                );
              }),
          ]);
        },
      ),
    );
  }
}
