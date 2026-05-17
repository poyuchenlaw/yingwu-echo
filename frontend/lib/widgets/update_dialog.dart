import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/version_check.dart';
import '../theme/echo_theme.dart';

Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: EchoColors.panel,
    isScrollControlled: true,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: EchoColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.system_update, color: EchoColors.accent),
                const SizedBox(width: 10),
                Text(
                  '新版本 v${info.latestVersion}',
                  style: const TextStyle(
                    color: EchoColors.accent,
                    fontSize: 18,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '目前版本 v${info.currentVersion}',
              style: const TextStyle(color: EchoColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text('更新內容', style: TextStyle(color: EchoColors.fg, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EchoColors.bg,
                border: Border.all(color: EchoColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                child: Text(
                  info.notes.trim().isEmpty ? '（無 release notes）' : info.notes,
                  style: const TextStyle(
                    color: EchoColors.fg,
                    fontSize: 12.5,
                    height: 1.7,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: EchoColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('稍後',
                        style: TextStyle(color: EchoColors.muted)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      final url = info.apkUrl.isNotEmpty
                          ? info.apkUrl
                          : info.releaseUrl;
                      if (url.isEmpty) return;
                      Navigator.pop(ctx);
                      final uri = Uri.parse(url);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    child: const Text('下載並安裝'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '註：首次安裝需在系統設定允許「來自此來源的應用程式」一次性授權。',
              style: TextStyle(color: EchoColors.muted, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}
