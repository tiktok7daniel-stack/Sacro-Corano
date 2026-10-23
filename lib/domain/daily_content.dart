import 'quran_models.dart';

/// Verses rotated as "verse of the day". References only; the text comes
/// from the bundled mushaf.
const _dailyVerses = [
  '2:255', '2:152', '2:186', '3:139', '13:28', '39:53', '65:3', '94:5', '2:286', '93:5',
  '16:97', '29:69', '33:41', '57:4', '50:16', '49:13', '3:200', '20:114', '14:7', '9:51',
  '2:153', '3:173', '12:87', '17:82', '28:24', '40:60', '55:13', '59:22', '64:11', '73:20',
];

/// Supplications from the Quran ("dua of the day").
const quranicDuas = [
  '2:127', '2:201', '2:250', '2:286', '3:8', '3:16', '3:147', '3:193', '7:23', '7:126',
  '10:85', '14:40', '14:41', '17:24', '17:80', '18:10', '20:25', '20:114', '21:87', '23:109',
  '25:65', '25:74', '26:83', '27:19', '28:24', '46:15', '59:10', '66:8',
];

int _dayNumber(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

AyahRef verseOfTheDay(DateTime d) => AyahRef.parse(_dailyVerses[_dayNumber(d) % _dailyVerses.length]);

AyahRef duaOfTheDay(DateTime d) => AyahRef.parse(quranicDuas[(_dayNumber(d) * 7) % quranicDuas.length]);

/// Deterministic daily index into any list (e.g. a zikr of the day).
int dailyIndex(DateTime d, int length, {int salt = 0}) => (_dayNumber(d) * 31 + salt) % length;
