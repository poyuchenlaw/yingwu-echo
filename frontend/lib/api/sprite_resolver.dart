// sprite_resolver.dart — (species_zh, rarity) → asset path.
// v0.5.3: all 3 rarities bundled (75 sprites total across common/rare/legendary).
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

  String? path(String speciesZh, String rarity) {
    final pinyin = _pinyinByName?[speciesZh];
    if (pinyin == null) return null;
    final r = (rarity == 'rare' || rarity == 'legendary') ? rarity : 'common';
    return 'assets/sprites/${pinyin}_$r.jpg';
  }

  String? pathSync(String speciesZh, String rarity) => path(speciesZh, rarity);
}
