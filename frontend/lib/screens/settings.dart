import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../api/echo_client.dart';
import '../main.dart';
import '../services/local_journal.dart';
import '../services/version_check.dart';
import '../theme/echo_theme.dart';
import '../widgets/update_dialog.dart';

const _presets = <String, String>{
  '正式線（推薦）': 'https://yingwu.kuangshin.tw',
  'Tailscale（內網）': 'http://100.84.86.128:8080',
  'Android 模擬器': 'http://10.0.2.2:8080',
  '本機 localhost': 'http://127.0.0.1:8080',
};

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _ctl;
  String _status = '';
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: ref.read(apiBaseProvider));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _ctl.text.trim();
    if (v.isEmpty) {
      setState(() => _status = '位址不可空');
      return;
    }
    await ref.read(settingsProvider).setApiBase(v);
    ref.read(apiBaseProvider.notifier).state = v;
    setState(() => _status = '✓ 已儲存：$v');
  }

  Future<void> _test() async {
    final v = _ctl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _testing = true;
      _status = '測試中…';
    });
    try {
      final client = EchoClient(base: v);
      final h = await client.health();
      setState(() => _status = '✓ 後端在線：${h["service"]} / ${h["status"]}');
    } catch (e) {
      setState(() => _status = '❌ ${friendlyError(e)}');
    } finally {
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API 位址（後端伺服器）',
              style: TextStyle(color: EchoColors.accent, fontSize: 16, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            const Text(
              '此版 APK 後端跑在開發機（WSL2）上。實機需透過 Tailscale 連線；模擬器走 10.0.2.2 預設。',
              style: TextStyle(color: EchoColors.muted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctl,
              decoration: const InputDecoration(
                hintText: 'http://100.84.86.128:8080',
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            const Text('預設選項', style: TextStyle(color: EchoColors.muted, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.entries
                  .map((e) => ActionChip(
                        label: Text(e.key),
                        backgroundColor: EchoColors.bg,
                        side: const BorderSide(color: EchoColors.border),
                        labelStyle: const TextStyle(color: EchoColors.fg, fontSize: 12),
                        onPressed: () => setState(() => _ctl.text = e.value),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _testing ? null : _test,
                  child: Text(_testing ? '測試中…' : '測試連線'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: EchoColors.accentSoft),
                  child: const Text('儲存'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EchoColors.panel,
                  border: Border.all(color: EchoColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_status,
                    style: const TextStyle(color: EchoColors.fg, fontSize: 13, height: 1.5)),
              ),
            const SizedBox(height: 28),
            const Divider(color: EchoColors.border),
            const SizedBox(height: 12),
            const Text('我的書寫歷程',
                style: TextStyle(color: EchoColors.accent, fontSize: 14, letterSpacing: 1)),
            const SizedBox(height: 6),
            const Text(
              '所有書寫主要存在後端資料庫，手機本地有完整快取。可隨時匯出 JSON 分享到 Drive / 信箱 / LINE 自己保管。',
              style: TextStyle(color: EchoColors.muted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('匯出書寫歷程 JSON'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: EchoColors.border),
                foregroundColor: EchoColors.fg,
              ),
              onPressed: () async {
                final n = await LocalJournal.instance.count();
                if (n == 0) {
                  if (!mounted) return;
                  setState(() => _status = '尚無書寫紀錄可匯出');
                  return;
                }
                setState(() => _status = '匯出中…');
                final jsonStr = await LocalJournal.instance.exportAllJson();
                final dir = await getTemporaryDirectory();
                final ts = DateTime.now()
                    .toIso8601String()
                    .replaceAll(':', '')
                    .substring(0, 15);
                final f = File('${dir.path}/yingwu-journal-$ts.json');
                await f.writeAsString(jsonStr);
                if (!mounted) return;
                setState(() => _status = '✓ 已產出 $n 篇，請選擇分享目的地');
                await Share.shareXFiles(
                  [XFile(f.path, mimeType: 'application/json')],
                  subject: '應物 ECHO · 書寫歷程',
                  text: '我在應物 ECHO 累積的 $n 篇書寫歷程',
                );
              },
            ),
            const SizedBox(height: 28),
            const Divider(color: EchoColors.border),
            const SizedBox(height: 12),
            const Text('版本與更新',
                style: TextStyle(color: EchoColors.accent, fontSize: 14, letterSpacing: 1)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.system_update, size: 18),
              label: const Text('立即檢查更新'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: EchoColors.border),
                foregroundColor: EchoColors.fg,
              ),
              onPressed: () async {
                setState(() => _status = '查詢 GitHub Release…');
                final info = await VersionCheck.instance.check();
                if (!mounted) return;
                if (info == null) {
                  setState(() => _status = '✓ 已是最新版本（或 GitHub 暫不可達）');
                  return;
                }
                setState(() => _status = '⬆ 發現 v${info.latestVersion}');
                if (!context.mounted) return;
                await showUpdateDialog(context, info);
              },
            ),
            const SizedBox(height: 28),
            const Divider(color: EchoColors.border),
            const SizedBox(height: 12),
            const Text(
              '常見問題',
              style: TextStyle(color: EchoColors.accent, fontSize: 14, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            _qa('連不到後端怎麼辦？',
                '依序檢查：① WSL2 端 backend 是否啟動 ② 手機 Tailscale 是否登入並 connect ③ 上方位址是否與 Tailscale 顯示的 IP 相同。'),
            _qa('Tailscale 是什麼？',
                '一個讓手機跨網路直連到開發機的 VPN。在手機商店搜尋「Tailscale」安裝，登入相同帳號即可看到 100.84.86.128 這台主機。'),
            _qa('為什麼預設是 10.0.2.2？',
                '那是 Android 模擬器專用的 host loopback，連到開發機的 localhost。實機沒有這個位址，必須改 Tailscale。'),
          ],
        ),
      ),
    );
  }

  Widget _qa(String q, String a) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Q · $q', style: const TextStyle(color: EchoColors.fg, fontSize: 13)),
            const SizedBox(height: 4),
            Text(a, style: const TextStyle(color: EchoColors.muted, fontSize: 12, height: 1.6)),
          ],
        ),
      );
}
