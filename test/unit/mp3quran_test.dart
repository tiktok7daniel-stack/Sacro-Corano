import 'package:flutter_test/flutter_test.dart';
import 'package:mishkah/domain/mp3quran.dart';

void main() => mp3quranTests();

void mp3quranTests() {
  group('MP3Quran library', () {
    test('parses reciters, sets and surah lists and drops broken records', () {
      final list = parseFullReciters([
        {
          'id': 1,
          'name': 'عبد الباسط عبد الصمد',
          'moshaf': [
            {'id': 10, 'name': 'حفص - مرتل', 'server': 'https://server7.mp3quran.net/basit', 'surah_list': '1,2,114,115,x'},
            {'id': 11, 'name': 'http only', 'server': 'http://insecure.example/a/', 'surah_list': '1'},
            {'id': 12, 'name': 'empty', 'server': 'https://s.example/b/', 'surah_list': ''},
          ],
        },
        {'id': 2, 'name': '', 'moshaf': []},
        'not a map',
      ]);
      expect(list.length, 1);
      final m = list.single.moshafs.single;
      expect(m.surahs, {1, 2, 114});
      expect(m.url(1).toString(), 'https://server7.mp3quran.net/basit/001.mp3');
      expect(m.url(114).toString(), 'https://server7.mp3quran.net/basit/114.mp3');
      expect(m.has(3), isFalse);
    });
  });
}
