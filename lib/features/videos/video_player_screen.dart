import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/brand.dart';
import '../../data/video_repository.dart';
import '../../services/audio.dart';
import 'videos_screen.dart';

/// Plays a clip inside the app: YouTube through its official embedded
/// player (views count for the publisher), MP4 recitations natively.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.item, this.related = const []});
  final VideoItem item;
  final List<VideoItem> related;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late VideoItem _item = widget.item;
  YoutubePlayerController? _yt;
  VideoPlayerController? _mp4;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Recitation audio and a video should not play over each other.
    Future.microtask(() => ref.read(audioProvider.notifier).stop());
    _open(_item);
  }

  void _open(VideoItem item) {
    setState(() {
      _item = item;
      _failed = false;
    });
    if (item.isYoutube) {
      _mp4?.dispose();
      _mp4 = null;
      final yt = _yt;
      if (yt == null) {
        _yt = YoutubePlayerController.fromVideoId(
          videoId: item.youtubeId!,
          autoPlay: true,
          params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true, interfaceLanguage: 'ar', captionLanguage: 'ar'),
        );
      } else {
        yt.loadVideoById(videoId: item.youtubeId!);
      }
    } else {
      _mp4?.dispose();
      final c = VideoPlayerController.networkUrl(Uri.parse(item.url!));
      _mp4 = c;
      c.initialize().then((_) {
        if (mounted && _mp4 == c) {
          setState(() {});
          c.play();
        }
      }, onError: (_) {
        if (mounted) setState(() => _failed = true);
      });
    }
  }

  @override
  void dispose() {
    _yt?.close();
    _mp4?.dispose();
    super.dispose();
  }

  Uri get _webUrl => _item.isYoutube ? Uri.https('www.youtube.com', '/watch', {'v': _item.youtubeId!}) : Uri.parse(_item.url!);

  Widget _player() {
    final yt = _yt;
    if (_item.isYoutube && yt != null) {
      return YoutubeValueBuilder(
        controller: yt,
        builder: (context, value) => value.hasError
            ? _Fallback(onOpen: () => launchUrl(_webUrl, mode: LaunchMode.externalApplication))
            : YoutubePlayer(controller: yt, aspectRatio: 16 / 9),
      );
    }
    final c = _mp4;
    if (_failed || c == null) return _Fallback(onOpen: () => launchUrl(_webUrl, mode: LaunchMode.externalApplication));
    if (!c.value.isInitialized) return const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator()));
    return AspectRatio(
      aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
      child: Stack(alignment: Alignment.bottomCenter, children: [
        VideoPlayer(c),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (context, v, _) => Center(
            child: IconButton.filledTonal(
              iconSize: 40,
              tooltip: v.isPlaying ? context.tr('pause') : context.tr('play'),
              onPressed: () => v.isPlaying ? c.pause() : c.play(),
              icon: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
          ),
        ),
        VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Brand.gold)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final more = widget.related.where((v) => v.key != _item.key).toList();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Column(children: [
        ColoredBox(color: Colors.black, child: _player()),
        Expanded(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
              Text(_item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4)),
              const SizedBox(height: 4),
              Text(_item.channel, style: const TextStyle(color: Brand.textMid)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () => SharePlus.instance.share(ShareParams(text: '${_item.title}\n$_webUrl')),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(context.tr('share')),
                ),
                if (_item.isYoutube)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(_webUrl, mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(context.tr('open_in_youtube')),
                  ),
              ]),
              if (more.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(context.tr('up_next'), style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                for (final v in more.take(12))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _open(v),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 150, child: VideoThumb(item: v, radius: 12, playSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3)),
                            const SizedBox(height: 4),
                            Text(v.channel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.textMid, fontSize: 12)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 40),
            const SizedBox(height: 8),
            Text(context.tr('video_unavailable'), style: const TextStyle(color: Colors.white70)),
            TextButton(onPressed: onOpen, child: Text(context.tr('open_in_youtube'))),
          ]),
        ),
      );
}
