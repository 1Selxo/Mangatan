import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_preference_safety_policy.dart';

class ChimahonPreferenceMergeResult {
  ChimahonPreferenceMergeResult({
    required Iterable<BackupPreference> preferences,
    required Map<String, ChimahonPreferenceSelectionOrigin> selections,
  }) : preferences = List.unmodifiable(preferences),
       selections = Map.unmodifiable(selections);

  final List<BackupPreference> preferences;
  final Map<String, ChimahonPreferenceSelectionOrigin> selections;

  Set<String> get remoteAuthoritativeKeys => Set.unmodifiable(
    selections.entries
        .where(
          (entry) => entry.value == ChimahonPreferenceSelectionOrigin.remote,
        )
        .map((entry) => entry.key),
  );
}

/// Reconciles Chimahon preferences against the last successfully merged
/// snapshot.
///
/// Mangatan's local list is a projection of the settings it understands, not
/// a complete preference snapshot. The separately recorded local projection
/// distinguishes a supported setting that was deleted from an opaque setting
/// which Mangatan never represented.
class ChimahonPreferenceThreeWayMerger {
  const ChimahonPreferenceThreeWayMerger();

  /// Records a comparable local baseline without turning a projection gap
  /// into an absence. A later supported value can then be recognized as a
  /// local edit instead of being mistaken for a newly discovered default.
  List<BackupPreference> baselineForProjection({
    required Iterable<BackupPreference> local,
    required Iterable<BackupPreference> raw,
    required Set<String> locallyUnrepresentableKeys,
  }) {
    final resultByKey = {
      for (final preference in local) preference.key: preference.deepCopy(),
    };
    final rawByKey = _byKey(raw);
    for (final key in locallyUnrepresentableKeys) {
      final fallback = rawByKey[key];
      if (fallback != null) resultByKey.putIfAbsent(key, fallback.deepCopy);
    }
    final keys = resultByKey.keys.toList()..sort();
    return [for (final key in keys) resultByKey[key]!];
  }

  List<BackupPreference> merge({
    required Iterable<BackupPreference> baseline,
    Iterable<BackupPreference>? localBaseline,
    required Iterable<BackupPreference> local,
    required Iterable<BackupPreference> remote,
    Set<String> locallyUnrepresentableKeys = const {},
  }) => mergeWithSafetyPolicy(
    baseline: baseline,
    localBaseline: localBaseline,
    local: local,
    remote: remote,
    locallyUnrepresentableKeys: locallyUnrepresentableKeys,
  ).preferences;

  /// Returns the selected values together with the keys for which policy chose
  /// the current remote message unchanged.
  ///
  /// The safety audit uses only this origin metadata; preference values remain
  /// in the already-private remote and proposed protobufs.
  ChimahonPreferenceMergeResult mergeWithSafetyPolicy({
    required Iterable<BackupPreference> baseline,
    Iterable<BackupPreference>? localBaseline,
    required Iterable<BackupPreference> local,
    required Iterable<BackupPreference> remote,
    Set<String> locallyUnrepresentableKeys = const {},
  }) {
    final baselineByKey = _byKey(baseline);
    final localBaselineByKey = localBaseline == null
        ? const <String, BackupPreference>{}
        : _byKey(localBaseline);
    final localByKey = _byKey(local);
    final remoteByKey = _byKey(remote);
    final keys = {
      ...baselineByKey.keys,
      ...localByKey.keys,
      ...remoteByKey.keys,
    }.toList()..sort();

    final resultByKey = <String, BackupPreference>{};
    final selections = <String, ChimahonPreferenceSelectionOrigin>{};
    for (final key in keys) {
      final baselinePreference = baselineByKey[key];
      final localPreference = localByKey[key];
      final remotePreference = remoteByKey[key];
      final selected = _select(
        baseline: baselinePreference,
        localBaseline: localBaselineByKey[key],
        local: localPreference,
        remote: remotePreference,
        locallyUnrepresentable: locallyUnrepresentableKeys.contains(key),
      );
      selections[key] = selected.origin;
      final selectedPreference = selected.preference;
      if (selectedPreference == null) continue;

      // A locally projected known value cannot carry future Chimahon fields.
      // When that projection wins, retain raw remote/baseline unknown fields
      // first and local unknown intent last. If a future scalar field reuses
      // the same tag, protobuf's last-value behavior still honors local intent.
      final fallback = remotePreference ?? baselinePreference;
      final lossless =
          selected.origin == ChimahonPreferenceSelectionOrigin.local &&
              fallback != null
          ? _overlayUnknownFields(selectedPreference, fallback)
          : selectedPreference;
      // GeneratedMessage.deepCopy() retains the underlying byte list for
      // `bytes` fields. A wire round-trip also clones those buffers while
      // preserving unknown protobuf fields.
      resultByKey[key] = BackupPreference.fromBuffer(lossless.writeToBuffer());
    }
    final remoteKeys = remoteByKey.keys.toSet();
    final localOnlyKeys =
        resultByKey.keys.where((key) => !remoteKeys.contains(key)).toList()
          ..sort();
    final result = [
      // Repeated protobuf fields are ordered. Keep every retained Chimahon
      // key in its current wire position; otherwise an unchanged projection
      // manufactures an order-only upload on every sync.
      for (final key in remoteByKey.keys)
        if (resultByKey.containsKey(key)) resultByKey[key]!,
      // Local-only settings have no remote position to preserve. Sort just
      // this tail so exporter/database iteration order cannot affect bytes.
      for (final key in localOnlyKeys) resultByKey[key]!,
    ];
    return ChimahonPreferenceMergeResult(
      preferences: result,
      selections: selections,
    );
  }

