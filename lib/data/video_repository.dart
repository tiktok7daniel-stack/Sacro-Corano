import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'local/storage.dart';

/// One playable clip: a YouTube video (played in the official embedded
/// player) or an MP4 recitation hosted by MP3Quran.net.
@immutable
class VideoItem {
  const VideoItem({required this.title, required this.channel, required this.thumb, this.youtubeId, this.url});

  final String title;
  final String channel;
  final String thumb;
  final String? youtubeId;
  final String? url;

  bool get isYoutube => youtubeId != null;
  String get key => youtubeId ?? url ?? title;

  Map<String, dynamic> toJson() => {'t': title, 'c': channel, 'i': thumb, if (youtubeId != null) 'y': youtubeId, if (url != null) 'u': url};
  factory VideoItem.fromJson(Map<String, dynamic> j) => VideoItem(
        title: j['t'] as String? ?? '',
        channel: j['c'] as String? ?? '',
        thumb: j['i'] as String? ?? '',
        youtubeId: j['y'] as String?,
        url: j['u'] as String?,
      );

  static String youtubeThumb(String id) => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
}

/// A shelf of clips on the videos screen.
class VideoSection {
  const VideoSection(this.id, this.titleAr, this.titleEn, {this.query, this.mp3quran = false});
  final String id;
  final String titleAr;
  final String titleEn;

  /// YouTube search terms; the results are the shelf.
  final String? query;

  /// Video recitations from the MP3Quran.net API instead of YouTube.
  final bool mp3quran;

  String title(String lang) => lang == 'ar' ? titleAr : titleEn;
}

const videoSections = <VideoSection>[
  VideoSection('quran', 'القرآن', 'Quran', query: 'تلاوة خاشعة مؤثرة القرآن الكريم'),
  VideoSection('clips', 'مقتطفات', 'Short reminders', query: 'مقطع ديني مؤثر موعظة قصيرة'),
  VideoSection('ibtihalat', 'ابتهالات وتواشيح', 'Ibtihalat & tawashih', query: 'ابتهالات النقشبندي نصر الدين طوبار'),
  VideoSection('classic', 'تلاوات نادرة', 'Rare recitations', query: 'تلاوة نادرة المنشاوي عبد الباسط مصطفى إسماعيل'),
  VideoSection('mp3quran', 'تلاوات مرئية', 'Video recitations', mp3quran: true),
  VideoSection('stories', 'قصص القرآن', 'Stories of the Quran', query: 'قصص القرآن الكريم للشيخ'),
  VideoSection('tafsir', 'تفسير وتدبّر', 'Tafsir & reflection', query: 'تدبر آية تفسير مختصر'),
];

class VideoRepository {
  VideoRepository(this._storage, {http.Client? client, DateTime Function()? now})
      : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  final Storage _storage;
  final http.Client _client;
  final DateTime Function() _now;

  static const ttl = Duration(hours: 6);
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36',
    'Accept-Language': 'ar,en;q=0.8',
    // Skip the EU consent interstitial.
    'Cookie': 'CONSENT=YES+cb; SOCS=CAI',
  };

  /// Cached for [ttl]; stale cache is used when the network fails.
  Future<List<VideoItem>> section(VideoSection s, {bool refresh = false}) async {
    final key = 'videos:${s.id}';
    final cached = _storage.readMap(key);
    final at = DateTime.tryParse(cached['at'] as String? ?? '');
    final items = [for (final e in (cached['items'] as List?) ?? const []) VideoItem.fromJson(Map<String, dynamic>.from(e as Map))];
    if (!refresh && at != null && items.isNotEmpty && _now().difference(at) < ttl) return items;
    try {
      final fresh = s.mp3quran ? await _mp3quran() : await _youtube(s.query!);
      if (fresh.isNotEmpty) {
        await _storage.write(key, {'at': _now().toIso8601String(), 'items': fresh.map((e) => e.toJson()).toList()});
        return fresh;
      }
    } catch (e) {
      if (items.isEmpty) rethrow;
    }
    if (items.isEmpty) throw StateError('no videos');
    return items;
  }

  Future<List<VideoItem>> _youtube(String query) async {
    // sp=EgIQAQ== keeps only videos (no channels, playlists or shorts shelves).
    final uri = Uri.https('www.youtube.com', '/results', {'search_query': query, 'sp': 'EgIQAQ==', 'hl': 'ar'});
    final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode}', uri);
    return compute(parseYoutubeSearch, utf8.decode(res.bodyBytes, allowMalformed: true));
  }

  Future<List<VideoItem>> _mp3quran() async {
    final uri = Uri.parse('https://www.mp3quran.net/api/v3/videos?language=ar');
    final res = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode}', uri);
    return parseMp3QuranVideos(utf8.decode(res.bodyBytes));
  }
}

