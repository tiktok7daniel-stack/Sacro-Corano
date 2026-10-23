import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../app/providers.dart';
import '../domain/quran_models.dart';

@immutable
class TafsirReadingState {
  const TafsirReadingState({this.current, this.speaking = false, this.unavailable = false});
  final AyahRef? current;
  final bool speaking;

  /// No Arabic voice on the device.
  final bool unavailable;
}

/// "Audio tafsir": reads Tafsir al-Muyassar aloud with the device's
/// text-to-speech engine, verse after verse. No recordings are needed, so it
/// works offline wherever an Arabic voice is installed (Google TTS has one).
class TafsirReader extends Notifier<TafsirReadingState> {
  FlutterTts? _tts;
  int _surah = 1;
  int _ayah = 1;
  int _last = 1;
  bool _stopped = true;

  @override
  TafsirReadingState build() {
    ref.onDispose(() {
      _stopped = true;
      _tts?.stop().catchError((Object _) => null);
    });
    return const TafsirReadingState();
  }

  Future<FlutterTts> _engine() async {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = FlutterTts();
    await tts.awaitSpeakCompletion(true);
    final ok = await tts.isLanguageAvailable('ar');
    if (ok != true) {
      state = const TafsirReadingState(unavailable: true);
    }
    await tts.setLanguage('ar');
    await tts.setSpeechRate(0.45);
    return _tts = tts;
  }

  Future<void> start(int surah, {int from = 1}) async {
    final quran = await ref.read(quranProvider.future);
    _surah = surah;
    _ayah = from;
    _last = quran.surah(surah).ayahCount;
    _stopped = false;
    final tts = await _engine();
    if (state.unavailable) return;
    unawaited(_loop(tts));
  }

  Future<void> _loop(FlutterTts tts) async {
    final repo = ref.read(contentRepoProvider);
    while (!_stopped && _ayah <= _last) {
      final r = AyahRef(_surah, _ayah);
      state = TafsirReadingState(current: r, speaking: true);
      final text = await repo.tafsir('muyassar', _surah, _ayah);
      if (_stopped) break;
      await tts.speak(text);
      if (_stopped) break;
      _ayah++;
    }
    state = TafsirReadingState(current: state.current, speaking: false);
  }

  Future<void> stop() async {
    _stopped = true;
    await _tts?.stop();
    state = TafsirReadingState(current: state.current, speaking: false);
  }

  Future<void> skip(int delta) async {
    final next = (_ayah + delta).clamp(1, _last);
    await stop();
    await start(_surah, from: next);
  }
}

final tafsirReaderProvider = NotifierProvider<TafsirReader, TafsirReadingState>(TafsirReader.new);
