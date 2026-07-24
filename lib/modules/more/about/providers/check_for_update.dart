import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/services/fetch_sources_list.dart';
import 'package:mangayomi/services/http/m_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'check_for_update.g.dart';

/// Convenience alias: (version, body, htmlUrl, assets).
typedef UpdateInfo = (String, String, String, List<dynamic>);

/// Automatic update-check provider.
///
/// Respects the user's [checkForAppUpdatesProvider] preference.  Returns
/// [UpdateInfo] when a newer version exists, `null` otherwise.
@riverpod
Future<UpdateInfo?> checkForUpdate(Ref ref) async {
  if (!ref.read(checkForAppUpdatesProvider)) return null;
  return _getUpdateIfAvailable();
}

/// Compares the running version against the latest release.
/// Returns [UpdateInfo] when an update is available, or `null` when already
/// up-to-date.  Throws if the network request fails.
Future<UpdateInfo?> _getUpdateIfAvailable() async {
  final info = await PackageInfo.fromPlatform();
  if (kDebugMode) {
    log(info.data.toString());
  }
  final latest = await _fetchLatestRelease();
  return compareVersions(info.version, latest.$1) < 0 ? latest : null;
}

@riverpod
bool checkForAppUpdates(Ref ref) {
  return isar.settings.getSync(227)?.checkForAppUpdates ?? true;
}

/// Performs an update check unconditionally, ignoring the auto-update setting.
Future<UpdateInfo?> performManualUpdateCheck() => _getUpdateIfAvailable();

Future<UpdateInfo> _fetchLatestRelease() async {
  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  final res = await http.get(
    Uri.parse(
      'https://api.github.com/repos/1Selxo/Mangatan/releases?per_page=20',
    ),
  );
  if (res.statusCode != 200) {
    throw StateError('GitHub release check failed (${res.statusCode})');
  }

  final releases = jsonDecode(res.body) as List<dynamic>;
  final release = releases.cast<Map<String, dynamic>>().firstWhere(
    (entry) => entry['draft'] != true,
    orElse: () => throw StateError('No Mangatan release is available'),
  );
  final tag = release['tag_name']?.toString() ?? '';
  final version = RegExp(r'\d+\.\d+\.\d+').firstMatch(tag)?.group(0);
  if (version == null) {
    throw StateError('Mangatan release has an invalid tag: $tag');
  }

  return (
    version,
    release['body']?.toString() ?? '',
    release['html_url']?.toString() ??
        'https://github.com/1Selxo/Mangatan/releases',
    (release['assets'] as List<dynamic>? ?? const [])
        .map((asset) => (asset as Map<String, dynamic>)['browser_download_url'])
        .whereType<String>()
        .toList(),
  );
}
