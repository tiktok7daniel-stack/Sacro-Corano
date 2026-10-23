import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/widgets/common.dart';
import '../../domain/daily_content.dart';
import '../../domain/prophets.dart';
import '../../domain/quran_models.dart';
import '../quran/widgets/verse_card.dart';

const _moodIcons = {
  'sad': Icons.sentiment_dissatisfied_rounded,
  'anxious': Icons.psychology_alt_rounded,
  'afraid': Icons.shield_moon_rounded,
  'grateful': Icons.favorite_rounded,
  'hopeless': Icons.wb_twilight_rounded,
  'patient': Icons.hourglass_bottom_rounded,
  'distress': Icons.waves_rounded,
};

/// "Verses for your state": the user picks how they feel and gets the
/// matching verses with Tafsir al-Muyassar under each.
class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  MoodVerses? _mood;

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        PageTitle(context.tr('mood_verses'), subtitle: context.tr('mood_sub')),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final mood in moods)
            ChoiceChip(
              avatar: Icon(_moodIcons[mood.id], size: 18),
              label: Text(context.isAr ? mood.nameAr : mood.nameEn),
              selected: _mood?.id == mood.id,
              onSelected: (_) => setState(() => _mood = mood),
            ),
        ]),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: m.medium,
          child: _mood == null
              ? EmptyState(icon: Icons.spa_rounded, title: context.tr('mood_pick'))
              : Column(
                  key: ValueKey(_mood!.id),
                  children: [
                    for (final (i, r) in _mood!.refs.indexed)
                      FadeSlideIn.indexed(
                        i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: VerseCard(range: AyahRange.parse(r), showTafsir: true),
                        ),
                      ),
                  ],
                ),
        ),
      ]),
    );
  }
}

/// Supplications from the Quran.
class QuranicDuasScreen extends StatelessWidget {
  const QuranicDuasScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          itemCount: quranicDuas.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) return PageTitle(context.tr('quran_duas'), subtitle: context.tr('quran_duas_sub'));
            return FadeSlideIn.indexed(
              i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VerseCard(range: AyahRange.parse(quranicDuas[i - 1]), compact: true),
              ),
            );
          },
        ),
      );
}
