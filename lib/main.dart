import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/local/storage.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final storage = await Storage.init();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'app.mishkah.audio',
      androidNotificationChannelName: 'Quran recitation',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_stat_mishkah',
    );
  } catch (e) {
    debugPrint('Background audio unavailable: $e');
  }
  // Notifications initialise lazily but timezone data must exist early.
  await Notifications.instance.initTimezones();

  runApp(ProviderScope(
    overrides: [storageProvider.overrideWithValue(storage)],
    child: const MishkahApp(),
  ));
}
