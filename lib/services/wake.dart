import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on (mosque mode, focused listening). Failures are
/// harmless: the screen simply follows the system timeout.
Future<void> keepScreenOn(bool on) async {
  try {
    on ? await WakelockPlus.enable() : await WakelockPlus.disable();
  } catch (e) {
    debugPrint('Wakelock unavailable: $e');
  }
}
