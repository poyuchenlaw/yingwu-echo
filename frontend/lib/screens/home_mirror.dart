// home_mirror.dart — 主鏡畫面（靈魂映照儀表板）
//
// Responsibilities:
//   - Display player's active monster companion
//   - Show today's writing streak and growth points
//   - Entry point to write_today, incarnation_view, battle_arena
//
// TODO: wire up API service once backend /player endpoint is ready
import 'package:flutter/material.dart';
import 'write_today.dart';
import 'incarnation_view.dart';
import 'battle_arena.dart';

class HomeMirrorScreen extends StatelessWidget {
  const HomeMirrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A00),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          '應物 ECHO',
          style: TextStyle(
            fontFamily: 'serif',
            letterSpacing: 4,
            color: Color(0xFFD4A050),
          ),
        ),
        centerTitle: true,
      ),
      body: const _HomeMirrorBody(),
      bottomNavigationBar: _buildNavBar(context),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    // TODO: replace with proper state-driven navigator (go_router)
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF2A1500),
      selectedItemColor: const Color(0xFFD4A050),
      unselectedItemColor: const Color(0xFF7A5030),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '鏡境'),
        BottomNavigationBarItem(icon: Icon(Icons.edit), label: '書寫'),
        BottomNavigationBarItem(icon: Icon(Icons.pets), label: '靈體'),
        BottomNavigationBarItem(icon: Icon(Icons.sports_martial_arts), label: '對決'),
      ],
      onTap: (index) {
        switch (index) {
          case 1:
            Navigator.push(context, MaterialPageRoute(builder: (_) => const WriteTodayScreen()));
            break;
          case 2:
            Navigator.push(context, MaterialPageRoute(builder: (_) => const IncarnationViewScreen()));
            break;
          case 3:
            Navigator.push(context, MaterialPageRoute(builder: (_) => const BattleArenaScreen()));
            break;
        }
      },
    );
  }
}

class _HomeMirrorBody extends StatelessWidget {
  const _HomeMirrorBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // TODO: replace with actual monster sprite from assets/
          const Icon(Icons.blur_circular, size: 120, color: Color(0xFFD4A050)),
          const SizedBox(height: 16),
          const Text(
            '心之核', // TODO: replace with player's monster name
            style: TextStyle(fontSize: 24, color: Color(0xFFD4A050), letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          // TODO: wire to real growth_points from API
          const Text('成長值: --', style: TextStyle(color: Color(0xFF9A7050))),
          const SizedBox(height: 32),
          _buildStreakIndicator(),
        ],
      ),
    );
  }

  Widget _buildStreakIndicator() {
    // TODO: wire to real writing streak data
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        return Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < 3 ? const Color(0xFFD4A050) : const Color(0xFF3A2010),
          ),
        );
      }),
    );
  }
}
