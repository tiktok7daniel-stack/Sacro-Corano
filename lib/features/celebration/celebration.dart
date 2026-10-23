import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/theme/brand.dart';

/// Celebration overlay (stars + glow, assets/lottie/celebration.json).
/// With reduced motion a static badge is shown instead.
Future<void> showCelebration(BuildContext context, {required String title, String? subtitle}) {
  final reduced = Motion.of(context).reduced;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black54,
    transitionDuration: reduced ? Duration.zero : const Duration(milliseconds: 350),
    pageBuilder: (context, _, _) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 240,
            height: 240,
            child: reduced
                ? const Icon(Icons.workspace_premium_rounded, size: 140, color: Brand.gold)
                : Lottie.asset('assets/lottie/celebration.json', repeat: false),
          ),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(subtitle, style: const TextStyle(color: Brand.gold))),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('alhamdulillah'))),
        ]),
      ),
    ),
    transitionBuilder: (context, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: a, child: child),
    ),
  );
}
