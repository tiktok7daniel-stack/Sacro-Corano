/// Reciters streamed verse-by-verse from EveryAyah.com, which publishes the
/// recordings for free non-commercial use. Per-verse files are what make
/// precise verse highlighting, repeat-a-verse and offline download possible.
class Reciter {
  const Reciter(this.id, this.nameAr, this.nameEn, this.folder, {this.style = 'murattal'});

  final String id;
  final String nameAr;
  final String nameEn;

  /// Folder under https://everyayah.com/data/
  final String folder;
  final String style;

  String name(String lang) => lang == 'ar' ? nameAr : nameEn;

  static String _pad(int n) => n.toString().padLeft(3, '0');

  String fileName(int surah, int ayah) => '${_pad(surah)}${_pad(ayah)}.mp3';

  Uri url(int surah, int ayah) => Uri.parse('https://everyayah.com/data/$folder/${fileName(surah, ayah)}');
}

const reciters = <Reciter>[
  Reciter('alafasy', 'مشاري راشد العفاسي', 'Mishary Alafasy', 'Alafasy_128kbps'),
  Reciter('husary', 'محمود خليل الحصري', 'Mahmoud Khalil Al-Husary', 'Husary_128kbps'),
  Reciter('husary_mujawwad', 'الحصري (مجوّد)', 'Al-Husary (Mujawwad)', 'Husary_128kbps_Mujawwad', style: 'mujawwad'),
  Reciter('abdulbasit', 'عبد الباسط عبد الصمد', 'Abdul Basit (Murattal)', 'Abdul_Basit_Murattal_192kbps'),
  Reciter('abdulbasit_mujawwad', 'عبد الباسط (مجوّد)', 'Abdul Basit (Mujawwad)', 'Abdul_Basit_Mujawwad_128kbps', style: 'mujawwad'),
  Reciter('minshawi', 'محمد صديق المنشاوي', 'Al-Minshawi (Murattal)', 'Minshawy_Murattal_128kbps'),
  Reciter('minshawi_mujawwad', 'المنشاوي (مجوّد)', 'Al-Minshawi (Mujawwad)', 'Minshawy_Mujawwad_192kbps', style: 'mujawwad'),
  Reciter('hudhaify', 'علي الحذيفي', 'Ali Al-Hudhaify', 'Hudhaify_128kbps'),
  Reciter('sudais', 'عبد الرحمن السديس', 'Abdurrahman As-Sudais', 'Abdurrahmaan_As-Sudais_192kbps'),
  Reciter('shuraim', 'سعود الشريم', 'Saud Ash-Shuraim', 'Saood_ash-Shuraym_128kbps'),
  Reciter('muaiqly', 'ماهر المعيقلي', 'Maher Al-Muaiqly', 'MaherAlMuaiqly128kbps'),
  Reciter('ghamadi', 'سعد الغامدي', 'Saad Al-Ghamdi', 'Ghamadi_40kbps'),
  Reciter('shatri', 'أبو بكر الشاطري', 'Abu Bakr Ash-Shatri', 'Abu_Bakr_Ash-Shaatree_128kbps'),
  Reciter('ayyoub', 'محمد أيوب', 'Muhammad Ayyoub', 'Muhammad_Ayyoub_128kbps'),
  Reciter('dussary', 'ياسر الدوسري', 'Yasser Ad-Dussary', 'Yasser_Ad-Dussary_128kbps'),
  Reciter('ajamy', 'أحمد بن علي العجمي', 'Ahmed Al-Ajamy', 'ahmed_ibn_ali_al_ajamy_128kbps'),
  Reciter('rifai', 'هاني الرفاعي', 'Hani Ar-Rifai', 'Hani_Rifai_192kbps'),
  Reciter('jibreel', 'محمد جبريل', 'Muhammad Jibreel', 'Muhammad_Jibreel_128kbps'),
];

Reciter reciterById(String id) => reciters.firstWhere((r) => r.id == id, orElse: () => reciters.first);
