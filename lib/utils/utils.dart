import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/utils/source_lookup.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';

/// The stored sources [getSource] can answer with for these arguments.
///
/// Every installed source carries its whole extension, so loading them all to
/// pick one is slow. This narrows the query to the rows that can match: the
/// id when there is one (ids are unique), otherwise the exact language.
/// [findSourceFromList] still applies every check to what it returns.
QueryBuilder<Source, Source, QAfterFilterCondition> sourceLookupQuery(
  String lang,
  int? sourceId, {
  bool installedOnly = false,
}) {
  var sourcesFilter = isar.sources.filter().idIsNotNull();
  if (installedOnly) {
    // isActive is the Browse language/source visibility filter. A hidden
    // source remains installed and must still serve existing library items.
    sourcesFilter = sourcesFilter.isAddedEqualTo(true);
  }
  return sourceId != null
      ? sourcesFilter.idEqualTo(sourceId)
      : sourcesFilter.langEqualTo(lang);
}

Source? getSource(
  String lang,
  String name,
  int? sourceId, {
  bool installedOnly = false,
}) {
  try {
    final sourcesList = sourceLookupQuery(
      lang,
      sourceId,
      installedOnly: installedOnly,
    ).findAllSync();
    return findSourceFromList(
      sourcesList,
      lang: lang,
      name: name,
      sourceId: sourceId,
      installedOnly: installedOnly,
    );
  } catch (_) {
    return null;
  }
}
