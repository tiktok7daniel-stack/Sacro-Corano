import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/arabic.dart';
import '../../core/widgets/common.dart';
import '../../domain/search_engine.dart';
import 'reader_screen.dart';

/// Full-text search over the mushaf (Arabic, normalised) or the selected
/// translation, with surah / juz / revelation filters.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  SearchMode _mode = SearchMode.allWords;
  SearchScope _scope = SearchScope.quran;
  bool? _revelation;
  int? _juz;
  int? _surah;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => setState(() => _query = v));
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(searchEngineProvider);
    final q = ref.watch(quranProvider).value;
    final s = ref.watch(settingsProvider);
    final translation = ref.watch(translationProvider(s.translationId)).value;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: context.tr('search_hint'),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            filled: false,
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
      ),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip(context.tr('scope_quran'), _scope == SearchScope.quran, () => setState(() => _scope = SearchScope.quran)),
              _chip(context.tr('scope_translation'), _scope == SearchScope.translation, () => setState(() => _scope = SearchScope.translation)),
              const VerticalDivider(),
              _chip(context.tr('mode_all'), _mode == SearchMode.allWords, () => setState(() => _mode = SearchMode.allWords)),
              _chip(context.tr('mode_phrase'), _mode == SearchMode.phrase, () => setState(() => _mode = SearchMode.phrase)),
              _chip(context.tr('mode_any'), _mode == SearchMode.anyWord, () => setState(() => _mode = SearchMode.anyWord)),
              const VerticalDivider(),
              _chip(context.tr('meccan'), _revelation == true, () => setState(() => _revelation = _revelation == true ? null : true)),
              _chip(context.tr('medinan'), _revelation == false, () => setState(() => _revelation = _revelation == false ? null : false)),
              ActionChip(
                label: Text(_juz == null ? context.tr('juz') : context.tr('juz_n', {'n': _juz!})),
                onPressed: () async {
                  final v = await _pickNumber(context, 30, context.tr('juz'));
                  setState(() => _juz = v);
                },
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: Text(_surah == null || q == null ? context.tr('surah') : q.surah(_surah!).nameAr),
                onPressed: () async {
                  final v = await _pickNumber(context, 114, context.tr('surah'), label: (n) => q?.surah(n).nameAr ?? '$n');
                  setState(() => _surah = v);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<SearchEngine>(
            value: engine,
            builder: (e) {
              if (_query.trim().isEmpty) {
                return EmptyState(icon: Icons.manage_search_rounded, title: context.tr('search_empty_title'), body: context.tr('search_empty_body'));
              }
              final hits = e.search(
                _query,
                mode: _mode,
                scope: _scope,
                translation: translation,
                filter: SearchFilter(
                  fromSurah: _surah ?? 1,
                  toSurah: _surah ?? 114,
                  revelation: _revelation,
                  juz: _juz,
                ),
              );
              if (hits.isEmpty) return EmptyState(icon: Icons.search_off_rounded, title: context.tr('no_results'));
              final needle = normalizeArabic(_query);
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(context.tr('results_n', {'n': hits.length}), style: const TextStyle(color: Brand.gold)),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    itemCount: hits.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final h = hits[i];
                      final showTr = _scope == SearchScope.translation || !isArabic(_query);
                      return AppCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => push(context, ReaderScreen(surah: h.ref.surah, initialAyah: h.ref.ayah)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('${q!.surah(h.ref.surah).nameAr} · ${context.num(h.ref.ayah)}',
                              style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 6),
                          if (showTr && translation != null)
                            Text(translation.of(h.ref.surah, h.ref.ayah), maxLines: 3, overflow: TextOverflow.ellipsis)
                          else
                            _HighlightedVerse(text: q.textOf(h.ref), needle: needle),
                        ]),
                      );
                    },
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: FilterChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );

  Future<int?> _pickNumber(BuildContext context, int max, String title, {String Function(int)? label}) =>
      showModalBottomSheet<int?>(
        context: context,
        builder: (context) => Column(children: [
          ListTile(title: Text(title), trailing: TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('clear')))),
          Expanded(
            child: ListView.builder(
              itemCount: max,
              itemBuilder: (context, i) => ListTile(
                title: Text(label?.call(i + 1) ?? context.num(i + 1)),
                onTap: () => Navigator.pop(context, i + 1),
              ),
            ),
          ),
        ]),
      );
}

/// Highlights matching words by comparing normalised forms word by word.
class _HighlightedVerse extends StatelessWidget {
  const _HighlightedVerse({required this.text, required this.needle});
  final String text;
  final String needle;

  @override
  Widget build(BuildContext context) {
    final words = needle.split(' ').where((w) => w.isNotEmpty).toList();
    final spans = <TextSpan>[];
    for (final w in text.split(' ')) {
      final n = normalizeArabic(w);
      final n2 = normalizeArabic(w, daggerAsAlef: true);
      final hit = words.any((x) => n.contains(x) || n2.contains(x));
      spans.add(TextSpan(text: '$w ', style: hit ? const TextStyle(color: Brand.gold) : null));
    }
    return Text.rich(
      TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 21, height: 1.9),
    );
  }
}
