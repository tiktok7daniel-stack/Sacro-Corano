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

  Reflection copyWith({String? text, List<String>? tags}) => Reflection(id: id, ref: ref, text: text ?? this.text, tags: tags ?? this.tags, created: created);

  Map<String, dynamic> toJson() => {'id': id, 'r': ref.key, 'x': text, 'g': tags, 't': created.toIso8601String()};
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

  DayActivity copyWith({int? ayahsRead, int? secondsRead, int? tasbih, Set<String>? prayers, Set<String>? azkar}) => DayActivity(
    ayahsRead: ayahsRead ?? this.ayahsRead,
    secondsRead: secondsRead ?? this.secondsRead,
    tasbih: tasbih ?? this.tasbih,
    prayers: prayers ?? this.prayers,
    azkar: azkar ?? this.azkar,
  );

  Map<String, dynamic> toJson() => {'a': ayahsRead, 's': secondsRead, 't': tasbih, 'p': prayers.toList(), 'z': azkar.toList()};
  factory DayActivity.fromJson(Map<String, dynamic> j) => DayActivity(
    ayahsRead: j['a'] as int? ?? 0,
    secondsRead: j['s'] as int? ?? 0,
    tasbih: j['t'] as int? ?? 0,
    prayers: ((j['p'] as List?) ?? []).cast<String>().toSet(),
    azkar: ((j['z'] as List?) ?? []).cast<String>().toSet(),
  );
}

/// A saved hadith or dhikr (verses use [Bookmark]).
@immutable
class FavoriteItem {
  const FavoriteItem({required this.type, required this.id, required this.text, required this.source, required this.created});

  /// 'hadith' or 'zikr'.
  final String type;
  final String id;
  final String text;
  final String source;
  final DateTime created;

  Map<String, dynamic> toJson() => {'y': type, 'id': id, 'x': text, 's': source, 't': created.toIso8601String()};
  factory FavoriteItem.fromJson(Map<String, dynamic> j) => FavoriteItem(
    type: j['y'] as String,
    id: j['id'] as String,
    text: j['x'] as String,
    source: j['s'] as String? ?? '',
    created: DateTime.parse(j['t'] as String),
  );
}

/// A good deed dedicated to someone (sadaqa jariya log).
@immutable
class Dedication {
  const Dedication({required this.id, required this.name, required this.deed, required this.created, this.note = ''});
  final String id;
  final String name;

  /// 'khatma', 'surah', 'tasbih', 'dua', 'other'.
  final String deed;
  final String note;
  final DateTime created;

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'd': deed, 'x': note, 't': created.toIso8601String()};
  factory Dedication.fromJson(Map<String, dynamic> j) => Dedication(
    id: j['id'] as String,
    name: j['n'] as String,
    deed: j['d'] as String,
    note: j['x'] as String? ?? '',
    created: DateTime.parse(j['t'] as String),
  );
}

/// Fasting log: Ramadan days (and any other day) marked as fasted, missed
/// or excused, plus make-up (qada) fasts owed and done.
@immutable
class FastingLog {
  const FastingLog({this.days = const {}, this.extraOwed = 0, this.qadaDone = 0});

  /// dayKey → 'fasted' | 'missed' | 'excused'.
  final Map<String, String> days;

  /// Make-up fasts owed from earlier years, entered by hand.
  final int extraOwed;
  final int qadaDone;

  int get missedCount => days.values.where((v) => v == 'missed' || v == 'excused').length;
  int get fastedCount => days.values.where((v) => v == 'fasted').length;
  int get qadaRemaining => (missedCount + extraOwed - qadaDone).clamp(0, 100000);

  FastingLog copyWith({Map<String, String>? days, int? extraOwed, int? qadaDone}) =>
      FastingLog(days: days ?? this.days, extraOwed: extraOwed ?? this.extraOwed, qadaDone: qadaDone ?? this.qadaDone);

  Map<String, dynamic> toJson() => {'d': days, 'o': extraOwed, 'q': qadaDone};
  factory FastingLog.fromJson(Map<String, dynamic> j) => FastingLog(
        days: (j['d'] is Map) ? (j['d'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
        extraOwed: (j['o'] as num?)?.toInt() ?? 0,
        qadaDone: (j['q'] as num?)?.toInt() ?? 0,
      );
}
