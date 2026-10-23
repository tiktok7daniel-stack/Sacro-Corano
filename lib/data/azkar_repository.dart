import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Zikr {
  const Zikr({required this.text, required this.count, required this.reference});
  final String text;
  final int count;
  final String reference;
}

class AzkarCategory {
  const AzkarCategory({required this.id, required this.name, required this.items});
  final int id;
  final String name;
  final List<Zikr> items;
}

/// Hisn al-Muslim (Saʿid al-Qahtani), bundled offline.
class AzkarData {
  AzkarData(this.categories, this.source);
  final List<AzkarCategory> categories;
  final String source;

  static Future<AzkarData> load([AssetBundle? bundle]) async {
    final bytes = (await (bundle ?? rootBundle).load('assets/data/azkar.json.gz')).buffer.asUint8List();
    return compute(parse, bytes);
  }

  @visibleForTesting
  static AzkarData parse(Uint8List bytes) {
    final j = jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
    final cats = <AzkarCategory>[];
    var i = 0;
    for (final c in (j['categories'] as List).cast<Map<String, dynamic>>()) {
      cats.add(AzkarCategory(
        id: i++,
        name: c['name'] as String,
        items: [
          for (final z in (c['items'] as List).cast<Map<String, dynamic>>())
            Zikr(text: z['t'] as String, count: z['c'] as int, reference: z['r'] as String),
        ],
      ));
    }
    return AzkarData(cats, j['source'] as String);
  }

  AzkarCategory? byName(String name) {
    for (final c in categories) {
      if (c.name == name) return c;
    }
    return null;
  }

  // Category names as they appear in Hisn al-Muslim.
  static const morning = 'أذكار الصباح';
  static const evening = 'أذكار المساء';
  static const sleep = 'أذكار النوم';
  static const waking = 'أذكار الاستيقاظ من النوم';
  static const afterPrayer = 'الأذكار بعد السلام من الصلاة';
  static const distress = 'دعاء الهم والحزن';
  static const travel = 'دعاء السفر';
  static const istighfar = 'الاستغفار و التوبة';
}
