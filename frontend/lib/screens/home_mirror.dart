import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/echo_client.dart';
import '../main.dart';
import '../theme/echo_theme.dart';
import 'write_today.dart';
import 'incarnation_view.dart';
import 'battle_arena.dart';

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
      appBar: AppBar(title: const Text('應物 ECHO')),
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
