import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';

/// Chimahon's three independently selectable media payloads.
///
/// These values are backed up as ordinary BooleanPreferenceValue app
/// preferences. Categories are not generally coupled to their media switch:
/// Chimahon retains manga/anime categories, but its novel creator treats the
/// novel entries and novel categories as one selectable payload.
class ChimahonMediaSyncSelection {
  const ChimahonMediaSyncSelection({
    this.manga = true,
    this.anime = true,
    this.novels = true,
  });

  static const mangaPreferenceKey = 'library_entries';
  static const animePreferenceKey = 'anime_entries';
  static const novelsPreferenceKey = 'sync_novels';
  static const preferenceKeys = <String>{
    mangaPreferenceKey,
    animePreferenceKey,
    novelsPreferenceKey,
  };

  final bool manga;
  final bool anime;
  final bool novels;

  ChimahonMediaSyncSelection copyWith({
    bool? manga,
    bool? anime,
    bool? novels,
  }) => ChimahonMediaSyncSelection(
    manga: manga ?? this.manga,
    anime: anime ?? this.anime,
    novels: novels ?? this.novels,
  );

  /// Reads only Chimahon's exact boolean preference representation.
  ///
  /// A missing, malformed, or differently typed value is not interpreted as
  /// false. The supplied fallback remains authoritative for that key.
  factory ChimahonMediaSyncSelection.fromPreferences(
    Iterable<BackupPreference> preferences, {
    ChimahonMediaSyncSelection fallback = const ChimahonMediaSyncSelection(),
    ChimahonPreferenceCodec codec = const ChimahonPreferenceCodec(),
  }) {
    final byKey = <String, BackupPreference>{
      for (final preference in preferences)
        if (preferenceKeys.contains(preference.key)) preference.key: preference,
    };
    final values = <String, bool>{};
    for (final entry in byKey.entries) {
      try {
        final decoded = codec.decode(entry.value);
        if (decoded.kind == ChimahonPreferenceKind.boolean &&
            decoded.value is bool) {
          values[entry.key] = decoded.value! as bool;
        }
      } catch (_) {
        // A future or damaged preference must not silently disable media.
      }
    }
    return ChimahonMediaSyncSelection(
      manga: values[mangaPreferenceKey] ?? fallback.manga,
      anime: values[animePreferenceKey] ?? fallback.anime,
      novels: values[novelsPreferenceKey] ?? fallback.novels,
    );
  }

  /// Resolves selectors for media filtering with Chimahon restore semantics.
  ///
  /// An absent row is Chimahon's `true` default. A present row with a wrong or
  /// damaged type is ignored by Chimahon's preference restorer, so that key
  /// retains [malformedFallback]. Exact malformed rows remain untouched in the
  /// backed preference payload; this method only derives semantic booleans.
  factory ChimahonMediaSyncSelection.forFiltering(
    Iterable<BackupPreference> preferences, {
    required ChimahonMediaSyncSelection malformedFallback,
    ChimahonPreferenceCodec codec = const ChimahonPreferenceCodec(),
  }) {
    final byKey = <String, BackupPreference>{
      for (final preference in preferences)
        if (preferenceKeys.contains(preference.key)) preference.key: preference,
    };
    bool resolved(String key, bool fallback) {
      final preference = byKey[key];
      if (preference == null) return true;
      try {
        final decoded = codec.decode(preference);
        if (decoded.kind == ChimahonPreferenceKind.boolean &&
            decoded.value is bool) {
          return decoded.value! as bool;
        }
      } catch (_) {
        // Chimahon ignores a value it cannot restore.
      }
      return fallback;
    }

    return ChimahonMediaSyncSelection(
      manga: resolved(mangaPreferenceKey, malformedFallback.manga),
      anime: resolved(animePreferenceKey, malformedFallback.anime),
      novels: resolved(novelsPreferenceKey, malformedFallback.novels),
    );
  }

  /// Whether the last occurrence of [key] has Chimahon's exact boolean type.
  static bool hasValidBooleanPreference(
    Iterable<BackupPreference> preferences,
    String key, {
    ChimahonPreferenceCodec codec = const ChimahonPreferenceCodec(),
  }) {
    BackupPreference? selected;
    for (final preference in preferences) {
      if (preference.key == key) selected = preference;
    }
    if (selected == null) return false;
    try {
      final decoded = codec.decode(selected);
      return decoded.kind == ChimahonPreferenceKind.boolean &&
          decoded.value is bool;
    } catch (_) {
      return false;
    }
  }

  /// True when a present selector row uses a non-boolean or malformed value.
  /// Missing rows are Chimahon's ordinary true defaults and are not malformed.
  static bool hasMalformedPreference(
    Iterable<BackupPreference> preferences, {
    ChimahonPreferenceCodec codec = const ChimahonPreferenceCodec(),
  }) {
    final presentKeys = <String>{
      for (final preference in preferences)
        if (preferenceKeys.contains(preference.key)) preference.key,
    };
    return presentKeys.any(
      (key) => !hasValidBooleanPreference(preferences, key, codec: codec),
    );
  }

