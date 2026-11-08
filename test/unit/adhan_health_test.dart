import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishkah/services/notifications.dart';

import '../fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every notification resource named in code is kept from the release shrinker', () {
    // A resource used only by name from Dart is removed from release builds
    // unless keep.xml lists it; a missing icon silently kills every alert.
    final keep = File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
    final code = File('lib/services/notifications.dart').readAsStringSync();
    final icons = RegExp(r"AndroidInitializationSettings\('([a-z0-9_]+)'\)").allMatches(code).map((m) => m.group(1)!);
    final sounds = {'full', 'short'}.map((k) => 'mishkah_adhan_$k');
    expect(icons, contains('ic_stat_mishkah'));
    for (final i in icons) {
      expect(keep, contains('@drawable/$i'), reason: i);
      expect(File('android/app/src/main/res/drawable-hdpi/$i.png').existsSync(), isTrue, reason: i);
    }
    for (final s in sounds) {
      expect(keep, contains('@raw/$s'), reason: s);
      expect(File('android/app/src/main/res/raw/$s.ogg').existsSync(), isTrue, reason: s);
    }
  });

  test('health reports permissions and scheduled adhans; a missing icon falls back to the launcher icon', () async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    var inits = 0;
    final rec = ChannelRecorder('dexterous.com/flutter/local_notifications', reply: (c) {
      switch (c.method) {
        case 'initialize':
          inits++;
          if (inits == 1) throw PlatformException(code: 'invalid_icon', message: 'The resource ic_stat_mishkah could not be found');
          return true;
        case 'areNotificationsEnabled':
          return false;
        case 'canScheduleExactNotifications':
          return true;
        case 'pendingNotificationRequests':
          return [
            {'id': 1000, 'title': 'fajr', 'body': '', 'payload': null},
            {'id': 1001, 'title': 'dhuhr', 'body': '', 'payload': null},
            {'id': 5000, 'title': 'reminder', 'body': '', 'payload': null},
          ];
      }
      return null;
    });
    addTearDown(rec.dispose);
    final h = await Notifications.instance.health();
    expect(inits, 2, reason: 'retried with the launcher icon');
    expect((rec.named('initialize').last.arguments as Map)['defaultIcon'], '@mipmap/ic_launcher');
    expect(h.enabled, isFalse);
    expect(h.exact, isTrue);
    expect(h.pendingAdhans, 2);
    expect(h.ok, isFalse);
    expect(const NotificationHealth(enabled: true, exact: true, pendingAdhans: 3).ok, isTrue);
  });
}
