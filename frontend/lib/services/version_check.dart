import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.apkUrl,
    required this.notes,
    required this.releaseUrl,
  });
  final String currentVersion;
  final String latestVersion;
  final String apkUrl;
  final String notes;
  final String releaseUrl;
}

class VersionCheck {
  VersionCheck._();
  static final instance = VersionCheck._();

  static const String _owner = 'poyuchenlaw';
  static const String _repo = 'yingwu-echo';

  /// Returns UpdateInfo if remote tag is newer than current. Null otherwise
  /// (including any network failure — silent for end users on launch).
  Future<UpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final r = await http
          .get(
            Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = json.decode(r.body) as Map<String, dynamic>;
      final tag = (j['tag_name'] as String? ?? '').trim();
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latest.isEmpty) return null;
      if (!_isNewer(current, latest)) return null;
      final assets = (j['assets'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final apk = assets.firstWhere(
        (a) => (a['name'] as String? ?? '').endsWith('.apk'),
        orElse: () => const <String, dynamic>{},
      );
      final apkUrl = apk['browser_download_url'] as String? ?? '';
      final notes = j['body'] as String? ?? '';
      final url = j['html_url'] as String? ?? '';
      return UpdateInfo(
        currentVersion: current,
        latestVersion: latest,
        apkUrl: apkUrl,
        notes: notes,
        releaseUrl: url,
      );
    } catch (_) {
      return null;
    }
  }

  /// semver-ish compare: split by '.', compare ints. Falls back to string compare.
  static bool _isNewer(String current, String latest) {
    final a = current.split('.').map(int.tryParse).toList();
    final b = latest.split('.').map(int.tryParse).toList();
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final ai = i < a.length ? (a[i] ?? 0) : 0;
      final bi = i < b.length ? (b[i] ?? 0) : 0;
      if (bi > ai) return true;
      if (bi < ai) return false;
    }
    return false;
  }
}
