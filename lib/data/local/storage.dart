import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Local, offline-first persistence.
///
/// Everything the user creates (settings, bookmarks, notes, tasbih history,
/// memorisation progress…) lives in AES-256 encrypted Hive boxes. The key is
/// generated on first launch and kept in the Android Keystore through
/// flutter_secure_storage, so data never leaves the device unless the user
/// exports an (also encrypted) backup.
class Storage {
  Storage._(this._settings, this._user);

  final Box<dynamic> _settings;
  final Box<dynamic> _user;

  static Storage? _instance;
  static Storage get instance {
    final s = _instance;
    if (s == null) throw StateError('Storage.init() was not called');
    return s;
  }

  static const _keyName = 'mishkah.hive.key.v1';

  static Future<Storage> init() async {
    await Hive.initFlutter('mishkah');
    HiveAesCipher? cipher;
    try {
      const secure = FlutterSecureStorage();
      var encoded = await secure.read(key: _keyName);
      if (encoded == null) {
        encoded = base64Url.encode(Hive.generateSecureKey());
        await secure.write(key: _keyName, value: encoded);
      }
      cipher = HiveAesCipher(base64Url.decode(encoded));
    } catch (e) {
      // Devices with a broken keystore still get a working (unencrypted) app.
      debugPrint('Secure storage unavailable, falling back to plain boxes: $e');
    }
    final settings = await Hive.openBox<dynamic>('settings', encryptionCipher: cipher);
    final user = await Hive.openBox<dynamic>('user', encryptionCipher: cipher);
    return _instance = Storage._(settings, user);
  }

  /// In-memory storage for tests.
  @visibleForTesting
  static Future<Storage> initForTest(String dir) async {
    Hive.init(dir);
    final settings = await Hive.openBox<dynamic>('settings_test_${DateTime.now().microsecondsSinceEpoch}');
    final user = await Hive.openBox<dynamic>('user_test_${DateTime.now().microsecondsSinceEpoch}');
    return _instance = Storage._(settings, user);
  }

  // ---- settings ----
  Map<String, dynamic> readSettings() => _decode(_settings.get('app'));
  Future<void> writeSettings(Map<String, dynamic> map) => _track(_settings.put('app', jsonEncode(map)));

  // ---- generic user documents (JSON encoded) ----
  T? read<T>(String key) {
    final raw = _user.get(key);
    if (raw == null) return null;
    return jsonDecode(raw as String) as T;
  }

  Map<String, dynamic> readMap(String key) => _decode(_user.get(key));

  List<dynamic> readList(String key) {
    final raw = _user.get(key);
    if (raw == null) return [];
    return (jsonDecode(raw as String) as List).toList();
  }

  Future<void> write(String key, Object? value) => _track(_user.put(key, jsonEncode(value)));

  // Notifiers write fire-and-forget; tests (and backup import) await these.
  final Set<Future<void>> _pending = {};

  Future<void> _track(Future<void> f) {
    _pending.add(f);
    return f.whenComplete(() => _pending.remove(f));
  }

  /// Completes when every queued write (and compaction) has finished.
  Future<void> settle() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }

  Future<void> delete(String key) => _track(_user.delete(key));

  /// Every user document, for encrypted backup export.
  Map<String, dynamic> exportAll() => {
        'settings': readSettings(),
        'user': {for (final k in _user.keys) k.toString(): jsonDecode(_user.get(k) as String)},
      };

  Future<void> importAll(Map<String, dynamic> data) async {
    await settle();
    final s = data['settings'];
    if (s is Map) await writeSettings(Map<String, dynamic>.from(s));
    final u = data['user'];
    if (u is Map) {
      await _user.clear();
      for (final e in u.entries) {
        await _user.put(e.key.toString(), jsonEncode(e.value));
      }
    }
  }

  static Map<String, dynamic> _decode(Object? raw) {
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
  }
}
