// sprite_resolver.dart — map (species_zh, rarity) → asset path.
// v0.5: only common sprites bundled. Rare/legendary fall back to common until Phase 2/3.
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class SpriteResolver {
  SpriteResolver._();
  static final instance = SpriteResolver._();
  Map<String, String>? _pinyinByName;

  Future<void> ensureLoaded() async {
    if (_pinyinByName != null) return;
    final raw = await rootBundle.loadString('assets/species_pinyin_map.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    _pinyinByName = decoded.map((k, v) => MapEntry(k, v as String));
  }

  // Returns the asset path for (species_zh, rarity). Returns null if no mapping.
  String? path(String speciesZh, String rarity) {
    final pinyin = _pinyinByName?[speciesZh];
    if (pinyin == null) return null;
    // Phase 1: rare/legendary fall back to common
    final effective = rarity == 'common' ? 'common' : 'common';
    return 'assets/sprites/${pinyin}_$effective.jpg';
  }

  // Synchronous variant that requires preloaded data.
  String? pathSync(String speciesZh, String rarity) {
    return path(speciesZh, rarity);
  }
}
