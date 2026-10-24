import 'package:flutter/foundation.dart';

import '../core/theme/app_theme.dart';

/// User preferences. Persisted as a flat JSON map; unknown keys are ignored
/// so older backups stay importable.
@immutable
class AppSettings {
  const AppSettings({
    this.theme = AppThemeKind.night,
    this.readingTheme = AppThemeKind.system,
    this.lang = 'ar',
    this.highContrast = false,
    this.reduceMotion = false,
    this.haptics = true,
    this.quranFontSize = 30,
    this.translationId = 'en_sahih',
    this.showTranslation = false,
    this.tafsirId = 'muyassar',
    this.reciterId = 'alafasy',
    this.pageMode = false,
    this.lat,
    this.lng,
    this.placeName,
    this.autoLocation = true,
    this.calcMethod = 'muslim_world_league',
    this.madhab = 'shafi',
    this.highLatRule = 'middle_of_the_night',
    this.prayerOffsets = const {},
    this.adhanEnabled = const {'fajr': true, 'dhuhr': true, 'asr': true, 'maghrib': true, 'isha': true},
    this.preAdhanMinutes = 0,
    this.hijriOffset = 0,
    this.azkarReminders = true,
    this.wirdReminderHour = 21,
    this.tasbihGoal = 100,
    this.kidsPin,
    this.onboarded = false,
    this.tajweed = true,
    this.adhanSound = 'full',
    this.iqamaAlert = false,
    this.iqamaMinutes = 15,
    this.ramadanReminders = true,
    this.kahfReminder = true,
    this.salawatReminder = true,
    this.whiteDaysReminder = true,
    this.monThuReminder = false,
    this.occasionFastReminder = true,
  });

  final AppThemeKind theme;
  final AppThemeKind readingTheme;
  final String lang;
  final bool highContrast;
  final bool reduceMotion;
  final bool haptics;
  final double quranFontSize;
  final String translationId;
  final bool showTranslation;
  final String tafsirId;
  final String reciterId;
  final bool pageMode;
  final double? lat;
  final double? lng;
  final String? placeName;
  final bool autoLocation;
  final String calcMethod;
  final String madhab;
  final String highLatRule;
  final Map<String, int> prayerOffsets;
  final Map<String, bool> adhanEnabled;
  final int preAdhanMinutes;
  final int hijriOffset;
  final bool azkarReminders;
  final int wirdReminderHour;
  final int tasbihGoal;
  final String? kidsPin;
  final bool onboarded;

  /// Colour-coded tajweed in the reader.
  final bool tajweed;
  final String adhanSound;
  final bool iqamaAlert;
  final int iqamaMinutes;
  final bool ramadanReminders;
  final bool kahfReminder;
  final bool salawatReminder;
  final bool whiteDaysReminder;
  final bool monThuReminder;
  final bool occasionFastReminder;

  bool get hasLocation => lat != null && lng != null;

