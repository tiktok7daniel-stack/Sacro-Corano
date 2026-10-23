import 'package:flutter/widgets.dart';

import '../utils/arabic.dart';

part 'strings_data.dart';

/// Lightweight localisation: a key → text table per language. It avoids a
/// code-generation step and keeps adding a language to one map (see
/// docs/DEVELOPER_GUIDE.md → "Adding a language").
abstract final class L10n {
  static const supported = ['ar', 'en'];

  static String lookup(String lang, String key) =>
      _strings[lang]?[key] ?? _strings['en']?[key] ?? key;

  /// Every key present in [lang]; used by tests to keep tables in sync.
  static Set<String> keys(String lang) => _strings[lang]?.keys.toSet() ?? {};
}

extension L10nX on BuildContext {
  String get lang => Localizations.maybeLocaleOf(this)?.languageCode ?? 'ar';
  bool get isAr => lang == 'ar';

  String tr(String key, [Map<String, Object>? args]) {
    var s = L10n.lookup(lang, key);
    if (args != null) {
      args.forEach((k, v) {
        final value = (v is int || v is double) ? localNum(v, lang) : v.toString();
        s = s.replaceAll('{$k}', value);
      });
    }
    return s;
  }

  String num(Object n) => localNum(n, lang);
}
