import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// What the recitation check needs from a speech recogniser, so tests can
/// swap in a fake and the plugin stays out of the domain code.
abstract class SpeechEngine {
  /// Asks for the microphone and prepares the recogniser. False when
  /// permission is refused or the device has no recogniser.
  Future<bool> init({required void Function(String error) onError, required void Function() onDone});

  /// True when the device offers an Arabic recogniser.
  Future<bool> hasArabic();

  Future<void> listen({required void Function(String words, bool isFinal) onResult, bool onDeviceOnly = false});
  Future<void> stop();
  Future<void> cancel();
}

class DeviceSpeech implements SpeechEngine {
  final _stt = SpeechToText();
  String? _locale;

  @override
  Future<bool> init({required void Function(String error) onError, required void Function() onDone}) async {
    try {
      return await _stt.initialize(
        onError: (e) => onError(e.errorMsg),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') onDone();
        },
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
      return false;
    }
  }

  @override
  Future<bool> hasArabic() async {
    final locales = await _stt.locales();
    final ar = locales.where((l) => l.localeId.toLowerCase().startsWith('ar')).toList();
    if (ar.isEmpty) return false;
    // Prefer Saudi Arabic: closest to classical pronunciation.
    _locale = (ar.firstWhere((l) => l.localeId.toLowerCase().replaceAll('_', '-') == 'ar-sa', orElse: () => ar.first)).localeId;
    return true;
  }

  @override
  Future<void> listen({required void Function(String words, bool isFinal) onResult, bool onDeviceOnly = false}) {
    return _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        onDevice: onDeviceOnly,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 6),
        localeId: _locale ?? 'ar-SA',
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();
}