/// Pulls the video results out of a YouTube search page (`ytInitialData`).
List<VideoItem> parseYoutubeSearch(String html) {
  final m = RegExp(r'ytInitialData\s*=\s*(\{.+?\})\s*;\s*</script>', dotAll: true).firstMatch(html);
  if (m == null) return const [];
  final Object? data;
  try {
    data = jsonDecode(m.group(1)!);
  } catch (_) {
    return const [];
  }
  final out = <VideoItem>[];
  final seen = <String>{};

  String text(Object? node) {
    if (node is Map) {
      if (node['simpleText'] is String) return node['simpleText'] as String;
      if (node['content'] is String) return node['content'] as String;
      final runs = node['runs'];
      if (runs is List) return runs.map((r) => (r as Map)['text'] ?? '').join();
    }
    return '';
  }

  void walk(Object? node) {
    if (node is Map) {
      final v = node['videoRenderer'];
      if (v is Map && v['videoId'] is String) {
        final id = v['videoId'] as String;
        final title = text(v['title']);
        if (title.isNotEmpty && seen.add(id)) {
          out.add(VideoItem(title: title, channel: text(v['ownerText']), thumb: VideoItem.youtubeThumb(id), youtubeId: id));
        }
        return;
      }
      final l = node['lockupViewModel'];
      if (l is Map && l['contentId'] is String && (l['contentType'] as String? ?? '').contains('VIDEO')) {
        final id = l['contentId'] as String;
        final meta = (l['metadata'] as Map?)?['lockupMetadataViewModel'] as Map?;
        final title = text(meta?['title']);
        if (title.isNotEmpty && seen.add(id)) {
          final rows = (((meta?['metadata'] as Map?)?['contentMetadataViewModel'] as Map?)?['metadataRows'] as List?) ?? const [];
          final parts = rows.isEmpty ? const [] : (((rows.first as Map)['metadataParts'] as List?) ?? const []);
          final channel = parts.isEmpty ? '' : text((parts.first as Map)['text']);
          out.add(VideoItem(title: title, channel: channel, thumb: VideoItem.youtubeThumb(id), youtubeId: id));
        }
        return;
      }
      node.values.forEach(walk);
    } else if (node is List) {
      node.forEach(walk);
    }
  }

  walk(data);
  return out;
}

/// MP3Quran.net `/api/v3/videos`: reciters, each with MP4 clips.
List<VideoItem> parseMp3QuranVideos(String body) {
  final out = <VideoItem>[];
  void walk(Object? node, String reciter) {
    if (node is Map) {
      final name = (node['reciter_name'] ?? node['name']) is String ? (node['reciter_name'] ?? node['name']) as String : reciter;
      final url = node['video_url'];
      if (url is String && url.startsWith('https')) {
        out.add(VideoItem(title: name.trim(), channel: 'MP3Quran.net', thumb: node['video_thumb_url'] as String? ?? '', url: url));
        return;
      }
      for (final v in node.values) {
        walk(v, name);
      }
    } else if (node is List) {
      for (final v in node) {
        walk(v, reciter);
      }
    }
  }

  walk(jsonDecode(body), '');
  return out;
}
