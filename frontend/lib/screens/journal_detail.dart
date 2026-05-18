import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/sprite_resolver.dart';
import '../services/local_journal.dart';
import '../theme/echo_theme.dart';

class JournalDetailScreen extends StatefulWidget {
  const JournalDetailScreen({super.key, required this.entryId});
  final String entryId;
  @override
  State<JournalDetailScreen> createState() => _JournalDetailState();
}

class _JournalDetailState extends State<JournalDetailScreen> {
  JournalEntry? _e;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await LocalJournal.instance.getById(widget.entryId);
    if (!mounted) return;
    setState(() {
      _e = e;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final e = _e;
    if (e == null) {
      return const Scaffold(
        body: Center(child: Text('找不到此筆紀錄', style: TextStyle(color: EchoColors.muted))),
      );
    }
    final dateFmt = DateFormat('yyyy/MM/dd · EEEE HH:mm', 'zh');
    final spritePath = e.monsterName.isNotEmpty
        ? SpriteResolver.instance.pathSync(e.monsterName, 'common')
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('書寫詳情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(dateFmt, e.writtenAt.toLocal()),
              style: const TextStyle(color: EchoColors.accent, fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            if (e.locationAlias.isNotEmpty)
              Row(children: [
                const Icon(Icons.place, size: 16, color: EchoColors.muted),
                const SizedBox(width: 4),
                Text(e.locationAlias,
                    style: const TextStyle(color: EchoColors.muted, fontSize: 13)),
              ]),
            const SizedBox(height: 16),
            Row(children: [
              if (e.emotionTag.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: EchoColors.bg,
                    border: Border.all(color: EchoColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(e.emotionTag,
                      style: const TextStyle(color: EchoColors.fg, fontSize: 12)),
                ),
              const SizedBox(width: 8),
              if (e.wuxingDetected.isNotEmpty) WuxingBadge(e.wuxingDetected),
              const SizedBox(width: 8),
              if (e.celestialDetected.isNotEmpty)
                Text('九曜 · ${e.celestialDetected}',
                    style: const TextStyle(color: EchoColors.muted, fontSize: 12)),
            ]),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EchoColors.panel,
                border: Border.all(color: EchoColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                e.content,
                style: const TextStyle(color: EchoColors.fg, fontSize: 15, height: 1.85),
              ),
            ),
            const SizedBox(height: 20),
            if (e.monsterName.isNotEmpty) ...[
              const Text('應物所得',
                  style: TextStyle(color: EchoColors.accent, fontSize: 14, letterSpacing: 1)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: EchoColors.panel,
                  border: Border.all(color: EchoColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (spritePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          spritePath,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            width: 96,
                            height: 96,
                            child: Icon(Icons.pets, color: EchoColors.muted, size: 40),
                          ),
                        ),
                      )
                    else
                      const SizedBox(
                        width: 96,
                        height: 96,
                        child: Icon(Icons.pets, color: EchoColors.muted, size: 40),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.monsterName,
                              style: const TextStyle(
                                  color: EchoColors.accent,
                                  fontSize: 18,
                                  letterSpacing: 1)),
                          const SizedBox(height: 6),
                          if (e.cardQuote.isNotEmpty)
                            Text(
                              e.cardQuote,
                              style: const TextStyle(
                                color: EchoColors.fg,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                height: 1.7,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(children: [
              const Text('真誠度 ', style: TextStyle(color: EchoColors.muted, fontSize: 12)),
              const SizedBox(width: 4),
              Expanded(
                child: LinearProgressIndicator(
                  value: e.validityScore.clamp(0.0, 1.0),
                  backgroundColor: EchoColors.bg,
                  color: EchoColors.accent,
                  minHeight: 6,
                ),
              ),
              const SizedBox(width: 8),
              Text('${(e.validityScore * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: EchoColors.muted, fontSize: 12)),
            ]),
            const SizedBox(height: 32),
            Center(
              child: Text('id: ${e.id}',
                  style: const TextStyle(color: EchoColors.muted, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateFormat fmt, DateTime t) {
    try {
      return fmt.format(t);
    } catch (_) {
      return DateFormat('yyyy/MM/dd HH:mm').format(t);
    }
  }
}
