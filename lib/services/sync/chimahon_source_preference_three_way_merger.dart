import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_preference_safety_policy.dart';
import 'package:mangayomi/services/sync/chimahon_preference_three_way_merger.dart';

class ChimahonSourcePreferenceMergeResult {
  ChimahonSourcePreferenceMergeResult({
    required Iterable<BackupSourcePreferences> preferences,
    required Map<ChimahonSourcePreferenceKey, ChimahonPreferenceSelectionOrigin>
    selections,
    required Map<String, ChimahonPreferenceSelectionOrigin>
    sourceGroupEnvelopeSelections,
  }) : preferences = List.unmodifiable(preferences),
       selections = Map.unmodifiable(selections),
       sourceGroupEnvelopeSelections = Map.unmodifiable(
         sourceGroupEnvelopeSelections,
       );

  final List<BackupSourcePreferences> preferences;
  final Map<ChimahonSourcePreferenceKey, ChimahonPreferenceSelectionOrigin>
  selections;
  final Map<String, ChimahonPreferenceSelectionOrigin>
  sourceGroupEnvelopeSelections;

  Set<ChimahonSourcePreferenceKey> get remoteAuthoritativeKeys =>
      Set.unmodifiable(
        selections.entries
            .where(
              (entry) =>
                  entry.value == ChimahonPreferenceSelectionOrigin.remote,
            )
            .map((entry) => entry.key),
      );
}

/// Three-way reconciliation for per-source preference stores.
///
/// The raw deferred payload is the previous remote baseline, while [local]
/// contains only preferences Mangatan can project for sources installed on
/// this device. A source absent from [local] is therefore not a deletion: it
/// is an uninstalled/opaque source whose current remote representation wins.
class ChimahonSourcePreferenceThreeWayMerger {
  const ChimahonSourcePreferenceThreeWayMerger({
    this.preferenceMerger = const ChimahonPreferenceThreeWayMerger(),
  });

  final ChimahonPreferenceThreeWayMerger preferenceMerger;

  List<BackupSourcePreferences> merge({
    required Iterable<BackupSourcePreferences> baseline,
    Iterable<BackupSourcePreferences>? localBaseline,
    required Iterable<BackupSourcePreferences> local,
    required Iterable<BackupSourcePreferences> remote,
  }) => mergeWithSafetyPolicy(
    baseline: baseline,
    localBaseline: localBaseline,
    local: local,
    remote: remote,
  ).preferences;

  ChimahonSourcePreferenceMergeResult mergeWithSafetyPolicy({
    required Iterable<BackupSourcePreferences> baseline,
    Iterable<BackupSourcePreferences>? localBaseline,
    required Iterable<BackupSourcePreferences> local,
    required Iterable<BackupSourcePreferences> remote,
  }) {
    final baselineByKey = _byKey(baseline);
    final localBaselineByKey = localBaseline == null
        ? const <String, BackupSourcePreferences>{}
        : _byKey(localBaseline);
    final localByKey = _byKey(local);
    final remoteByKey = _byKey(remote);
    final localOnlyKeys =
        localByKey.keys.where((key) => !remoteByKey.containsKey(key)).toList()
          ..sort();
    final keys = [...remoteByKey.keys, ...localOnlyKeys];

    final result = <BackupSourcePreferences>[];
    final selections =
        <ChimahonSourcePreferenceKey, ChimahonPreferenceSelectionOrigin>{};
    final sourceGroupEnvelopeSelections =
        <String, ChimahonPreferenceSelectionOrigin>{};
    for (final key in keys) {
      final localGroup = localByKey[key];
      final remoteGroup = remoteByKey[key];

      // No local projection means that this source is unavailable here. Its
      // opaque store follows the current remote snapshot, including deletion.
      if (localGroup == null) {
        if (remoteGroup != null) {
          result.add(remoteGroup.deepCopy());
          for (final preference in remoteGroup.prefs) {
            selections[(sourceKey: key, preferenceKey: preference.key)] =
                ChimahonPreferenceSelectionOrigin.remote;
          }
          if (remoteGroup.unknownFields.isNotEmpty) {
            sourceGroupEnvelopeSelections[key] =
                ChimahonPreferenceSelectionOrigin.remote;
          }
        }
        continue;
      }

      // Source preference definitions are supplied by the installed
      // extension. A key disappearing from the projection means the extension
      // no longer exposes it, not that the user deleted an opaque remote key.
      final projectedKeys = {
        for (final preference in localGroup.prefs) preference.key,
      };
      final preferenceResult = preferenceMerger.mergeWithSafetyPolicy(
        baseline:
            baselineByKey[key]?.prefs.where(
              (preference) => projectedKeys.contains(preference.key),
            ) ??
            const [],
        localBaseline: localBaselineByKey[key]?.prefs.where(
          (preference) => projectedKeys.contains(preference.key),
        ),
        local: localGroup.prefs,
        remote: remoteGroup?.prefs ?? const [],
      );
      final preferences = preferenceResult.preferences;
      for (final entry in preferenceResult.selections.entries) {
        selections[(sourceKey: key, preferenceKey: entry.key)] = entry.value;
      }

      final merged = BackupSourcePreferences(sourceKey: key, prefs: preferences)
        ..mergeUnknownFields(localGroup.unknownFields);
      if (remoteGroup != null) {
        merged.mergeUnknownFields(remoteGroup.unknownFields);
      }
      if (merged.unknownFields.isNotEmpty) {
        sourceGroupEnvelopeSelections[key] =
            remoteGroup?.unknownFields.isNotEmpty == true
            ? ChimahonPreferenceSelectionOrigin.remote
            : ChimahonPreferenceSelectionOrigin.local;
      }
      if (preferences.isEmpty && merged.unknownFields.isEmpty) continue;
      // If the projection contributed no source-envelope data and every
      // selected nested preference is the exact remote message in the exact
      // remote order, retain the whole group. Besides avoiding unnecessary
      // allocations, this guarantees byte-stable proto3 field presence and
      // future-field envelopes for a routine no-edit preview.
      result.add(
        remoteGroup != null &&
                localGroup.unknownFields.isEmpty &&
                _samePreferenceSequence(preferences, remoteGroup.prefs)
            ? remoteGroup.deepCopy()
            : merged,
      );
    }
    return ChimahonSourcePreferenceMergeResult(
      preferences: result,
      selections: selections,
      sourceGroupEnvelopeSelections: sourceGroupEnvelopeSelections,
    );
  }

  Map<String, BackupSourcePreferences> _byKey(
    Iterable<BackupSourcePreferences> values,
  ) => {for (final value in values) value.sourceKey: value};

  bool _samePreferenceSequence(
    Iterable<BackupPreference> first,
    Iterable<BackupPreference> second,
  ) {
    final firstValues = first.toList(growable: false);
    final secondValues = second.toList(growable: false);
    if (firstValues.length != secondValues.length) return false;
    for (var index = 0; index < firstValues.length; index++) {
      final firstBytes = firstValues[index].writeToBuffer();
      final secondBytes = secondValues[index].writeToBuffer();
      if (firstBytes.length != secondBytes.length) return false;
      for (var byteIndex = 0; byteIndex < firstBytes.length; byteIndex++) {
        if (firstBytes[byteIndex] != secondBytes[byteIndex]) return false;
      }
    }
    return true;
  }
}
