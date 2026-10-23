/// The Prophet's life ﷺ as told in the Quran.
///
/// Like the prophets' stories, each event stores only verse references; the
/// app shows the verses with Tafsir al-Muyassar. Event titles are plain
/// historical names (Badr, the Hijra…), not narrative.
class SiraEvent {
  const SiraEvent(this.id, this.titleAr, this.titleEn, this.refs);
  final String id;
  final String titleAr;
  final String titleEn;
  final List<String> refs;
  String title(String lang) => lang == 'ar' ? titleAr : titleEn;
}

class SiraSection {
  const SiraSection(this.id, this.titleAr, this.titleEn, this.subtitleAr, this.subtitleEn, this.events);
  final String id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final List<SiraEvent> events;
  String title(String lang) => lang == 'ar' ? titleAr : titleEn;
  String subtitle(String lang) => lang == 'ar' ? subtitleAr : subtitleEn;
}

const siraSections = <SiraSection>[
  SiraSection('about', 'نبذة عن الرسول ﷺ', 'About the Prophet ﷺ', 'صفاته وأخلاقه كما وصفها القرآن', 'His character as described in the Quran', [
    SiraEvent('character', 'خُلُقه العظيم', 'His great character', ['68:1-4', '3:159']),
    SiraEvent('mercy', 'رحمة للعالمين', 'A mercy to the worlds', ['21:107', '9:128']),
    SiraEvent('example', 'الأسوة الحسنة', 'The excellent example', ['33:21', '33:45-46']),
    SiraEvent('description', 'صفته في الكتب السابقة', 'Described in earlier scriptures', ['7:157', '48:29', '61:6']),
    SiraEvent('seal', 'خاتم النبيين', 'Seal of the prophets', ['33:40', '3:144']),
    SiraEvent('comfort', 'تثبيت الله لنبيه', 'Allah reassures His Prophet', ['93:1-11', '94:1-8', '108:1-3']),
  ]),
  SiraSection('life', 'حياة الرسول ﷺ', 'His life ﷺ', 'من البعثة إلى حجة الوداع، مرتبةً', 'From revelation to the farewell pilgrimage', [
    SiraEvent('first_revelation', 'بدء الوحي', 'The first revelation', ['96:1-5', '74:1-7']),
    SiraEvent('open_call', 'الجهر بالدعوة', 'The open call', ['26:214-216', '15:94-99']),
    SiraEvent('isra', 'الإسراء والمعراج', 'The Night Journey and Ascension', ['17:1', '53:1-18']),
    SiraEvent('hijra', 'الهجرة', 'The Hijra', ['8:30', '9:40']),
    SiraEvent('qibla', 'تحويل القبلة', 'Change of the qibla', ['2:142-150']),
    SiraEvent('hudaybiyyah', 'صلح الحديبية', 'Treaty of Hudaybiyyah', ['48:1-10', '48:18-27']),
    SiraEvent('conquest', 'فتح مكة', 'Conquest of Makkah', ['110:1-3']),
    SiraEvent('farewell', 'حجة الوداع وإكمال الدين', 'Farewell pilgrimage', ['5:3']),
  ]),
  SiraSection('battles', 'غزوات الرسول ﷺ', 'His battles ﷺ', 'بدر وأحد والأحزاب وسائر الغزوات', 'Badr, Uhud, the Trench and others', [
    SiraEvent('badr', 'غزوة بدر', 'Battle of Badr', ['8:5-19', '8:41-48', '3:123-127']),
    SiraEvent('uhud', 'غزوة أحد', 'Battle of Uhud', ['3:121-122', '3:139-175']),
    SiraEvent('nadir', 'إجلاء بني النضير', 'Banu an-Nadir', ['59:2-6']),
    SiraEvent('ahzab', 'غزوة الأحزاب (الخندق)', 'Battle of the Trench', ['33:9-27']),
    SiraEvent('hunayn', 'غزوة حنين', 'Battle of Hunayn', ['9:25-27']),
    SiraEvent('tabuk', 'غزوة تبوك', 'Expedition of Tabuk', ['9:38-42', '9:117-118']),
  ]),
  SiraSection('family', 'زوجات وأهل بيت الرسول ﷺ', 'His wives and household ﷺ', 'أمهات المؤمنين وما نزل فيهن', 'The Mothers of the Believers', [
    SiraEvent('mothers', 'أمهات المؤمنين', 'Mothers of the Believers', ['33:6', '33:28-34']),
    SiraEvent('ifk', 'براءة عائشة رضي الله عنها', 'The innocence of ʿAʾishah', ['24:11-26']),
    SiraEvent('zaynab', 'زواجه من زينب رضي الله عنها', 'His marriage to Zaynab', ['33:37-40']),
    SiraEvent('rulings', 'أحكام بيت النبي ﷺ', 'Rulings of the Prophet\'s household', ['33:50-53', '66:1-5']),
  ]),
];
