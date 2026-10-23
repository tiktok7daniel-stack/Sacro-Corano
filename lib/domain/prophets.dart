import 'quran_models.dart';

/// The 25 prophets named in the Quran, each mapped to the passages that tell
/// their story. Only *references* are stored: the app renders the verses
/// from the bundled mushaf text and explains them with Tafsir al-Muyassar,
/// so no narrative is invented. Passage choice follows the classical
/// arrangement used in works such as Ibn Kathir's "Qasas al-Anbiya".
class Prophet {
  const Prophet({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.passages,
    this.messenger = false,
    this.ululAzm = false,
    required this.color,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final List<String> passages;
  final bool messenger;
  final bool ululAzm;
  final int color;

  List<AyahRange> get ranges => passages.map(AyahRange.parse).toList();
  String title(String lang) => lang == 'ar' ? 'قصة $nameAr عليه السلام' : 'Prophet $nameEn';
}

const prophets = <Prophet>[
  Prophet(id: 'adam', nameAr: 'آدم', nameEn: 'Adam', passages: ['2:30-39', '7:11-27', '20:115-123'], color: 0xFF465C33),
  Prophet(id: 'idris', nameAr: 'إدريس', nameEn: 'Idris', passages: ['19:56-57', '21:85-86'], color: 0xFF3F5A3A),
  Prophet(id: 'nuh', nameAr: 'نوح', nameEn: 'Nuh', passages: ['11:25-49', '23:23-30', '71:1-28'], messenger: true, ululAzm: true, color: 0xFF1F4C57),
  Prophet(id: 'hud', nameAr: 'هود', nameEn: 'Hud', passages: ['11:50-60', '26:123-140', '46:21-26'], messenger: true, color: 0xFF6B2C30),
  Prophet(id: 'salih', nameAr: 'صالح', nameEn: 'Salih', passages: ['11:61-68', '26:141-159', '91:11-15'], messenger: true, color: 0xFF7A3F1D),
  Prophet(id: 'ibrahim', nameAr: 'إبراهيم', nameEn: 'Ibrahim', passages: ['6:74-83', '21:51-73', '37:83-113', '14:35-41'], messenger: true, ululAzm: true, color: 0xFF1F4C57),
  Prophet(id: 'lut', nameAr: 'لوط', nameEn: 'Lut', passages: ['11:77-83', '15:57-77', '26:160-175'], messenger: true, color: 0xFF6A4B2A),
  Prophet(id: 'ismail', nameAr: 'إسماعيل', nameEn: 'Ismail', passages: ['2:125-129', '19:54-55', '37:100-107'], messenger: true, color: 0xFF6A4B2A),
  Prophet(id: 'ishaq', nameAr: 'إسحاق', nameEn: 'Ishaq', passages: ['11:69-73', '37:112-113', '51:24-30'], color: 0xFF2F4466),
  Prophet(id: 'yaqub', nameAr: 'يعقوب', nameEn: 'Yaqub', passages: ['2:132-133', '19:49-50', '12:94-98'], color: 0xFF6A4B2A),
  Prophet(id: 'yusuf', nameAr: 'يوسف', nameEn: 'Yusuf', passages: ['12:4-101'], messenger: true, color: 0xFF3D5530),
  Prophet(id: 'shuaib', nameAr: 'شعيب', nameEn: 'Shuʿayb', passages: ['7:85-93', '11:84-95', '26:176-191'], messenger: true, color: 0xFF7A3F1D),
  Prophet(id: 'ayyub', nameAr: 'أيوب', nameEn: 'Ayyub', passages: ['21:83-84', '38:41-44'], color: 0xFF6A4B2A),
  Prophet(id: 'dhulkifl', nameAr: 'ذو الكفل', nameEn: 'Dhul-Kifl', passages: ['21:85-86', '38:48'], color: 0xFF1E5A52),
  Prophet(id: 'musa', nameAr: 'موسى', nameEn: 'Musa', passages: ['28:3-46', '20:9-98', '26:10-68', '18:60-82'], messenger: true, ululAzm: true, color: 0xFF1F4C57),
  Prophet(id: 'harun', nameAr: 'هارون', nameEn: 'Harun', passages: ['20:29-36', '20:90-94', '7:142', '7:150-151'], messenger: true, color: 0xFF7A3F1D),
  Prophet(id: 'dawud', nameAr: 'داود', nameEn: 'Dawud', passages: ['2:251', '34:10-11', '38:17-26'], color: 0xFF7A3F1D),
  Prophet(id: 'sulayman', nameAr: 'سليمان', nameEn: 'Sulayman', passages: ['21:78-82', '27:15-44', '34:12-14', '38:30-40'], color: 0xFF7A3F1D),
  Prophet(id: 'ilyas', nameAr: 'إلياس', nameEn: 'Ilyas', passages: ['37:123-132'], messenger: true, color: 0xFF5A2E55),
  Prophet(id: 'alyasa', nameAr: 'اليسع', nameEn: 'Al-Yasaʿ', passages: ['6:86', '38:48'], color: 0xFF6A4B2A),
  Prophet(id: 'yunus', nameAr: 'يونس', nameEn: 'Yunus', passages: ['37:139-148', '21:87-88', '10:98', '68:48-50'], messenger: true, color: 0xFF7A3F1D),
  Prophet(id: 'zakariya', nameAr: 'زكريا', nameEn: 'Zakariya', passages: ['3:37-41', '19:2-11', '21:89-90'], color: 0xFF1E5A52),
  Prophet(id: 'yahya', nameAr: 'يحيى', nameEn: 'Yahya', passages: ['19:12-15', '3:39'], color: 0xFF7A3F1D),
  Prophet(id: 'isa', nameAr: 'عيسى', nameEn: 'ʿIsa', passages: ['3:42-59', '19:16-36', '5:110-118', '61:6'], messenger: true, ululAzm: true, color: 0xFF1F4C57),
  Prophet(id: 'muhammad', nameAr: 'محمد ﷺ', nameEn: 'Muhammad ﷺ', passages: ['93:1-11', '94:1-8', '17:1', '33:40', '48:29'], messenger: true, ululAzm: true, color: 0xFF155E63),
];

/// Verses a user can open for a given state of heart. References only.
class MoodVerses {
  const MoodVerses(this.id, this.nameAr, this.nameEn, this.refs);
  final String id;
  final String nameAr;
  final String nameEn;
  final List<String> refs;
}

const moods = <MoodVerses>[
  MoodVerses('sad', 'حزين', 'Sad', ['94:5-6', '12:86', '9:40', '3:139', '2:286']),
  MoodVerses('anxious', 'قلِق', 'Anxious', ['13:28', '65:2-3', '2:186', '3:173', '2:153']),
  MoodVerses('afraid', 'خائف', 'Afraid', ['9:51', '20:46', '10:62', '3:173']),
  MoodVerses('grateful', 'شاكر', 'Grateful', ['14:7', '16:18', '93:11', '55:13']),
  MoodVerses('hopeless', 'يائس', 'Losing hope', ['39:53', '12:87', '15:56', '94:5-6']),
  MoodVerses('patient', 'أحتاج الصبر', 'Need patience', ['2:155-157', '39:10', '3:200']),
  MoodVerses('distress', 'في ضيق', 'In distress', ['21:87-88', '65:2-3', '27:62']),
];
