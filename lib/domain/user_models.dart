import 'package:flutter/foundation.dart';

import 'quran_models.dart';

@immutable
class Bookmark {
  const Bookmark({required this.ref, required this.collection, required this.created});
  final AyahRef ref;
  final String collection;
  final DateTime created;

  Map<String, dynamic> toJson() => {'r': ref.key, 'c': collection, 't': created.toIso8601String()};
  factory Bookmark.fromJson(Map<String, dynamic> j) =>
      Bookmark(ref: AyahRef.parse(j['r'] as String), collection: j['c'] as String, created: DateTime.parse(j['t'] as String));
}

/// A personal reflection (tadabbur) attached to a verse.
@immutable
class Reflection {
  const Reflection({required this.id, required this.ref, required this.text, this.tags = const [], required this.created});
  final String id;
  final AyahRef ref;
  final String text;
  final List<String> tags;
  final DateTime created;

  Reflection copyWith({String? text, List<String>? tags}) =>
      Reflection(id: id, ref: ref, text: text ?? this.text, tags: tags ?? this.tags, created: created);

  Map<String, dynamic> toJson() =>
      {'id': id, 'r': ref.key, 'x': text, 'g': tags, 't': created.toIso8601String()};
  factory Reflection.fromJson(Map<String, dynamic> j) => Reflection(
        id: j['id'] as String,
        ref: AyahRef.parse(j['r'] as String),
        text: j['x'] as String,
        tags: ((j['g'] as List?) ?? []).cast<String>(),
        created: DateTime.parse(j['t'] as String),
      );
}

/// Tasbih presets. Texts are the well-known short adhkar from the Sunnah.
@immutable
class Dhikr {
  const Dhikr(this.id, this.text, this.target);
  final String id;
  final String text;
  final int target;

  Map<String, dynamic> toJson() => {'id': id, 'x': text, 'n': target};
  factory Dhikr.fromJson(Map<String, dynamic> j) => Dhikr(j['id'] as String, j['x'] as String, j['n'] as int);
}

const defaultDhikr = <Dhikr>[
  Dhikr('subhanallah', 'سُبْحَانَ اللَّهِ', 33),
  Dhikr('alhamdulillah', 'الْحَمْدُ لِلَّهِ', 33),
  Dhikr('allahuakbar', 'اللَّهُ أَكْبَرُ', 34),
  Dhikr('tahlil', 'لَا إِلَهَ إِلَّا اللَّهُ', 100),
  Dhikr('istighfar', 'أَسْتَغْفِرُ اللَّهَ', 100),
  Dhikr('hawqala', 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ', 100),
  Dhikr('salawat', 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ', 100),
  Dhikr('subhanallah_wabihamdihi', 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 100),
];

/// Daily activity aggregates used by statistics, streaks and achievements.
@immutable
class DayActivity {
  const DayActivity({this.ayahsRead = 0, this.secondsRead = 0, this.tasbih = 0, this.prayers = const {}, this.azkar = const {}});
  final int ayahsRead;
  final int secondsRead;
  final int tasbih;

  /// fajr/dhuhr/asr/maghrib/isha prayed (self-reported).
  final Set<String> prayers;

  /// Azkar categories completed today.
  final Set<String> azkar;

  bool get active => ayahsRead > 0 || tasbih > 0 || prayers.isNotEmpty || azkar.isNotEmpty;

  DayActivity copyWith({int? ayahsRead, int? secondsRead, int? tasbih, Set<String>? prayers, Set<String>? azkar}) =>
      DayActivity(
        ayahsRead: ayahsRead ?? this.ayahsRead,
        secondsRead: secondsRead ?? this.secondsRead,
        tasbih: tasbih ?? this.tasbih,
        prayers: prayers ?? this.prayers,
        azkar: azkar ?? this.azkar,
      );

  Map<String, dynamic> toJson() =>
      {'a': ayahsRead, 's': secondsRead, 't': tasbih, 'p': prayers.toList(), 'z': azkar.toList()};
  factory DayActivity.fromJson(Map<String, dynamic> j) => DayActivity(
        ayahsRead: j['a'] as int? ?? 0,
        secondsRead: j['s'] as int? ?? 0,
        tasbih: j['t'] as int? ?? 0,
        prayers: ((j['p'] as List?) ?? []).cast<String>().toSet(),
        azkar: ((j['z'] as List?) ?? []).cast<String>().toSet(),
      );
}
