import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';

/// Lossless bridge for preferences owned by installed Mihon source factories.
///
/// Chimahon identifies a preference store as `source_<native source id>`.
/// Mangatan's Isar source ID is a process-local hash and must never appear on
/// that wire. Unknown stores, keys, value types, and malformed values are left
/// untouched locally; the deferred payload retains their original protobuf.
class ChimahonSourcePreferencesAdapter {
  const ChimahonSourcePreferencesAdapter({
    this.codec = const ChimahonPreferenceCodec(),
  });

  final ChimahonPreferenceCodec codec;

  List<BackupSourcePreferences> export({
    required Iterable<Source> sources,
    Iterable<SourcePreference> storedPreferences = const [],
  }) {
    final storedBySource = <int, List<SourcePreference>>{};
    for (final preference in storedPreferences) {
      final sourceId = preference.sourceId;
      if (sourceId == null) continue;
      storedBySource.putIfAbsent(sourceId, () => []).add(preference);
    }

    final result = <String, BackupSourcePreferences>{};
    for (final source in sources) {
      final sourceKey = sourcePreferenceKey(source);
      final localId = source.id;
      if (sourceKey == null || localId == null) continue;

      final preferences = _preferencesFor(
        source,
        fallback: storedBySource[localId] ?? const [],
      );
      final encoded = <BackupPreference>[];
      for (final preference in preferences) {
        final key = preference.key;
        final value = _valueOf(preference);
        if (key == null || key.isEmpty || value == null) continue;
        encoded.add(codec.encode(key, value));
      }
      if (encoded.isNotEmpty) {
        encoded.sort((left, right) => left.key.compareTo(right.key));
        result[sourceKey] = BackupSourcePreferences(
          sourceKey: sourceKey,
          prefs: encoded,
        );
      }
    }
    final keys = result.keys.toList()..sort();
    return [for (final key in keys) result[key]!];
  }

  /// Applies compatible values to installed source definitions.
  ///
  /// This intentionally does not delete a local definition merely because it
  /// is absent remotely. An absent key can mean the extension now uses its
  /// default, while deleting the definition would also discard its UI schema.
  void importInto({
    required Isar database,
    required Iterable<BackupSourcePreferences> sourcePreferences,
  }) {
    final sources = database.sources.where().findAllSync();
    final remoteByKey = {
      for (final group in sourcePreferences) group.sourceKey: group,
    };
    if (remoteByKey.isEmpty) return;

    final stored = database.sourcePreferences.where().findAllSync();
    final storedBySource = <int, List<SourcePreference>>{};
    for (final preference in stored) {
      final sourceId = preference.sourceId;
      if (sourceId == null) continue;
      storedBySource.putIfAbsent(sourceId, () => []).add(preference);
    }

    final changedSources = <Source>[];
    final changedPreferences = <SourcePreference>[];
    for (final source in sources) {
      final sourceKey = sourcePreferenceKey(source);
      final localId = source.id;
      final remote = sourceKey == null ? null : remoteByKey[sourceKey];
      if (remote == null || localId == null) continue;

      final definitions = _preferencesFor(
        source,
        fallback: storedBySource[localId] ?? const [],
      );
      final definitionsByKey = <String, SourcePreference>{};
      for (final preference in definitions) {
        if (preference.key case final key?) {
          definitionsByKey[key] = preference;
        }
      }
      final storedByKey = <String, SourcePreference>{};
      for (final preference in storedBySource[localId] ?? const []) {
        if (preference.key case final key?) {
          storedByKey[key] = preference;
        }
      }
      var sourceChanged = false;
      for (final encoded in remote.prefs) {
        final definition = definitionsByKey[encoded.key];
        if (definition == null) continue;
        DecodedChimahonPreference decoded;
        try {
          decoded = codec.decode(encoded);
        } on Object {
          continue;
        }
        if (!_applyCompatible(definition, decoded)) continue;
        sourceChanged = true;

        final persisted = SourcePreference.fromJson(definition.toJson())
          ..id = storedByKey[encoded.key]?.id
          ..sourceId = localId;
        changedPreferences.add(persisted);
        storedByKey[encoded.key] = persisted;
      }
      if (!sourceChanged) continue;
      source.preferenceList = jsonEncode(
        definitions.map((preference) => preference.toJson()).toList(),
      );
      changedSources.add(source);
    }

    if (changedSources.isEmpty && changedPreferences.isEmpty) return;
    database.writeTxnSync(() {
      if (changedSources.isNotEmpty) {
        database.sources.putAllSync(changedSources);
      }
      if (changedPreferences.isNotEmpty) {
        database.sourcePreferences.putAllSync(changedPreferences);
      }
    });
  }

