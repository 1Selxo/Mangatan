import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/source.dart';

const _retiredKeiyoushiPath = '/keiyoushi/extensions/';
const _yuzonoMangaRepo =
    'https://raw.githubusercontent.com/yuzono/manga-repo/repo/index.min.json';

List<String> extensionIconCandidates(Source source) {
  final candidates = <String>[];

  void add(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty && !candidates.contains(normalized)) {
      candidates.add(normalized);
    }
  }

  add(source.iconUrl);
  if (source.sourceCodeLanguage != SourceCodeLanguage.mihon) {
    return candidates;
  }

  final packageName = mihonSourceMetadata(source)?.packageName.trim() ?? '';
  if (packageName.isEmpty) return candidates;

  add(extensionRepositoryIconUrl(source.repo?.jsonUrl, packageName));

  final usesRetiredKeiyoushiIcons = candidates.any(
    (url) => url.toLowerCase().contains(_retiredKeiyoushiPath),
  );
  if (usesRetiredKeiyoushiIcons &&
      packageName.startsWith('eu.kanade.tachiyomi.extension.')) {
    add(extensionRepositoryIconUrl(_yuzonoMangaRepo, packageName));
  }

  return candidates;
}

String? extensionRepositoryIconUrl(String? indexUrl, String packageName) {
  final normalizedIndex = indexUrl?.trim() ?? '';
  final normalizedPackage = packageName.trim();
  if (normalizedIndex.isEmpty || normalizedPackage.isEmpty) return null;

  final uri = Uri.tryParse(normalizedIndex);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

  final segments = [...uri.pathSegments];
  if (segments.isEmpty) return null;
  segments
    ..removeLast()
    ..add('icon')
    ..add('$normalizedPackage.png');

  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    pathSegments: segments,
  ).toString();
}
