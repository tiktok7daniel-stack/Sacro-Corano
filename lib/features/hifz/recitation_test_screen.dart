import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/arabic.dart';
import '../../core/widgets/common.dart';
import '../../data/quran/word_data.dart';
import '../../domain/recitation_match.dart';
import '../../services/audio.dart';
import '../celebration/celebration.dart';

/// The device speech recogniser, swappable in tests.
final speechProvider = Provider<SpeechToText>((ref) => SpeechToText());

/// Recite from memory and watch the words appear as they are recognised;
/// skipped or wrong words are revealed in red. Uses the phone's own speech
/// recognition (Google's on most Android phones), so accuracy depends on it.
class RecitationTestScreen extends ConsumerStatefulWidget {
  const RecitationTestScreen({super.key, required this.surah, required this.from, required this.to});
  final int surah;
  final int from;
  final int to;

  @override
  ConsumerState<RecitationTestScreen> createState() => _RecitationTestScreenState();
}

class _RecitationTestScreenState extends ConsumerState<RecitationTestScreen> {
  late final SpeechToText _stt = ref.read(speechProvider);
  final List<String> _committed = [];
  String _partial = '';
  List<ExpectedWord> _expected = const [];
  List<int> _verseOf = const [];
  RecitationAlignment? _align;
  bool _ready = false;
  bool _unavailable = false;
  bool _active = false;
  bool _showText = false;
  int _hints = 0;
  String? _locale;
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(audioProvider.notifier).stop());
    _init();
  }

  Future<void> _init() async {
    final q = await ref.read(quranProvider.future);
    final words = <ExpectedWord>[];
    final verseOf = <int>[];
    for (var a = widget.from; a <= widget.to; a++) {
      for (final w in verseWords(q.text(widget.surah, a))) {
        words.add(ExpectedWord(w));
        verseOf.add(a);
      }
    }
    var ok = false;
    try {
      ok = await _stt.initialize(onStatus: _onStatus, onError: _onError);
      if (ok) {
        final locales = await _stt.locales();
        final ar = locales.where((l) => l.localeId.toLowerCase().startsWith('ar')).toList();
        _locale = ar.isEmpty ? 'ar-SA' : (ar.firstWhere((l) => l.localeId.contains('SA'), orElse: () => ar.first)).localeId;
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _expected = words;
      _verseOf = verseOf;
      _align = alignRecitation(words, const []);
      _ready = true;
      _unavailable = !ok;
    });
  }

  @override
  void dispose() {
    _active = false;
    _stt.cancel();
    super.dispose();
  }

  void _onStatus(String status) {
    // Android ends a session after a pause; keep listening until the
    // passage is done or the user stops.
    if ((status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) && _active && mounted) {
      _commitPartial();
      if (!(_align?.done ?? false)) {
        Timer(const Duration(milliseconds: 250), () {
          if (_active && mounted && !_stt.isListening) _listen();
        });
      }
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted) return;
    // "no match" and timeouts just mean silence; restart quietly.
    if (e.permanent && e.errorMsg != 'error_no_match' && e.errorMsg != 'error_speech_timeout') {
      setState(() => _active = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('speech_error'))));
    }
  }

  void _commitPartial() {
    if (_partial.trim().isEmpty) return;
    _committed.addAll(_partial.trim().split(RegExp(r'\s+')));
    _partial = '';
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!mounted) return;
    setState(() {
      _partial = r.recognizedWords;
      if (r.finalResult) _commitPartial();
      _realign();
    });
  }

  void _realign() {
    final spoken = [..._committed, ..._partial.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty)];
    final a = alignRecitation(_expected, spoken);
    // Words revealed with a hint count as missed, not recited.
    _align = a;
    if (a.done && _active) {
      _active = false;
      _stt.stop();
      _finish();
    }
  }

  void _finish() {
    final a = _align!;
    if (_celebrated || a.states.isEmpty) return;
    _celebrated = true;
    haptic(ref, HapticKind.medium);
    final score = (a.correct * 100 / a.states.length).round();
    if (score >= 90) {
      showCelebration(context, title: context.tr('recitation_excellent'), subtitle: context.tr('score_n', {'n': score}));
    }
  }

  Future<void> _listen() async {
    try {
      await _stt.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 6),
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _active = false);
    }
  }

  void _toggle() {
    if (_active) {
      setState(() => _active = false);
      _stt.stop();
      _commitPartial();
      return;
    }
    if (_align?.done ?? false) _reset();
    setState(() => _active = true);
    _listen();
  }

  void _reset() {
    _stt.cancel();
    setState(() {
      _committed.clear();
      _partial = '';
      _hints = 0;
      _celebrated = false;
      _active = false;
      _align = alignRecitation(_expected, const []);
    });
  }

  void _hint() {
    final a = _align;
    if (a == null || a.done) return;
    // Treat the next word as heard so the reciter can carry on.
    setState(() {
      _hints++;
      _committed.add(_expected[a.position].a);
      _realign();
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    final a = _align;
    final pulse = Motion.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('test_recitation')),
        actions: [
          IconButton(
            tooltip: context.tr(_showText ? 'hide_text' : 'show_text'),
            onPressed: () => setState(() => _showText = !_showText),
            icon: Icon(_showText ? Icons.visibility_off_rounded : Icons.visibility_rounded),
          ),
          IconButton(tooltip: context.tr('restart'), onPressed: _ready ? _reset : null, icon: const Icon(Icons.restart_alt_rounded)),
        ],
      ),
      body: !_ready || q == null || a == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      '${q.surah(widget.surah).nameAr} · ${context.num(widget.from)}${widget.to > widget.from ? '–${context.num(widget.to)}' : ''}',
                      style: const TextStyle(color: Brand.tealBright, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Pill('${context.num(a.correct)} / ${context.num(a.states.length)}'),
                ]),
              ),
              LinearProgressIndicator(value: a.states.isEmpty ? 0 : a.position / a.states.length, color: Brand.gold, backgroundColor: Colors.transparent),
              if (_unavailable)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppCard(borderColor: Colors.orange, child: Text(context.tr('speech_unavailable'), style: const TextStyle(height: 1.6))),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Wrap(
                    textDirection: TextDirection.rtl,
                    spacing: 6,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < _expected.length; i++) ...[
                        _Word(word: _expected[i].display, state: a.states[i], visible: _showText || a.states[i] != WordState.pending, next: i == a.position && _active),
                        if (i + 1 == _expected.length || _verseOf[i + 1] != _verseOf[i])
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(ayahMarker(_verseOf[i]), style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 22, color: Brand.gold)),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (a.done)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: AppCard(
                    child: Row(children: [
                      const Icon(Icons.emoji_events_rounded, color: Brand.gold, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(context.tr('score_n', {'n': (a.correct * 100 / a.states.length).round()}), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(context.tr('recitation_summary', {'m': a.missed, 'h': _hints}), style: const TextStyle(color: Brand.textMid)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              if (!_active && _partial.isEmpty && _committed.isEmpty && !_unavailable)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(context.tr('recitation_hint'), textAlign: TextAlign.center, style: const TextStyle(color: Brand.textMid, height: 1.5)),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Row(children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: a.done ? null : _hint,
                        icon: const Icon(Icons.lightbulb_outline_rounded),
                        label: Text(context.tr('next_word_hint')),
                      ),
                    ),
                    _MicButton(active: _active, enabled: !_unavailable, animate: !pulse.reduced, onTap: _toggle),
                    Expanded(
                      child: Text(
                        _active ? context.tr('listening') : (a.done ? context.tr('done_tap_retry') : context.tr('tap_to_recite')),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _active ? Brand.gold : Brand.textMid),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.word, required this.state, required this.visible, required this.next});
  final String word;
  final WordState state;
  final bool visible;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      WordState.correct => Brand.tealBright,
      WordState.missed => const Color(0xFFFF6B6B),
      WordState.pending => Theme.of(context).colorScheme.onSurface,
    };
    if (!visible) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: (word.runes.where(isArabicLetter).length * 13.0).clamp(26, 120),
        height: 30,
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: next ? Brand.gold.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }
    return Text(
      word,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: Brand.quranFont,
        fontSize: 26,
        height: 1.9,
        color: color,
        decoration: state == WordState.missed ? TextDecoration.underline : null,
        decorationColor: color,
      ),
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({required this.active, required this.enabled, required this.animate, required this.onTap});
  final bool active;
  final bool enabled;
  final bool animate;
  final VoidCallback onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(covariant _MicButton old) {
    super.didUpdateWidget(old);
    if (widget.active && widget.animate) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: context.tr(widget.active ? 'stop' : 'tap_to_recite'),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: widget.active ? const [Color(0xFFE53935), Color(0xFFFF7961)] : Brand.gKhatma),
              ),
              child: Icon(widget.active ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 36),
            ),
          ),
        ),
      );
}

