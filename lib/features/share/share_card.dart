import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/logo.dart';
import '../../domain/quran_models.dart';

/// Renders [card] off-screen to a PNG and opens the system share sheet.
Future<void> shareWidgetAsImage(BuildContext context, Widget card, {String name = 'mishkah', double width = 1080}) async {
  final key = GlobalKey();
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -width * 2,
      top: 0,
      child: RepaintBoundary(
        key: key,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: Directionality.of(context),
            child: Material(type: MaterialType.transparency, child: SizedBox(width: width / 2.5, child: card)),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name-${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')]));
  } finally {
    entry.remove();
  }
}

Future<void> shareVerseImage(BuildContext context, WidgetRef ref, AyahRange range) async {
  final q = await ref.read(quranProvider.future);
  final info = q.surah(range.surah);
  final buf = StringBuffer();
  for (var a = range.from; a <= range.to; a++) {
    buf.write('${q.text(range.surah, a)} ${ayahMarker(a)} ');
  }
  if (!context.mounted) return;
  await shareWidgetAsImage(
    context,
    BrandedCard(
      title: '${context.tr('surah')} ${info.nameAr} · $range',
      child: Text(
        buf.toString().trim(),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 24, height: 2.0, color: Brand.textHigh),
      ),
    ),
    name: 'verse',
  );
}

/// Islamic-styled frame used for every shared image.
class BrandedCard extends StatelessWidget {
  const BrandedCard({super.key, required this.child, this.title});
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF103A44), Brand.ink]),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
          decoration: BoxDecoration(
            border: Border.all(color: Brand.gold.withValues(alpha: 0.8), width: 1.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.auto_awesome_rounded, color: Brand.gold, size: 18),
            const SizedBox(height: 10),
            child,
            const SizedBox(height: 14),
            if (title != null) Text(title!, style: const TextStyle(color: Brand.gold, fontSize: 12, fontFamily: Brand.uiFont)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const MishkahLogo(size: 22),
              const SizedBox(width: 6),
              Text('مِشكاة · Mishkah', style: TextStyle(color: Brand.textMid.withValues(alpha: 0.9), fontSize: 11, fontFamily: Brand.uiFont)),
            ]),
          ]),
        ),
      );
}
