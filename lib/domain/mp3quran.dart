import 'package:flutter/foundation.dart';

/// One recording set of a reciter on MP3Quran.net: a server folder holding a
/// single gapless file per surah (`001.mp3` … `114.mp3`).
@immutable
class Moshaf {
  const Moshaf({required this.id, required this.name, required this.server, required this.surahs});
  final int id;
  final String name;
  final String server;
  final Set<int> surahs;

  static String _pad(int n) => n.toString().padLeft(3, '0');

  String fileName(int surah) => '${_pad(surah)}.mp3';

  Uri url(int surah) => Uri.parse('${server.endsWith('/') ? server : '$server/'}${fileName(surah)}');

  bool has(int surah) => surahs.contains(surah);
}

@immutable
class FullReciter {
  const FullReciter({required this.id, required this.name, required this.moshafs});
  final int id;
  final String name;
  final List<Moshaf> moshafs;
}

/// Parses the `reciters` array of `https://mp3quran.net/api/v3/reciters`.
/// Entries without an https server or without any surah are dropped, so a
/// malformed record never breaks the list.
List<FullReciter> parseFullReciters(List<dynamic> json) {
  final out = <FullReciter>[];
  for (final r in json) {
    if (r is! Map) continue;
    final moshafs = <Moshaf>[];
    for (final m in (r['moshaf'] as List? ?? const [])) {
      if (m is! Map) continue;
      final server = m['server'];
      if (server is! String || !server.startsWith('https')) continue;
      final surahs = <int>{
        for (final s in (m['surah_list']?.toString() ?? '').split(','))
          if (int.tryParse(s.trim()) case final n? when n >= 1 && n <= 114) n,
      };
      if (surahs.isEmpty) continue;
      moshafs.add(Moshaf(id: (m['id'] as num?)?.toInt() ?? 0, name: (m['name'] as String? ?? '').trim(), server: server, surahs: surahs));
    }
    final name = (r['name'] as String? ?? '').trim();
    if (moshafs.isEmpty || name.isEmpty) continue;
    out.add(FullReciter(id: (r['id'] as num?)?.toInt() ?? 0, name: name, moshafs: moshafs));
  }
  return out;
}
