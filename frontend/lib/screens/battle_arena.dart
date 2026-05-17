import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/echo_client.dart';
import '../main.dart';
import '../theme/echo_theme.dart';

class BattleArenaScreen extends ConsumerStatefulWidget {
  const BattleArenaScreen({super.key});
  @override
  ConsumerState<BattleArenaScreen> createState() => _BattleArenaState();
}

class _BattleArenaState extends ConsumerState<BattleArenaScreen> {
  List<Map<String, dynamic>> _monsters = [];
  String? _selectedId;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String _status = '';

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
      setState(() => _status = '❌ $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fight() async {
    if (_selectedId == null) return;
    setState(() {
      _loading = true;
      _result = null;
      _status = '召喚共鳴體…';
    });
    try {
      final r = await ref.read(clientProvider).battle(_selectedId!);
      setState(() {
        _result = r;
        _status = '';
      });
    } catch (e) {
      setState(() => _status = '❌ $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('鏡境對決'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            child: _loading && _monsters.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    children: _monsters.map((m) {
                      final id = m['id'] as String;
                      final sel = _selectedId == id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedId = id),
                        child: Container(
                          width: 150,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: EchoColors.panel,
                            border: Border.all(
                              color: sel ? EchoColors.accent : EchoColors.border,
                              width: sel ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${EchoColors.rarityStar(m["rarity"] as String? ?? "")} ${m["nickname"] ?? m["species_name"]}',
                                style: const TextStyle(color: EchoColors.accent),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              WuxingBadge(m['wuxing_attr'] as String? ?? 'earth'),
                              const Spacer(),
                              Text(
                                '⚔ ${m["power_base"]} ♥ ${m["hp_base"]}',
                                style: const TextStyle(color: EchoColors.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: _loading || _selectedId == null ? null : _fight,
              child: Text(_loading ? '對戰中…' : '出戰'),
            ),
          ),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_status, style: const TextStyle(color: EchoColors.muted)),
            ),
          if (_result != null)
            Expanded(child: _BattleLog(_result!)),
        ],
      ),
    );
  }
}

class _BattleLog extends StatelessWidget {
  const _BattleLog(this.r);
  final Map<String, dynamic> r;
  @override
  Widget build(BuildContext context) {
    final rounds = (r['rounds'] as List<dynamic>?) ?? const [];
    final outcomeCN = {
      'attacker_won': '勝',
      'defender_won': '敗',
      'mirror_window_open': '鏡之窗',
      'draw': '平',
    }[r['outcome'] as String? ?? ''] ?? r['outcome'] ?? '';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EchoColors.bg,
        border: Border.all(color: EchoColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListView(
        children: [
          Row(children: [
            Expanded(
              child: Text(
                '${r["attacker_species"]} vs ${r["defender_nickname"] ?? r["defender_species"]}',
                style: const TextStyle(color: EchoColors.accent, fontSize: 16),
              ),
            ),
            Text('×${r["damage_multiplier"]}', style: const TextStyle(color: EchoColors.muted)),
          ]),
          const SizedBox(height: 10),
          ...rounds.map((r0) {
            final round = r0 as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'T${round["turn"]} ${round["actor"] == "attacker" ? "你" : "敵"} -${round["damage"]}  →  你 ${round["attacker_hp"]} ｜ 敵 ${round["defender_hp"]}',
                style: const TextStyle(color: EchoColors.muted, fontFamily: 'monospace', fontSize: 12),
              ),
            );
          }),
          const SizedBox(height: 12),
          if (r['reverse_gambit_triggered'] == true)
            const Text('▽ Reverse Gambit 觸發', style: TextStyle(color: Color(0xFFE64B4B), fontWeight: FontWeight.w600)),
          if (r['mirror_window_opened'] == true)
            const Text('○ 鏡之窗開啟', style: TextStyle(color: EchoColors.accent, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('結果：$outcomeCN', style: const TextStyle(color: EchoColors.fg, fontSize: 15)),
          if (r['imprint_attempted'] == true) ...[
            const SizedBox(height: 6),
            Text(
              '印記 prob=${((r["imprint_probability"] as num).toDouble() * 100).toStringAsFixed(0)}% → ${r["imprint_success"] == true ? "✨ ${r["captured_nickname"]}" : "失敗"}',
              style: TextStyle(
                color: r['imprint_success'] == true ? const Color(0xFFD4A574) : EchoColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
