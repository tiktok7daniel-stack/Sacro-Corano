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
import '../../data/quran/mushaf_layout.dart';
import '../../data/quran/quran_data.dart';
import '../../data/quran/word_data.dart';
import '../../domain/quran_models.dart';
import '../../domain/translation_helpers.dart';
import '../../services/audio.dart';
import '../audio/mini_player.dart';
import 'ayah_actions.dart';
import 'focus_listen_screen.dart';
import 'reading_settings_sheet.dart';
import 'widgets/tajweed_text.dart';
import 'word_sheet.dart';

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
  Timer? _hideChrome;
  bool _chrome = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    // Mushaf pages: the bars step aside after a moment so the page header
    // shows; a tap on the page brings them back.
    if (ref.read(settingsProvider).pageMode) {
      _hideChrome = Timer(const Duration(milliseconds: 2500), () {
        if (mounted && ref.read(settingsProvider).pageMode) setState(() => _chrome = false);
      });
    }
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
    _hideChrome?.cancel();
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
    final tajweed = s.tajweed ? ref.watch(tajweedProvider).value : null;
    final colors = tajweedColors(dark: palette.page.computeLuminance() < 0.3);

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
          runs: tajweed?.runs(widget.surah, i) ?? const [],
          classes: tajweed?.classes ?? const [],
          colors: colors,
          onTap: () => widget.onAyahTap(ref0),
          onWord: (w) => showWordSheet(context, ref0, word: w),
        );
      },
    );
  }
}

class _VerseTile extends StatefulWidget {
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
    required this.onWord,
    this.runs = const [],
    this.classes = const [],
    this.colors = const {},
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
  final void Function(int word) onWord;
  final List<int> runs;
  final List<String> classes;
  final Map<String, Color> colors;

  @override
  State<_VerseTile> createState() => _VerseTileState();
}

