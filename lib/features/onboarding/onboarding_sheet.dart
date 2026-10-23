import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';
import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/logo.dart';
import '../../services/notifications.dart';
import '../prayer/prayer_screen.dart';

/// First-run: language, location for prayer times, notification permission.
/// Everything can be skipped; the app works fully without any permission.
Future<void> showOnboarding(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const _Onboarding(),
    );

class _Onboarding extends ConsumerStatefulWidget {
  const _Onboarding();
  @override
  ConsumerState<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<_Onboarding> {
  bool _busy = false;
  String? _error;

  void _finish() {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboarded: true));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const MishkahLogo(size: 88),
          const SizedBox(height: 12),
          Text(context.tr('welcome'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(context.tr('welcome_body'), textAlign: TextAlign.center, style: const TextStyle(color: Brand.textMid, height: 1.6)),
          const SizedBox(height: 18),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('English'))],
            selected: {s.lang},
            onSelectionChanged: (v) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(lang: v.first)),
          ),
          const SizedBox(height: 18),
          if (s.hasLocation)
            ListTile(leading: const Icon(Icons.check_circle_rounded, color: Brand.tealBright), title: Text(s.placeName ?? ''))
          else ...[
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      final err = await useCurrentLocation(ref, context.lang);
                      if (!mounted) return;
                      setState(() {
                        _busy = false;
                        _error = err;
                      });
                    },
              icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded),
              label: Text(context.tr('use_my_location')),
            ),
            TextButton(onPressed: () => pickCity(context, ref), child: Text(context.tr('choose_city'))),
            if (_error != null) Text(context.tr(_error!), style: const TextStyle(color: Colors.orangeAccent)),
          ],
          const SizedBox(height: 8),
          Text(context.tr('privacy_promise'), textAlign: TextAlign.center, style: const TextStyle(color: Brand.textLow, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Brand.gold, foregroundColor: Brand.ink, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                await Notifications.instance.requestPermissions();
                if (mounted) _finish();
              },
              child: Text(context.tr('start')),
            ),
          ),
          TextButton(onPressed: _finish, child: Text(context.tr('skip'))),
        ]),
      ),
    );
  }
}
