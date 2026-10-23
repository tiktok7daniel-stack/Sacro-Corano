import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mishkah/core/utils/arabic.dart';
import 'package:mishkah/data/azkar_repository.dart';
import 'package:mishkah/data/quran/content_repository.dart';
import 'package:mishkah/data/quran/quran_data.dart';
import 'package:mishkah/domain/daily_content.dart';
import 'package:mishkah/domain/prophets.dart';
import 'package:mishkah/domain/quran_models.dart';
import 'package:mishkah/domain/search_engine.dart';

late QuranData quran;

QuranData loadQuran() => QuranData.fromRaw(
      File('assets/data/meta.json').readAsStringSync(),
      File('assets/data/quran_uthmani.json.gz').readAsBytesSync(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => quran = loadQuran());

  group('QuranData integrity', () {
    test('114 surahs, 6236 verses, 604 pages', () {
      expect(quran.surahs.length, 114);
      expect(quran.surahs.fold<int>(0, (s, x) => s + x.ayahCount), 6236);
      expect(quran.surah(2).ayahCount, 286);
      expect(quran.surah(2).nameAr, 'البقرة');
      expect(quran.surah(114).startIndex + quran.surah(114).ayahCount - 1, 6236);
    });

    test('verse text', () {
      expect(normalizeArabic(quran.text(1, 1)), 'بسم الله الرحمن الرحيم');
      expect(normalizeArabic(quran.text(112, 1)), 'قل هو الله احد');
    });

    test('Madani page / juz / hizb boundaries', () {
      expect(quran.pageOf(1, 1), 1);
      expect(quran.pageOf(2, 1), 2);
      expect(quran.pageOf(2, 255), 42);
      expect(quran.pageOf(18, 1), 293);
      expect(quran.pageOf(36, 1), 440);
      expect(quran.pageOf(67, 1), 562);
      expect(quran.pageOf(114, 6), 604);
      expect(quran.juzOf(2, 141), 1);
      expect(quran.juzOf(2, 142), 2);
      expect(quran.juzOf(78, 1), 30);
      expect(quran.hizbOf(1, 1), 1);
      expect(quran.hizbOf(114, 6), 60);
      expect(quran.startsRub(2, 26), isTrue);
    });

    test('pages cover every verse exactly once', () {
      var count = 0;
      AyahRef? prev;
      for (var p = 1; p <= QuranData.totalPages; p++) {
        for (final r in quran.ayahsOnPage(p)) {
          if (prev != null) expect(quran.absoluteIndex(r.surah, r.ayah), quran.absoluteIndex(prev.surah, prev.ayah) + 1);
          prev = r;
          count++;
        }
      }
      expect(count, 6236);
      expect(quran.ayahsOnPage(1).length, 7);
    });

    test('refAt / absoluteIndex round trip', () {
      for (final i in [1, 7, 8, 293, 2000, 6236]) {
        final r = quran.refAt(i);
        expect(quran.absoluteIndex(r.surah, r.ayah), i);
      }
      expect(quran.countBetween(const AyahRef(1, 1), const AyahRef(2, 1)), 8);
    });

    test('15 sajda verses including 96:19', () {
      var n = 0;
      for (final s in quran.surahs) {
        for (var a = 1; a <= s.ayahCount; a++) {
          if (quran.isSajda(s.number, a)) n++;
        }
      }
      expect(n, 15);
      expect(quran.isSajda(96, 19), isTrue);
    });

    test('juz starts', () {
      expect(quran.juzStart(1), const AyahRef(1, 1));
      expect(quran.juzStart(30), const AyahRef(78, 1));
      expect(quran.rubStart(240).surah, greaterThanOrEqualTo(100));
    });
  });

  group('Curated references point at real verses', () {
    void check(String ref) {
      final r = AyahRange.parse(ref);
      expect(r.surah, inInclusiveRange(1, 114), reason: ref);
      final max = quran.surah(r.surah).ayahCount;
      expect(r.from, inInclusiveRange(1, max), reason: ref);
      if (r.to != -1) expect(r.to, inInclusiveRange(r.from, max), reason: ref);
    }

    test('prophets', () {
      expect(prophets.length, 25);
      for (final p in prophets) {
        for (final ref in p.passages) {
          check(ref);
        }
      }
      expect(prophets.where((p) => p.ululAzm).length, 5);
    });

    test('moods and daily content', () {
      for (final m in moods) {
        m.refs.forEach(check);
      }
      quranicDuas.forEach(check);
      for (var i = 0; i < 60; i++) {
        final v = verseOfTheDay(DateTime(2026, 1, 1).add(Duration(days: i)));
        check(v.toString());
        final d = duaOfTheDay(DateTime(2026, 1, 1).add(Duration(days: i)));
        check(d.toString());
      }
      expect(dailyIndex(DateTime(2026), 10), inInclusiveRange(0, 9));
    });

    test('Yusuf story starts with the dream (12:4)', () {
      expect(normalizeArabic(quran.text(12, 4)), contains('يوسف'));
    });
  });

  group('SearchEngine', () {
    late SearchEngine engine;
    late Translation en;

    setUpAll(() async {
      final index = QuranData.buildSearchIndex(quran.rawText);
      engine = SearchEngine(
        refs: [for (final s in quran.surahs) for (var a = 1; a <= s.ayahCount; a++) AyahRef(s.number, a)],
        arabicIndex: index,
        isMeccan: (n) => quran.surah(n).meccan,
        juzOf: (r) => quran.juzOf(r.surah, r.ayah),
      );
      en = await ContentRepository(bundle: _FileBundle()).translation('en_sahih');
    });

    test('everyday spelling finds Uthmani text', () {
      final hits = engine.search('الصراط المستقيم', mode: SearchMode.phrase);
      expect(hits.map((h) => h.ref), contains(const AyahRef(1, 6)));
      final r = engine.search('الرحمن الرحيم');
      expect(r.map((h) => h.ref), containsAll([const AyahRef(1, 1), const AyahRef(1, 3)]));
    });

    test('filters', () {
      final all = engine.search('الله');
      final juz30 = engine.search('الله', filter: const SearchFilter(juz: 30));
      expect(juz30.length, lessThan(all.length));
      expect(juz30.every((h) => quran.juzOf(h.ref.surah, h.ref.ayah) == 30), isTrue);
      final medinan = engine.search('الله', filter: const SearchFilter(revelation: false));
      expect(medinan.every((h) => !quran.surah(h.ref.surah).meccan), isTrue);
      final one = engine.search('الله', filter: const SearchFilter(fromSurah: 112, toSurah: 112));
      expect(one.every((h) => h.ref.surah == 112), isTrue);
    });

    test('any-word vs all-words', () {
      final all = engine.search('موسى فرعون', mode: SearchMode.allWords);
      final any = engine.search('موسى فرعون', mode: SearchMode.anyWord);
      expect(any.length, greaterThan(all.length));
    });

    test('translation search', () {
      final hits = engine.search('Lord of the worlds', translation: en, scope: SearchScope.translation);
      expect(hits.map((h) => h.ref), contains(const AyahRef(1, 2)));
      expect(engine.search('   '), isEmpty);
    });
  });

  group('ContentRepository', () {
    test('bundled translations align with the mushaf', () async {
      final repo = ContentRepository(bundle: _FileBundle());
      for (final e in Editions.translations) {
        final t = await repo.translation(e.id);
        expect(t.ayahs.length, 114, reason: e.id);
        for (final s in quran.surahs) {
          expect(t.ayahs[s.number - 1].length, s.ayahCount, reason: '${e.id} ${s.number}');
        }
      }
    });

    test('Muyassar is bundled, has intros and no leftover markers', () async {
      final repo = ContentRepository(bundle: _FileBundle());
      final t = await repo.tafsir('muyassar', 2, 255);
      expect(t, isNotEmpty);
      expect(await repo.tafsir('muyassar', 1, 1), isNot(contains('[التفسير]')));
      expect(await repo.surahIntro(2), contains('البقرة'));
      expect(await repo.isSurahDownloaded('muyassar', 5), isTrue);
    });

    test('remote tafsir is downloaded once then cached', () async {
      final dir = await Directory.systemTemp.createTemp('mishkah');
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        expect(req.url.toString(), contains('ar-tafsir-ibn-kathir/1.json'));
        return http.Response.bytes(
          utf8.encode(jsonEncode([
            {'text': 'تفسير الآية الأولى', 'ayah': 1, 'surah': 1},
            {'text': 'تفسير الآية الثانية', 'ayah': 2, 'surah': 1},
          ])),
          200,
        );
      });
      final repo = ContentRepository(bundle: _FileBundle(), client: client, docsDir: () async => dir);
      expect(await repo.tafsir('ibn_kathir', 1, 2), 'تفسير الآية الثانية');
      final repo2 = ContentRepository(bundle: _FileBundle(), client: client, docsDir: () async => dir);
      expect(await repo2.tafsir('ibn_kathir', 1, 1), 'تفسير الآية الأولى');
      expect(calls, 1);
      expect(await repo2.isSurahDownloaded('ibn_kathir', 1), isTrue);
      expect(await repo2.downloadedSurahCount('ibn_kathir'), 1);
      await repo2.deleteEdition('ibn_kathir');
      expect(await repo2.downloadedSurahCount('ibn_kathir'), 0);
      await dir.delete(recursive: true);
    });

    test('offline remote tafsir throws TafsirUnavailable', () async {
      final dir = await Directory.systemTemp.createTemp('mishkah');
      final client = MockClient((_) async => throw const SocketException('offline'));
      final repo = ContentRepository(bundle: _FileBundle(), client: client, docsDir: () async => dir);
      expect(() => repo.tafsir('saadi', 1, 1), throwsA(isA<TafsirUnavailable>()));
      final repo404 = ContentRepository(bundle: _FileBundle(), client: MockClient((_) async => http.Response('', 404)), docsDir: () async => dir);
      expect(() => repo404.tafsir('saadi', 1, 1), throwsA(isA<TafsirUnavailable>()));
    });

    test('edition lookup', () {
      expect(Editions.tafsir('nope').id, 'muyassar');
      expect(Editions.translation('it_piccardo').lang, 'it');
      expect(Editions.tafsirs.where((e) => e.bundled).length, 1);
    });
  });

  group('Azkar', () {
    test('Hisn al-Muslim parses with core categories', () {
      final data = AzkarData.parse(File('assets/data/azkar.json.gz').readAsBytesSync());
      expect(data.categories.length, greaterThan(100));
      for (final name in [AzkarData.morning, AzkarData.evening, AzkarData.sleep, AzkarData.afterPrayer, AzkarData.distress]) {
        expect(data.byName(name), isNotNull, reason: name);
        expect(data.byName(name)!.items, isNotEmpty);
      }
      expect(data.byName('does not exist'), isNull);
      expect(data.categories.expand((c) => c.items).every((z) => z.count >= 1 && z.text.isNotEmpty), isTrue);
    });
  });
}

/// Serves assets straight from the repository for pure unit tests.
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(File(key).readAsBytesSync());
}