  /// Whether the payload explicitly contains at least one media selector.
  ///
  /// Chimahon omits preferences that have never been changed, so an entirely
  /// absent selector set must leave an existing device selection untouched.
  static bool hasAnyPreference(Iterable<BackupPreference> preferences) =>
      preferences.any((preference) => preferenceKeys.contains(preference.key));

  /// Returns the local Chimahon projection selected by these switches.
  ///
  /// Remote payloads must never be passed through this method: an omitted
  /// local media type means "do not contribute it", not "delete it remotely".
  BackupMihon projectLocal(
    BackupMihon backup, {
    ChimahonPreferenceCodec codec = const ChimahonPreferenceCodec(),
  }) {
    final projected = withBackedPreferences(backup, codec: codec);
    if (!manga) {
      projected.backupManga.clear();
      projected.backupSources.clear();
    }
    if (!anime) {
      projected.backupAnime.clear();
      projected.backupAnimeSources.clear();
    }
    if (!novels) {
      projected.backupNovels.clear();
      projected.backupNovelCategories.clear();
    }
    return projected;
  }

  /// Adds or updates the three exact backed preferences without filtering any
  /// media records. Projection snapshots use this before the current remote
  /// is known; the sync engine applies [projectLocal] once bootstrap has been
  /// resolved against that remote.
  BackupMihon withBackedPreferences(
    BackupMihon backup, {
    ChimahonPreferenceCodec codec = const ChimahonPreferenceCodec(),
  }) {
    final projected = backup.deepCopy();
    _replacePreferences(projected.backupPreferences, codec);
    return projected;
  }

  void _replacePreferences(
    List<BackupPreference> preferences,
    ChimahonPreferenceCodec codec,
  ) {
    final selectedValues = <String, bool>{
      mangaPreferenceKey: manga,
      animePreferenceKey: anime,
      novelsPreferenceKey: novels,
    };
    final existingByKey = <String, List<BackupPreference>>{};
    for (final preference in preferences) {
      if (selectedValues.containsKey(preference.key)) {
        existingByKey.putIfAbsent(preference.key, () => []).add(preference);
      }
    }
    final seen = <String>{};
    final result = <BackupPreference>[];
    for (final preference in preferences) {
      final selected = selectedValues[preference.key];
      if (selected == null) {
        result.add(preference);
        continue;
      }
      if (!seen.add(preference.key)) continue;
      final duplicates = existingByKey[preference.key]!;
      if (duplicates.length == 1) {
        try {
          final decoded = codec.decode(preference);
          if (decoded.kind == ChimahonPreferenceKind.boolean &&
              decoded.value == selected) {
            result.add(preference);
            continue;
          }
        } catch (_) {
          // Replace a malformed local control preference below.
        }
      }
      result.add(
        _encodedOverExisting(
          codec.encode(preference.key, selected),
          duplicates,
        ),
      );
    }
    for (final entry in selectedValues.entries) {
      if (seen.add(entry.key)) {
        result.add(codec.encode(entry.key, entry.value));
      }
    }
    preferences
      ..clear()
      ..addAll(result);
  }

  BackupPreference _encodedOverExisting(
    BackupPreference encoded,
    Iterable<BackupPreference> existing,
  ) {
    for (final preference in existing) {
      encoded.unknownFields.mergeFromUnknownFieldSet(preference.unknownFields);
      if (preference.hasValue()) {
        encoded.value.unknownFields.mergeFromUnknownFieldSet(
          preference.value.unknownFields,
        );
      }
    }
    return encoded;
  }

  @override
  bool operator ==(Object other) =>
      other is ChimahonMediaSyncSelection &&
      manga == other.manga &&
      anime == other.anime &&
      novels == other.novels;

  @override
  int get hashCode => Object.hash(manga, anime, novels);

  @override
  String toString() =>
      'ChimahonMediaSyncSelection(manga: $manga, anime: $anime, '
      'novels: $novels)';
}

/// One atomic persisted selector/authority revision.
class ChimahonMediaSyncSelectionState {
  const ChimahonMediaSyncSelectionState({
    this.selection = const ChimahonMediaSyncSelection(),
    this.initialized = false,
    this.userSelected = false,
    this.scopeToken,
    this.generation = 0,
  });

  factory ChimahonMediaSyncSelectionState.fromPreference(
    SyncPreference preference,
  ) => ChimahonMediaSyncSelectionState(
    selection: ChimahonMediaSyncSelection(
      manga: preference.chimahonSyncManga,
      anime: preference.chimahonSyncAnime,
      novels: preference.chimahonSyncNovels,
    ),
    initialized: preference.chimahonMediaSelectionInitialized,
    userSelected: preference.chimahonMediaSelectionUserSelected,
    scopeToken: preference.chimahonMediaSelectionScopeToken,
    generation: preference.chimahonMediaSelectionGeneration,
  );