  Map<String, BackupPreference> _byKey(
    Iterable<BackupPreference> preferences,
  ) => {for (final preference in preferences) preference.key: preference};

  _PreferenceSelection _select({
    required BackupPreference? baseline,
    required BackupPreference? localBaseline,
    required BackupPreference? local,
    required BackupPreference? remote,
    required bool locallyUnrepresentable,
  }) {
    if (local == null && locallyUnrepresentable) {
      // This is a projection gap, not a local tombstone. Keep the current raw
      // remote value (including all future protobuf fields), while still
      // honoring a real deletion made by another client.
      return _PreferenceSelection.remote(remote);
    }
    if (baseline == null) {
      if (remote != null) return _PreferenceSelection.remote(remote);
      if (localBaseline != null &&
          local != null &&
          _sameMessage(local, localBaseline)) {
        // The raw baseline no longer contains a key that the previous local
        // projection still had. Keep the remote deletion until the user
        // actually changes/re-adds the setting locally.
        return const _PreferenceSelection.remote(null);
      }
      return local == null
          ? const _PreferenceSelection.deleted()
          : _PreferenceSelection.local(local);
    }

    // No local projection means Mangatan never represented this key. Follow
    // the current raw remote snapshot, including a remote deletion.
    if (localBaseline == null && local == null) {
      return _PreferenceSelection.remote(remote);
    }

    // A missing local baseline means this installation has not yet recorded
    // how the raw Chimahon value projects into Mangatan. Preserve the raw
    // value for one cycle; the engine records a projection after import.
    final localChanged =
        localBaseline != null &&
        (local == null || !_sameMessage(local, localBaseline));
    final remoteChanged = remote == null || !_sameMessage(remote, baseline);
    if (remoteChanged) return _PreferenceSelection.remote(remote);
    if (localChanged) {
      return local == null
          ? const _PreferenceSelection.deleted()
          : _PreferenceSelection.local(local);
    }
    return _PreferenceSelection.remote(remote);
  }

  BackupPreference _overlayUnknownFields(
    BackupPreference selected,
    BackupPreference fallback,
  ) {
    final result = selected.deepCopy()..unknownFields.clear();
    result
      ..mergeUnknownFields(fallback.unknownFields)
      ..mergeUnknownFields(selected.unknownFields);
    if (selected.hasValue() && fallback.hasValue()) {
      final value = selected.value.deepCopy()..unknownFields.clear();
      value
        ..mergeUnknownFields(fallback.value.unknownFields)
        ..mergeUnknownFields(selected.value.unknownFields);
      result.value = value;
    }
    return result;
  }

  bool _sameMessage(BackupPreference left, BackupPreference right) {
    final leftBytes = left.writeToBuffer();
    final rightBytes = right.writeToBuffer();
    if (leftBytes.length != rightBytes.length) return false;
    for (var index = 0; index < leftBytes.length; index++) {
      if (leftBytes[index] != rightBytes[index]) return false;
    }
    return true;
  }
}

class _PreferenceSelection {
  const _PreferenceSelection.remote(this.preference)
    : origin = ChimahonPreferenceSelectionOrigin.remote;

  const _PreferenceSelection.local(this.preference)
    : assert(preference != null),
      origin = ChimahonPreferenceSelectionOrigin.local;

  const _PreferenceSelection.deleted()
    : preference = null,
      origin = ChimahonPreferenceSelectionOrigin.deleted;

  final BackupPreference? preference;
  final ChimahonPreferenceSelectionOrigin origin;
}
