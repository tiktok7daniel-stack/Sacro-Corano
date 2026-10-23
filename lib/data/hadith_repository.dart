import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

@immutable
class Hadith {
  const Hadith({required this.collection, required this.number, required this.ar, this.en = '', this.chapter});
  final String collection;
  final int number;
  final String ar;
  final String en;
  final String? chapter;

  String get id => '$collection:$number';
}

@immutable
class HadithCollectionInfo {
  const HadithCollectionInfo(this.id, this.nameAr, this.nameEn, {this.remote, this.approxMb = 0, this.authentic = false});
  final String id;
  final String nameAr;
  final String nameEn;

  /// Edition in fawazahmed0/hadith-api to download; null = bundled.
  final String? remote;
  final int approxMb;

  /// Collections whose hadiths are all graded sahih by consensus.
  final bool authentic;

  bool get bundled => remote == null;
  String name(String lang) => lang == 'ar' ? nameAr : nameEn;
}

const hadithCollections = [
  HadithCollectionInfo('nawawi', 'الأربعون النووية', "An-Nawawi's Forty"),
  HadithCollectionInfo('qudsi', 'الأحاديث القدسية', 'Forty Hadith Qudsi'),
  HadithCollectionInfo('bukhari', 'صحيح البخاري', 'Sahih al-Bukhari', remote: 'ara-bukhari', approxMb: 9, authentic: true),
  HadithCollectionInfo('muslim', 'صحيح مسلم', 'Sahih Muslim', remote: 'ara-muslim', approxMb: 8, authentic: true),
];

HadithCollectionInfo collectionInfo(String id) => hadithCollections.firstWhere((c) => c.id == id);

class HadithUnavailable implements Exception {
  const HadithUnavailable();
}

/// Hadith from github.com/fawazahmed0/hadith-api (public domain).
/// The two forties ship with the app; Bukhari and Muslim download once.
class HadithRepository {
  HadithRepository({AssetBundle? bundle, http.Client? client, Future<Directory> Function()? docsDir})
    : _bundle = bundle ?? rootBundle,
      _client = client ?? http.Client(),
      _docsDir = docsDir ?? getApplicationDocumentsDirectory;

  final AssetBundle _bundle;
  final http.Client _client;
  final Future<Directory> Function() _docsDir;
  final Map<String, List<Hadith>> _cache = {};

  static const _cdn = 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions';

  Future<List<Hadith>> collection(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;
    final info = collectionInfo(id);
    if (info.bundled) {
      final bytes = (await _bundle.load('assets/data/hadith.json.gz')).buffer.asUint8List();
      final all = await compute(_parseBundled, bytes);
      _cache.addAll(all);
      return _cache[id]!;
    }
    final file = await _file(info);
    if (!await file.exists()) throw const HadithUnavailable();
    return _cache[id] = await compute(_parseRemote, (id, await file.readAsString()));
  }

  Future<bool> isDownloaded(String id) async {
    final info = collectionInfo(id);
    if (info.bundled) return true;
    return (await _file(info)).exists();
  }

  Future<void> download(String id) async {
    final info = collectionInfo(id);
    if (info.bundled) return;
    final res = await _client.get(Uri.parse('$_cdn/${info.remote}.min.json')).timeout(const Duration(minutes: 3));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
    final file = await _file(info);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(res.bodyBytes);
    _cache.remove(id);
  }

  Future<void> delete(String id) async {
    final info = collectionInfo(id);
    if (info.bundled) return;
    final f = await _file(info);
    if (await f.exists()) await f.delete();
    _cache.remove(id);
  }

  Future<File> _file(HadithCollectionInfo info) async => File('${(await _docsDir()).path}/hadith/${info.remote}.json');

  static Map<String, List<Hadith>> _parseBundled(Uint8List bytes) {
    final j = jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
    return {
      for (final c in (j['collections'] as List).cast<Map<String, dynamic>>())
        c['id'] as String: [
          for (final h in (c['items'] as List).cast<Map<String, dynamic>>())
            Hadith(collection: c['id'] as String, number: h['n'] as int, ar: h['ar'] as String, en: h['en'] as String? ?? ''),
        ],
    };
  }

  static List<Hadith> _parseRemote((String, String) input) {
    final j = jsonDecode(input.$2) as Map<String, dynamic>;
    final sections = ((j['metadata'] as Map)['sections'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
    return [
      for (final h in (j['hadiths'] as List).cast<Map<String, dynamic>>())
        if ((h['text'] as String).trim().isNotEmpty)
          Hadith(
            collection: input.$1,
            number: (h['hadithnumber'] as num).toInt(),
            ar: (h['text'] as String).trim(),
            chapter: sections['${(h['reference'] as Map?)?['book'] ?? ''}'],
          ),
    ];
  }
}
