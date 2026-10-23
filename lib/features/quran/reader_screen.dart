import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../data/quran/quran_data.dart';
import '../../domain/quran_models.dart';
import '../../domain/translation_helpers.dart';
import '../../services/audio.dart';
import '../audio/mini_player.dart';
import 'ayah_actions.dart';
import 'focus_listen_screen.dart';
import 'reading_settings_sheet.dart';

/// The mushaf. Two modes share state and playback:
///  * verse mode – one verse per row, optional translation, auto-follows
///    the reciter;
///  * page mode – the 604 Madani pages with a page-turn animation.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.surah, this.initialAyah = 1});
  final int surah;
  final int initialAyah;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> with WidgetsBindingObserver {
  late int _surah = widget.surah;
  late AyahRef _anchor = AyahRef(widget.surah, widget.initialAyah);
  AyahRef? _selected;
  Timer? _readingTimer;
  bool _chrome = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 30), (_) => ref.read(activityProvider.notifier).addReadingSeconds(30));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    state == AppLifecycleState.resumed ? _startTimer() : _readingTimer?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readingTimer?.cancel();
    super.dispose();
  }

  void _onVisible(QuranData q, AyahRef r) {
    _anchor = r;
    if (_surah != r.surah) setState(() => _surah = r.surah);
    ref.read(lastReadProvider.notifier).set(r);
    ref.read(activityProvider.notifier).markAyahRead(r);
    final khatma = ref.read(khatmaProvider);
    if (khatma != null) {
      // Sequential reading: finishing the page before this verse's page.
      final page = q.pageOf(r.surah, r.ayah);
      if (page - 1 > khatma.pagesRead && page - 1 - khatma.pagesRead <= 2) {
        ref.read(khatmaProvider.notifier).markRead(page - 1);
      }
    }
  }

  void _openActions(AyahRef r) {
    setState(() => _selected = r);
    showAyahActions(context, ref, r).whenComplete(() {
      if (mounted) setState(() => _selected = null);
    });
  }

  ReadingPalette _palette(BuildContext context) {
    final kind = ref.watch(settingsProvider.select((s) => s.readingTheme));
    return switch (kind) {
      AppThemeKind.night => ReadingPalette.night,
      AppThemeKind.light => ReadingPalette.light,
      AppThemeKind.sepia => ReadingPalette.sepia,
      AppThemeKind.system => context.reading,
    };
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    final pageMode = ref.watch(settingsProvider.select((s) => s.pageMode));
    final palette = _palette(context);
    if (q == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final info = q.surah(_surah);
    final m = Motion.of(context);

    return Theme(
      data: Theme.of(context).copyWith(extensions: [palette]),
      child: Scaffold(
        backgroundColor: palette.page,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: AnimatedSlide(
            offset: _chrome ? Offset.zero : const Offset(0, -1.2),
            duration: m.medium,
            curve: Motion.emphasized,
            child: AppBar(
              backgroundColor: palette.page.withValues(alpha: 0.94),
              foregroundColor: palette.ink,
              title: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pickSurah(q),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(info.nameAr, style: TextStyle(fontFamily: Brand.quranFont, fontSize: 22, color: palette.ink)),
                      Icon(Icons.expand_more_rounded, color: palette.ink),
                    ]),
                    Text(
                      '${context.tr('juz_n', {'n': q.juzOf(_anchor.surah, _anchor.ayah)})} · ${context.tr('page_n', {'n': q.pageOf(_anchor.surah, _anchor.ayah)})}',
                      style: TextStyle(fontSize: 11, color: palette.ink.withValues(alpha: 0.6)),
                    ),
                  ]),
                ),
              ),
              actions: [
                IconButton(
                  tooltip: context.tr('focus_listen'),
                  icon: const Icon(Icons.center_focus_strong_rounded),
                  onPressed: () => push(context, FocusListenScreen(start: _anchor)),
                ),
                IconButton(
                  tooltip: context.tr('play'),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  onPressed: () => ref.read(audioProvider.notifier).playSurah(_anchor.surah, from: math.max(1, _anchor.ayah)),
                ),
                IconButton(
                  tooltip: context.tr('reading_settings'),
                  icon: const Icon(Icons.text_fields_rounded),
                  onPressed: () => showReadingSettings(context),
                ),
              ],
            ),
          ),
        ),
        body: Stack(children: [
          AnimatedSwitcher(
            duration: m.medium,
            child: pageMode
                ? _PageMode(
                    key: const ValueKey('page'),
                    quran: q,
                    initialPage: q.pageOf(_anchor.surah, math.max(1, _anchor.ayah)),
                    selected: _selected,
                    onAyahTap: _openActions,
                    onPageShown: (p) {
                      final refs = q.ayahsOnPage(p);
                      _onVisible(q, refs.first);
                    },
                    onToggleChrome: () => setState(() => _chrome = !_chrome),
                  )
                : _VerseMode(
                    key: ValueKey('verse$_surah'),
                    quran: q,
                    surah: _surah,
                    initialAyah: _anchor.surah == _surah ? _anchor.ayah : 1,
                    selected: _selected,
                    onAyahTap: _openActions,
                    onVisible: (r) => _onVisible(q, r),
                    onNextSurah: _surah < 114
                        ? () => setState(() {
                              _surah++;
                              _anchor = AyahRef(_surah, 1);
                            })
                        : null,
                    onScrollDirection: (down) {
                      if (_chrome == down) setState(() => _chrome = !down);
                    },
                  ),
          ),
          const PositionedDirectional(start: 0, end: 0, bottom: 0, child: SafeArea(child: MiniPlayer(inReader: true))),
        ]),
      ),
    );
  }

  Future<void> _pickSurah(QuranData q) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          itemCount: 114,
          itemBuilder: (context, i) {
            final s = q.surahs[i];
            return ListTile(
              selected: s.number == _surah,
              leading: Text(context.num(s.number)),
              title: Text(s.nameAr, style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 22)),
              subtitle: Text(s.translit),
              onTap: () => Navigator.pop(context, s.number),
            );
          },
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _surah = picked;
        _anchor = AyahRef(picked, 1);
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Verse mode
// ---------------------------------------------------------------------------

