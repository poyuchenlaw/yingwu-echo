// incarnation_view.dart — 靈體化身畫面（怪獸圖鑑 + 煉化入口）
//
// Responsibilities:
//   - List player's monsters grouped by species / rarity
//   - Show forge eligibility indicator
//   - Navigate to forge modal
//
// TODO: wire GET /api/player/monsters
import 'package:flutter/material.dart';

class IncarnationViewScreen extends StatelessWidget {
  const IncarnationViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A00),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('靈體圖鑑', style: TextStyle(color: Color(0xFFD4A050))),
        iconTheme: const IconThemeData(color: Color(0xFFD4A050)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFFD4A050)),
            tooltip: '煉化',
            onPressed: () {
              // TODO: open forge bottom sheet
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          '靈體列表載入中...',
          style: TextStyle(color: Color(0xFF7A5030)),
        ),
        // TODO: replace with GridView of MonsterCard widgets
      ),
    );
  }
}
