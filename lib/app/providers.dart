import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../data/azkar_repository.dart';
import '../data/hadith_repository.dart';
import '../data/local/storage.dart';
import '../data/quran/content_repository.dart';
import '../data/quran/mushaf_layout.dart';
import '../data/quran/quran_data.dart';
import '../data/quran/word_data.dart';
import '../domain/khatma.dart';
import '../domain/prayer_times.dart';
import '../domain/quran_models.dart';
import '../domain/search_engine.dart';
import '../domain/settings.dart';
import '../domain/srs.dart';
import '../domain/user_models.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

/// Overridden in main() once Hive is open.
final storageProvider = Provider<Storage>((ref) => Storage.instance);

final quranProvider = FutureProvider<QuranData>((ref) => QuranData.load());

final contentRepoProvider = Provider<ContentRepository>((ref) => ContentRepository());

final azkarProvider = FutureProvider<AzkarData>((ref) => AzkarData.load());

final tajweedProvider = FutureProvider<TajweedData>((ref) => TajweedData.load());

final wordByWordProvider = FutureProvider<WordByWord>((ref) => WordByWord.load());

final mushafLayoutProvider = FutureProvider<MushafLayout>((ref) => MushafLayout.load());

final translationProvider = FutureProvider.family<Translation, String>((ref, id) => ref.watch(contentRepoProvider).translation(id));

final searchEngineProvider = FutureProvider<SearchEngine>((ref) async {
  final q = await ref.watch(quranProvider.future);
  final index = await compute(QuranData.buildSearchIndex, q.rawText);
  final refs = <AyahRef>[
    for (final s in q.surahs)
      for (var a = 1; a <= s.ayahCount; a++) AyahRef(s.number, a),
  ];
  return SearchEngine(refs: refs, arabicIndex: index, isMeccan: (n) => q.surah(n).meccan, juzOf: (r) => q.juzOf(r.surah, r.ayah));
});

/// Ticks every second; used by countdowns.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