  AppSettings copyWith({
    AppThemeKind? theme,
    AppThemeKind? readingTheme,
    String? lang,
    bool? highContrast,
    bool? reduceMotion,
    bool? haptics,
    double? quranFontSize,
    String? translationId,
    bool? showTranslation,
    String? tafsirId,
    String? reciterId,
    bool? pageMode,
    double? lat,
    double? lng,
    String? placeName,
    bool? autoLocation,
    String? calcMethod,
    String? madhab,
    String? highLatRule,
    Map<String, int>? prayerOffsets,
    Map<String, bool>? adhanEnabled,
    int? preAdhanMinutes,
    int? hijriOffset,
    bool? azkarReminders,
    int? wirdReminderHour,
    int? tasbihGoal,
    String? kidsPin,
    bool clearKidsPin = false,
    bool? onboarded,
    bool? tajweed,
    String? adhanSound,
    bool? iqamaAlert,
    int? iqamaMinutes,
    bool? ramadanReminders,
    bool? kahfReminder,
    bool? salawatReminder,
    bool? whiteDaysReminder,
    bool? monThuReminder,
    bool? occasionFastReminder,
  }) =>
      AppSettings(
        theme: theme ?? this.theme,
        readingTheme: readingTheme ?? this.readingTheme,
        lang: lang ?? this.lang,
        highContrast: highContrast ?? this.highContrast,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        haptics: haptics ?? this.haptics,
        quranFontSize: quranFontSize ?? this.quranFontSize,
        translationId: translationId ?? this.translationId,
        showTranslation: showTranslation ?? this.showTranslation,
        tafsirId: tafsirId ?? this.tafsirId,
        reciterId: reciterId ?? this.reciterId,
        pageMode: pageMode ?? this.pageMode,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        placeName: placeName ?? this.placeName,
        autoLocation: autoLocation ?? this.autoLocation,
        calcMethod: calcMethod ?? this.calcMethod,
        madhab: madhab ?? this.madhab,
        highLatRule: highLatRule ?? this.highLatRule,
        prayerOffsets: prayerOffsets ?? this.prayerOffsets,
        adhanEnabled: adhanEnabled ?? this.adhanEnabled,
        preAdhanMinutes: preAdhanMinutes ?? this.preAdhanMinutes,
        hijriOffset: hijriOffset ?? this.hijriOffset,
        azkarReminders: azkarReminders ?? this.azkarReminders,
        wirdReminderHour: wirdReminderHour ?? this.wirdReminderHour,
        tasbihGoal: tasbihGoal ?? this.tasbihGoal,
        kidsPin: clearKidsPin ? null : (kidsPin ?? this.kidsPin),
        onboarded: onboarded ?? this.onboarded,
        tajweed: tajweed ?? this.tajweed,
        adhanSound: adhanSound ?? this.adhanSound,
        iqamaAlert: iqamaAlert ?? this.iqamaAlert,
        iqamaMinutes: iqamaMinutes ?? this.iqamaMinutes,
        ramadanReminders: ramadanReminders ?? this.ramadanReminders,
        kahfReminder: kahfReminder ?? this.kahfReminder,
        salawatReminder: salawatReminder ?? this.salawatReminder,
        whiteDaysReminder: whiteDaysReminder ?? this.whiteDaysReminder,
        monThuReminder: monThuReminder ?? this.monThuReminder,
        occasionFastReminder: occasionFastReminder ?? this.occasionFastReminder,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'readingTheme': readingTheme.name,
        'lang': lang,
        'highContrast': highContrast,
        'reduceMotion': reduceMotion,
        'haptics': haptics,
        'quranFontSize': quranFontSize,
        'translationId': translationId,
        'showTranslation': showTranslation,
        'tafsirId': tafsirId,
        'reciterId': reciterId,
        'pageMode': pageMode,
        'lat': lat,
        'lng': lng,
        'placeName': placeName,
        'autoLocation': autoLocation,
        'calcMethod': calcMethod,
        'madhab': madhab,
        'highLatRule': highLatRule,
        'prayerOffsets': prayerOffsets,
        'adhanEnabled': adhanEnabled,
        'preAdhanMinutes': preAdhanMinutes,
        'hijriOffset': hijriOffset,
        'azkarReminders': azkarReminders,
        'wirdReminderHour': wirdReminderHour,
        'tasbihGoal': tasbihGoal,
        'kidsPin': kidsPin,
        'onboarded': onboarded,
        'tajweed': tajweed,
        'adhanSound': adhanSound,
        'iqamaAlert': iqamaAlert,
        'iqamaMinutes': iqamaMinutes,
        'ramadanReminders': ramadanReminders,
        'kahfReminder': kahfReminder,
        'salawatReminder': salawatReminder,
        'whiteDaysReminder': whiteDaysReminder,
        'monThuReminder': monThuReminder,
        'occasionFastReminder': occasionFastReminder,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    AppThemeKind kind(Object? v, AppThemeKind fallback) =>
        AppThemeKind.values.firstWhere((e) => e.name == v, orElse: () => fallback);
    T pick<T>(String k, T fallback) {
      final v = j[k];
      return v is T ? v : fallback;
    }

    double? dbl(String k) => j[k] is num ? (j[k] as num).toDouble() : null;
    String? text(String k) => j[k] is String ? j[k] as String : null;

    return AppSettings(
      theme: kind(j['theme'], d.theme),
      readingTheme: kind(j['readingTheme'], d.readingTheme),
      lang: pick('lang', d.lang),
      highContrast: pick('highContrast', d.highContrast),
      reduceMotion: pick('reduceMotion', d.reduceMotion),
      haptics: pick('haptics', d.haptics),
      quranFontSize: dbl('quranFontSize') ?? d.quranFontSize,
      translationId: pick('translationId', d.translationId),
      showTranslation: pick('showTranslation', d.showTranslation),
      tafsirId: pick('tafsirId', d.tafsirId),
      reciterId: pick('reciterId', d.reciterId),
      pageMode: pick('pageMode', d.pageMode),
      lat: dbl('lat'),
      lng: dbl('lng'),
      placeName: text('placeName'),
      autoLocation: pick('autoLocation', d.autoLocation),
      calcMethod: pick('calcMethod', d.calcMethod),
      madhab: pick('madhab', d.madhab),
      highLatRule: pick('highLatRule', d.highLatRule),
      prayerOffsets: j['prayerOffsets'] is Map
          ? {
              for (final e in (j['prayerOffsets'] as Map).entries)
                if (e.value is num) e.key.toString(): (e.value as num).toInt(),
            }
          : d.prayerOffsets,
      adhanEnabled: j['adhanEnabled'] is Map
          ? (j['adhanEnabled'] as Map).map((k, v) => MapEntry(k.toString(), v == true))
          : d.adhanEnabled,
      preAdhanMinutes: pick('preAdhanMinutes', d.preAdhanMinutes),
      hijriOffset: pick('hijriOffset', d.hijriOffset),
      azkarReminders: pick('azkarReminders', d.azkarReminders),
      wirdReminderHour: pick('wirdReminderHour', d.wirdReminderHour),
      tasbihGoal: pick('tasbihGoal', d.tasbihGoal),
      kidsPin: text('kidsPin'),
      onboarded: pick('onboarded', d.onboarded),
      tajweed: pick('tajweed', d.tajweed),
      adhanSound: pick('adhanSound', d.adhanSound),
      iqamaAlert: pick('iqamaAlert', d.iqamaAlert),
      iqamaMinutes: pick('iqamaMinutes', d.iqamaMinutes),
      ramadanReminders: pick('ramadanReminders', d.ramadanReminders),
      kahfReminder: pick('kahfReminder', d.kahfReminder),
      salawatReminder: pick('salawatReminder', d.salawatReminder),
      whiteDaysReminder: pick('whiteDaysReminder', d.whiteDaysReminder),
      monThuReminder: pick('monThuReminder', d.monThuReminder),
      occasionFastReminder: pick('occasionFastReminder', d.occasionFastReminder),
    );
  }
}