class _VerseTileState extends State<_VerseTile> {
  final _recognizers = <GestureRecognizer>[];

  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.reading;
    final m = Motion.of(context);
    final w = widget;
    final refAyah = w.refAyah;
    final text = w.text;
    final translation = w.translation;
    final highlighted = w.highlighted;
    _clear();
    return Semantics(
      label: '${context.tr('ayah_n', {'n': refAyah.ayah})}. $text',
      button: true,
      child: InkWell(
        onTap: w.onTap,
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
            if (w.rub || w.sajda)
              Row(children: [
                if (w.rub) Text('۞ ${context.tr('rub_start')}', style: TextStyle(color: p.marker, fontSize: 12)),
                const Spacer(),
                if (w.sajda) Text('۩ ${context.tr('sajda')}', style: TextStyle(color: p.marker, fontSize: 12)),
              ]),
            Text.rich(
              TextSpan(children: [
                ...verseSpans(
                  text,
                  runs: w.runs,
                  classes: w.classes,
                  colors: w.colors,
                  onWordLongPress: w.onWord,
                  recognizers: _recognizers,
                ),
                const TextSpan(text: ' '),
                TextSpan(text: ayahMarker(refAyah.ayah), style: TextStyle(color: p.marker)),
              ]),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.justify,
              style: TextStyle(fontFamily: Brand.quranFont, fontSize: w.fontSize, height: 2.1, color: p.ink),
            ),
            if (translation != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  translation,
                  textDirection: w.translationRtl ? TextDirection.rtl : TextDirection.ltr,
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
            behavior: HitTestBehavior.translucent,
            onTap: widget.onToggleChrome,
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

/// One Madani page laid out like a printed mushaf: a framed page that
/// always fits the screen (the text size is chosen so the whole page fits,
/// never above the reader's own size), the surah and juz in the header,
/// the page number at the foot, and every verse tappable.
class MushafPage extends ConsumerStatefulWidget {
  const MushafPage({super.key, required this.quran, required this.page, this.selected, required this.onAyahTap});
  final QuranData quran;
  final int page;
  final AyahRef? selected;
  final void Function(AyahRef) onAyahTap;

  @override
  ConsumerState<MushafPage> createState() => _MushafPageState();
}

/// A run of verses, or a surah banner (with its basmala when it has one).
class _Segment {
  _Segment.text(this.spans) : surah = null;
  _Segment.banner(this.surah) : spans = const [];
  final List<InlineSpan> spans;
  final SurahInfo? surah;
}

const _basmala = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';
const _lineHeight = 1.95;

/// Text sizes already fitted, by page and box; layout is the costly part.
final _fitCache = <String, double>{};

class _MushafPageState extends ConsumerState<MushafPage> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  static double _bannerHeight(double fs) => fs * 1.7;
  static bool _hasBasmala(SurahInfo s) => s.number != 1 && s.number != 9;

  /// Height of the page's content at font size [fs] in a column [width] wide.
  static double _heightAt(List<_Segment> segments, double fs, double width, TextStyle base) {
    var h = 0.0;
    for (final seg in segments) {
      final style = base.copyWith(fontSize: fs);
      final painter = TextPainter(textDirection: TextDirection.rtl, textAlign: TextAlign.justify, textScaler: TextScaler.noScaling);
      if (seg.surah != null) {
        h += _bannerHeight(fs) + fs * 0.3;
        if (_hasBasmala(seg.surah!)) {
          painter.text = TextSpan(text: _basmala, style: style);
          painter.layout(maxWidth: width);
          h += painter.height;
        }
      } else {
        painter.text = TextSpan(style: style, children: seg.spans);
        painter.layout(maxWidth: width);
        h += painter.height;
      }
      painter.dispose();
    }
    return h;
  }

  /// The largest size (up to [maxSize]) at which the page fits [height].
  static double _fit(String key, List<_Segment> segments, double width, double height, double maxSize, TextStyle base) {
    final cached = _fitCache[key];
    if (cached != null) return cached;
    var lo = 10.0;
    var hi = maxSize;
    if (_heightAt(segments, hi, width, base) <= height) {
      lo = hi;
    } else {
      for (var i = 0; i < 9; i++) {
        final mid = (lo + hi) / 2;
        if (_heightAt(segments, mid, width, base) <= height) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
    }
    if (_fitCache.length > 400) _fitCache.clear();
    return _fitCache[key] = lo;
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
    final tajweed = s.tajweed ? ref.watch(tajweedProvider).value : null;
    final dark = p.page.computeLuminance() < 0.3;
    final colors = tajweedColors(dark: dark);
    final base = TextStyle(fontFamily: Brand.quranFont, height: _lineHeight, color: p.ink);
    final layout = ref.watch(mushafLayoutProvider).value;

    final segments = <_Segment>[];
    var spans = <InlineSpan>[];
    void flush() {
      if (spans.isNotEmpty) segments.add(_Segment.text(spans));
      spans = <InlineSpan>[];
    }

    for (final r in refs) {
      if (r.ayah == 1) {
        flush();
        segments.add(_Segment.banner(q.surah(r.surah)));
      }
      final rec = TapGestureRecognizer()..onTap = () => widget.onAyahTap(r);
      _recognizers.add(rec);
      final hl = r == playing || r == widget.selected;
      spans.add(TextSpan(
        style: hl ? TextStyle(backgroundColor: p.highlight) : null,
        children: [
          // A label needs text of its own: a zero-width space carries it.
          TextSpan(text: '​', semanticsLabel: '${context.tr('ayah_n', {'n': r.ayah})} ${q.text(r.surah, r.ayah)}', recognizer: rec),
          ...verseSpans(
            q.text(r.surah, r.ayah),
            runs: tajweed?.runs(r.surah, r.ayah) ?? const [],
            classes: tajweed?.classes ?? const [],
            colors: colors,
            tap: rec,
          ),
          TextSpan(text: ' ', recognizer: rec),
        ],
      ));
      spans.add(TextSpan(text: '${ayahMarker(r.ayah)} ', style: TextStyle(color: p.marker), recognizer: rec));
    }
    flush();

    final surahs = refs.map((r) => r.surah).toSet().toList();
    final headerStyle = TextStyle(fontFamily: Brand.naskhFont, color: p.ink.withValues(alpha: 0.75), fontSize: 13, fontWeight: FontWeight.w600);
    final frame = p.marker;
    // Odd pages sit on the right of the open book: the spine is on their left.
    final spineOnLeft = widget.page.isOdd;

    return ColoredBox(
      color: Color.alphaBlend(frame.withValues(alpha: dark ? 0.06 : 0.12), p.page),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: p.page,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: frame, width: 2.2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.4 : 0.15), blurRadius: 8, offset: const Offset(0, 3))],
              gradient: LinearGradient(
                begin: spineOnLeft ? Alignment.centerLeft : Alignment.centerRight,
                end: spineOnLeft ? Alignment.centerRight : Alignment.centerLeft,
                stops: const [0, 0.06, 1],
                colors: [Color.alphaBlend(Colors.black.withValues(alpha: dark ? 0.25 : 0.08), p.page), p.page, p.page],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: frame.withValues(alpha: 0.55)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: Column(children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        surahs.map((n) => 'سورة ${q.surah(n).nameAr}').join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: headerStyle,
                      ),
                    ),
                    Text(
                      '${context.tr('juz_n', {'n': q.juzOf(first.surah, first.ayah)})} · ${context.tr('hizb_n', {'n': q.hizbOf(first.surah, first.ayah)})}',
                      style: headerStyle,
                    ),
                  ]),
                ),
                Divider(color: frame.withValues(alpha: 0.45), height: 10),
                Expanded(
                  child: layout != null && layout.page(widget.page).isNotEmpty
                      ? _LinedPage(
                          quran: q,
                          page: widget.page,
                          lines: layout.page(widget.page),
                          palette: p,
                          tajweed: tajweed,
                          colors: colors,
                          highlighted: {?playing, ?widget.selected},
                          onAyahTap: widget.onAyahTap,
                        )
                      : LayoutBuilder(builder: (context, box) {
                    final key = '${widget.page}|${box.maxWidth.round()}x${box.maxHeight.round()}|${s.quranFontSize}|${tajweed != null}';
                    final fs = _fit(key, segments, box.maxWidth, box.maxHeight, s.quranFontSize, base);
                    final style = base.copyWith(fontSize: fs);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final seg in segments)
                          if (seg.surah != null) ...[
                            _SurahBanner(info: seg.surah!, size: fs, palette: p),
                            SizedBox(height: fs * 0.3),
                            if (_hasBasmala(seg.surah!))
                              Text(_basmala,
                                  textAlign: TextAlign.center, textDirection: TextDirection.rtl, textScaler: TextScaler.noScaling, style: style),
                          ] else
                            Text.rich(
                              TextSpan(children: seg.spans),
                              textAlign: TextAlign.justify,
                              textDirection: TextDirection.rtl,
                              textScaler: TextScaler.noScaling,
                              style: style,
                            ),
                      ],
                    );
                  }),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
                  decoration: BoxDecoration(
                    border: Border.all(color: frame.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(context.num(widget.page), style: TextStyle(color: p.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A page drawn line for line as printed: 15 lines (8 on the first two
/// pages, set in the middle), every line justified edge to edge, words
/// tappable (verse actions) and long-pressable (word meaning).
class _LinedPage extends ConsumerWidget {
  const _LinedPage({
    required this.quran,
    required this.page,
    required this.lines,
    required this.palette,
    required this.tajweed,
    required this.colors,
    required this.highlighted,
    required this.onAyahTap,
  });

  final QuranData quran;
  final int page;
  final List<MushafLine> lines;
  final ReadingPalette palette;
  final TajweedData? tajweed;
  final Map<String, Color> colors;
  final Set<AyahRef> highlighted;
  final void Function(AyahRef) onAyahTap;

  static const _ref = 20.0;

  /// Natural width (at [_ref] px) of each line's tokens, measured once per
  /// page: the font size is then the largest at which every line fits.
  static final _widthCache = <int, List<List<double>>>{};

  List<List<double>> _widths(Map<int, List<List<InlineSpan>>> words, TextStyle base) {
    final cached = _widthCache[page];
    if (cached != null) return cached;
    final style = base.copyWith(fontSize: _ref);
    final out = <List<double>>[];
    for (final line in lines) {
      final row = <double>[];
      if (line.isWords) {
        for (var i = 0; i < line.length; i++) {
          final tp = TextPainter(
            text: TextSpan(style: style, children: _token(line, i, words, style)),
            textDirection: TextDirection.rtl,
            textScaler: TextScaler.noScaling,
          )..layout();
          row.add(tp.width);
          tp.dispose();
        }
      }
      out.add(row);
    }
    if (_widthCache.length > 60) _widthCache.clear();
    return _widthCache[page] = out;
  }

  List<InlineSpan> _token(MushafLine line, int i, Map<int, List<List<InlineSpan>>> words, TextStyle style) {
    final s = line.surahAt(i);
    final a = line.ayahAt(i);
    final w = line.wordAt(i);
    if (w < 0) return [TextSpan(text: ayahMarker(a), style: TextStyle(color: palette.marker))];
    final list = words[s * 1000 + a]!;
    return w < list.length ? list[w] : const [];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = TextStyle(fontFamily: Brand.quranFont, color: palette.ink, height: 1.55);
    // Spans of every verse on the page, split into words.
    final words = <int, List<List<InlineSpan>>>{};
    for (final line in lines) {
      for (var i = 0; i < line.length; i++) {
        final key = line.surahAt(i) * 1000 + line.ayahAt(i);
        words.putIfAbsent(
          key,
          () => wordSpanLists(
            quran.text(line.surahAt(i), line.ayahAt(i)),
            runs: tajweed?.runs(line.surahAt(i), line.ayahAt(i)) ?? const [],
            classes: tajweed?.classes ?? const [],
            colors: colors,
          ),
        );
      }
    }
    final widths = _widths(words, base);
    final opening = page <= 2;

    return LayoutBuilder(builder: (context, box) {
      final width = opening ? box.maxWidth * 0.84 : box.maxWidth;
      // Largest size where every line fits its width with a small gap
      // between words, and the line fits its slot.
      // (the opening frame adds about 2 lines of padding)
      var fs = opening ? (box.maxHeight - 12) / (lines.length * 2.2 + 2) : box.maxHeight / 15 / 1.62;
      for (final row in widths) {
        if (row.isEmpty) continue;
        final natural = row.fold<double>(0, (a, b) => a + b) + _ref * 0.18 * (row.length - 1);
        fs = math.min(fs, width / natural * _ref);
      }
      // The opening pages are set in a block in the middle of the page.
      final slot = opening ? fs * 2.2 : box.maxHeight / 15;
      final style = base.copyWith(fontSize: fs);
      final gap = fs * 0.18;

      Widget wordsLine(int li) {
        final line = lines[li];
        final natural = widths[li].fold<double>(0, (a, b) => a + b) * fs / _ref + gap * (line.length - 1);
        // A short line (the end of a surah) is centred, as in print.
        final justify = !opening && natural > width * 0.72;
        final children = <Widget>[];
        for (var i = 0; i < line.length; i++) {
          final r = AyahRef(line.surahAt(i), line.ayahAt(i));
          final w = line.wordAt(i);
          if (!justify && i > 0) children.add(SizedBox(width: gap));
          children.add(GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onAyahTap(r),
            onLongPress: w < 0 ? null : () => showWordSheet(context, r, word: w),
            child: DecoratedBox(
              decoration: BoxDecoration(color: highlighted.contains(r) ? palette.highlight : null, borderRadius: BorderRadius.circular(4)),
              child: Text.rich(
                TextSpan(children: _token(line, i, words, style)),
                textDirection: TextDirection.rtl,
                textScaler: TextScaler.noScaling,
                maxLines: 1,
                softWrap: false,
                style: style,
              ),
            ),
          ));
        }
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Row(mainAxisAlignment: justify ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center, children: children),
        );
      }

      final block = SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (li, line) in lines.indexed)
                SizedBox(
                  height: slot,
                  child: Center(
                    child: switch (line) {
                      _ when line.isHeader => _SurahBanner(info: quran.surah(line.surah!), size: math.min(fs, slot / 1.85), palette: palette),
                      _ when line.basmala => Text(_basmala,
                          textDirection: TextDirection.rtl, textScaler: TextScaler.noScaling, maxLines: 1, style: style),
                      // Safety net: a line never overflows, it shrinks.
                      _ => FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: width, child: wordsLine(li))),
                    },
                  ),
                ),
            ],
          ),
        );
      if (!opening) return Center(child: block);
      // The opening pages: the text in a decorated double frame.
      return Center(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.marker, width: 2),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: box.maxWidth * 0.04, vertical: fs * 0.8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.marker.withValues(alpha: 0.5)),
              gradient: RadialGradient(colors: [palette.marker.withValues(alpha: 0.07), palette.marker.withValues(alpha: 0.0)]),
            ),
            child: block,
          ),
        ),
      );
    });
  }
}

/// The ornamental surah title inside a mushaf page, sized with the text.
class _SurahBanner extends StatelessWidget {
  const _SurahBanner({required this.info, required this.size, required this.palette});
  final SurahInfo info;
  final double size;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        height: _MushafPageState._bannerHeight(size),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.5),
          border: Border.all(color: palette.marker.withValues(alpha: 0.8), width: 1.4),
          gradient: LinearGradient(colors: [
            palette.marker.withValues(alpha: 0.06),
            palette.marker.withValues(alpha: 0.2),
            palette.marker.withValues(alpha: 0.06),
          ]),
        ),
        child: Text(
          'سُورَةُ ${info.nameAr}',
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontFamily: Brand.quranFont, fontSize: size * 0.9, height: 1.2, color: palette.ink),
        ),
      );
}
