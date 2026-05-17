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