/// The clock truncated to the minute: screens that only show times rebuild
/// once a minute; only countdown text listens to [clockProvider].
final minuteProvider = Provider<DateTime>((ref) {
  final t = ref.watch(clockProvider.select((v) {
    final n = v.value ?? DateTime.now();
    return DateTime(n.year, n.month, n.day, n.hour, n.minute);
  }));
  return t;
});

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final storage = ref.read(storageProvider);
    var s = AppSettings.fromJson(storage.readSettings());
    // v1.5: the reader opens as mushaf pages, white page and black text,
    // for everyone once; both can be changed back in the reading settings.
    if (storage.read<bool>('mig_mushafPages') != true) {
      s = s.copyWith(pageMode: true, readingTheme: AppThemeKind.light);
      storage.writeSettings(s.toJson());
      storage.write('mig_mushafPages', true);
    }
    return s;
  }

  void update(AppSettings Function(AppSettings s) change) {
    state = change(state);
    ref.read(storageProvider).writeSettings(state.toJson());
  }

  void replace(AppSettings s) {
    state = s;
    ref.read(storageProvider).writeSettings(s.toJson());
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

final prayerCalculatorProvider = Provider<PrayerCalculator?>((ref) {
  final s = ref.watch(settingsProvider);
  return s.hasLocation ? PrayerCalculator(s) : null;
});

// ---------------------------------------------------------------------------
// User data
// ---------------------------------------------------------------------------

abstract class _ListStore<T> extends Notifier<List<T>> {
  String get key;
  T decode(Map<String, dynamic> j);
  Map<String, dynamic> encode(T v);

  @override
  List<T> build() => ref.read(storageProvider).readList(key).map((e) => decode(Map<String, dynamic>.from(e as Map))).toList();

  @protected
  void save(List<T> next) {
    state = next;
    ref.read(storageProvider).write(key, next.map(encode).toList());
  }
}

class BookmarksController extends _ListStore<Bookmark> {
  @override
  String get key => 'bookmarks';
  @override
  Bookmark decode(Map<String, dynamic> j) => Bookmark.fromJson(j);
  @override
  Map<String, dynamic> encode(Bookmark v) => v.toJson();

  bool isBookmarked(AyahRef r) => state.any((b) => b.ref == r);

  void toggle(AyahRef r, {String collection = 'default'}) {
    if (isBookmarked(r)) {
      save(state.where((b) => b.ref != r).toList());
    } else {
      save([Bookmark(ref: r, collection: collection, created: DateTime.now()), ...state]);
    }
  }

  void move(AyahRef r, String collection) => save([for (final b in state) b.ref == r ? Bookmark(ref: r, collection: collection, created: b.created) : b]);

  List<String> get collections => {'default', ...state.map((b) => b.collection)}.toList();
}

final bookmarksProvider = NotifierProvider<BookmarksController, List<Bookmark>>(BookmarksController.new);

class ReflectionsController extends _ListStore<Reflection> {
  @override
  String get key => 'reflections';
  @override
  Reflection decode(Map<String, dynamic> j) => Reflection.fromJson(j);
  @override
  Map<String, dynamic> encode(Reflection v) => v.toJson();

  void add(AyahRef r, String text, List<String> tags) => save([
    Reflection(id: '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}', ref: r, text: text, tags: tags, created: DateTime.now()),
    ...state,
  ]);

  void edit(String id, String text, List<String> tags) => save([for (final x in state) x.id == id ? x.copyWith(text: text, tags: tags) : x]);

  void remove(String id) => save(state.where((x) => x.id != id).toList());

  List<Reflection> forAyah(AyahRef r) => state.where((x) => x.ref == r).toList();
}

final reflectionsProvider = NotifierProvider<ReflectionsController, List<Reflection>>(ReflectionsController.new);

/// Last reading position (resume card on home).
class LastReadController extends Notifier<AyahRef?> {
  @override
  AyahRef? build() {
    final s = ref.read(storageProvider).read<String>('lastRead');
    return s == null ? null : AyahRef.parse(s);
  }

  void set(AyahRef r) {
    if (state == r) return;
    state = r;
    ref.read(storageProvider).write('lastRead', r.key);
  }
}

final lastReadProvider = NotifierProvider<LastReadController, AyahRef?>(LastReadController.new);

/// Per-day activity log powering statistics, streaks and achievements.
class ActivityController extends Notifier<Map<String, DayActivity>> {
  @override
  Map<String, DayActivity> build() =>
      ref.read(storageProvider).readMap('activity').map((k, v) => MapEntry(k, DayActivity.fromJson(Map<String, dynamic>.from(v as Map))));

  final Set<String> _seenToday = {};

  DayActivity today() => state[dayKey(DateTime.now())] ?? const DayActivity();

  void _mutate(DayActivity Function(DayActivity d) f, [DateTime? day]) {
    final k = dayKey(day ?? DateTime.now());
    final next = Map<String, DayActivity>.from(state)..[k] = f(state[k] ?? const DayActivity());
    state = next;
    ref.read(storageProvider).write('activity', next.map((k, v) => MapEntry(k, v.toJson())));
  }

  /// Counts a verse as read once per day (scrolling back does not inflate).
  void markAyahRead(AyahRef r) {
    final key = '${dayKey(DateTime.now())}/${r.key}';
    if (!_seenToday.add(key)) return;
    _mutate((d) => d.copyWith(ayahsRead: d.ayahsRead + 1));
  }

  void addReadingSeconds(int s) => _mutate((d) => d.copyWith(secondsRead: d.secondsRead + s));
  void addTasbih(int n) => _mutate((d) => d.copyWith(tasbih: d.tasbih + n));

  void togglePrayer(String prayer, [DateTime? day]) => _mutate((d) {
    final p = Set<String>.from(d.prayers);
    p.contains(prayer) ? p.remove(prayer) : p.add(prayer);
    return d.copyWith(prayers: p);
  }, day);

  void completeAzkar(String category) => _mutate((d) => d.copyWith(azkar: {...d.azkar, category}));
}

final activityProvider = NotifierProvider<ActivityController, Map<String, DayActivity>>(ActivityController.new);

class KhatmaController extends Notifier<KhatmaPlan?> {
  @override
  KhatmaPlan? build() {
    final m = ref.read(storageProvider).readMap('khatma');
    return m.isEmpty ? null : KhatmaPlan.fromJson(m);
  }

  void _save(KhatmaPlan? p) {
    state = p;
    p == null ? ref.read(storageProvider).delete('khatma') : ref.read(storageProvider).write('khatma', p.toJson());
  }

  void start(int days, Set<int> busy) =>
      _save(KhatmaPlan(start: DateTime.now(), targetDays: days, busyWeekdays: busy, completedCount: state?.completedCount ?? 0));

  void markRead(int page) {
    final p = state;
    if (p != null) _save(p.markRead(page, DateTime.now()));
  }

  void restart() {
    final p = state;
    if (p != null) _save(p.restart(DateTime.now()));
  }

  void updateBusy(Set<int> busy) {
    final p = state;
    if (p != null) _save(p.copyWith(busyWeekdays: busy));
  }

  void cancel() => _save(null);
}

final khatmaProvider = NotifierProvider<KhatmaController, KhatmaPlan?>(KhatmaController.new);

class FastingController extends Notifier<FastingLog> {
  @override
  FastingLog build() => FastingLog.fromJson(ref.read(storageProvider).readMap('fasting'));

  void _save(FastingLog f) {
    state = f;
    ref.read(storageProvider).write('fasting', f.toJson());
  }

  /// Cycles a day: none → fasted → missed → excused → none.
  void cycle(DateTime day) {
    const order = [null, 'fasted', 'missed', 'excused'];
    final k = dayKey(day);
    final next = order[(order.indexOf(state.days[k]) + 1) % order.length];
    final m = Map<String, String>.from(state.days);
    next == null ? m.remove(k) : m[k] = next;
    _save(state.copyWith(days: m));
  }

  void set(DateTime day, String? status) {
    final m = Map<String, String>.from(state.days);
    status == null ? m.remove(dayKey(day)) : m[dayKey(day)] = status;
    _save(state.copyWith(days: m));
  }

  void addOwed(int delta) => _save(state.copyWith(extraOwed: (state.extraOwed + delta).clamp(0, 10000)));
  void addQadaDone(int delta) => _save(state.copyWith(qadaDone: (state.qadaDone + delta).clamp(0, 10000)));
}

final fastingProvider = NotifierProvider<FastingController, FastingLog>(FastingController.new);

class HifzController extends _ListStore<HifzCard> {
  @override
  String get key => 'hifz';
  @override
  HifzCard decode(Map<String, dynamic> j) => HifzCard.fromJson(j);
  @override
  Map<String, dynamic> encode(HifzCard v) => v.toJson();

  void addSurah(int surah, int ayahCount, {int chunk = 5}) {
    final existing = state.map((c) => c.id).toSet();
    final now = DateTime.now();
    final added = [
      for (final (f, t) in chunkSurah(ayahCount, size: chunk))
        if (!existing.contains('$surah:$f-$t')) HifzCard(id: '$surah:$f-$t', surah: surah, from: f, to: t, due: now),
    ];
    save([...state, ...added]);
  }

  void review(String id, int grade, int mistakes) =>
      save([for (final c in state) c.id == id ? reviewCard(c, grade, now: DateTime.now(), mistakes: mistakes) : c]);

  void removeSurah(int surah) => save(state.where((c) => c.surah != surah).toList());

  List<HifzCard> due() {
    final now = DateTime.now();
    final list = state.where((c) => c.isDue(now)).toList()..sort((a, b) => a.due != b.due ? a.due.compareTo(b.due) : a.id.compareTo(b.id));
    return list;
  }
}

final hifzProvider = NotifierProvider<HifzController, List<HifzCard>>(HifzController.new);

@immutable
class TasbihState {
  const TasbihState({required this.presets, required this.selected, required this.count, required this.rounds});
  final List<Dhikr> presets;
  final String selected;
  final int count;
  final int rounds;

  Dhikr get current => presets.firstWhere((d) => d.id == selected, orElse: () => presets.first);
}

class TasbihController extends Notifier<TasbihState> {
  @override
  TasbihState build() {
    final m = ref.read(storageProvider).readMap('tasbih');
    final custom = ((m['custom'] as List?) ?? []).map((e) => Dhikr.fromJson(Map<String, dynamic>.from(e as Map)));
    return TasbihState(
      presets: [...defaultDhikr, ...custom],
      selected: m['selected'] as String? ?? defaultDhikr.first.id,
      count: m['count'] as int? ?? 0,
      rounds: m['rounds'] as int? ?? 0,
    );
  }

  void _save(TasbihState s) {
    state = s;
    ref.read(storageProvider).write('tasbih', {
      'custom': s.presets.skip(defaultDhikr.length).map((d) => d.toJson()).toList(),
      'selected': s.selected,
      'count': s.count,
      'rounds': s.rounds,
    });
  }

  /// Returns true when the tap completed a round.
  bool increment() {
    ref.read(activityProvider.notifier).addTasbih(1);
    final next = state.count + 1;
    if (next >= state.current.target) {
      _save(TasbihState(presets: state.presets, selected: state.selected, count: 0, rounds: state.rounds + 1));
      return true;
    }
    _save(TasbihState(presets: state.presets, selected: state.selected, count: next, rounds: state.rounds));
    return false;
  }

  void reset() => _save(TasbihState(presets: state.presets, selected: state.selected, count: 0, rounds: 0));

  void select(String id) => _save(TasbihState(presets: state.presets, selected: id, count: 0, rounds: 0));

  void addCustom(String text, int target) {
    final d = Dhikr('c${DateTime.now().millisecondsSinceEpoch}', text, target);
    _save(TasbihState(presets: [...state.presets, d], selected: d.id, count: 0, rounds: 0));
  }

  void removeCustom(String id) {
    if (defaultDhikr.any((d) => d.id == id)) return;
    final presets = state.presets.where((d) => d.id != id).toList();
    _save(TasbihState(presets: presets, selected: presets.first.id, count: 0, rounds: 0));
  }
}

final tasbihProvider = NotifierProvider<TasbihController, TasbihState>(TasbihController.new);

/// Stars earned per surah in kids mode.
class KidsController extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => ref.read(storageProvider).readMap('kids').map((k, v) => MapEntry(k, (v as num).toInt()));

  int get total => state.values.fold(0, (a, b) => a + b);

  void award(int surah, int stars) {
    final k = '$surah';
    if ((state[k] ?? 0) >= stars) return;
    state = {...state, k: stars.clamp(0, 3)};
    ref.read(storageProvider).write('kids', state);
  }
}

