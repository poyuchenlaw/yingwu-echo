// battle_arena.dart — 鏡境對決畫面
//
// Responsibilities:
//   - Display attacker vs defender HP bars
//   - Show current battle state (idle / summoned / mirror_window / captured)
//   - Five-element indicator (wuxing advantage badge)
//   - Imprint button (enabled during mirror_window_open)
//   - Reverse gambit notification (HP < 30%)
//
// TODO: wire WebSocket / SSE for live battle state updates
import 'package:flutter/material.dart';

class BattleArenaScreen extends StatefulWidget {
  const BattleArenaScreen({super.key});

  @override
  State<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class _BattleArenaScreenState extends State<BattleArenaScreen> {
  // TODO: replace with real BattleSession model from API
  double _attackerHPFraction = 1.0;
  double _defenderHPFraction = 1.0;
  String _battleState = 'idle';
  bool _mirrorWindowOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0500),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('鏡境對決', style: TextStyle(color: Color(0xFFD4A050))),
        iconTheme: const IconThemeData(color: Color(0xFFD4A050)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          _buildHPBar('攻方', _attackerHPFraction, const Color(0xFFD45050)),
          const SizedBox(height: 12),
          _buildHPBar('守方', _defenderHPFraction, const Color(0xFF50A0D4)),
          const Spacer(),
          _buildStateLabel(),
          const SizedBox(height: 16),
          _buildImprintButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHPBar(String label, double fraction, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9A7050))),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: fraction,
            backgroundColor: const Color(0xFF2A1500),
            valueColor: AlwaysStoppedAnimation<Color>(
              fraction < 0.30 ? const Color(0xFFFF4040) : color,
            ),
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
          ),
          if (fraction < 0.30)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '落後反轉觸發！',
                style: TextStyle(color: Color(0xFFFF8040), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStateLabel() {
    // TODO: localise state labels
    const stateLabels = {
      'idle': '待機',
      'summoned': '召喚中',
      'mirror_window_open': '映刻視窗開啟',
      'captured': '映刻成功',
      'returned_to_owner': '歸還原主',
    };
    return Text(
      stateLabels[_battleState] ?? _battleState,
      style: const TextStyle(color: Color(0xFFD4A050), fontSize: 20, letterSpacing: 2),
    );
  }

  Widget _buildImprintButton() {
    return ElevatedButton.icon(
      onPressed: _mirrorWindowOpen
          ? () {
              // TODO: call battle API to trigger imprint
              setState(() => _battleState = 'captured');
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD4A050),
        foregroundColor: const Color(0xFF1A0A00),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        disabledBackgroundColor: const Color(0xFF3A2010),
      ),
      icon: const Icon(Icons.flash_on),
      label: const Text('映刻', style: TextStyle(fontSize: 18, letterSpacing: 2)),
    );
  }
}
