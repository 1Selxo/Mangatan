/// Identifies a preference inside one Chimahon source-preference group.
typedef ChimahonSourcePreferenceKey = ({
  String sourceKey,
  String preferenceKey,
});

/// The side selected by three-way preference reconciliation.
///
/// The enum deliberately carries no value data. The safety audit reads the
/// selected value from its already-defensive local or remote protobuf input.
enum ChimahonPreferenceSelectionOrigin { remote, local, deleted }

/// Minimal conflict-policy evidence needed by the pre-upload safety audit.
///
/// Values are deliberately omitted: the audit already owns defensive remote,
/// local, and proposed protobufs. These maps identify which side selected each
/// key, including an explicit local deletion, without retaining preference
/// values in a diagnostic object.
class ChimahonPreferenceSafetyPolicy {
  ChimahonPreferenceSafetyPolicy({
    Map<String, ChimahonPreferenceSelectionOrigin> appSelections = const {},
    Map<ChimahonSourcePreferenceKey, ChimahonPreferenceSelectionOrigin>
        sourceSelections =
        const {},
    Map<String, ChimahonPreferenceSelectionOrigin>
        sourceGroupEnvelopeSelections =
        const {},
  }) : appSelections = Map.unmodifiable(appSelections),
       sourceSelections = Map.unmodifiable(sourceSelections),
       sourceGroupEnvelopeSelections = Map.unmodifiable(
         sourceGroupEnvelopeSelections,
       );

  final Map<String, ChimahonPreferenceSelectionOrigin> appSelections;
  final Map<ChimahonSourcePreferenceKey, ChimahonPreferenceSelectionOrigin>
  sourceSelections;

  /// Selection evidence for source-group unknown protobuf fields.
  ///
  /// Plain empty groups need no entry. A group is classified when either side
  /// carries future fields on the `BackupSourcePreferences` envelope.
  final Map<String, ChimahonPreferenceSelectionOrigin>
  sourceGroupEnvelopeSelections;

  Set<String> get remoteAuthoritativeAppKeys =>
      _keysWithOrigin(appSelections, ChimahonPreferenceSelectionOrigin.remote);

  Set<ChimahonSourcePreferenceKey> get remoteAuthoritativeSourceKeys =>
      _keysWithOrigin(
        sourceSelections,
        ChimahonPreferenceSelectionOrigin.remote,
      );

  Set<String> get localAuthoritativeAppKeys =>
      _keysWithOrigin(appSelections, ChimahonPreferenceSelectionOrigin.local);

  Set<ChimahonSourcePreferenceKey> get localAuthoritativeSourceKeys =>
      _keysWithOrigin(
        sourceSelections,
        ChimahonPreferenceSelectionOrigin.local,
      );

  Set<String> get deletedAppKeys =>
      _keysWithOrigin(appSelections, ChimahonPreferenceSelectionOrigin.deleted);

  Set<ChimahonSourcePreferenceKey> get deletedSourceKeys => _keysWithOrigin(
    sourceSelections,
    ChimahonPreferenceSelectionOrigin.deleted,
  );

  Set<K> _keysWithOrigin<K>(
    Map<K, ChimahonPreferenceSelectionOrigin> selections,
    ChimahonPreferenceSelectionOrigin origin,
  ) => Set.unmodifiable(
    selections.entries
        .where((entry) => entry.value == origin)
        .map((entry) => entry.key),
  );
}
