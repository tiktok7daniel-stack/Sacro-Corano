import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';

/// Religious clips: curated searches that open in YouTube itself, so views
/// count for the publishers and the app embeds no third-party content.
class VideoTopic {
  const VideoTopic(this.titleAr, this.titleEn, this.query, this.icon, this.colors);
  final String titleAr;
  final String titleEn;
  final String query;
  final IconData icon;
  final List<Color> colors;
  String title(String lang) => lang == 'ar' ? titleAr : titleEn;
}

const videoTopics = <VideoTopic>[
  VideoTopic('تلاوات خاشعة', 'Moving recitations', 'تلاوة خاشعة قرآن كريم', Icons.menu_book_rounded, Brand.gReciters),
  VideoTopic('المصحف المرتل', 'Murattal mushaf', 'المصحف المرتل كامل', Icons.auto_stories_rounded, Brand.gPrayer),
  VideoTopic('المصحف المجوّد', 'Mujawwad recitations', 'تلاوة مجودة نادرة', Icons.mic_rounded, Brand.gHifz),
  VideoTopic('ابتهالات وتواشيح', 'Ibtihalat & tawashih', 'ابتهالات دينية', Icons.music_note_rounded, Brand.gAzkar),
  VideoTopic('دروس ومواعظ', 'Lessons & reminders', 'موعظة مؤثرة درس ديني', Icons.record_voice_over_rounded, Brand.gKhatma),
  VideoTopic('قصص القرآن', 'Stories of the Quran', 'قصص القرآن الكريم', Icons.history_edu_rounded, Brand.gProphets),
  VideoTopic('تفسير', 'Tafsir lessons', 'تفسير القرآن الكريم درس', Icons.lightbulb_rounded, Brand.gStats),
  VideoTopic('الأذكار', 'Adhkar', 'أذكار الصباح والمساء', Icons.wb_sunny_rounded, Brand.gDua),
];

Future<void> openYouTubeSearch(String query) =>
    launchUrl(Uri.https('www.youtube.com', '/results', {'search_query': query}), mode: LaunchMode.externalApplication);

class VideosScreen extends StatelessWidget {
  const VideosScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: PageTitle(context.tr('videos'), subtitle: context.tr('videos_sub'))),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.25,
            children: [
              for (final (i, t) in videoTopics.indexed)
                FadeSlideIn.indexed(
                  i,
                  child: GradientTile(label: t.title(context.lang), icon: t.icon, colors: t.colors, onTap: () => openYouTubeSearch(t.query)),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: AppCard(
              child: Text(context.tr('videos_note'), style: const TextStyle(color: Brand.textMid, height: 1.6)),
            ),
          ),
        ),
      ],
    ),
  );
}
