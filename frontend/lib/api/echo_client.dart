// echo_client.dart — yingwu-echo backend HTTP client.
//
// Endpoint base picked from --dart-define=API_BASE=...  with default for
// Android emulator (10.0.2.2 maps to host's localhost in emulator).
// Physical device: rebuild with --dart-define=API_BASE=http://<lan-ip>:8080
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String kDefaultBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8080',
);

class EchoClient {
  EchoClient({String? base}) : base = base ?? kDefaultBase;
  final String base;

  Uri _u(String path) => Uri.parse('$base$path');

  Future<Map<String, dynamic>> health() async {
    final r = await http.get(_u('/health'));
    return json.decode(r.body) as Map<String, dynamic>;
  }

  // Demo path — synchronous Gemini, no DB. Returns analysis inline.
  Future<Map<String, dynamic>> demoAnalyze({
    required String content,
    required String emotionTag,
  }) async {
    final r = await http
        .post(
          _u('/api/v1/demo/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'content': content, 'emotion_tag': emotionTag}),
        )
        .timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) {
      throw Exception('demoAnalyze ${r.statusCode}: ${r.body}');
    }
    return json.decode(r.body) as Map<String, dynamic>;
  }

  // Production path — INSERT writing, kick off async Gemini, returns id.
  Future<String> postWriting({
    required String content,
    required String emotionTag,
    String locationAlias = '',
  }) async {
    final r = await http.post(
      _u('/api/v1/writings'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'content': content,
        'emotion_tag': emotionTag,
        'location_alias': locationAlias,
        'word_count': content.runes.length,
      }),
    );
    if (r.statusCode == 409) {
      final j = json.decode(r.body) as Map<String, dynamic>;
      throw DuplicateWritingException(j['writing_id'] as String? ?? '');
    }
    if (r.statusCode != 202) {
      throw Exception('postWriting ${r.statusCode}: ${r.body}');
    }
    return (json.decode(r.body) as Map<String, dynamic>)['writing_id'] as String;
  }

  // Poll analysis until COMPLETE or FAILED. Returns final result.
  Future<Map<String, dynamic>> pollAnalysis(String writingId,
      {Duration interval = const Duration(seconds: 2), int maxTries = 30}) async {
    for (var i = 0; i < maxTries; i++) {
      await Future<void>.delayed(interval);
      final r = await http.get(_u('/api/v1/writings/$writingId/analysis'));
      if (r.statusCode != 200) continue;
      final j = json.decode(r.body) as Map<String, dynamic>;
      final status = j['status'] as String? ?? '';
      if (status == 'COMPLETE') return j;
      if (status == 'FAILED') throw Exception('analysis FAILED');
    }
    throw TimeoutException('analysis timeout after ${maxTries * interval.inSeconds}s');
  }

  Future<List<Map<String, dynamic>>> getMonsters() async {
    final r = await http.get(_u('/api/v1/monsters'));
    if (r.statusCode != 200) throw Exception('monsters ${r.statusCode}');
    final j = json.decode(r.body) as Map<String, dynamic>;
    final list = j['monsters'] as List<dynamic>? ?? const [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> battle(String attackerId) async {
    final r = await http.post(
      _u('/api/v1/battle'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'attacker_monster_id': attackerId}),
    ).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw Exception('battle ${r.statusCode}: ${r.body}');
    return json.decode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> forge({
    required List<String> sourceIds,
    required String targetRarity,
    int charsAccumulated = 0,
  }) async {
    final r = await http.post(
      _u('/api/v1/forge'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'source_ids': sourceIds,
        'target_rarity': targetRarity,
        'chars_accumulated': charsAccumulated,
      }),
    );
    if (r.statusCode == 409) {
      final j = json.decode(r.body) as Map<String, dynamic>;
      throw LegendaryCapException(
        message: j['error'] as String? ?? 'cap reached',
        refundedIds: ((j['refunded_card_ids'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
    }
    if (r.statusCode != 200) throw Exception('forge ${r.statusCode}: ${r.body}');
    return json.decode(r.body) as Map<String, dynamic>;
  }

  Future<List<String>> seedCards({
    String emotion = '累',
    String wuxing = 'water',
  }) async {
    final r = await http.post(_u('/api/v1/dev/seed-cards?emotion=$emotion&wuxing=$wuxing'));
    if (r.statusCode != 200) throw Exception('seed ${r.statusCode}: ${r.body}');
    final j = json.decode(r.body) as Map<String, dynamic>;
    return ((j['created'] as List<dynamic>?) ?? const []).map((e) => e.toString()).toList();
  }
}

class DuplicateWritingException implements Exception {
  DuplicateWritingException(this.existingId);
  final String existingId;
  @override
  String toString() => 'duplicate writing (existing id: $existingId)';
}

class LegendaryCapException implements Exception {
  LegendaryCapException({required this.message, required this.refundedIds});
  final String message;
  final List<String> refundedIds;
}

/// Map raw exceptions to friendly Chinese messages for end users.
/// Falls back to the raw toString() so we never swallow info during dev.
String friendlyError(Object e) {
  final s = e.toString();
  if (s.contains('Operation not permitted') ||
      s.contains('errno = 1') ||
      s.contains('Connection refused') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection failed') ||
      s.contains('SocketException')) {
    if (s.contains('10.0.2.2')) {
      return '連不到後端：當前位址是 10.0.2.2（Android 模擬器專用）。'
          '請按右上⚙ 設定，把 API 位址改為 Tailscale (http://100.84.86.128:8080) 並確認手機已連 Tailscale。';
    }
    return '連不到後端。請檢查：\n'
        '1) WSL2 後端是否啟動（cd backend && go run ./cmd/server）\n'
        '2) 手機是否已連 Tailscale\n'
        '3) 右上⚙ 設定中的 API 位址是否正確';
  }
  if (s.contains('TimeoutException')) {
    return '請求逾時。後端或 Gemini API 可能還在處理，請稍候再試。';
  }
  if (s.contains('FormatException')) {
    return '後端回應格式錯誤（可能版本不符）。請更新 APK。';
  }
  return s;
}

