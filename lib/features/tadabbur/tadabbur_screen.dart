import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../domain/user_models.dart';
import '../quran/reader_screen.dart';
import '../share/share_card.dart';
import 'reflection_editor.dart';

/// Reflection companion: personal notes on verses, browsable as a list or
/// as a map that links topics to the verses you reflected on.
class TadabburScreen extends ConsumerStatefulWidget {
  const TadabburScreen({super.key});

  @override
  ConsumerState<TadabburScreen> createState() => _TadabburScreenState();
}

class _TadabburScreenState extends ConsumerState<TadabburScreen> {
  bool _map = false;
  String? _topic;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(reflectionsProvider);
    final q = ref.watch(quranProvider).value;
    final list = _topic == null ? all : all.where((r) => r.tags.contains(_topic)).toList();
    return Scaffold(
      appBar: AppBar(actions: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, icon: const Icon(Icons.view_agenda_rounded), tooltip: context.tr('list')),
            ButtonSegment(value: true, icon: const Icon(Icons.hub_rounded), tooltip: context.tr('map')),
          ],
          selected: {_map},
          onSelectionChanged: (s) => setState(() => _map = s.first),
        ),
        const SizedBox(width: 12),
      ]),
      body: Column(children: [
        PageTitle(context.tr('tadabbur'), subtitle: context.tr('tadabbur_sub')),
        if (all.isEmpty)
          Expanded(child: EmptyState(icon: Icons.edit_note_rounded, title: context.tr('no_reflections'), body: context.tr('no_reflections_body')))
        else if (_map)
          Expanded(child: _ReflectionMap(reflections: all, onTopic: (t) => setState(() {
                _topic = t;
                _map = false;
              })))
        else ...[
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(label: Text(context.tr('all')), selected: _topic == null, onSelected: (_) => setState(() => _topic = null)),
                ),
                for (final t in all.expand((r) => r.tags).toSet())
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(label: Text(topicLabel(context, t)), selected: _topic == t, onSelected: (_) => setState(() => _topic = t)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = list[i];
                return FadeSlideIn.indexed(
                  i,
                  child: AppCard(
                    onTap: () => push(context, ReaderScreen(surah: r.ref.surah, initialAyah: r.ref.ayah)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('${q?.surah(r.ref.surah).nameAr ?? ''} · ${context.num(r.ref.ayah)}',
                            style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.ios_share_rounded, size: 20), tooltip: context.tr('share'), onPressed: () => _share(r)),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') showReflectionEditor(context, ref, r.ref, existing: r);
                            if (v == 'delete') ref.read(reflectionsProvider.notifier).remove(r.id);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(context.tr('edit'))),
                            PopupMenuItem(value: 'delete', child: Text(context.tr('delete'))),
                          ],
                        ),
                      ]),
                      if (q != null)
                        Text(q.textOf(r.ref),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 18, height: 1.8, color: Brand.textMid)),
                      const SizedBox(height: 8),
                      Text(r.text, style: const TextStyle(height: 1.6)),
                      if (r.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: [for (final t in r.tags) Pill(topicLabel(context, t))]),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _share(Reflection r) async {
    final q = await ref.read(quranProvider.future);
    if (!mounted) return;
    await shareWidgetAsImage(
      context,
      BrandedCard(
        title: '${q.surah(r.ref.surah).nameAr} · ${r.ref.ayah}',
        child: Column(children: [
          Text(q.textOf(r.ref),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 20, height: 1.9, color: Brand.textHigh)),
          const Divider(color: Brand.gold, height: 24),
          Text(r.text, textAlign: TextAlign.center, style: const TextStyle(color: Brand.textMid, fontSize: 14, height: 1.6)),
        ]),
      ),
      name: 'reflection',
    );
  }
}

/// Radial graph: topics on an outer ring, linked to verse dots grouped by
/// surah in the centre. Tapping a topic filters the list.
class _ReflectionMap extends StatelessWidget {
  const _ReflectionMap({required this.reflections, required this.onTopic});
  final List<Reflection> reflections;
  final void Function(String) onTopic;

  @override
  Widget build(BuildContext context) {
    final topics = <String, int>{};
    for (final r in reflections) {
      for (final t in r.tags.isEmpty ? ['—'] : r.tags) {
        topics[t] = (topics[t] ?? 0) + 1;
      }
    }
    final names = topics.keys.toList();
    return LayoutBuilder(builder: (context, c) {
      final size = math.min(c.maxWidth, c.maxHeight) - 24;
      final center = Offset(c.maxWidth / 2, c.maxHeight / 2);
      final radius = size / 2 - 40;
      Offset topicPos(int i) {
        final a = -math.pi / 2 + 2 * math.pi * i / names.length;
        return center + Offset(math.cos(a), math.sin(a)) * radius;
      }

      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.of(context).long,
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Stack(children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapPainter(
                center: center,
                topics: [for (var i = 0; i < names.length; i++) topicPos(i)],
                reflections: reflections,
                names: names,
                progress: t,
              ),
            ),
          ),
          for (var i = 0; i < names.length; i++)
            Positioned(
              left: topicPos(i).dx - 46,
              top: topicPos(i).dy - 18,
              width: 92,
              child: Opacity(
                opacity: t,
                child: ActionChip(
                  label: Text('${topicLabel(context, names[i])} ${context.num(topics[names[i]]!)}', overflow: TextOverflow.ellipsis),
                  onPressed: names[i] == '—' ? null : () => onTopic(names[i]),
                ),
              ),
            ),
        ]),
      );
    });
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.center, required this.topics, required this.reflections, required this.names, required this.progress});
  final Offset center;
  final List<Offset> topics;
  final List<Reflection> reflections;
  final List<String> names;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Brand.tealBright.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    final rnd = math.Random(42);
    for (final r in reflections) {
      final a = (r.ref.surah / 114) * 2 * math.pi + rnd.nextDouble() * 0.3;
      final d = 30 + (r.ref.ayah % 40) * 1.6;
      final p = center + Offset(math.cos(a), math.sin(a)) * d * progress;
      for (final t in r.tags.isEmpty ? ['—'] : r.tags) {
        final i = names.indexOf(t);
        if (i < 0) continue;
        canvas.drawLine(p, Offset.lerp(p, topics[i], progress)!, line);
      }
      canvas.drawCircle(p, 5, Paint()..color = Brand.gold);
    }
    canvas.drawCircle(center, 10, Paint()..color = Brand.teal);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.progress != progress || old.reflections != reflections;
}
