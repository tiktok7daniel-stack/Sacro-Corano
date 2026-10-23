import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/brand.dart';
import '../../domain/quran_models.dart';
import '../../domain/user_models.dart';

/// Topics a reflection can be filed under (also the nodes of the
/// reflection map). Users can add their own.
const reflectionTopics = ['rahma', 'sabr', 'tawakkul', 'shukr', 'dua', 'akhira', 'akhlaq', 'family', 'stories', 'tawba'];

String topicLabel(BuildContext context, String id) {
  final key = 'topic_$id';
  final v = context.tr(key);
  return v == key ? id : v;
}

Future<void> showReflectionEditor(BuildContext context, WidgetRef ref, AyahRef r, {Reflection? existing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _Editor(refAyah: r, existing: existing),
      ),
    );

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.refAyah, this.existing});
  final AyahRef refAyah;
  final Reflection? existing;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final _text = TextEditingController(text: widget.existing?.text ?? '');
  late final Set<String> _tags = {...?widget.existing?.tags};
  final _custom = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _save() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    final c = ref.read(reflectionsProvider.notifier);
    widget.existing == null ? c.add(widget.refAyah, t, _tags.toList()) : c.edit(widget.existing!.id, t, _tags.toList());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    if (q == null) return const Center(child: CircularProgressIndicator());
    final used = ref.watch(reflectionsProvider).expand((r) => r.tags).toSet();
    final topics = {...reflectionTopics, ...used, ..._tags};
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.tr('reflection'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(q.textOf(widget.refAyah),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 19, height: 1.8, color: Brand.textMid)),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            decoration: InputDecoration(hintText: context.tr('reflection_hint')),
          ),
          const SizedBox(height: 12),
          Text(context.tr('topics')),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final t in topics)
              FilterChip(
                label: Text(topicLabel(context, t)),
                selected: _tags.contains(t),
                onSelected: (v) => setState(() => v ? _tags.add(t) : _tags.remove(t)),
              ),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _custom,
                decoration: InputDecoration(hintText: context.tr('new_topic'), isDense: true),
                onSubmitted: (v) {
                  if (v.trim().isEmpty) return;
                  setState(() => _tags.add(v.trim()));
                  _custom.clear();
                },
              ),
            ),
          ]),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(context.tr('save'))),
        ]),
      ),
    );
  }
}
