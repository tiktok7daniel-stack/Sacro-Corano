import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../data/video_repository.dart';
import 'video_player_screen.dart';

final videoRepoProvider = Provider<VideoRepository>((ref) => VideoRepository(ref.watch(storageProvider)));

final videoSectionProvider = FutureProvider.family<List<VideoItem>, String>((ref, id) {
  final s = videoSections.firstWhere((s) => s.id == id);
  return ref.watch(videoRepoProvider).section(s);
});

/// Room for a card's title and channel lines at the user's text size.
double videoCardTextHeight(BuildContext context) => MediaQuery.textScalerOf(context).scale(14) * 3.2 + 12;

void openVideo(BuildContext context, VideoItem item, List<VideoItem> related) => push(context, VideoPlayerScreen(item: item, related: related));

/// 16:9 thumbnail with a play badge; decoded at display size to save memory.
class VideoThumb extends StatelessWidget {
  const VideoThumb({super.key, required this.item, this.radius = 18, this.playSize = 40});
  final VideoItem item;
  final double radius;
  final double playSize;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (context, c) => Stack(fit: StackFit.expand, children: [
            const ColoredBox(color: Color(0xFF1A232C)),
            if (item.thumb.isNotEmpty)
              Image.network(
                item.thumb,
                fit: BoxFit.cover,
                cacheWidth: (c.maxWidth * dpr).round().clamp(64, 1280),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const Icon(Icons.smart_display_rounded, color: Colors.white24, size: 40),
                frameBuilder: (context, child, frame, sync) => sync
                    ? child
                    : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 250), child: child),
              ),
            Center(
              child: Container(
                width: playSize * 1.6,
                height: playSize * 1.6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.35), border: Border.all(color: Colors.white70, width: 2)),
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: playSize),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.item, required this.related, this.width});
  final VideoItem item;
  final List<VideoItem> related;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openVideo(context, item, related),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            VideoThumb(item: item),
            const SizedBox(height: 8),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(item.channel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.textMid, fontSize: 12)),
          ]),
        ),
      );
}

/// "Religious clips": shelves of videos that play inside the app.
class VideosScreen extends ConsumerWidget {
  const VideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(),
        body: RefreshIndicator(
          onRefresh: () async {
            for (final s in videoSections) {
              await ref.read(videoRepoProvider).section(s, refresh: true).catchError((_) => <VideoItem>[]);
              ref.invalidate(videoSectionProvider(s.id));
            }
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              PageTitle(context.tr('videos'), subtitle: context.tr('videos_sub')),
              for (final s in videoSections) _Shelf(section: s),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: AppCard(child: Text(context.tr('videos_note'), style: const TextStyle(color: Brand.textMid, height: 1.6))),
              ),
            ],
          ),
        ),
      );
}

class _Shelf extends ConsumerWidget {
  const _Shelf({required this.section});
  final VideoSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(videoSectionProvider(section.id));
    final list = v.value;
    // A shelf that cannot load stays out of the way.
    if (v.hasError && list == null) return const SizedBox.shrink();
    final w = MediaQuery.sizeOf(context).width * 0.62;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Row(children: [
          Expanded(child: Text(section.title(context.lang), style: const TextStyle(color: Brand.tealBright, fontSize: 18, fontWeight: FontWeight.w700))),
          if (list != null)
            TextButton(
              onPressed: () => push(context, SectionVideosScreen(section: section)),
              child: Text('${context.tr('show_all')} (${context.num(list.length)})'),
            ),
        ]),
      ),
      SizedBox(
        height: w * 9 / 16 + videoCardTextHeight(context),
        child: list == null
            ? ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) => SizedBox(
                  width: w,
                  child: const Align(
                    alignment: Alignment.topCenter,
                    child: AspectRatio(aspectRatio: 16 / 9, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF1A232C), borderRadius: BorderRadius.all(Radius.circular(18))))),
                  ),
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => VideoCard(item: list[i], related: list, width: w),
              ),
      ),
    ]);
  }
}

class SectionVideosScreen extends ConsumerWidget {
  const SectionVideosScreen({super.key, required this.section});
  final VideoSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(section.title(context.lang))),
        body: AsyncView<List<VideoItem>>(
          value: ref.watch(videoSectionProvider(section.id)),
          onRetry: () => ref.invalidate(videoSectionProvider(section.id)),
          builder: (list) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) => VideoCard(item: list[i], related: list),
          ),
        ),
      );
}

/// Home card "Videos": a featured clip and a row of more.
class VideosHomeCard extends ConsumerWidget {
  const VideosHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(videoSectionProvider(videoSections.first.id));
    final list = v.value;
    if (v.hasError && list == null) return const SizedBox.shrink();
    final small = MediaQuery.sizeOf(context).width * 0.42;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: Brand.surface.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr('videos_card'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            FilledButton.tonal(onPressed: () => push(context, const VideosScreen()), child: Text(context.tr('show_all'))),
          ]),
        ),
        const SizedBox(height: 12),
        if (list == null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: AspectRatio(aspectRatio: 16 / 9, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF1A232C), borderRadius: BorderRadius.all(Radius.circular(22))))),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GestureDetector(
              onTap: () => openVideo(context, list.first, list),
              child: Stack(children: [
                VideoThumb(item: list.first, radius: 22, playSize: 36),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87], stops: [0.45, 1]),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 14,
                  end: 14,
                  bottom: 12,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Text(list.first.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.35)),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                      onPressed: () => openVideo(context, list.first, list),
                      child: Text(context.tr('watch_now')),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: small * 9 / 16 + videoCardTextHeight(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: (list.length - 1).clamp(0, 10),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => VideoCard(item: list[i + 1], related: list, width: small),
            ),
          ),
        ],
      ]),
    );
  }
}