class _VerseMode extends ConsumerStatefulWidget {
  const _VerseMode({
    super.key,
    required this.quran,
    required this.surah,
    required this.initialAyah,
    required this.selected,
    required this.onAyahTap,
    required this.onVisible,
    required this.onNextSurah,
    required this.onScrollDirection,
  });

  final QuranData quran;
  final int surah;
  final int initialAyah;
  final AyahRef? selected;
  final void Function(AyahRef) onAyahTap;
  final void Function(AyahRef) onVisible;
  final VoidCallback? onNextSurah;
  final void Function(bool down) onScrollDirection;

  @override
  ConsumerState<_VerseMode> createState() => _VerseModeState();
}

class _VerseModeState extends ConsumerState<_VerseMode> {
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  int _lastFirst = -1;

  @override
  void initState() {
    super.initState();
    _positions.itemPositions.addListener(_onPositions);
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_onPositions);
    super.dispose();
  }

  void _onPositions() {
    final visible = _positions.itemPositions.value.where((p) => p.itemTrailingEdge > 0.15 && p.itemLeadingEdge < 0.9);
    if (visible.isEmpty) return;
    final first = visible.map((p) => p.index).reduce(math.min);
    if (first == _lastFirst) return;
    widget.onScrollDirection(first > _lastFirst && _lastFirst >= 0);
    _lastFirst = first;
    final ayah = first.clamp(1, widget.quran.surah(widget.surah).ayahCount);
    widget.onVisible(AyahRef(widget.surah, ayah));
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.quran.surah(widget.surah);
    final s = ref.watch(settingsProvider);
    final palette = context.reading;
    final playing = ref.watch(audioProvider.select((p) => p.current));
    final translation = s.showTranslation ? ref.watch(translationProvider(s.translationId)).value : null;

    ref.listen<AyahRef?>(audioProvider.select((p) => p.current), (prev, next) {
      if (next != null && next.surah == widget.surah && next.ayah > 0 && _scroll.isAttached) {
        final d = Motion.of(context).medium;
        d == Duration.zero
            ? _scroll.jumpTo(index: next.ayah, alignment: 0.2)
            : _scroll.scrollTo(index: next.ayah, duration: d, curve: Motion.emphasized, alignment: 0.2);
      }
    });

    return ScrollablePositionedList.builder(
      itemScrollController: _scroll,
      itemPositionsListener: _positions,
      initialScrollIndex: widget.initialAyah <= 1 ? 0 : widget.initialAyah,
      initialAlignment: widget.initialAyah <= 1 ? 0 : 0.12,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8, bottom: 160),
      itemCount: info.ayahCount + 2,
      itemBuilder: (context, i) {
        if (i == 0) return SurahHeader(info: info, palette: palette);
        if (i == info.ayahCount + 1) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: widget.onNextSurah == null
                ? const SizedBox.shrink()
                : FilledButton.tonalIcon(
                    onPressed: widget.onNextSurah,
                    icon: const Icon(Icons.skip_previous_rounded),
                    label: Text('${context.tr('next_surah')}: ${widget.quran.surah(widget.surah + 1).nameAr}'),
                  ),
          );
        }
        final ref0 = AyahRef(widget.surah, i);
        final isPlaying = playing == ref0;
        final isSelected = widget.selected == ref0;
        return _VerseTile(
          refAyah: ref0,
          text: widget.quran.text(widget.surah, i),
          translation: translation == null ? null : cleanTranslation(translation.of(widget.surah, i)),
          translationRtl: translation?.lang == 'ar',
          fontSize: s.quranFontSize,
          highlighted: isPlaying || isSelected,
          sajda: widget.quran.isSajda(widget.surah, i),
          rub: widget.quran.startsRub(widget.surah, i) && i > 1,
          onTap: () => widget.onAyahTap(ref0),
        );
      },
    );
  }
}

