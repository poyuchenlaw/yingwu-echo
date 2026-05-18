import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/echo_client.dart';
import '../main.dart';
import '../services/local_journal.dart';
import '../theme/echo_theme.dart';
import '../widgets/help_sheet.dart';
import 'journal_detail.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});
  @override
  ConsumerState<JournalScreen> createState() => _JournalState();
}

class _JournalState extends ConsumerState<JournalScreen> {
  List<JournalEntry> _entries = [];
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final local = await LocalJournal.instance.listRecent(limit: 200);
    setState(() {
      _entries = local;
      _loading = false;
    });
    _syncFromBackend();
  }

  Future<void> _syncFromBackend() async {
    try {
      final remote = await ref.read(clientProvider).getWritings(limit: 200);
      final entries = remote.map((m) => JournalEntry.fromJson(m)).toList();
      await LocalJournal.instance.upsertAll(entries);
      final merged = await LocalJournal.instance.listRecent(limit: 200);
      if (!mounted) return;
      setState(() {
        _entries = merged;
        _status = '已同步 ${entries.length} 篇';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '離線模式：${friendlyError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('過往書寫'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '說明',
            onPressed: () => showHelpSheet(context, title: '過往書寫 · 說明', entries: const [
              HelpEntry('每張卡片',
                  '一篇你寫過的書寫。顯示日期、地點（若有）、情緒、AI 對映的共鳴體與 quote。',
                  icon: Icons.notes),
              HelpEntry('點卡片',
                  '進入詳情頁，看全文與完整分析（五行、九曜、真誠度、共鳴體圖像）。',
                  icon: Icons.touch_app),
              HelpEntry('資料存哪？',
                  '後端 PostgreSQL 為主，手機本地 SQLite 為快取。後端離線也能瀏覽。',
                  icon: Icons.storage),
              HelpEntry('匯出全部',
                  '到 ⚙ 設定按「匯出書寫歷程」可分享到 Drive / 信箱 / LINE。',
                  icon: Icons.ios_share),
              HelpEntry('下拉刷新',
                  '從 backend 重新拉最新清單（會合併到本地快取）。',
                  icon: Icons.sync),
            ]),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _syncFromBackend,
              child: _entries.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(32),
                      children: const [
                        SizedBox(height: 64),
                        Icon(Icons.menu_book, size: 72, color: EchoColors.muted),
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            '還沒有書寫紀錄',
                            style: TextStyle(color: EchoColors.muted, fontSize: 16),
                          ),
                        ),
                        SizedBox(height: 6),
                        Center(
                          child: Text(
                            '回首頁點「今日書寫」開始留下第一篇',
                            style: TextStyle(color: EchoColors.muted, fontSize: 12),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: _entries.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
                            child: Text(
                              '共 ${_entries.length} 篇${_status.isEmpty ? "" : "  ·  $_status"}',
                              style: const TextStyle(color: EchoColors.muted, fontSize: 12),
                            ),
                          );
                        }
                        final e = _entries[i - 1];
                        return _JournalCard(
                          e: e,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => JournalDetailScreen(entryId: e.id)),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.e, required this.onTap});
  final JournalEntry e;
  final VoidCallback onTap;

  static final _dateFmt = DateFormat('MM/dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final preview = e.content.replaceAll('\n', ' ');
    final shortPreview = preview.runes.length > 50
        ? '${String.fromCharCodes(preview.runes.take(50))}…'
        : preview;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      splashColor: EchoColors.accent.withOpacity(0.12),
      child: EchoCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _dateFmt.format(e.writtenAt.toLocal()),
                  style: echoMono(12, color: EchoColors.accent),
                ),
                if (e.locationAlias.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.place, size: 13, color: EchoColors.muted),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      e.locationAlias,
                      style: const TextStyle(color: EchoColors.muted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                if (e.emotionTag.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: EchoColors.bg,
                      border: Border.all(color: EchoColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(e.emotionTag,
                        style:
                            const TextStyle(color: EchoColors.fg, fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              shortPreview,
              style: const TextStyle(color: EchoColors.fg, fontSize: 14, height: 1.55),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(children: [
              if (e.wuxingDetected.isNotEmpty) WuxingBadge(e.wuxingDetected),
              const SizedBox(width: 8),
              if (e.monsterName.isNotEmpty)
                Flexible(
                  child: Text(
                    '· ${e.monsterName}',
                    style: echoTitle(13, color: EchoColors.accent, letterSpacing: 1),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const Spacer(),
              if (e.status != 'COMPLETE')
                Text(
                  e.status,
                  style: const TextStyle(color: EchoColors.muted, fontSize: 11),
                ),
            ]),
            if (e.cardQuote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                e.cardQuote,
                style: const TextStyle(
                    color: EchoColors.muted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.55),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
