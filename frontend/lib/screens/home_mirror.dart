import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../services/version_check.dart';
import '../theme/echo_theme.dart';
import '../widgets/help_sheet.dart';
import '../widgets/update_dialog.dart';
import 'write_today.dart';
import 'incarnation_view.dart';
import 'battle_arena.dart';
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

  @override
  void initState() {
    super.initState();
    _refresh();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    // Defer to next frame so the home screen is built before showing the sheet.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final info = await VersionCheck.instance.check();
    if (!mounted || info == null) return;
    showUpdateDialog(context, info);
  }

  Future<void> _refresh() async {
    final client = ref.read(clientProvider);
    try {
      final h = await client.health();
      final ms = await client.getMonsters();
      setState(() {
        _health = h;
        _monsters = ms.length;
        _legendaries = ms.where((m) => m['rarity'] == 'legendary').length;
      });
    } catch (_) {
      setState(() => _health = {'status': 'unreachable'});
    }
  }

  @override
  Widget build(BuildContext context) {
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
              HelpEntry('狀態列', '收藏 N · 神獸 M · backend 狀態（ok / unreachable）。下拉可手動同步。',
                  icon: Icons.sync),
              HelpEntry('今日書寫', '寫一段感受 → AI 給你一隻山海經風格共鳴體（含五行、九曜、真誠度、quote）。',
                  icon: Icons.edit_note),
              HelpEntry('靈體圖鑑 / 鎔鑄',
                  '看收藏；3 張同五行 common → rare；3 張同五行 rare → legendary。',
                  icon: Icons.pets),
              HelpEntry('鏡境對決', '挑戰 NPC 山海者，五行相剋給傷害倍率，鏡之窗可永久收編對方。',
                  icon: Icons.flash_on),
              HelpEntry('⚙ 設定', '改 API 位址（實機請選 Tailscale 100.84.86.128:8080）+ 常見問題。',
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
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 20),
              const Center(
                child: Icon(Icons.blur_circular, size: 100, color: EchoColors.accent),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  '心之核',
                  style: TextStyle(color: EchoColors.accent, fontSize: 22, letterSpacing: 4),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '收藏 $_monsters · 神獸 $_legendaries · backend ${_health?["status"] ?? "…"}',
                  style: const TextStyle(color: EchoColors.muted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 36),
              _NavTile(
                icon: Icons.edit_note,
                title: '今日書寫',
                subtitle: '寫一段感受，AI 給你山海經共鳴體',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const WriteTodayScreen())).then((_) => _refresh()),
              ),
              const SizedBox(height: 12),
              _NavTile(
                icon: Icons.pets,
                title: '靈體圖鑑 / 鎔鑄',
                subtitle: '檢視收藏，3 同源 common → rare → legendary',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const IncarnationViewScreen())).then((_) => _refresh()),
              ),
              const SizedBox(height: 12),
              _NavTile(
                icon: Icons.flash_on,
                title: '鏡境對決',
                subtitle: '挑戰山海者 NPC，鏡之窗永久收編',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const BattleArenaScreen())).then((_) => _refresh()),
              ),
              const SizedBox(height: 36),
              const Center(
                child: Text(
                  '下拉以同步狀態',
                  style: TextStyle(color: EchoColors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
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
      color: EchoColors.panel,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: EchoColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(icon, color: EchoColors.accent, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: EchoColors.fg,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(color: EchoColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: EchoColors.muted),
          ]),
        ),
      ),
    );
  }
}
