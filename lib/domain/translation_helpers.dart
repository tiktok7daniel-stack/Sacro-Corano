/// Normalises translation text for display (some sources embed HTML
/// footnote markers or stray whitespace).
String cleanTranslation(String s) =>
    s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
