import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../theme/echo_theme.dart';
import 'home_mirror.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen> {
  final _ctl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    await ref.read(settingsProvider).markOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeMirrorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pages = <_Slide>[
      _Slide(
        icon: Icons.blur_circular,
        title: '應物 ECHO',
        body: '把你日常的感受寫下來，AI 會把它對映成一個山海經風格的「共鳴體」。\n\n'
            '本作是書寫＋怪物收集的混合作品。你寫的越真，你收的怪物越獨特。',
      ),
      _Slide(
        icon: Icons.edit_note,
        title: '今日書寫',
        body: '寫一段你今天的情緒，從 10 個情緒標籤裡選一個。\n\n'
            '系統會用 Gemini 分析：\n'
            '· 五行屬性（金木水火土）\n'
            '· 九曜共鳴\n'
            '· 一隻獨一無二的共鳴體（含暱稱與 quote）\n'
            '· 真誠度（0-100%）',
      ),
      _Slide(
        icon: Icons.pets,
        title: '靈體圖鑑 / 鎔鑄',
        body: '收藏的共鳴體會排列成卡片格子。每張卡片：\n\n'
            '· ★ 數量 = 稀有度（· common / ★ rare / ★★ legendary）\n'
            '· 圓形彩標 = 五行（金灰／木綠／水藍／火紅／土黃）\n'
            '· ⚔ 攻擊 ♥ 血量\n\n'
            '選 3 張同五行 common 可鎔鑄出 rare；3 張同五行 rare 可鎔鑄 legendary。',
      ),
      _Slide(
        icon: Icons.flash_on,
        title: '鏡境對決',
        body: '選一隻共鳴體出戰 NPC 山海者。每回合會打出傷害記錄。\n\n'
            '· 勝利可推進挑戰\n'
            '· 出現「鏡之窗」時可永久收編對方共鳴體\n'
            '· 五行相剋會給傷害倍率\n\n'
            '右上 ? 可隨時叫出對應頁的圖例說明，⚙ 可調 API 位址。',
      ),
    ];
    final isLast = _page == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _ctl,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (i) {
                  final active = i == _page;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? EchoColors.accent : EchoColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _done,
                    child: const Text('略過', style: TextStyle(color: EchoColors.muted)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (isLast) {
                        _done();
                      } else {
                        _ctl.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: Text(isLast ? '開始體驗' : '下一步'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: EchoColors.accent, size: 72),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  color: EchoColors.accent, fontSize: 28, letterSpacing: 4, height: 1.4)),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                body,
                style: const TextStyle(color: EchoColors.fg, fontSize: 15, height: 1.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
