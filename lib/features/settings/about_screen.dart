import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/logo.dart';

/// Credits every data source and licence shown in THIRD_PARTY_LICENSES.md.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Motion.of(context).reduced ? _c.value = 1 : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    const sources = [
      ('نص المصحف (الرسم العثماني)', 'Quran text (Uthmani)', 'QuranEnc.com · via quran-json (CC BY-SA 4.0)'),
      ('بيانات الصفحات والأجزاء', 'Page / juz / hizb data', 'quran-meta (MIT)'),
      ('التفسير الميسر', 'Tafsir al-Muyassar', 'King Fahd Complex · spa5k/tafsir_api (MIT)'),
      ('التفاسير القابلة للتحميل', 'Downloadable tafsir', 'spa5k/tafsir_api via jsDelivr (MIT)'),
      ('الترجمات', 'Translations', 'Tanzil.net (Saheeh Intl., Hamidullah) · islam.js (Piccardo)'),
      ('حصن المسلم', 'Hisn al-Muslim', 'islam.js azkar collection (MIT)'),
      ('التلاوات', 'Recitations', 'EveryAyah.com'),
      ('مواقيت الصلاة', 'Prayer times', 'adhan-dart (MIT)'),
      ('الخطوط', 'Fonts', 'Amiri, Amiri Quran, Readex Pro (SIL OFL 1.1)'),
    ];
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
        Center(child: AnimatedBuilder(animation: _c, builder: (_, _) => MishkahLogo(size: 128, progress: _c.value))),
        const SizedBox(height: 12),
        const Center(child: Text('مِشكاة', style: TextStyle(fontFamily: Brand.naskhFont, fontSize: 40, color: Brand.gold))),
        Center(child: Text('Mishkah · v1.0.0', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
        const SizedBox(height: 12),
        Text(context.tr('about_body'), textAlign: TextAlign.center, style: const TextStyle(height: 1.7)),
        const SizedBox(height: 8),
        const Text(
          '﴿ مَثَلُ نُورِهِۦ كَمِشۡكَوٰةٖ فِيهَا مِصۡبَاحٌۖ ﴾',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: Brand.quranFont, fontSize: 22, color: Brand.tealBright),
        ),
        const SizedBox(height: 20),
        Text(context.tr('sources'), style: Theme.of(context).textTheme.titleMedium),
        for (final (ar, en, src) in sources)
          ListTile(contentPadding: EdgeInsets.zero, title: Text(context.isAr ? ar : en), subtitle: Text(src)),
        if (q != null) Text(q.textSource, style: const TextStyle(color: Brand.textLow, fontSize: 12)),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => showLicensePage(context: context, applicationName: 'Mishkah', applicationVersion: '1.0.0', applicationIcon: const MishkahLogo(size: 64)),
          child: Text(context.tr('open_source_licenses')),
        ),
        const SizedBox(height: 8),
        Text(context.tr('license_note'), textAlign: TextAlign.center, style: const TextStyle(color: Brand.textLow, fontSize: 12)),
      ]),
    );
  }
}
