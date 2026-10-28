import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One printed line of a Madani mushaf page: a surah title, a basmala, or
/// a run of words (`word == -1` is the end-of-verse marker).
class MushafLine {
  const MushafLine.header(this.surah) : basmala = false, _words = null;
  const MushafLine.basmala(this.surah) : basmala = true, _words = null;
  MushafLine.words(Int32List words) : surah = null, basmala = false, _words = words;

  /// Surah of a title or basmala line.
  final int? surah;
  final bool basmala;
  final Int32List? _words;

  bool get isHeader => surah != null && !basmala;
  bool get isWords => _words != null;

  /// Number of tokens (words and verse markers) on the line.
  int get length => (_words?.length ?? 0) ~/ 3;
  int surahAt(int i) => _words![i * 3];
  int ayahAt(int i) => _words![i * 3 + 1];
  int wordAt(int i) => _words![i * 3 + 2];
}

/// The printed page layout (15 lines a page; 8 on the first two pages),
/// mapped onto the words of the bundled text. See tool/data/build_data.py.
class MushafLayout {
  MushafLayout(this._pages);
  final List<List<MushafLine>> _pages;

  List<MushafLine> page(int n) => n < 1 || n > _pages.length ? const [] : _pages[n - 1];

  static Future<MushafLayout> load([AssetBundle? bundle]) async {
    final bytes = (await (bundle ?? rootBundle).load('assets/data/mushaf_lines.json.gz')).buffer.asUint8List();
    return compute(parse, bytes);
  }

  @visibleForTesting
  static MushafLayout parse(Uint8List bytes) {
    final j = jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
    return MushafLayout([
      for (final p in j['pages'] as List)
        [
          for (final r in (p as List).cast<Map<String, dynamic>>())
            if (r['h'] != null)
              MushafLine.header(r['h'] as int)
            else if (r['b'] != null)
              MushafLine.basmala(r['b'] as int)
            else
              MushafLine.words(Int32List.fromList([for (final w in (r['w'] as List? ?? const [])) ...(w as List).cast<int>()])),
        ],
    ]);
  }
}