/// Choose a surah and a range of verses to test.
class RecitationPickerScreen extends ConsumerStatefulWidget {
  const RecitationPickerScreen({super.key});

  @override
  ConsumerState<RecitationPickerScreen> createState() => _RecitationPickerScreenState();
}

class _RecitationPickerScreenState extends ConsumerState<RecitationPickerScreen> {
  String _q = '';

  Future<void> _pickRange(int surah, int count) async {
    var range = RangeValues(1, count.clamp(1, 7).toDouble());
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(context.tr('choose_verses'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('${context.num(range.start.round())} – ${context.num(range.end.round())}', style: const TextStyle(color: Brand.gold, fontSize: 20)),
              if (count > 1)
                RangeSlider(
                  values: range,
                  min: 1,
                  max: count.toDouble(),
                  divisions: count - 1,
                  onChanged: (v) => setState(() => range = v),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.mic_rounded), label: Text(context.tr('start'))),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      push(context, RecitationTestScreen(surah: surah, from: range.start.round(), to: range.end.round()));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: AsyncView(
          value: ref.watch(quranProvider),
          builder: (q) {
            final n = normalizeArabic(_q);
            final list = q.surahs.where((s) => n.isEmpty || normalizeArabic(s.nameAr).contains(n) || s.translit.toLowerCase().contains(_q.toLowerCase())).toList();
            return Column(children: [
              PageTitle(context.tr('test_recitation'), subtitle: context.tr('test_recitation_sub')),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.tr('search_surah')),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 40),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Brand.teal.withValues(alpha: 0.18),
                        child: Text(context.num(s.number), style: const TextStyle(fontSize: 12, color: Brand.tealBright)),
                      ),
                      title: Text(s.nameAr, style: const TextStyle(fontFamily: Brand.naskhFont, fontSize: 19)),
                      subtitle: Text(context.tr('ayahs_n', {'n': s.ayahCount})),
                      trailing: const Icon(Icons.mic_none_rounded, color: Brand.gold),
                      onTap: () => _pickRange(s.number, s.ayahCount),
                    );
                  },
                ),
              ),
            ]);
          },
        ),
      );
}
