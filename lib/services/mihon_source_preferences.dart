import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/models/source.dart';

/// Decodes the preference schema and values persisted on a Mihon source.
///
/// Malformed extension data is treated as absent so callers can fall back to
/// normalized Isar rows or a freshly queried bridge schema.
List<SourcePreference> decodeMihonSourcePreferences(String? payload) {
  if (payload == null || payload.isEmpty) return const [];
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (value) => SourcePreference.fromJson(
            value.map((key, item) => MapEntry(key.toString(), item)),
          ),
        )
        .toList(growable: false);
  } on Object {
    return const [];
  }
}

/// Merges preference definitions by key while preserving [primary] values.
List<SourcePreference> mergeMihonSourcePreferenceDefinitions(
  Iterable<SourcePreference> primary,
  Iterable<SourcePreference> fallback,
) {
  final byKey = <String, SourcePreference>{};
  for (final preference in [...primary, ...fallback]) {
    final key = preference.key;
    if (key != null && key.isNotEmpty) {
      byKey.putIfAbsent(key, () => preference);
    }
  }
  return byKey.values.toList(growable: false);
}

/// Reads one source's serialized definitions plus normalized fallback rows.
List<SourcePreference> loadPersistedMihonSourcePreferences(
  Isar database,
  Source source,
) {
  final sourceId = source.id;
  final normalized = sourceId == null
      ? const <SourcePreference>[]
      : database.sourcePreferences
            .filter()
            .sourceIdEqualTo(sourceId)
            .findAllSync();
  return mergeMihonSourcePreferenceDefinitions(
    decodeMihonSourcePreferences(source.preferenceList),
    normalized,
  );
}
