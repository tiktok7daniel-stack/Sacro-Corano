import 'package:flutter/foundation.dart';

@immutable
class SurahInfo {
  const SurahInfo({
    required this.number,
    required this.nameAr,
    required this.translit,
    required this.nameEn,
    required this.ayahCount,
    required this.startIndex,
    required this.revelationOrder,
    required this.meccan,
  });

  final int number;
  final String nameAr;
  final String translit;
  final String nameEn;
  final int ayahCount;

  /// 1-based absolute index of the first ayah in the mushaf (1..6236).
  final int startIndex;
  final int revelationOrder;
  final bool meccan;

  factory SurahInfo.fromJson(Map<String, dynamic> j) => SurahInfo(
        number: j['n'] as int,
        nameAr: j['ar'] as String,
        translit: j['tr'] as String,
        nameEn: j['en'] as String,
        ayahCount: j['c'] as int,
        startIndex: j['s'] as int,
        revelationOrder: j['o'] as int,
        meccan: j['m'] == 1,
      );
}

/// A verse address, e.g. 2:255.
@immutable
class AyahRef implements Comparable<AyahRef> {
  const AyahRef(this.surah, this.ayah);

  final int surah;
  final int ayah;

  factory AyahRef.parse(String s) {
    final p = s.split(':');
    return AyahRef(int.parse(p[0]), int.parse(p[1]));
  }

  String get key => '$surah:$ayah';

  @override
  int compareTo(AyahRef other) =>
      surah != other.surah ? surah.compareTo(other.surah) : ayah.compareTo(other.ayah);

  bool operator <=(AyahRef o) => compareTo(o) <= 0;
  bool operator >=(AyahRef o) => compareTo(o) >= 0;

  @override
  bool operator ==(Object other) => other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  @override
  String toString() => key;
}

/// Inclusive range of verses inside one surah.
@immutable
class AyahRange {
  const AyahRange(this.surah, this.from, this.to);

  final int surah;
  final int from;
  final int to;

  factory AyahRange.parse(String s) {
    // "12:4-101" or "71" (whole surah handled by caller) or "2:255"
    final p = s.split(':');
    final surah = int.parse(p[0]);
    if (p.length == 1) return AyahRange(surah, 1, -1);
    final r = p[1].split('-');
    final from = int.parse(r[0]);
    return AyahRange(surah, from, r.length > 1 ? int.parse(r[1]) : from);
  }

  int get length => to - from + 1;

  @override
  String toString() => from == to ? '$surah:$from' : '$surah:$from-$to';
}

@immutable
class Translation {
  const Translation({required this.id, required this.name, required this.lang, required this.source, required this.ayahs});

  final String id;
  final String name;
  final String lang;
  final String source;
  final List<List<String>> ayahs;

  String of(int surah, int ayah) => ayahs[surah - 1][ayah - 1];
}
