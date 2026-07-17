import 'package:mangayomi/models/source.dart';

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
  for (final source in sources) {
    if (installedOnly && !(source.isAdded ?? false)) continue;
    if (source.sourceCode == null) continue;

    final matches = sourceId != null
        ? source.id == sourceId
        : source.name?.toLowerCase() == name.toLowerCase() &&
              source.lang == lang;
    if (matches) return source;
  }
  return null;
}
