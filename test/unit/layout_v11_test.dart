import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/core/utils/arabic.dart';
import 'package:mishkah/core/utils/hijri.dart';
import 'package:mishkah/data/azkar_repository.dart';
import 'package:mishkah/data/hadith_repository.dart';
import 'package:mishkah/data/local/storage.dart';
import 'package:mishkah/data/quran/content_repository.dart';
import 'package:mishkah/data/video_repository.dart';
import 'package:mishkah/domain/occasions.dart';
import 'package:mishkah/domain/quran_models.dart';
import 'package:mishkah/domain/sira.dart';
import 'package:mishkah/domain/user_models.dart';
import 'package:mishkah/features/radio/radio_screen.dart';
import 'package:mishkah/services/tafsir_reader.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Storage storage;
  late ProviderContainer c;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mishkah_v11_unit');
    storage = await Storage.initForTest(dir.path);
    c = ProviderContainer(overrides: [
      storageProvider.overrideWithValue(storage),
      quranProvider.overrideWith((ref) async => testQuran()),
      contentRepoProvider.overrideWithValue(ContentRepository(bundle: FileBundle())),
    ]);
  });

  tearDown(() async {
    c.dispose();
    await storage.settle();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('occasions', () {
    test('known dates map to occasions', () {
      // 1 Ramadan 1448 ≈ 9 Feb 2027 (Umm al-Qura).
      final start = nextOccasion(DateTime(2026, 12, 1), only: const {'ramadan'});
      expect(start.$1.id, 'ramadan');
      final day = DateTime(2026, 12, 1).add(Duration(days: start.$2));
      final h = HijriDate.fromGregorian(day);
      expect((h.month, h.day), (9, 1));
      expect(occasionsOn(day).map((o) => o.id), contains('ramadan'));
      expect(occasionsOn(day.add(const Duration(days: 20))).map((o) => o.id), containsAll(['ramadan', 'last_ten']));
    });

    test('white days and sunnah weekdays', () {
      expect(isWhiteDay(const HijriDate(1448, 3, 13)), isTrue);
      expect(isWhiteDay(const HijriDate(1448, 9, 14)), isFalse, reason: 'Ramadan is already fasted');
      expect(isWhiteDay(const HijriDate(1448, 3, 16)), isFalse);
      expect(isSunnahFastWeekday(DateTime(2026, 10, 19)), isTrue); // Monday
      expect(isSunnahFastWeekday(DateTime(2026, 10, 20)), isFalse);
      expect(occasions.firstWhere((o) => o.id == 'tashriq').covers(const HijriDate(1448, 12, 13)), isTrue);
      expect(occasions.first.name('en'), 'Islamic New Year');
    });
  });

  test('sira references are valid verse ranges', () {
    final q = testQuran();
    var events = 0;
    for (final s in siraSections) {
      expect(s.title('ar'), isNotEmpty);
      expect(s.subtitle('en'), isNotEmpty);
      for (final e in s.events) {
        events++;
        expect(e.title('en'), isNotEmpty);
        for (final r in e.refs) {
          final range = AyahRange.parse(r);
          expect(range.to, lessThanOrEqualTo(q.surah(range.surah).ayahCount), reason: r);
        }
      }
    }
    expect(events, greaterThan(20));
  });

  test('merged azkar join categories in order', () {
    final d = testAzkar();
    final ruqya = d.merged('ruqya', AzkarData.ruqya);
    expect(ruqya.items.length, d.byName(AzkarData.ruqyaQuran)!.items.length + d.byName(AzkarData.ruqyaSunnah)!.items.length);
    expect(ruqya.items.first.text, d.byName(AzkarData.ruqyaQuran)!.items.first.text);
    for (final n in AzkarData.inPrayer) {
      expect(d.byName(n), isNotNull, reason: n);
    }
    expect(d.byName(AzkarData.tasbihCat), isNotNull);
    expect(d.itemCount, greaterThan(250));
  });

  test('favourites and dedications persist', () {
    final f = c.read(favoritesProvider.notifier);
    f.toggle('hadith', 'nawawi:1', 'text', 'src');
    expect(f.contains('hadith', 'nawawi:1'), isTrue);
    final c2 = ProviderContainer(overrides: [storageProvider.overrideWithValue(storage)]);
    expect(c2.read(favoritesProvider).single.source, 'src');
    f.toggle('hadith', 'nawawi:1', 'text', 'src');
    expect(c.read(favoritesProvider), isEmpty);

    final d = c.read(dedicationsProvider.notifier);
    d.add('Mother', 'khatma', '');
    final id = c.read(dedicationsProvider).single.id;
    expect(Dedication.fromJson(c.read(dedicationsProvider).single.toJson()).name, 'Mother');
    d.remove(id);
    expect(c.read(dedicationsProvider), isEmpty);
    c2.dispose();
  });

  group('hadith repository', () {
    test('bundled forties load with numbers', () async {
      final repo = HadithRepository(bundle: FileBundle(), docsDir: () async => dir);
      final nawawi = await repo.collection('nawawi');
      expect(nawawi.length, greaterThanOrEqualTo(40));
      expect(nawawi.first.number, 1);
      expect(normalizeArabic(nawawi.first.ar), contains(normalizeArabic('الأعمال بالنيات')));
      expect((await repo.collection('qudsi')).length, greaterThanOrEqualTo(40));
      expect(await repo.isDownloaded('nawawi'), isTrue);
      expect(collectionInfo('bukhari').authentic, isTrue);
      expect(collectionInfo('nawawi').bundled, isTrue);
    });

    test('remote collections download, parse and delete', () async {
      final body = jsonEncode({
        'metadata': {
          'sections': {'1': 'كتاب بدء الوحي'},
        },
        'hadiths': [
          {'hadithnumber': 1, 'text': 'إنما الأعمال بالنيات', 'reference': {'book': 1, 'hadith': 1}},
          {'hadithnumber': 2, 'text': ' ', 'reference': {'book': 1, 'hadith': 2}},
        ],
      });
      Uri? asked;
      final repo = HadithRepository(
        bundle: FileBundle(),
        docsDir: () async => dir,
        client: MockClient((r) async {
          asked = r.url;
          return http.Response.bytes(utf8.encode(body), 200);
        }),
      );
      expect(await repo.isDownloaded('bukhari'), isFalse);
      await expectLater(repo.collection('bukhari'), throwsA(isA<HadithUnavailable>()));
      await repo.download('bukhari');
      expect(asked.toString(), endsWith('ara-bukhari.min.json'));
      expect(await repo.isDownloaded('bukhari'), isTrue);
      final list = await repo.collection('bukhari');
      expect(list.single.chapter, 'كتاب بدء الوحي');
      expect(list.single.id, 'bukhari:1');
      await repo.delete('bukhari');
      expect(await repo.isDownloaded('bukhari'), isFalse);
    });

    test('failed downloads throw', () async {
      final repo = HadithRepository(docsDir: () async => dir, client: MockClient((r) async => http.Response('no', 404)));
      await expectLater(repo.download('muslim'), throwsA(isA<HttpException>()));
    });
  });

  group('radio stations', () {
    test('fetches https stations and caches them', () async {
      final list = await http.runWithClient(
        () => c.read(radioStationsProvider.future),
        () => MockClient((r) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'radios': [
                  {'name': ' إذاعة أ ', 'url': 'https://a.example/live'},
                  {'name': 'insecure', 'url': 'http://b.example/live'},
                ],
              })),
              200,
            )),
      );
      expect(list.single.name, 'إذاعة أ');
      expect(storage.readList('radioCache'), hasLength(2));
    });

    test('falls back to the cache offline, errors when empty', () async {
      Future<List<RadioStation>> offline(ProviderContainer pc) =>
          http.runWithClient(() => pc.read(radioStationsProvider.future), () => MockClient((r) async => throw const SocketException('offline')));
      await expectLater(offline(c), throwsA(isA<StateError>()));
      await storage.write('radioCache', [
        {'name': 'cached', 'url': 'https://c.example/live'},
      ]);
      final c2 = ProviderContainer(overrides: [storageProvider.overrideWithValue(storage)]);
      expect((await offline(c2)).single.name, 'cached');
      c2.dispose();
    });
  });

  group('tafsir reader', () {
    final spoken = <String>[];
    var available = true;
    setUp(() {
      spoken.clear();
      available = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
        if (call.method == 'speak') spoken.add(call.arguments as String);
        if (call.method == 'isLanguageAvailable') return available;
        return 1;
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), null));

    Future<void> idle() async {
      for (var i = 0; i < 40 && c.read(tafsirReaderProvider).speaking; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    test('reads a surah verse by verse, skips and stops', () async {
      final r = c.read(tafsirReaderProvider.notifier);
      await r.start(112);
      await idle();
      expect(spoken, hasLength(4));
      expect(c.read(tafsirReaderProvider).current, const AyahRef(112, 4));
      expect(c.read(tafsirReaderProvider).speaking, isFalse);
      spoken.clear();
      await r.start(112, from: 2);
      await r.skip(1);
      await idle();
      expect(spoken, isNotEmpty);
      await r.stop();
      expect(c.read(tafsirReaderProvider).speaking, isFalse);
    });

    test('reports a missing Arabic voice', () async {
      available = false;
      await c.read(tafsirReaderProvider.notifier).start(1);
      expect(c.read(tafsirReaderProvider).unavailable, isTrue);
      expect(spoken, isEmpty);
    });
  });

  group('videos', () {
    String page(Object data) => '<html><script>var ytInitialData = ${jsonEncode(data)};</script></html>';

    test('parses classic and lockup search results', () {
      final html = page({
        'contents': [
          {
            'videoRenderer': {
              'videoId': 'abc',
              'title': {
                'runs': [
                  {'text': 'تلاوة '},
                  {'text': 'خاشعة'},
                ],
              },
              'ownerText': {
                'runs': [
                  {'text': 'قناة'},
                ],
              },
            },
          },
          {
            'videoRenderer': {'videoId': 'abc', 'title': {'simpleText': 'duplicate'}},
          },
          {
            'lockupViewModel': {
              'contentId': 'xyz',
              'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
              'metadata': {
                'lockupMetadataViewModel': {
                  'title': {'content': 'درس'},
                  'metadata': {
                    'contentMetadataViewModel': {
                      'metadataRows': [
                        {
                          'metadataParts': [
                            {'text': {'content': 'شيخ'}},
                          ],
                        },
                      ],
                    },
                  },
                },
              },
            },
          },
          {
            'lockupViewModel': {'contentId': 'pl', 'contentType': 'LOCKUP_CONTENT_TYPE_PLAYLIST'},
          },
        ],
      });
      final list = parseYoutubeSearch(html);
      expect(list.map((v) => v.youtubeId), ['abc', 'xyz']);
      expect(list.first.title, 'تلاوة خاشعة');
      expect(list.first.channel, 'قناة');
      expect(list.first.thumb, 'https://i.ytimg.com/vi/abc/hqdefault.jpg');
      expect(list.last.channel, 'شيخ');
      expect(parseYoutubeSearch('<html>no data</html>'), isEmpty);
      expect(parseYoutubeSearch('ytInitialData = {broken;</script>'), isEmpty);
    });

    test('parses MP3Quran video recitations', () {
      final list = parseMp3QuranVideos(jsonEncode({
        'videos': [
          {
            'id': 1,
            'reciter_name': 'مشاري العفاسي ',
            'videos': [
              {'id': 9, 'video_url': 'https://cdn.example/v.mp4', 'video_thumb_url': 'https://cdn.example/v.jpg'},
              {'id': 10, 'video_url': 'http://insecure/v.mp4'},
            ],
          },
        ],
      }));
      expect(list.single.title, 'مشاري العفاسي');
      expect(list.single.url, 'https://cdn.example/v.mp4');
      expect(list.single.isYoutube, isFalse);
      expect(VideoItem.fromJson(list.single.toJson()).thumb, 'https://cdn.example/v.jpg');
    });

    test('caches sections, refreshes after the ttl and falls back offline', () async {
      var now = DateTime(2026, 10, 23, 12);
      var calls = 0;
      var online = true;
      final repo = VideoRepository(
        storage,
        now: () => now,
        client: MockClient((r) async {
          calls++;
          if (!online) throw const SocketException('offline');
          return http.Response.bytes(
            utf8.encode(page({
              'videoRenderer': {'videoId': 'v$calls', 'title': {'simpleText': 'clip $calls'}},
            })),
            200,
          );
        }),
      );
      final s = videoSections.first;
      expect((await repo.section(s)).single.youtubeId, 'v1');
      expect((await repo.section(s)).single.youtubeId, 'v1', reason: 'served from cache');
      expect(calls, 1);
      now = now.add(const Duration(hours: 7));
      expect((await repo.section(s)).single.youtubeId, 'v2');
      online = false;
      expect((await repo.section(s, refresh: true)).single.youtubeId, 'v2', reason: 'stale cache when offline');
      await expectLater(repo.section(videoSections[1]), throwsA(anything));
    });

    test('MP3Quran section uses its API', () async {
      final repo = VideoRepository(
        storage,
        client: MockClient((r) async {
          expect(r.url.host, 'www.mp3quran.net');
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'videos': [
                {'reciter_name': 'r', 'video_url': 'https://x/v.mp4'},
              ],
            })),
            200,
          );
        }),
      );
      final list = await repo.section(videoSections.firstWhere((s) => s.mp3quran));
      expect(list.single.url, 'https://x/v.mp4');
      expect(videoSections.first.title('en'), 'Quran');
    });
  });
}
