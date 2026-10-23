import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import '../app/providers.dart';
import '../domain/quran_models.dart';
import '../domain/reciters.dart';

@immutable
class PlaybackState {
  const PlaybackState({
    this.current,
    this.playing = false,
    this.loading = false,
    this.surah,
    this.repeatEach = 1,
    this.rangeEnd,
    this.speed = 1.0,
    this.error,
    this.stream,
  });

  final AyahRef? current;
  final bool playing;
  final bool loading;
  final int? surah;

  /// How many times each verse is played (memorisation aid).
  final int repeatEach;

  /// Optional last verse of a looped range (hifz mode).
  final int? rangeEnd;
  final double speed;
  final String? error;

  /// Title of a live stream (radio) when one is playing instead of verses.
  final String? stream;

  bool get active => current != null || stream != null;

  PlaybackState copyWith({
    AyahRef? current,
    bool? playing,
    bool? loading,
    int? surah,
    int? repeatEach,
    int? rangeEnd,
    double? speed,
    String? error,
    bool clearError = false,
    String? stream,
  }) => PlaybackState(
    current: current ?? this.current,
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    surah: surah ?? this.surah,
    repeatEach: repeatEach ?? this.repeatEach,
    rangeEnd: rangeEnd ?? this.rangeEnd,
    speed: speed ?? this.speed,
    error: clearError ? null : (error ?? this.error),
    stream: stream ?? this.stream,
  );
}

/// Verse-by-verse recitation with lock-screen controls (Media Session via
/// just_audio_background). Each verse is its own track, so the current track
/// index *is* the highlighted verse: no timing data is needed.
class AudioController extends Notifier<PlaybackState> {
  AudioPlayer? _p;
  final List<AyahRef> _queue = [];
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Created on first playback so app start-up never pays for it.
  AudioPlayer get _player => _p ??= _create();

  AudioPlayer _create() {
    final player = AudioPlayer();
    _subs.add(
      player.currentIndexStream.listen((i) {
        if (i == null || i >= _queue.length) return;
        final ref = _queue[i];
        state = state.copyWith(current: ref);
        if (ref.ayah > 0) this.ref.read(activityProvider.notifier).markAyahRead(ref);
      }),
    );
    _subs.add(
      player.playerStateStream.listen((s) {
        state = state.copyWith(
          playing: s.playing && s.processingState != ProcessingState.completed,
          loading: s.processingState == ProcessingState.loading || s.processingState == ProcessingState.buffering,
        );
      }),
    );
    _subs.add(player.errorStream.listen((e) => state = state.copyWith(error: e.message ?? 'playback')));
    return player;
  }

