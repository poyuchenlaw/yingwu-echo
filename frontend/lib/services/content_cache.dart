// content_cache.dart — fetch JSON content from GitHub raw with ETag cache,
// fallback to bundled rootBundle asset on failure.
//
// Usage:
//   await ContentCache.instance.loadJson(
//     assetPath: 'assets/species_pinyin_map.json',
//     remotePath: 'frontend/assets/species_pinyin_map.json',
//   )
//
// First call (online): fetches GitHub raw, caches body + ETag in SharedPreferences.
// Subsequent calls: sends If-None-Match; on 304 uses cache; on 200 updates cache.
// Offline / GitHub down: returns last cached body; if no cache, returns bundled.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ContentCache {
  ContentCache._();
  static final instance = ContentCache._();

  static const String _owner = 'poyuchenlaw';
  static const String _repo = 'yingwu-echo';
  static const String _branch = 'master';

  /// Try remote with ETag; fall back to bundled asset on any failure.
  /// Returns parsed JSON Map. For lists, decode caller-side.
  Future<dynamic> loadJson({
    required String assetPath,
    required String remotePath,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final body = await loadString(
      assetPath: assetPath,
      remotePath: remotePath,
      timeout: timeout,
    );
    return json.decode(body);
  }

  Future<String> loadString({
    required String assetPath,
    required String remotePath,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cc:body:$remotePath';
    final etagKey = 'cc:etag:$remotePath';
    final cachedBody = prefs.getString(cacheKey);
    final cachedEtag = prefs.getString(etagKey);

    try {
      final url = 'https://raw.githubusercontent.com/$_owner/$_repo/$_branch/$remotePath';
      final headers = <String, String>{};
      if (cachedEtag != null && cachedBody != null) {
        headers['If-None-Match'] = cachedEtag;
      }
      final r = await http.get(Uri.parse(url), headers: headers).timeout(timeout);
      if (r.statusCode == 304 && cachedBody != null) {
        return cachedBody;
      }
      if (r.statusCode == 200) {
        await prefs.setString(cacheKey, r.body);
        final newEtag = r.headers['etag'];
        if (newEtag != null) await prefs.setString(etagKey, newEtag);
        return r.body;
      }
      // 404 / 5xx etc → fall through
    } catch (_) {
      // network down / timeout → fall through
    }

    if (cachedBody != null) return cachedBody;
    // Last resort — bundled asset.
    return rootBundle.loadString(assetPath);
  }

  Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    final keys = p.getKeys().where((k) => k.startsWith('cc:')).toList();
    for (final k in keys) {
      await p.remove(k);
    }
  }
}