class _VerseTile extends StatelessWidget {
  const _VerseTile({
    required this.refAyah,
    required this.text,
    required this.translation,
    required this.translationRtl,
    required this.fontSize,
    required this.highlighted,
    required this.sajda,
    required this.rub,
    required this.onTap,
  });

  final AyahRef refAyah;
  final String text;
  final String? translation;
  final bool translationRtl;
  final double fontSize;
  final bool highlighted;
  final bool sajda;
  final bool rub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.reading;
    final m = Motion.of(context);
    return Semantics(
      label: '${context.tr('ayah_n', {'n': refAyah.ayah})}. $text',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: m.medium,
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: highlighted ? p.highlight : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (rub || sajda)
              Row(children: [
                if (rub) Text('۞ ${context.tr('rub_start')}', style: TextStyle(color: p.marker, fontSize: 12)),
                const Spacer(),
                if (sajda) Text('۩ ${context.tr('sajda')}', style: TextStyle(color: p.marker, fontSize: 12)),
              ]),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${text.replaceAll('۞', '').trim()} '),
                TextSpan(text: ayahMarker(refAyah.ayah), style: TextStyle(color: p.marker)),
              ]),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.justify,
              style: TextStyle(fontFamily: Brand.quranFont, fontSize: fontSize, height: 2.1, color: p.ink),
            ),
            if (translation != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  translation!,
                  textDirection: translationRtl ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(fontSize: 15, height: 1.6, color: p.ink.withValues(alpha: 0.72)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Ornamental surah title + basmala.
class SurahHeader extends StatelessWidget {
  const SurahHeader({super.key, required this.info, required this.palette});
  final SurahInfo info;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(children: [
        Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.marker.withValues(alpha: 0.7), width: 1.4),
            gradient: LinearGradient(colors: [
              palette.marker.withValues(alpha: 0.05),
              palette.marker.withValues(alpha: 0.16),
              palette.marker.withValues(alpha: 0.05),
            ]),
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            Text(info.meccan ? context.tr('meccan') : context.tr('medinan'), style: TextStyle(color: palette.ink.withValues(alpha: 0.6), fontSize: 12)),
            Expanded(
              child: Text('سُورَةُ ${info.nameAr}',
                  textAlign: TextAlign.center, style: TextStyle(fontFamily: Brand.quranFont, fontSize: 26, color: palette.ink)),
            ),
            Text(context.tr('ayahs_n', {'n': info.ayahCount}), style: TextStyle(color: palette.ink.withValues(alpha: 0.6), fontSize: 12)),
            const SizedBox(width: 14),
          ]),
        ),
        if (info.number != 1 && info.number != 9)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: Brand.quranFont, fontSize: 26, color: palette.ink),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Page mode
// ---------------------------------------------------------------------------

class _PageMode extends ConsumerStatefulWidget {
  const _PageMode({
    super.key,
    required this.quran,
    required this.initialPage,
    required this.selected,
    required this.onAyahTap,
    required this.onPageShown,
    required this.onToggleChrome,
  });

  final QuranData quran;
  final int initialPage;
  final AyahRef? selected;
  final void Function(AyahRef) onAyahTap;
  final void Function(int page) onPageShown;
  final VoidCallback onToggleChrome;

  @override
  ConsumerState<_PageMode> createState() => _PageModeState();
}

