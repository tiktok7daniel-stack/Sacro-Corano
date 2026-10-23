import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';
import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../audio/mini_player.dart';
import '../azkar/azkar_screen.dart';
import '../home/home_screen.dart';
import '../prayer/prayer_screen.dart';
import '../quran/quran_index_screen.dart';
import '../settings/settings_screen.dart';

/// Bottom navigation keeps the five daily destinations one tap away, which
/// suits one-handed use better than a drawer; everything else hangs off Home.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    QuranIndexScreen(),
    PrayerScreen(),
    AzkarScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Bootstrap.afterFirstFrame(context, ref));
  }

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: m.medium,
              switchInCurve: Motion.emphasized,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(a), child: child),
              ),
              child: KeyedSubtree(key: ValueKey(_index), child: _pages[_index]),
            ),
            const PositionedDirectional(start: 0, end: 0, bottom: 0, child: MiniPlayer()),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            haptic(ref, HapticKind.selection);
            setState(() => _index = i);
          },
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: context.tr('nav_home')),
            NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book_rounded), label: context.tr('nav_quran')),
            NavigationDestination(icon: const Icon(Icons.access_time), selectedIcon: const Icon(Icons.access_time_filled), label: context.tr('nav_prayer')),
            NavigationDestination(icon: const Icon(Icons.volunteer_activism_outlined), selectedIcon: const Icon(Icons.volunteer_activism), label: context.tr('nav_azkar')),
            NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: context.tr('nav_settings')),
          ],
        ),
      ),
    );
  }
}
