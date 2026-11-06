import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';

/// Resolves a stored source without treating Browse visibility as runtime
/// availability.
///
/// [Source.isActive] deliberately does not participate here: language filters
/// use it to hide sources, while [Source.isAdded] records whether source code is
/// installed for library operations.
Source? findSourceFromList(
  Iterable<Source> sources, {
  required String lang,
  required String name,
  required int? sourceId,
  bool installedOnly = false,
}) {
  final lowerName = name.toLowerCase();
  Source? nameOnly;
  var nameOnlyCount = 0;
  for (final source in sources) {
    if (installedOnly && !(source.isAdded ?? false)) continue;
    if (installedOnly &&
        mihonSourceMetadata(source)?.factoryAvailable == false) {
      continue;
    }
    if (source.sourceCode == null) continue;

    if (sourceId != null) {
      if (source.id == sourceId) return source;
      continue;
    }
    if (source.name?.toLowerCase() != lowerName) continue;
    if (source.lang == lang) return source;
    nameOnly = source;
    nameOnlyCount++;
  }
  // A title restored or synced before its extension was installed carries
  // no source id and a placeholder language (the backup format stores only
  // the source's name). When exactly one source of that name is available,
  // it is the title's source; with several, the language cannot be guessed.
  return sourceId == null && nameOnlyCount == 1 ? nameOnly : null;
}
