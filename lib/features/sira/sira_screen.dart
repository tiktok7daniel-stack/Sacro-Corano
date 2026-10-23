import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../domain/quran_models.dart';
import '../../domain/sira.dart';
import '../quran/verse_journey.dart';

const _sectionIcons = {
  'about': Icons.menu_book_rounded,
  'life': Icons.history_edu_rounded,
  'battles': Icons.shield_rounded,
  'family': Icons.people_alt_rounded,
};

/// The Sira through the Quran: four sections like a classic sira book,
/// each event told by its verses and Tafsir al-Muyassar.
class SiraScreen extends StatelessWidget {
  const SiraScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        PageTitle(context.tr('sira'), subtitle: context.tr('sira_sub')),
        for (final (i, s) in siraSections.indexed)
          FadeSlideIn.indexed(
            i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AppCard(
                padding: const EdgeInsets.all(20),
                onTap: () => push(context, SiraSectionScreen(section: s)),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(colors: [Color(0xFF1E6F7B), Color(0xFF155763)]),
                      ),
                      child: Icon(_sectionIcons[s.id], color: Brand.gold, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title(context.lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(s.subtitle(context.lang), style: const TextStyle(color: Brand.textMid)),
                          const SizedBox(height: 8),
                          Pill(context.tr('topics_n', {'n': s.events.length})),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded, color: Brand.textMid),
                  ],
                ),
              ),
            ),
          ),
        Text(
          context.tr('sira_note'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.textLow, fontSize: 12),
        ),
      ],
    ),
  );
}

class SiraSectionScreen extends StatelessWidget {
  const SiraSectionScreen({super.key, required this.section});
  final SiraSection section;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(section.title(context.lang))),
    body: ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: section.events.length,
      itemBuilder: (context, i) {
        final e = section.events[i];
        return FadeSlideIn.indexed(
          i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => push(context, VerseJourneyScreen(title: e.title(context.lang), ranges: e.refs.map(AyahRange.parse).toList(), color: Brand.tealDeep)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Brand.gold.withValues(alpha: 0.15),
                    child: Text(
                      context.num(i + 1),
                      style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title(context.lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(e.refs.join(' · '), style: const TextStyle(color: Brand.textLow, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, color: Brand.textMid),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
