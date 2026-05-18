// local_journal.dart — SQLite mirror of player's writings.
//
// Why: lets the player browse their own history even when backend is down,
// and lets them export everything as JSON for backup (Google Drive, email, …).
// On launch we pull GET /api/v1/writings and upsert; write_today upserts each
// new analysis when polling completes.
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.content,
    required this.emotionTag,
    required this.locationAlias,
    required this.wuxingDetected,
    required this.celestialDetected,
    required this.monsterName,
    required this.cardQuote,
    required this.validityScore,
    required this.status,
    required this.writtenAt,
    this.analyzedAt,
  });
  final String id;
  final String content;
  final String emotionTag;
  final String locationAlias;
  final String wuxingDetected;
  final String celestialDetected;
  final String monsterName;
  final String cardQuote;
  final double validityScore;
  final String status;
  final DateTime writtenAt;
  final DateTime? analyzedAt;

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['id'] as String? ?? '',
        content: j['content'] as String? ?? '',
        emotionTag: j['emotion_tag'] as String? ?? '',
        locationAlias: j['location_alias'] as String? ?? '',
        wuxingDetected: j['wuxing_detected'] as String? ?? '',
        celestialDetected: j['celestial_detected'] as String? ?? '',
        monsterName: j['monster_name'] as String? ?? '',
        cardQuote: j['card_quote'] as String? ?? '',
        validityScore: (j['validity_score'] as num?)?.toDouble() ?? 0.0,
        status: j['status'] as String? ?? '',
        writtenAt: DateTime.tryParse(j['written_at'] as String? ?? '') ?? DateTime.now(),
        analyzedAt: DateTime.tryParse(j['analyzed_at'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'emotion_tag': emotionTag,
        'location_alias': locationAlias,
        'wuxing_detected': wuxingDetected,
        'celestial_detected': celestialDetected,
        'monster_name': monsterName,
        'card_quote': cardQuote,
        'validity_score': validityScore,
        'status': status,
        'written_at': writtenAt.toUtc().toIso8601String(),
        if (analyzedAt != null) 'analyzed_at': analyzedAt!.toUtc().toIso8601String(),
      };
}

class LocalJournal {
  LocalJournal._();
  static final instance = LocalJournal._();
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/journal.db';
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE journal(
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            emotion_tag TEXT NOT NULL,
            location_alias TEXT NOT NULL DEFAULT '',
            wuxing_detected TEXT NOT NULL DEFAULT '',
            celestial_detected TEXT NOT NULL DEFAULT '',
            monster_name TEXT NOT NULL DEFAULT '',
            card_quote TEXT NOT NULL DEFAULT '',
            validity_score REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'pending_analysis',
            written_at TEXT NOT NULL,
            analyzed_at TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_journal_written_at ON journal(written_at DESC)');
      },
    );
    return _db!;
  }

  Future<void> upsert(JournalEntry e) async {
    final db = await _open();
    await db.insert(
      'journal',
      {
        'id': e.id,
        'content': e.content,
        'emotion_tag': e.emotionTag,
        'location_alias': e.locationAlias,
        'wuxing_detected': e.wuxingDetected,
        'celestial_detected': e.celestialDetected,
        'monster_name': e.monsterName,
        'card_quote': e.cardQuote,
        'validity_score': e.validityScore,
        'status': e.status,
        'written_at': e.writtenAt.toUtc().toIso8601String(),
        'analyzed_at': e.analyzedAt?.toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAll(Iterable<JournalEntry> entries) async {
    final db = await _open();
    final batch = db.batch();
    for (final e in entries) {
      batch.insert(
        'journal',
        {
          'id': e.id,
          'content': e.content,
          'emotion_tag': e.emotionTag,
          'location_alias': e.locationAlias,
          'wuxing_detected': e.wuxingDetected,
          'celestial_detected': e.celestialDetected,
          'monster_name': e.monsterName,
          'card_quote': e.cardQuote,
          'validity_score': e.validityScore,
          'status': e.status,
          'written_at': e.writtenAt.toUtc().toIso8601String(),
          'analyzed_at': e.analyzedAt?.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<JournalEntry>> listRecent({int limit = 200}) async {
    final db = await _open();
    final rows = await db.query('journal',
        orderBy: 'written_at DESC', limit: limit);
    return rows.map(_rowToEntry).toList();
  }

  Future<JournalEntry?> getById(String id) async {
    final db = await _open();
    final rows = await db.query('journal', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _rowToEntry(rows.first);
  }

  Future<int> count() async {
    final db = await _open();
    final r = await db.rawQuery('SELECT COUNT(*) AS n FROM journal');
    return (r.first['n'] as int?) ?? 0;
  }

  /// Returns pretty-printed JSON of every entry (newest first).
  Future<String> exportAllJson() async {
    final entries = await listRecent(limit: 9999);
    final payload = {
      'app': 'yingwu-echo',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'count': entries.length,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  JournalEntry _rowToEntry(Map<String, Object?> r) => JournalEntry(
        id: r['id'] as String? ?? '',
        content: r['content'] as String? ?? '',
        emotionTag: r['emotion_tag'] as String? ?? '',
        locationAlias: r['location_alias'] as String? ?? '',
        wuxingDetected: r['wuxing_detected'] as String? ?? '',
        celestialDetected: r['celestial_detected'] as String? ?? '',
        monsterName: r['monster_name'] as String? ?? '',
        cardQuote: r['card_quote'] as String? ?? '',
        validityScore: (r['validity_score'] as num?)?.toDouble() ?? 0.0,
        status: r['status'] as String? ?? '',
        writtenAt: DateTime.tryParse(r['written_at'] as String? ?? '') ?? DateTime.now(),
        analyzedAt: r['analyzed_at'] != null
            ? DateTime.tryParse(r['analyzed_at'] as String)
            : null,
      );
}
