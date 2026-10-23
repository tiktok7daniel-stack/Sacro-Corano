import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';

import '../data/local/storage.dart';

class BackupException implements Exception {
  const BackupException(this.code);
  final String code;
  @override
  String toString() => code;
}

/// End-to-end encrypted backups.
///
/// The backup is AES-256-GCM encrypted with a key derived from the user's
/// passphrase (PBKDF2-HMAC-SHA256, 150k iterations, random salt). The file
/// can be kept anywhere — Google Drive, e-mail, a USB stick — and none of
/// those services can read it. Restoring on another device = sync.
abstract final class Backup {
  static const _iterations = 150000;
  static const format = 'mishkah-backup';

  static Uint8List deriveKey(String passphrase, List<int> salt, {int iterations = _iterations}) {
    final hmac = Hmac(sha256, utf8.encode(passphrase));
    // PBKDF2 with a single 32-byte block.
    final block = Uint8List.fromList([...salt, 0, 0, 0, 1]);
    var u = hmac.convert(block).bytes;
    final out = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  static List<int> _random(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }

  static String encryptJson(Map<String, dynamic> data, String passphrase, {int iterations = _iterations}) {
    final salt = _random(16);
    final iv = enc.IV(Uint8List.fromList(_random(12)));
    final key = enc.Key(deriveKey(passphrase, salt, iterations: iterations));
    final e = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final cipher = e.encryptBytes(utf8.encode(jsonEncode(data)), iv: iv);
    return jsonEncode({
      'format': format,
      'v': 1,
      'kdf': 'pbkdf2-sha256',
      'iter': iterations,
      'salt': base64.encode(salt),
      'iv': iv.base64,
      'data': cipher.base64,
    });
  }

  static Map<String, dynamic> decryptJson(String file, String passphrase) {
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(file) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('backup_invalid');
    }
    if (j['format'] != format) throw const BackupException('backup_invalid');
    final key = enc.Key(deriveKey(passphrase, base64.decode(j['salt'] as String), iterations: j['iter'] as int));
    final e = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    try {
      final plain = e.decryptBytes(enc.Encrypted.fromBase64(j['data'] as String), iv: enc.IV.fromBase64(j['iv'] as String));
      return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('backup_wrong_pass');
    }
  }

  static Future<File> exportToFile(Storage storage, String passphrase) async {
    final payload = encryptJson(storage.exportAll(), passphrase);
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    final file = File('${dir.path}/mishkah-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.mishkah');
    await file.writeAsString(payload);
    return file;
  }

  static Future<void> importFromFile(Storage storage, File file, String passphrase) async {
    final data = decryptJson(await file.readAsString(), passphrase);
    await storage.importAll(data);
  }
}