  final ChimahonMediaSyncSelection selection;
  final bool initialized;

  /// A direct switch edit is intentionally portable to the next account. This
  /// represents a deliberate device preference; remote-derived vectors are
  /// isolated by [scopeToken].
  final bool userSelected;
  final String? scopeToken;
  final int generation;

  bool isInitializedForScope(String activeScopeToken) =>
      userSelected || (initialized && scopeToken == activeScopeToken);

  ChimahonMediaSyncSelection selectionForScope(String activeScopeToken) =>
      isInitializedForScope(activeScopeToken)
      ? selection
      : const ChimahonMediaSyncSelection();

  @override
  bool operator ==(Object other) =>
      other is ChimahonMediaSyncSelectionState &&
      selection == other.selection &&
      initialized == other.initialized &&
      userSelected == other.userSelected &&
      scopeToken == other.scopeToken &&
      generation == other.generation;

  @override
  int get hashCode =>
      Object.hash(selection, initialized, userSelected, scopeToken, generation);
}

/// Derives the provisional UI vector for a newly connected account.
///
/// `null` means the persisted state is already authoritative for this scope.
/// A malformed same-account value falls back to that account's current value;
/// a different account starts from Chimahon's all-true defaults.
ChimahonMediaSyncSelection? chimahonMediaSelectionBootstrapForScope({
  required ChimahonMediaSyncSelectionState current,
  required String activeScopeToken,
  required Iterable<BackupPreference>? remotePreferences,
}) {
  if (current.isInitializedForScope(activeScopeToken)) return null;
  if (remotePreferences == null) return const ChimahonMediaSyncSelection();
  return ChimahonMediaSyncSelection.forFiltering(
    remotePreferences,
    malformedFallback: current.scopeToken == activeScopeToken
        ? current.selection
        : const ChimahonMediaSyncSelection(),
  );
}

/// Applies Chimahon's explicit restore/download selector semantics.
///
/// An entirely absent selector set means the backup predates the controls and
/// leaves this device untouched. Once any selector is present, omitted keys
/// take Chimahon's `true` default while malformed present keys keep the
/// current value.
ChimahonMediaSyncSelection chimahonMediaSelectionForExplicitRestore({
  required Iterable<BackupPreference> preferences,
  required ChimahonMediaSyncSelection current,
}) => ChimahonMediaSyncSelection.hasAnyPreference(preferences)
    ? ChimahonMediaSyncSelection.forFiltering(
        preferences,
        malformedFallback: current,
      )
    : current;

/// Compares the complete persisted selector state used by transactions.
bool matchesChimahonMediaSelectionState(
  SyncPreference preference,
  ChimahonMediaSyncSelectionState expected,
) => ChimahonMediaSyncSelectionState.fromPreference(preference) == expected;

/// Mutates [preference] only when its complete selector state still matches.
///
/// Callers run this inside the same Isar write transaction that persists the
/// object, preventing a sync result from overwriting a switch changed while
/// network I/O was in progress.
bool applyChimahonMediaSelectionIfUnchanged({
  required SyncPreference preference,
  required ChimahonMediaSyncSelectionState expected,
  required ChimahonMediaSyncSelection updated,
  required bool updatedInitialized,
  required bool updatedUserSelected,
  required String? updatedScopeToken,
}) {
  if (!matchesChimahonMediaSelectionState(preference, expected)) {
    return false;
  }
  preference
    ..chimahonSyncManga = updated.manga
    ..chimahonSyncAnime = updated.anime
    ..chimahonSyncNovels = updated.novels
    ..chimahonMediaSelectionInitialized = updatedInitialized
    ..chimahonMediaSelectionUserSelected = updatedUserSelected
    ..chimahonMediaSelectionScopeToken = updatedScopeToken
    ..chimahonMediaSelectionGeneration = expected.generation + 1;
  return true;
}

/// Applies one or more direct user edits to the current persisted row.
void applyChimahonMediaSelectionUserEdit(
  SyncPreference preference, {
  bool? manga,
  bool? anime,
  bool? novels,
}) {
  final nextGeneration = preference.chimahonMediaSelectionGeneration + 1;
  preference
    ..chimahonSyncManga = manga ?? preference.chimahonSyncManga
    ..chimahonSyncAnime = anime ?? preference.chimahonSyncAnime
    ..chimahonSyncNovels = novels ?? preference.chimahonSyncNovels
    ..chimahonMediaSelectionInitialized = true
    ..chimahonMediaSelectionUserSelected = true
    ..chimahonMediaSelectionGeneration = nextGeneration;
}

/// Privacy-safe stable identity for a provider/account scope.
String chimahonMediaSelectionScopeToken(String scopeKey) => sha256
    .convert(
      utf8.encode('mangatan:chimahon-media-selection-scope:v1\u0000$scopeKey'),
    )
    .toString();
