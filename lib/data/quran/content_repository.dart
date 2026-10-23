import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../domain/quran_models.dart';

/// Metadata for a translation or tafsir edition.
@immutable
class Edition {
  const Edition({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.lang,
    this.asset,
    this.remoteSlug,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String lang;

  /// Bundled gzip asset (available offline from first launch).
  final String? asset;

  /// Slug in github.com/spa5k/tafsir_api (downloaded on demand, MIT).
  final String? remoteSlug;

  bool get bundled => asset != null;
  String name(String uiLang) => uiLang == 'ar' ? nameAr : nameEn;
}

abstract final class Editions {
  static const translations = [
    Edition(id: 'en_sahih', nameAr: 'الإنجليزية – صحيح إنترناشونال', nameEn: 'English – Saheeh International', lang: 'en', asset: 'assets/data/tr_en_sahih.json.gz'),
    Edition(id: 'it_piccardo', nameAr: 'الإيطالية – بيكاردو', nameEn: 'Italiano – H. R. Piccardo', lang: 'it', asset: 'assets/data/tr_it_piccardo.json.gz'),
    Edition(id: 'fr_hamidullah', nameAr: 'الفرنسية – حميد الله', nameEn: 'Français – Hamidullah', lang: 'fr', asset: 'assets/data/tr_fr_hamidullah.json.gz'),
  ];

  /// Tafsir al-Muyassar ships with the app; the classical works are large
  /// (Ibn Kathir alone is ~25 MB) so they are downloaded per surah and cached.
  static const tafsirs = [
    Edition(id: 'muyassar', nameAr: 'التفسير الميسر', nameEn: 'Al-Muyassar', lang: 'ar', asset: 'assets/data/tafsir_muyassar.json.gz'),
    Edition(id: 'mukhtasar', nameAr: 'المختصر في التفسير', nameEn: 'Al-Mukhtasar', lang: 'ar', remoteSlug: 'ar-tafsir-al-mukhtasar'),
    Edition(id: 'saadi', nameAr: 'تفسير السعدي', nameEn: 'As-Saʿdi', lang: 'ar', remoteSlug: 'ar-tafseer-al-saddi'),
    Edition(id: 'ibn_kathir', nameAr: 'تفسير ابن كثير', nameEn: 'Ibn Kathir', lang: 'ar', remoteSlug: 'ar-tafsir-ibn-kathir'),
    Edition(id: 'tabari', nameAr: 'تفسير الطبري', nameEn: 'At-Tabari', lang: 'ar', remoteSlug: 'ar-tafsir-al-tabari'),
    Edition(id: 'qurtubi', nameAr: 'تفسير القرطبي', nameEn: 'Al-Qurtubi', lang: 'ar', remoteSlug: 'ar-tafseer-al-qurtubi'),
    Edition(id: 'baghawi', nameAr: 'تفسير البغوي', nameEn: 'Al-Baghawi', lang: 'ar', remoteSlug: 'ar-tafsir-al-baghawi'),
    Edition(id: 'wasit', nameAr: 'التفسير الوسيط', nameEn: 'Al-Wasit', lang: 'ar', remoteSlug: 'ar-tafsir-al-wasit'),
    Edition(id: 'gharib', nameAr: 'السراج في بيان غريب القرآن', nameEn: 'Gharib al-Quran (word meanings)', lang: 'ar', remoteSlug: 'asseraj-fi-bayan-gharib-alquran'),
    Edition(id: 'en_ibn_kathir', nameAr: 'ابن كثير (إنجليزي مختصر)', nameEn: 'Ibn Kathir (English, abridged)', lang: 'en', remoteSlug: 'en-tafisr-ibn-kathir'),
    Edition(id: 'en_asbab', nameAr: 'أسباب النزول للواحدي (إنجليزي)', nameEn: 'Asbab al-Nuzul – al-Wahidi', lang: 'en', remoteSlug: 'en-asbab-al-nuzul-by-al-wahidi'),
    Edition(id: 'it_mukhtasar', nameAr: 'المختصر (إيطالي)', nameEn: 'Al-Mukhtasar (Italiano)', lang: 'it', remoteSlug: 'italian-mokhtasar'),
  ];

  static Edition translation(String id) => translations.firstWhere((e) => e.id == id, orElse: () => translations.first);
  static Edition tafsir(String id) => tafsirs.firstWhere((e) => e.id == id, orElse: () => tafsirs.first);
}

class TafsirUnavailable implements Exception {
  const TafsirUnavailable(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

/// Loads translations and tafsir; caches downloaded tafsir as JSON files.
class ContentRepository {
  ContentRepository({AssetBundle? bundle, http.Client? client, Future<Directory> Function()? docsDir})
      : _bundle = bundle ?? rootBundle,
        _client = client ?? http.Client(),
        _docsDir = docsDir ?? getApplicationDocumentsDirectory;

  final AssetBundle _bundle;
  final http.Client _client;
  final Future<Directory> Function() _docsDir;

  final Map<String, Translation> _translations = {};
  final Map<String, List<List<String>>> _bundledTafsir = {};
  List<String>? _intros;
  final Map<String, List<String>> _remoteTafsirCache = {};

  static const _cdn = 'https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir';

  Future<Translation> translation(String id) async {
    final cached = _translations[id];
    if (cached != null) return cached;
    final ed = Editions.translation(id);
    final data = await _loadGz(ed.asset!);
    final t = Translation(
      id: ed.id,
      name: data['name'] as String,
      lang: data['lang'] as String,
      source: data['source'] as String,
      ayahs: (data['ayahs'] as List).map((s) => (s as List).cast<String>()).toList(),
    );
    return _translations[id] = t;
  }

  /// Tafsir text for one verse. Throws [TafsirUnavailable] when a remote
  /// edition is not downloaded and the device is offline.
  Future<String> tafsir(String id, int surah, int ayah) async {
    final ed = Editions.tafsir(id);
    if (ed.bundled) {
      final all = _bundledTafsir[id] ?? await _loadBundledTafsir(ed);
      return all[surah - 1][ayah - 1];
    }
    final list = await _remoteSurah(ed, surah);
    return ayah - 1 < list.length ? list[ayah - 1] : '';
  }

  Future<List<List<String>>> _loadBundledTafsir(Edition ed) async {
    final data = await _loadGz(ed.asset!);
    final intros = data['intros'];
    if (intros is List) _intros = intros.cast<String>();
    return _bundledTafsir[ed.id] = (data['ayahs'] as List).map((s) => (s as List).cast<String>()).toList();
  }

  /// Surah introduction (name and aims) shipped with the Muyassar dataset.
  Future<String> surahIntro(int surah) async {
    if (_intros == null) await _loadBundledTafsir(Editions.tafsirs.first);
    return _intros?[surah - 1] ?? '';
  }

  Future<bool> isSurahDownloaded(String id, int surah) async {
    final ed = Editions.tafsir(id);
    if (ed.bundled) return true;
    return (await _file(ed, surah)).exists();
  }

  /// Downloads every surah of a remote edition; reports progress 0..1.
  Future<void> downloadAll(String id, {void Function(double)? onProgress}) async {
    final ed = Editions.tafsir(id);
    if (ed.bundled) return;
    for (var s = 1; s <= 114; s++) {
      await _remoteSurah(ed, s);
      onProgress?.call(s / 114);
    }
  }

  Future<void> deleteEdition(String id) async {
    final ed = Editions.tafsir(id);
    if (ed.bundled) return;
    final dir = Directory('${(await _docsDir()).path}/tafsir/${ed.remoteSlug}');
    if (await dir.exists()) await dir.delete(recursive: true);
    _remoteTafsirCache.removeWhere((k, _) => k.startsWith('${ed.id}/'));
  }

  Future<int> downloadedSurahCount(String id) async {
    final ed = Editions.tafsir(id);
    if (ed.bundled) return 114;
    final dir = Directory('${(await _docsDir()).path}/tafsir/${ed.remoteSlug}');
    if (!await dir.exists()) return 0;
    return dir.list().where((f) => f.path.endsWith('.json')).length;
  }

  Future<List<String>> _remoteSurah(Edition ed, int surah) async {
    final key = '${ed.id}/$surah';
    final mem = _remoteTafsirCache[key];
    if (mem != null) return mem;
    final file = await _file(ed, surah);
    String body;
    if (await file.exists()) {
      body = await file.readAsString();
    } else {
      final uri = Uri.parse('$_cdn/${ed.remoteSlug}/$surah.json');
      http.Response res;
      try {
        res = await _client.get(uri).timeout(const Duration(seconds: 25));
      } catch (_) {
        throw const TafsirUnavailable('offline');
      }
      if (res.statusCode != 200) throw TafsirUnavailable('http ${res.statusCode}');
      body = utf8.decode(res.bodyBytes);
      await file.parent.create(recursive: true);
      await file.writeAsString(body);
    }
    final rows = (jsonDecode(body) as List).cast<Map<String, dynamic>>();
    final maxAyah = rows.fold<int>(0, (m, r) => (r['ayah'] as int) > m ? r['ayah'] as int : m);
    final out = List<String>.filled(maxAyah, '');
    for (final r in rows) {
      out[(r['ayah'] as int) - 1] = (r['text'] as String).trim();
    }
    return _remoteTafsirCache[key] = out;
  }

  Future<File> _file(Edition ed, int surah) async =>
      File('${(await _docsDir()).path}/tafsir/${ed.remoteSlug}/$surah.json');

  Future<Map<String, dynamic>> _loadGz(String asset) async {
    final bytes = (await _bundle.load(asset)).buffer.asUint8List();
    return compute(_decodeGz, bytes);
  }

  static Map<String, dynamic> _decodeGz(Uint8List bytes) =>
      jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
}