class _PageModeState extends ConsumerState<_PageMode> {
  late final PageController _pc = PageController(initialPage: widget.initialPage - 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onPageShown(widget.initialPage));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.of(context).reduced;
    ref.listen<AyahRef?>(audioProvider.select((p) => p.current), (prev, next) {
      if (next == null || next.ayah < 1 || !_pc.hasClients) return;
      final page = widget.quran.pageOf(next.surah, next.ayah);
      if ((_pc.page?.round() ?? 0) + 1 != page) {
        goToPage(context, _pc, page - 1);
      }
    });
    // The mushaf is always right-to-left, whatever the UI language.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PageView.builder(
        controller: _pc,
        itemCount: QuranData.totalPages,
        onPageChanged: (i) => widget.onPageShown(i + 1),
        itemBuilder: (context, i) => AnimatedBuilder(
          animation: _pc,
          builder: (context, child) {
            if (reduced || !_pc.hasClients || !_pc.position.haveDimensions) return child!;
            final delta = (_pc.page ?? i.toDouble()) - i;
            return _PageTurn(delta: delta, child: child!);
          },
          child: GestureDetector(
            onDoubleTap: widget.onToggleChrome,
            child: MushafPage(
              quran: widget.quran,
              page: i + 1,
              selected: widget.selected,
              onAyahTap: widget.onAyahTap,
            ),
          ),
        ),
      ),
    );
  }
}

/// A light 3D page-turn: the leaving page folds around the spine and the
/// incoming page brightens from the fold's shadow.
class _PageTurn extends StatelessWidget {
  const _PageTurn({required this.delta, required this.child});
  final double delta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = delta.clamp(-1.0, 1.0);
    if (d.abs() < 0.001) return child;
    final leaving = d > 0; // page index lower than the controller position
    final angle = (leaving ? d : -d) * math.pi / 2.4;
    final shade = (d.abs() * 0.45).clamp(0.0, 0.45);
    return Transform(
      // RTL book: the spine is on the right edge.
      alignment: leaving ? Alignment.centerRight : Alignment.centerLeft,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(leaving ? -angle : angle * 0.15),
      child: Stack(fit: StackFit.passthrough, children: [
        child,
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: leaving ? Alignment.centerRight : Alignment.centerLeft,
                end: leaving ? Alignment.centerLeft : Alignment.centerRight,
                colors: [Colors.black.withValues(alpha: shade), Colors.transparent],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// One Madani page: verses flow as justified text, tappable per verse.
class MushafPage extends ConsumerStatefulWidget {
  const MushafPage({super.key, required this.quran, required this.page, this.selected, required this.onAyahTap});
  final QuranData quran;
  final int page;
  final AyahRef? selected;
  final void Function(AyahRef) onAyahTap;

  @override
  ConsumerState<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends ConsumerState<MushafPage> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final q = widget.quran;
    final p = context.reading;
    final s = ref.watch(settingsProvider);
    final playing = ref.watch(audioProvider.select((x) => x.current));
    final refs = q.ayahsOnPage(widget.page);
    final first = refs.first;
    final style = TextStyle(fontFamily: Brand.quranFont, fontSize: s.quranFontSize * 0.86, height: 2.05, color: p.ink);

    final blocks = <Widget>[];
    var spans = <InlineSpan>[];
    void flush() {
      if (spans.isEmpty) return;
      blocks.add(Text.rich(TextSpan(children: spans), textAlign: TextAlign.justify, style: style));
      spans = [];
    }

    for (final r in refs) {
      if (r.ayah == 1) {
        flush();
        blocks.add(SurahHeader(info: q.surah(r.surah), palette: p));
      }
      final rec = TapGestureRecognizer()..onTap = () => widget.onAyahTap(r);
      _recognizers.add(rec);
      final hl = r == playing || r == widget.selected;
      spans.add(TextSpan(
        text: '${q.text(r.surah, r.ayah).replaceAll('۞', '۞ ')} ',
        recognizer: rec,
        style: hl ? TextStyle(backgroundColor: p.highlight) : null,
        semanticsLabel: '${context.tr('ayah_n', {'n': r.ayah})} ${q.text(r.surah, r.ayah)}',
      ));
      spans.add(TextSpan(text: '${ayahMarker(r.ayah)} ', style: TextStyle(color: p.marker), recognizer: rec));
    }
    flush();

    final surahNames = refs.map((r) => r.surah).toSet().map((n) => q.surah(n).nameAr).join(' · ');
    return Container(
      color: p.page,
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 4, 20, 4),
            child: Row(children: [
              Text(surahNames, style: TextStyle(fontFamily: Brand.naskhFont, color: p.ink.withValues(alpha: 0.65), fontSize: 14)),
              const Spacer(),
              Text(context.tr('juz_n', {'n': q.juzOf(first.surah, first.ayah)}), style: TextStyle(color: p.ink.withValues(alpha: 0.65), fontSize: 13)),
            ]),
          ),
          Divider(color: p.marker.withValues(alpha: 0.35), indent: 20, endIndent: 20, height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 90),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 70),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: p.marker.withValues(alpha: 0.6)), borderRadius: BorderRadius.circular(20)),
              child: Text(context.num(widget.page), style: TextStyle(color: p.ink)),
            ),
          ),
        ]),
      ),
    );
  }
}
