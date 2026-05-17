import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/echo_client.dart';
import '../api/sprite_resolver.dart';
import '../main.dart';
import '../theme/echo_theme.dart';
import '../widgets/help_sheet.dart';

class IncarnationViewScreen extends ConsumerStatefulWidget {
  const IncarnationViewScreen({super.key});
  @override
  ConsumerState<IncarnationViewScreen> createState() => _IncarnationViewState();
}

class _IncarnationViewState extends ConsumerState<IncarnationViewScreen> {
  List<Map<String, dynamic>> _monsters = [];
  final Set<String> _selected = {};
  String _status = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ms = await ref.read(clientProvider).getMonsters();
      setState(() => _monsters = ms);
    } catch (e) {
      setState(() => _status = '❌ ${friendlyError(e)}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _seed() async {
    setState(() => _status = '種 3 張 累+water common…');
    try {
      await ref.read(clientProvider).seedCards();
      setState(() => _status = '✓ 種 3 張');
      await _load();
    } catch (e) {
      setState(() => _status = '❌ ${friendlyError(e)}');
    }
  }

  Future<void> _forge(String target) async {
    final sourceRarity = target == 'rare' ? 'common' : 'rare';
    final selectedMonsters =
        _monsters.where((m) => _selected.contains(m['id'] as String)).toList();
    final eligible =
        selectedMonsters.where((m) => m['rarity'] == sourceRarity).toList();
    if (eligible.length < 3) {
      setState(() => _status = '需 3 張 $sourceRarity，目前 ${eligible.length} 張');
      return;
    }
    final wuxings = eligible.map((m) => m['wuxing_attr']).toSet();
    if (wuxings.length > 1) {
      setState(() => _status = '所選需同五行（目前 ${wuxings.join("/")}）');
      return;
    }
    setState(() => _status = '鎔鑄中…');
    try {
      final ids = eligible.take(3).map((m) => m['id'] as String).toList();
      final r = await ref.read(clientProvider).forge(
            sourceIds: ids,
            targetRarity: target,
            charsAccumulated: target == 'rare' ? 500 : 2000,
          );
      setState(() => _status = '✨ 鎔鑄成功 → ${r["forged_monster_id"]?.toString().substring(0, 8)}');
      _selected.clear();
      await _load();
    } on LegendaryCapException catch (e) {
      setState(() => _status = '⚠ ${e.message}（已退 ${e.refundedIds.length} 張）');
      await _load();
    } catch (e) {
      setState(() => _status = '❌ ${friendlyError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final commons = _monsters.where((m) => m['rarity'] == 'common').toList();
    final rares = _monsters.where((m) => m['rarity'] == 'rare').toList();
    final legendaries = _monsters.where((m) => m['rarity'] == 'legendary').toList();
    final selectedCommons =
        _selected.where((id) => commons.any((m) => m['id'] == id)).length;
    final selectedRares =
        _selected.where((id) => rares.any((m) => m['id'] == id)).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('靈體圖鑑'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '圖例',
            onPressed: () => showHelpSheet(context, title: '靈體圖鑑 · 圖例', entries: const [
              HelpEntry('卡片大圖', '怪物 sprite（512px JPEG）。底色因五行屬性會有微微 tint。',
                  icon: Icons.image),
              HelpEntry('★ 數量', '稀有度：· common（最普通）/ ★ rare / ★★ legendary（神獸）。',
                  icon: Icons.star),
              HelpEntry('右上彩色徽章', '五行：金灰 / 木綠 / 水藍 / 火紅 / 土黃。決定戰鬥相剋。',
                  icon: Icons.circle),
              HelpEntry('暱稱與物種', '上方大字 = AI 取的暱稱；下方小字 = 山海經物種 + 棲位。',
                  icon: Icons.label),
              HelpEntry('⚔ 攻擊 / ♥ 血量', '戰鬥用基礎數值；稀有度越高數值越大。',
                  icon: Icons.bolt),
              HelpEntry('鎔鑄規則',
                  '選 3 張同五行 common 點底部 ★ rare；3 張同五行 rare 點 ★★ legendary。',
                  icon: Icons.local_fire_department),
              HelpEntry('種 3 common（測試）',
                  '右上角測試按鈕：免寫作快速生 3 張累+water common 進倉，方便 demo 鎔鑄。',
                  icon: Icons.science),
            ]),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Text(
                      '共 ${_monsters.length} · ★★${legendaries.length} ★${rares.length} ·${commons.length}',
                      style: const TextStyle(color: EchoColors.muted, fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _seed,
                      child: const Text('種 3 common（測試）', style: TextStyle(color: EchoColors.accentSoft)),
                    ),
                  ]),
                ),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_status, style: const TextStyle(color: EchoColors.muted, fontSize: 12)),
                  ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 1.7,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: _monsters.length,
                    itemBuilder: (_, i) => _MonsterCard(
                      m: _monsters[i],
                      selected: _selected.contains(_monsters[i]['id']),
                      onTap: () {
                        setState(() {
                          final id = _monsters[i]['id'] as String;
                          if (_selected.contains(id)) {
                            _selected.remove(id);
                          } else {
                            _selected.add(id);
                          }
                        });
                      },
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: EchoColors.border)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedCommons == 3 ? () => _forge('rare') : null,
                        child: Text('鎔鑄 ★ rare ($selectedCommons/3)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedRares == 3 ? () => _forge('legendary') : null,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA04040)),
                        child: Text('鎔鑄 ★★ leg ($selectedRares/3)'),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }
}

class _MonsterCard extends StatelessWidget {
  const _MonsterCard({required this.m, required this.selected, required this.onTap});
  final Map<String, dynamic> m;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rarity = m['rarity'] as String? ?? 'common';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: EchoColors.panel,
          border: Border.all(
            color: selected ? EchoColors.accent : EchoColors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sprite portrait (Phase 1: common-only bundled)
            Container(
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF0d1117),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: EchoColors.border, width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Builder(builder: (_) {
                  final path = SpriteResolver.instance.pathSync(
                    m['species_name'] as String? ?? '',
                    m['rarity'] as String? ?? 'common',
                  );
                  if (path == null) {
                    return const Icon(Icons.image_not_supported, color: EchoColors.muted);
                  }
                  return ColorFiltered(
                    colorFilter: _wuxingFilter(m['wuxing_attr'] as String? ?? 'earth'),
                    child: Image.asset(
                      path,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Icon(Icons.pets, color: EchoColors.muted, size: 32)),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text(
                  '${EchoColors.rarityStar(rarity)} ${m["nickname"] ?? m["species_name"] ?? "?"}',
                  style: const TextStyle(color: EchoColors.accent, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              WuxingBadge(m['wuxing_attr'] as String? ?? 'earth'),
            ]),
            const SizedBox(height: 4),
            Text(
              '${m["species_name"] ?? ""} · ${m["position"] ?? ""}',
              style: const TextStyle(color: EchoColors.muted, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: EchoColors.rarity(rarity),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(rarity, style: const TextStyle(color: EchoColors.muted, fontSize: 11)),
              const Spacer(),
              Text(
                '⚔ ${m["power_base"] ?? "?"} ♥ ${m["hp_base"] ?? "?"}',
                style: const TextStyle(color: EchoColors.fg, fontSize: 12),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Subtle tint per wuxing element. Identity for earth (canonical neutral).
ColorFilter _wuxingFilter(String wuxing) {
  // Subtle multiply tint — keeps base art readable
  switch (wuxing) {
    case 'metal':
      return const ColorFilter.matrix([
        1.05, 0,   0,   0, 0,
        0,    1,   0,   0, 0,
        0,    0,   1.1, 0, 0,
        0,    0,   0,   1, 0,
      ]);
    case 'wood':
      return const ColorFilter.matrix([
        0.85, 0,   0,   0, 0,
        0,    1.15,0,   0, 0,
        0,    0,   0.85,0, 0,
        0,    0,   0,   1, 0,
      ]);
    case 'water':
      return const ColorFilter.matrix([
        0.85, 0,   0,   0, 0,
        0,    0.95,0,   0, 0,
        0,    0,   1.2, 0, 0,
        0,    0,   0,   1, 0,
      ]);
    case 'fire':
      return const ColorFilter.matrix([
        1.2,  0,   0,   0, 0,
        0,    0.85,0,   0, 0,
        0,    0,   0.85,0, 0,
        0,    0,   0,   1, 0,
      ]);
    case 'earth':
    default:
      return const ColorFilter.mode(Color(0x00000000), BlendMode.dst);
  }
}
