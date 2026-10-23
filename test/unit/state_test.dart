import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/core/l10n/strings.dart';
import 'package:mishkah/data/local/storage.dart';
import 'package:mishkah/domain/khatma.dart';
import 'package:mishkah/domain/quran_models.dart';
import 'package:mishkah/domain/user_models.dart';
import 'package:mishkah/services/backup.dart';

void main() {
  late Directory dir;
  late Storage storage;
  late ProviderContainer c;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mishkah_state');
    storage = await Storage.initForTest(dir.path);
    c = ProviderContainer(overrides: [storageProvider.overrideWithValue(storage)]);
  });

  tearDown(() async {
    c.dispose();
    await storage.settle();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('settings persist through storage', () {
    c.read(settingsProvider.notifier).update((s) => s.copyWith(lang: 'en', tasbihGoal: 300));
    final c2 = ProviderContainer(overrides: [storageProvider.overrideWithValue(storage)]);
    expect(c2.read(settingsProvider).lang, 'en');
    expect(c2.read(settingsProvider).tasbihGoal, 300);
    c2.dispose();
  });

  test('bookmarks toggle, move and collections', () {
    final b = c.read(bookmarksProvider.notifier);
    b.toggle(const AyahRef(2, 255));
    b.toggle(const AyahRef(1, 1));
    expect(c.read(bookmarksProvider).length, 2);
    expect(b.isBookmarked(const AyahRef(2, 255)), isTrue);
    b.move(const AyahRef(2, 255), 'protection');
    expect(b.collections, containsAll(['default', 'protection']));
    b.toggle(const AyahRef(2, 255));
    expect(b.isBookmarked(const AyahRef(2, 255)), isFalse);
  });

  test('reflections add, edit, remove', () {
    final r = c.read(reflectionsProvider.notifier);
    r.add(const AyahRef(94, 5), 'with hardship comes ease', ['sabr']);
    final id = c.read(reflectionsProvider).single.id;
    r.edit(id, 'edited', ['sabr', 'shukr']);
    expect(r.forAyah(const AyahRef(94, 5)).single.text, 'edited');
    r.remove(id);
    expect(c.read(reflectionsProvider), isEmpty);
  });

  test('activity counts each verse once per day', () {
    final a = c.read(activityProvider.notifier);
    a.markAyahRead(const AyahRef(1, 1));
    a.markAyahRead(const AyahRef(1, 1));
    a.markAyahRead(const AyahRef(1, 2));
    a.togglePrayer('fajr');
    a.completeAzkar('أذكار الصباح');
    a.addReadingSeconds(30);
    final today = a.today();
    expect(today.ayahsRead, 2);
    expect(today.prayers, {'fajr'});
    expect(today.azkar, {'أذكار الصباح'});
    expect(today.secondsRead, 30);
    a.togglePrayer('fajr');
    expect(a.today().prayers, isEmpty);
  });

  test('tasbih rounds, custom dhikr, reset', () {
    final t = c.read(tasbihProvider.notifier);
    t.select('subhanallah');
    var rounds = 0;
    for (var i = 0; i < 33; i++) {
      if (t.increment()) rounds++;
    }
    expect(rounds, 1);
    expect(c.read(tasbihProvider).count, 0);
    expect(c.read(tasbihProvider).rounds, 1);
    expect(c.read(activityProvider.notifier).today().tasbih, 33);
    t.addCustom('يا حي يا قيوم', 7);
    expect(c.read(tasbihProvider).current.text, 'يا حي يا قيوم');
    t.removeCustom(c.read(tasbihProvider).selected);
    expect(c.read(tasbihProvider).presets.length, defaultDhikr.length);
    t.removeCustom('subhanallah');
    expect(c.read(tasbihProvider).presets.length, defaultDhikr.length, reason: 'presets cannot be removed');
    t.increment();
    t.reset();
    expect(c.read(tasbihProvider).count, 0);
  });

  test('khatma lifecycle', () {
    final k = c.read(khatmaProvider.notifier);
    k.start(30, {5});
    k.markRead(20);
    expect(c.read(khatmaProvider)!.pagesRead, 20);
    expect(c.read(khatmaProvider)!.readOn(DateTime.now()), 20);
    k.updateBusy({6});
    expect(c.read(khatmaProvider)!.busyWeekdays, {6});
    k.markRead(604);
    k.restart();
    expect(c.read(khatmaProvider)!.completedCount, 1);
    k.cancel();
    expect(c.read(khatmaProvider), isNull);
  });

  test('hifz add, review, due, remove', () {
    final h = c.read(hifzProvider.notifier);
    h.addSurah(112, 4);
    h.addSurah(112, 4);
    expect(c.read(hifzProvider).length, 1, reason: 'no duplicates');
    expect(h.due().length, 1);
    h.review(c.read(hifzProvider).single.id, 5, 0);
    expect(h.due(), isEmpty);
    h.removeSurah(112);
    expect(c.read(hifzProvider), isEmpty);
  });

  test('last read, kids stars, celebrated', () {
    c.read(lastReadProvider.notifier).set(const AyahRef(18, 10));
    expect(ProviderContainer(overrides: [storageProvider.overrideWithValue(storage)]).read(lastReadProvider), const AyahRef(18, 10));
    final kids = c.read(kidsProvider.notifier);
    kids.award(114, 2);
    kids.award(114, 1);
    kids.award(113, 3);
    expect(kids.total, 5);
    c.read(celebratedProvider.notifier).add(['first_step']);
    expect(c.read(celebratedProvider), {'first_step'});
  });

  test('encrypted backup round trip restores everything', () {
    c.read(bookmarksProvider.notifier).toggle(const AyahRef(36, 1));
    c.read(khatmaProvider.notifier).start(10, {});
    final payload = Backup.encryptJson(storage.exportAll(), 'correct horse', iterations: 1000);
    expect(payload, isNot(contains('36:1')), reason: 'contents are encrypted');
    expect(() => Backup.decryptJson(payload, 'wrong pass'), throwsA(isA<BackupException>()));
    expect(() => Backup.decryptJson('not json', 'x'), throwsA(isA<BackupException>()));
    final data = Backup.decryptJson(payload, 'correct horse');
    expect((data['user'] as Map).containsKey('bookmarks'), isTrue);
  });

  test('importAll replaces user data', () async {
    c.read(bookmarksProvider.notifier).toggle(const AyahRef(1, 1));
    final snapshot = storage.exportAll();
    c.read(bookmarksProvider.notifier).toggle(const AyahRef(1, 1));
    c.read(bookmarksProvider.notifier).toggle(const AyahRef(2, 2));
    await storage.importAll(snapshot);
    final c2 = ProviderContainer(overrides: [storageProvider.overrideWithValue(storage)]);
    expect(c2.read(bookmarksProvider).single.ref, const AyahRef(1, 1));
    c2.dispose();
  });

  test('PBKDF2 matches RFC 6070-style reference (SHA-256 vector)', () {
    // PBKDF2-HMAC-SHA256("password", "salt", 1, 32)
    final k = Backup.deriveKey('password', 'salt'.codeUnits, iterations: 1);
    expect(k.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    final k2 = Backup.deriveKey('password', 'salt'.codeUnits, iterations: 2);
    expect(k2.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
  });

  test('dayKey used by providers is stable', () {
    expect(dayKey(DateTime(2026, 12, 31)), '2026-12-31');
  });

  group('l10n', () {
    test('Arabic and English tables have the same keys', () {
      expect(L10n.keys('ar'), L10n.keys('en'));
    });

    test('every key used in lib/ exists', () {
      final used = <String>{};
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        used.addAll(RegExp(r"tr\('([a-zA-Z0-9_]+)'").allMatches(f.readAsStringSync()).map((m) => m.group(1)!));
      }
      expect(used.difference(L10n.keys('ar')), isEmpty);
    });

    test('lookup falls back to the key', () {
      expect(L10n.lookup('ar', 'nav_home'), 'الرئيسية');
      expect(L10n.lookup('xx', 'nav_home'), 'Home');
      expect(L10n.lookup('ar', 'missing_key'), 'missing_key');
    });
  });
}
