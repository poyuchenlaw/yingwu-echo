import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../services/local_journal.dart';
import '../services/version_check.dart';
import '../theme/echo_theme.dart';
import '../widgets/help_sheet.dart';
import '../widgets/update_dialog.dart';
import 'write_today.dart';
import 'incarnation_view.dart';
import 'battle_arena.dart';
import 'journal.dart';
import 'settings.dart';

class HomeMirrorScreen extends ConsumerStatefulWidget {
  const HomeMirrorScreen({super.key});
  @override
  ConsumerState<HomeMirrorScreen> createState() => _HomeMirrorState();
}

class _HomeMirrorState extends ConsumerState<HomeMirrorScreen> {
  Map<String, dynamic>? _health;
  int _monsters = 0;
  int _legendaries = 0;
  int _journalCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final info = await VersionCheck.instance.check();
    if (!mounted || info == null) return;
    showUpdateDialog(context, info);
  }

  Future<void> _refresh() async {
    final client = ref.read(clientProvider);
    final localCount = await LocalJournal.instance.count();
    if (mounted) setState(() => _journalCount = localCount);
    try {
      final h = await client.health();
      final ms = await client.getMonsters();
      if (mounted) {
        setState(() {
          _health = h;
          _monsters = ms.length;
          _legendaries = ms.where((m) => m['rarity'] == 'legendary').length;
        });
      }
      _syncJournal();
    } catch (_) {
      if (mounted) setState(() => _health = {'status': 'unreachable'});
    }
  }

  Future<void> _syncJournal() async {
    try {
      final list = await ref.read(clientProvider).getWritings(limit: 200);
      final entries = list.map((m) => JournalEntry.fromJson(m)).toList();
      await LocalJournal.instance.upsertAll(entries);
      final n = await LocalJournal.instance.count();
      if (mounted) setState(() => _journalCount = n);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final healthStatus = _health?['status'] ?? '…';
    final isHealthy = healthStatus == 'ok';
    return Scaffold(
      appBar: AppBar(
        title: const Text('應物 ECHO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '操作說明',
            onPressed: () => showHelpSheet(context, title: '應物 ECHO · 介面說明', entries: const [
              HelpEntry('心之核（首頁中央）',
                  '本作核心：你寫的真誠度越高，AI 生成的共鳴體越獨特、越強。',
                  icon: Icons.blur_circular),
              HelpEntry('狀態列', '書寫 N · 收藏 M · 神獸 K · backend ok/unreachable。下拉同步。',
                  icon: Icons.sync),
              HelpEntry('今日書寫', '寫一段感受 → AI 給你一隻山海經共鳴體（含五行、九曜、真誠度、quote）。',
                  icon: Icons.edit_note),
              HelpEntry('靈體圖鑑 / 鎔鑄',
                  '看收藏；3 張同五行 common → rare；3 張同五行 rare → legendary。',
                  icon: Icons.pets),
              HelpEntry('鏡境對決', '挑戰 NPC，五行相剋給傷害倍率，鏡之窗可永久收編對方。',
                  icon: Icons.flash_on),
              HelpEntry('過往書寫', '時間軸瀏覽你寫過的每一篇 + 詳情頁可看全文與共鳴體。',
                  icon: Icons.menu_book),
              HelpEntry('⚙ 設定', '改 API 位址、檢查更新、匯出歷程 JSON。',
                  icon: Icons.settings),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _refresh()),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: EchoColors.accent,
          backgroundColor: EchoColors.panel,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const SizedBox(height: 28),
              // Central seal logo with subtle glow
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            EchoColors.accent.withOpacity(0.22),
                            Colors.transparent,
                          ],
                          radius: 0.6,
                        ),
                      ),
                    ),
                    const EchoSeal(text: '應\n物', size: 78),
                  ],
                ),
              ).animate().fadeIn(duration: 700.ms).scale(begin: const Offset(0.85, 0.85)),
              const SizedBox(height: 18),
              Center(
                child: Text('心之核', style: echoDisplay(22, letterSpacing: 8)),
              ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
              const SizedBox(height: 14),
              // Stat strip — bronze tags
              Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _StatChip(label: '書寫', value: '$_journalCount'),
                    _StatChip(label: '收藏', value: '$_monsters'),
                    _StatChip(label: '神獸', value: '$_legendaries'),
                    _StatChip(
                      label: '線路',
                      value: isHealthy ? '通' : (healthStatus == 'unreachable' ? '斷' : '…'),
                      valueColor: isHealthy ? EchoColors.wWood : EchoColors.cinnabar,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
              const SizedBox(height: 36),
              const EchoDivider(glyph: '𓂀'),
              const SizedBox(height: 24),
              ..._buildTiles(context),
              const SizedBox(height: 30),
              Center(
                child: Text(
                  '— 下拉以同步 —',
                  style: echoMono(11, color: EchoColors.muted),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTiles(BuildContext context) {
    final tiles = [
      _NavTile(
        icon: Icons.edit_note,
        title: '今日書寫',
        subtitle: '寫一段感受 · AI 給你山海經共鳴體',
        onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const WriteTodayScreen()))
            .then((_) => _refresh()),
      ),
      _NavTile(
        icon: Icons.menu_book,
        title: '過往書寫',
        subtitle: '回顧每一篇 · $_journalCount 篇歷程',
        onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const JournalScreen()))
            .then((_) => _refresh()),
      ),
      _NavTile(
        icon: Icons.pets,
        title: '靈體圖鑑 / 鎔鑄',
        subtitle: '檢視收藏 · 三同源升階',
        onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const IncarnationViewScreen()))
            .then((_) => _refresh()),
      ),
      _NavTile(
        icon: Icons.flash_on,
        title: '鏡境對決',
        subtitle: '挑戰山海者 · 鏡之窗永久收編',
        onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const BattleArenaScreen()))
            .then((_) => _refresh()),
      ),
    ];
    final widgets = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      widgets.add(tiles[i]
          .animate()
          .fadeIn(delay: (500 + i * 110).ms, duration: 600.ms)
          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic));
      if (i < tiles.length - 1) widgets.add(const SizedBox(height: 14));
    }
    return widgets;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: EchoColors.bgSoft,
        border: Border.all(color: EchoColors.border, width: 0.6),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: echoMono(11, color: EchoColors.muted)),
        const SizedBox(width: 6),
        Text(value,
            style: echoTitle(13, color: valueColor ?? EchoColors.accent, letterSpacing: 1)),
      ]),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        splashColor: EchoColors.accent.withOpacity(0.15),
        highlightColor: EchoColors.accent.withOpacity(0.06),
        child: EchoCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    EchoColors.accent.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(icon, color: EchoColors.accent, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: echoTitle(17, letterSpacing: 3)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: echoBody(12, color: EchoColors.muted, height: 1.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: EchoColors.muted, size: 22),
          ]),
        ),
      ),
    );
  }
}