  /// Returns Chimahon's portable preference-store key for [source].
  String? sourcePreferenceKey(Source source) {
    if (source.sourceCodeLanguage != SourceCodeLanguage.mihon) return null;
    final encodedId = mihonSourceMetadata(source)?.sourceId.trim();
    final nativeId = int.tryParse(encodedId ?? '');
    if (nativeId == null) return null;
    return 'source_$nativeId';
  }

  List<SourcePreference> _preferencesFor(
    Source source, {
    required Iterable<SourcePreference> fallback,
  }) {
    final byKey = <String, SourcePreference>{};
    final payload = source.preferenceList;
    if (payload != null && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is List) {
          for (final value in decoded.whereType<Map>()) {
            final preference = SourcePreference.fromJson(
              value.map((key, item) => MapEntry(key.toString(), item)),
            );
            final key = preference.key;
            if (key != null && key.isNotEmpty) byKey[key] = preference;
          }
        }
      } on Object {
        // Fall back to the normalized Isar rows below.
      }
    }
    for (final preference in fallback) {
      final key = preference.key;
      if (key != null && key.isNotEmpty) {
        byKey.putIfAbsent(key, () => preference);
      }
    }
    return byKey.values.toList(growable: false);
  }

  Object? _valueOf(SourcePreference preference) {
    if (preference.checkBoxPreference case final value?) return value.value;
    if (preference.switchPreferenceCompat case final value?) {
      return value.value;
    }
    if (preference.editTextPreference case final value?) {
      return value.value ?? value.text;
    }
    if (preference.listPreference case final value?) {
      final index = value.valueIndex;
      final values = value.entryValues ?? const <String>[];
      if (index == null || index < 0 || index >= values.length) return null;
      return values[index];
    }
    if (preference.multiSelectListPreference case final value?) {
      final values = value.values;
      return values?.toSet();
    }
    return null;
  }

  bool _applyCompatible(
    SourcePreference preference,
    DecodedChimahonPreference decoded,
  ) {
    if (preference.checkBoxPreference case final target?) {
      if (decoded.kind != ChimahonPreferenceKind.boolean ||
          decoded.value is! bool) {
        return false;
      }
      final value = decoded.value! as bool;
      target.value = value;
      return true;
    }
    if (preference.switchPreferenceCompat case final target?) {
      if (decoded.kind != ChimahonPreferenceKind.boolean ||
          decoded.value is! bool) {
        return false;
      }
      final value = decoded.value! as bool;
      target.value = value;
      return true;
    }
    if (preference.editTextPreference case final target?) {
      if (decoded.kind != ChimahonPreferenceKind.string ||
          decoded.value is! String) {
        return false;
      }
      final value = decoded.value! as String;
      target
        ..value = value
        ..text = value;
      return true;
    }
    if (preference.listPreference case final target?) {
      if (decoded.kind != ChimahonPreferenceKind.string ||
          decoded.value is! String) {
        return false;
      }
      final index = target.entryValues?.indexOf(decoded.value! as String) ?? -1;
      if (index < 0) return false;
      target.valueIndex = index;
      return true;
    }
    if (preference.multiSelectListPreference case final target?) {
      if (decoded.kind != ChimahonPreferenceKind.stringSet ||
          decoded.value is! Set<String>) {
        return false;
      }
      final value = decoded.value! as Set<String>;
      final entryValues = target.entryValues ?? const <String>[];
      target.values = [
        for (final entry in entryValues)
          if (value.contains(entry)) entry,
        for (final entry in value)
          if (!entryValues.contains(entry)) entry,
      ];
      return true;
    }
    return false;
  }
}