  @override
  PlaybackState build() {
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _p?.dispose();
    });
    return const PlaybackState();
  }

  Reciter get _reciter => reciterById(ref.read(settingsProvider).reciterId);

  /// Plays [surah] from verse [from] (to [to] when given, else to the end).
  Future<void> playSurah(int surah, {int from = 1, int? to, int? repeatEach}) async {
    final quran = await ref.read(quranProvider.future);
    final info = quran.surah(surah);
    final end = (to ?? info.ayahCount).clamp(from, info.ayahCount);
    final reps = repeatEach ?? state.repeatEach;
    final reciter = _reciter;
    final dir = await AudioDownloads.dir(reciter);

    _queue.clear();
    final sources = <AudioSource>[];
    // EveryAyah files do not include the basmala; prepend it (verse 1:1)
    // except for al-Fatiha (where it is verse 1) and at-Tawba.
    if (from == 1 && surah != 1 && surah != 9) {
      final local = File('${dir.path}/${reciter.fileName(1, 1)}');
      _queue.add(AyahRef(surah, 0));
      sources.add(
        AudioSource.uri(
          local.existsSync() ? Uri.file(local.path) : reciter.url(1, 1),
          tag: MediaItem(id: '${reciter.id}/$surah/0', title: info.nameAr, album: info.translit, artist: reciter.nameAr),
        ),
      );
    }
    for (var a = from; a <= end; a++) {
      for (var r = 0; r < reps; r++) {
        _queue.add(AyahRef(surah, a));
        final local = File('${dir.path}/${reciter.fileName(surah, a)}');
        final uri = local.existsSync() ? Uri.file(local.path) : reciter.url(surah, a);
        sources.add(
          AudioSource.uri(
            uri,
            tag: MediaItem(id: '${reciter.id}/$surah/$a/$r', title: '${info.nameAr} · $a', album: info.translit, artist: reciter.nameAr),
          ),
        );
      }
    }
    state = PlaybackState(surah: surah, rangeEnd: to, repeatEach: reps, current: AyahRef(surah, from), speed: state.speed);
    try {
      await _player.setAudioSources(sources, initialIndex: 0, preload: true);
      await _player.setSpeed(state.speed);
      unawaited(_player.play());
    } catch (e) {
      state = state.copyWith(error: e.toString(), playing: false);
    }
  }

  /// Plays a live radio stream (no verse tracking).
  Future<void> playStream(String url, String title) async {
    _queue.clear();
    state = PlaybackState(stream: title, speed: 1.0);
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(id: url, title: title, album: 'Mishkah · Radio'),
        ),
      );
      await _player.setSpeed(1.0);
      unawaited(_player.play());
    } catch (e) {
      state = state.copyWith(error: e.toString(), playing: false);
    }
  }

  Future<void> toggle() async => _player.playing ? _player.pause() : _player.play();

  Future<void> next() => _player.seekToNext();
  Future<void> previous() => _player.seekToPrevious();

  Future<void> stop() async {
    await _p?.stop();
    _queue.clear();
    state = const PlaybackState();
  }

  Future<void> setLoopRange(bool loop) => _player.setLoopMode(loop ? LoopMode.all : LoopMode.off);

  Future<void> setSpeed(double s) async {
    state = state.copyWith(speed: s);
    await _player.setSpeed(s);
  }

  void setRepeatEach(int n) => state = state.copyWith(repeatEach: n.clamp(1, 20));

  /// Jumps to [ayah] in the current queue, or starts the surah there.
  Future<void> seekToAyah(AyahRef r) async {
    final i = _queue.indexOf(r);
    if (i >= 0) {
      await _player.seek(Duration.zero, index: i);
      if (!_player.playing) unawaited(_player.play());
    } else {
      await playSurah(r.surah, from: r.ayah);
    }
  }
}

final audioProvider = NotifierProvider<AudioController, PlaybackState>(AudioController.new);

/// Offline audio: downloads every verse of a surah for a reciter.
class AudioDownloads {
  static Future<Directory> dir(Reciter r) async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/audio/${r.id}');
  }

  static Future<int> downloadedCount(Reciter r, int surah, int ayahCount) async {
    final d = await dir(r);
    if (!await d.exists()) return 0;
    var n = 0;
    for (var a = 1; a <= ayahCount; a++) {
      if (File('${d.path}/${r.fileName(surah, a)}').existsSync()) n++;
    }
    return n;
  }

  static Future<void> downloadSurah(
    Reciter r,
    int surah,
    int ayahCount, {
    void Function(double)? onProgress,
    bool Function()? cancelled,
    http.Client? client,
  }) async {
    final d = await dir(r);
    await d.create(recursive: true);
    final c = client ?? http.Client();
    try {
      for (var a = 1; a <= ayahCount; a++) {
        if (cancelled?.call() ?? false) return;
        final f = File('${d.path}/${r.fileName(surah, a)}');
        if (!f.existsSync()) {
          final res = await c.get(r.url(surah, a)).timeout(const Duration(seconds: 40));
          if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: r.url(surah, a));
          final tmp = File('${f.path}.part');
          await tmp.writeAsBytes(res.bodyBytes);
          await tmp.rename(f.path);
        }
        onProgress?.call(a / ayahCount);
      }
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<void> deleteSurah(Reciter r, int surah, int ayahCount) async {
    final d = await dir(r);
    for (var a = 1; a <= ayahCount; a++) {
      final f = File('${d.path}/${r.fileName(surah, a)}');
      if (f.existsSync()) await f.delete();
    }
  }

  /// Bytes used by downloaded recitations, per reciter id.
  static Future<Map<String, int>> usage() async {
    final base = Directory('${(await getApplicationDocumentsDirectory()).path}/audio');
    final out = <String, int>{};
    if (!await base.exists()) return out;
    await for (final e in base.list()) {
      if (e is! Directory) continue;
      var total = 0;
      await for (final f in e.list(recursive: true)) {
        if (f is File) total += await f.length();
      }
      out[e.path.split(Platform.pathSeparator).last] = total;
    }
    return out;
  }

  static Future<void> deleteReciter(String id) async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/audio/$id');
    if (await d.exists()) await d.delete(recursive: true);
  }
}
