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
import '../../services/audio.dart';

class RadioStation {
  const RadioStation(this.name, this.url);
  final String name;
  final String url;
}

/// Live Quran radio stations from the MP3Quran.net public API. The list is
/// cached so it opens instantly next time; streaming needs a connection.
final radioStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final storage = ref.read(storageProvider);
  final lang = ref.read(settingsProvider).lang;
  List<RadioStation> parse(List<dynamic> list) => [
    for (final r in list.cast<Map<String, dynamic>>())
      if ((r['url'] as String?)?.startsWith('https') ?? false) RadioStation((r['name'] as String).trim(), r['url'] as String),
  ];
  try {
    final res = await http.get(Uri.parse('https://mp3quran.net/api/v3/radios?language=${lang == 'ar' ? 'ar' : 'eng'}')).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final list = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['radios'] as List;
      await storage.write('radioCache', list);
      return parse(list);
    }
  } catch (_) {
    // Offline: fall back to the cached list below.
  }
  final cached = storage.readList('radioCache');
  if (cached.isEmpty) throw StateError('offline');
  return parse(cached);
});

class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});
  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final stations = ref.watch(radioStationsProvider);
    final playing = ref.watch(audioProvider.select((p) => p.stream));
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          PageTitle(context.tr('radio'), subtitle: context.tr('radio_sub')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.tr('search_radio')),
            ),
          ),
          Expanded(
            child: AsyncView<List<RadioStation>>(
              value: stations,
              onRetry: () => ref.invalidate(radioStationsProvider),
              builder: (list) {
                final n = normalizeArabic(_q);
                final shown = n.isEmpty
                    ? list
                    : list.where((s) => normalizeArabic(s.name).contains(n) || s.name.toLowerCase().contains(_q.toLowerCase())).toList();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final s = shown[i];
                    final on = playing == s.name;
                    return FadeSlideIn.indexed(
                      i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          borderColor: on ? Brand.gold : null,
                          onTap: () => on ? ref.read(audioProvider.notifier).stop() : ref.read(audioProvider.notifier).playStream(s.url, s.name),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: on ? Brand.gKhatma : Brand.gQibla),
                                ),
                                child: Icon(on ? Icons.stop_rounded : Icons.radio_rounded, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              if (on) const Icon(Icons.graphic_eq_rounded, color: Brand.gold),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