final kidsProvider = NotifierProvider<KidsController, Map<String, int>>(KidsController.new);

/// Achievements already celebrated, so the confetti shows only once.
class CelebratedController extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.read(storageProvider).readList('celebrated').cast<String>().toSet();

  void add(Iterable<String> ids) {
    state = {...state, ...ids};
    ref.read(storageProvider).write('celebrated', state.toList());
  }
}

final celebratedProvider = NotifierProvider<CelebratedController, Set<String>>(CelebratedController.new);

final hadithRepoProvider = Provider<HadithRepository>((ref) => HadithRepository());

class FavoritesController extends _ListStore<FavoriteItem> {
  @override
  String get key => 'favorites';
  @override
  FavoriteItem decode(Map<String, dynamic> j) => FavoriteItem.fromJson(j);
  @override
  Map<String, dynamic> encode(FavoriteItem v) => v.toJson();

  bool contains(String type, String id) => state.any((f) => f.type == type && f.id == id);

  void toggle(String type, String id, String text, String source) {
    if (contains(type, id)) {
      save(state.where((f) => !(f.type == type && f.id == id)).toList());
    } else {
      save([FavoriteItem(type: type, id: id, text: text, source: source, created: DateTime.now()), ...state]);
    }
  }
}

final favoritesProvider = NotifierProvider<FavoritesController, List<FavoriteItem>>(FavoritesController.new);

class DedicationsController extends _ListStore<Dedication> {
  @override
  String get key => 'dedications';
  @override
  Dedication decode(Map<String, dynamic> j) => Dedication.fromJson(j);
  @override
  Map<String, dynamic> encode(Dedication v) => v.toJson();

  void add(String name, String deed, String note) =>
      save([Dedication(id: '${DateTime.now().microsecondsSinceEpoch}', name: name, deed: deed, note: note, created: DateTime.now()), ...state]);

  void remove(String id) => save(state.where((d) => d.id != id).toList());
}

final dedicationsProvider = NotifierProvider<DedicationsController, List<Dedication>>(DedicationsController.new);
