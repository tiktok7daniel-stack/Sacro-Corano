import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../domain/recitation.dart';
import '../../services/speech.dart';

/// Recite a verse aloud and see, word by word, what the device's Arabic
/// speech recogniser heard: green for right, red for a different word, a
/// grey outline for one that was skipped.
///
/// With "hide the text" on, the verse is covered and each word appears as
/// you say it, which makes it a memorisation test. The check is only as good
/// as the device recogniser, so it is presented as an aid, not a verdict.
class RecitationScreen extends ConsumerStatefulWidget {
  const RecitationScreen({super.key, this.surah = 1, this.ayah = 1});
  final int surah;
  final int ayah;

  @override
  ConsumerState<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends ConsumerState<RecitationScreen> {
  late int _surah = widget.surah;
  late int _ayah = widget.ayah;
  bool _hidden = false;
  bool _onDevice = false;
  bool _ready = false;
  bool _listening = false;
  bool _finished = false;
  String _spoken = '';
  String? _problem;

  late final SpeechEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = ref.read(speechEngineProvider);
  }

  @override
  void dispose() {
    _engine.cancel();
    super.dispose();
  }

  void _reset() => setState(() {
        _spoken = '';
        _finished = false;
        _problem = null;
      });

  Future<void> _toggle() async {
    final engine = _engine;
    if (_listening) {
      await engine.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_ready) {
      final ok = await engine.init(
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _problem = 'rec_error';
          });
        },
        onDone: () {
          if (!mounted || !_listening) return;
          setState(() {
            _listening = false;
            _finished = _spoken.isNotEmpty;
          });
        },
      );
      if (!ok) return _fail('rec_no_mic');
      if (!await engine.hasArabic()) return _fail('rec_no_arabic');
      _ready = true;
    }
    _reset();
    setState(() => _listening = true);
    await engine.listen(
      onDeviceOnly: _onDevice,
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _spoken = words;
          if (isFinal) {
            _finished = true;
            _listening = false;
          }
        });
      },
    );
  }

  void _fail(String key) {
    if (mounted) setState(() => _problem = key);
  }

  void _go(int surah, int ayah) {
    _engine.cancel();
    setState(() {
      _surah = surah;
      _ayah = ayah;
      _listening = false;
    });
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    final quran = ref.watch(quranProvider);
    return Scaffold(
      appBar: AppBar(),
      body: AsyncView(
        value: quran,
        builder: (q) {
          final info = q.surah(_surah);
          final words = expectedWords(q.text(_surah, _ayah));
          final result = compareRecitation(words, _spoken, finished: _finished);
          final started = _spoken.isNotEmpty;
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              PageTitle(context.tr('rec_title'), subtitle: context.tr('rec_sub')),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _surah,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: context.tr('surah')),
                    items: [
                      for (final s in q.surahs) DropdownMenuItem(value: s.number, child: Text('${context.num(s.number)}. ${context.isAr ? s.nameAr : s.translit}')),
                    ],
                    onChanged: (v) => v == null ? null : _go(v, 1),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('ayah-$_surah'),
                    initialValue: _ayah,
                    decoration: InputDecoration(labelText: context.tr('rec_ayah')),
                    items: [for (var a = 1; a <= info.ayahCount; a++) DropdownMenuItem(value: a, child: Text(context.num(a)))],
                    onChanged: (v) => v == null ? null : _go(_surah, v),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final (i, w) in words.indexed) _Word(w.display, result.states[i], hidden: _hidden),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_problem != null)
                AppCard(
                  borderColor: Colors.redAccent,
                  child: Row(children: [
                    const Icon(Icons.mic_off_rounded, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(child: Text(context.tr(_problem!), style: const TextStyle(height: 1.5))),
                  ]),
                )
              else if (_finished && started)
                AppCard(
                  gradient: result.perfect ? const LinearGradient(colors: Brand.gQibla) : null,
                  borderColor: result.perfect ? Colors.transparent : null,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      result.perfect ? context.tr('rec_perfect') : context.tr('rec_score', {'c': result.correct, 'n': words.length}),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: result.perfect ? Colors.white : null),
                    ),
                    if (!result.perfect) ...[
                      const SizedBox(height: 4),
                      Text(context.tr('rec_review'), style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5)),
                    ],
                  ]),
                )
              else
                Center(child: Text(_listening ? context.tr('rec_listening') : context.tr('rec_tap_mic'), style: TextStyle(color: scheme.onSurfaceVariant))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton.filledTonal(
                  tooltip: context.tr('rec_prev'),
                  onPressed: _ayah > 1 ? () => _go(_surah, _ayah - 1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                const SizedBox(width: 20),
                Semantics(
                  button: true,
                  label: context.tr(_listening ? 'rec_stop' : 'rec_start'),
                  child: GestureDetector(
                    onTap: _toggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _listening ? 92 : 80,
                      height: _listening ? 92 : 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: _listening ? const [Color(0xFFD32F2F), Color(0xFFEF7A7A)] : Brand.gHifz),
                        boxShadow: [BoxShadow(color: (_listening ? Colors.red : Brand.gHifz.first).withValues(alpha: 0.4), blurRadius: _listening ? 24 : 12)],
                      ),
                      child: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 38),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                IconButton.filledTonal(
                  tooltip: context.tr('rec_next'),
                  onPressed: _ayah < info.ayahCount ? () => _go(_surah, _ayah + 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ]),
              const SizedBox(height: 20),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_rounded),
                title: Text(context.tr('rec_hide')),
                subtitle: Text(context.tr('rec_hide_sub')),
                value: _hidden,
                onChanged: (v) => setState(() => _hidden = v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.phone_android_rounded),
                title: Text(context.tr('rec_on_device')),
                subtitle: Text(context.tr('rec_on_device_sub')),
                value: _onDevice,
                onChanged: (v) => setState(() => _onDevice = v),
              ),
              const SizedBox(height: 8),
              Text(context.tr('rec_disclaimer'), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5, height: 1.6)),
            ],
          );
        },
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word(this.text, this.state, {required this.hidden});
  final String text;
  final WordState state;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, bg) = switch (state) {
      WordState.correct => (const Color(0xFF3DBE8B), const Color(0xFF3DBE8B)),
      WordState.wrong => (const Color(0xFFE5484D), const Color(0xFFE5484D)),
      WordState.missing => (const Color(0xFFE5484D), Colors.transparent),
      WordState.pending => (scheme.onSurface, Colors.transparent),
    };
    // Covered words are revealed once spoken, or when the attempt ends so the
    // reciter can see what they missed.
    final covered = hidden && (state == WordState.pending);
    return Semantics(
      label: text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: bg == Colors.transparent ? 0 : 0.14),
          borderRadius: BorderRadius.circular(10),
          border: state == WordState.missing ? Border.all(color: color.withValues(alpha: 0.7)) : null,
        ),
        child: covered
            ? Container(
                width: 14.0 + text.length * 4,
                height: 14,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: scheme.outline.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(7)),
              )
            : Text(text, style: TextStyle(fontFamily: Brand.quranFont, fontSize: 28, height: 1.9, color: color)),
      ),
    );
  }
}
