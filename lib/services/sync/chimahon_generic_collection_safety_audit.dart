import 'dart:convert';

import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupExtensionRepos.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupFeed.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSavedSearch.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/services/sync/chimahon_feed_identity.dart';
import 'package:mangayomi/services/sync/chimahon_opaque_rows.dart';
import 'package:mangayomi/services/sync/chimahon_unknown_field_safety.dart';
import 'package:protobuf/protobuf.dart';

/// Symmetric preservation checks for non-media Chimahon root collections.
///
/// Local known fields win ordinary conflicts for these keyed collections, but
/// remote identities and both sides' future protobuf fields must survive. The
/// global statistics collections are intentionally treated as exact opaque
/// rows: Chimahon excludes them from normal sync and manga statistics contain
/// a device-local database ID, so Mangatan must not invent a cross-device key.
class ChimahonGenericCollectionSafetyAudit {
  const ChimahonGenericCollectionSafetyAudit();

  void audit({
    required BackupMihon local,
    required BackupMihon remote,
    required BackupMihon proposed,
    required void Function(String code, Iterable<String> affected) fail,
    required void Function(String code, Iterable<String> affected) observe,
  }) {
    _auditKnownCollection<BackupSource>(
      family: 'source',
      local: local.backupSources,
      remote: remote.backupSources,
      proposed: proposed.backupSources,
      keyOf: _sourceKey,
      fail: fail,
    );
    _auditKnownCollection<BackupSource>(
      family: 'anime_source',
      local: local.backupAnimeSources,
      remote: remote.backupAnimeSources,
      proposed: proposed.backupAnimeSources,
      keyOf: _sourceKey,
      fail: fail,
    );
    _auditKnownCollection<BackupExtensionRepos>(
      family: 'extension_repo',
      local: local.backupExtensionRepo,
      remote: remote.backupExtensionRepo,
      proposed: proposed.backupExtensionRepo,
      keyOf: (repo) => repo.baseUrl,
      fail: fail,
    );
    _auditKnownCollection<BackupExtensionRepos>(
      family: 'anime_extension_repo',
      local: local.backupAnimeExtensionRepo,
      remote: remote.backupAnimeExtensionRepo,
      proposed: proposed.backupAnimeExtensionRepo,
      keyOf: (repo) => repo.baseUrl,
      fail: fail,
    );
    _auditKnownCollection<BackupSavedSearch>(
      family: 'saved_search',
      local: local.backupSavedSearches,
      remote: remote.backupSavedSearches,
      proposed: proposed.backupSavedSearches,
      keyOf: _savedSearchKey,
      fail: fail,
    );
    _auditKnownCollection<BackupFeed>(
      family: 'feed',
      local: local.backupFeeds,
      remote: remote.backupFeeds,
      proposed: proposed.backupFeeds,
      keyOf: ChimahonFeedIdentity.key,
      fail: fail,
    );

    _auditRootUnknownFields(
      local: local,
      remote: remote,
      proposed: proposed,
      fail: fail,
    );
    _auditOpaqueStatistics(
      local: local,
      remote: remote,
      proposed: proposed,
      fail: fail,
      observe: observe,
    );
  }

  void _auditKnownCollection<T extends GeneratedMessage>({
    required String family,
    required Iterable<T> local,
    required Iterable<T> remote,
    required Iterable<T> proposed,
    required String Function(T value) keyOf,
    required void Function(String code, Iterable<String> affected) fail,
  }) {
    final localList = local.toList(growable: false);
    final remoteList = remote.toList(growable: false);
    final proposedList = proposed.toList(growable: false);
    _auditDuplicateKeys(
      side: 'local',
      family: family,
      values: localList,
      keyOf: keyOf,
      fail: fail,
    );
    _auditDuplicateKeys(
      side: 'remote',
      family: family,
      values: remoteList,
      keyOf: keyOf,
      fail: fail,
    );
    _auditDuplicateKeys(
      side: 'proposed',
      family: family,
      values: proposedList,
      keyOf: keyOf,
      fail: fail,
    );
    final localByKey = _lastByKey(localList, keyOf);
    final remoteByKey = _lastByKey(remoteList, keyOf);
    final proposedByKey = _lastByKey(proposedList, keyOf);

    final localMissing = <String>[];
    final localChanged = <String>[];
    for (final entry in localByKey.entries) {
      final candidate = proposedByKey[entry.key];
      if (candidate == null) {
        localMissing.add(entry.key);
      } else if (!_sameKnownFields(entry.value, candidate)) {
        localChanged.add(entry.key);
      }
    }
    fail('local_${family}_missing_from_proposed', localMissing);
    fail('local_${family}_changed_in_proposed', localChanged);

    final remoteMissing = <String>[];
    final remoteOnlyChanged = <String>[];
    final remoteFrequency = <String, int>{};
    for (final value in remoteList) {
      final key = keyOf(value);
      remoteFrequency[key] = (remoteFrequency[key] ?? 0) + 1;
    }
    for (final entry in remoteByKey.entries) {
      final candidate = proposedByKey[entry.key];
      if (candidate == null) {
        remoteMissing.add(entry.key);
      } else if (!localByKey.containsKey(entry.key) &&
          remoteFrequency[entry.key] == 1 &&
          !_sameKnownFields(entry.value, candidate)) {
        remoteOnlyChanged.add(entry.key);
      }
    }
    fail('remote_${family}_missing_from_proposed', remoteMissing);
    fail('remote_${family}_changed_in_proposed', remoteOnlyChanged);

    _auditCollectionUnknownFields(
      side: 'local',
      family: family,
      baseline: localList,
      proposedByKey: proposedByKey,
      keyOf: keyOf,
      fail: fail,
    );
    _auditCollectionUnknownFields(
      side: 'remote',
      family: family,
      baseline: remoteList,
      proposedByKey: proposedByKey,
      keyOf: keyOf,
      fail: fail,
    );
  }

  void _auditDuplicateKeys<T>({
    required String side,
    required String family,
    required Iterable<T> values,
    required String Function(T value) keyOf,
    required void Function(String code, Iterable<String> affected) fail,
  }) {
    final counts = <String, int>{};
    for (final value in values) {
      final key = keyOf(value);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    fail(
      '${side}_${family}_duplicate_identity',
      counts.entries.expand((entry) => List.filled(entry.value - 1, entry.key)),
    );
  }

  void _auditCollectionUnknownFields<T extends GeneratedMessage>({
    required String side,
    required String family,
    required Iterable<T> baseline,
    required Map<String, T> proposedByKey,
    required String Function(T value) keyOf,
    required void Function(String code, Iterable<String> affected) fail,
  }) {
    final missing = <String>[];
    for (final value in baseline) {
      final key = keyOf(value);
      final candidate = proposedByKey[key];
      if (candidate == null) continue;
      missing.addAll(
        ChimahonUnknownFieldSafety.missingOrReorderedTags(
          baseline: value,
          target: candidate,
        ).map((tag) => _frame([key, '$tag'])),
      );
      if (value is BackupFeed &&
          candidate is BackupFeed &&
          value.hasSavedSearch() &&
          candidate.hasSavedSearch()) {
        missing.addAll(
          ChimahonUnknownFieldSafety.missingOrReorderedTags(
            baseline: value.savedSearch,
            target: candidate.savedSearch,
          ).map((tag) => _frame([key, 'saved-search', '$tag'])),
        );
      }
    }
    fail('${side}_${family}_unknown_envelope_not_preserved', missing);
  }

  void _auditRootUnknownFields({
    required BackupMihon local,
    required BackupMihon remote,
    required BackupMihon proposed,
    required void Function(String code, Iterable<String> affected) fail,
  }) {
    final remoteMissing = <String>[];
    final remoteChanged = <String>[];
    for (final entry in remote.unknownFields.asMap().entries) {
      if (!proposed.unknownFields.hasField(entry.key)) {
        remoteMissing.add('${entry.key}');
        continue;
      }
      final missing = ChimahonUnknownFieldSafety.missingOrReorderedTags(
        baseline: _messageWithOnlyUnknownField(remote, entry.key),
        target: proposed,
        placement: ChimahonUnknownFieldPlacement.prefix,
      );
      if (missing.isNotEmpty) remoteChanged.add('${entry.key}');
    }
    fail('remote_root_unknown_field_missing_from_proposed', remoteMissing);
    fail('remote_root_unknown_field_changed_in_proposed', remoteChanged);

    final localMissing = <String>[];
    final localChanged = <String>[];
    for (final entry in local.unknownFields.asMap().entries) {
      // Shared root tags are remote-authoritative during ordinary sync. A
      // selected pending restore is separately proven by restore authority.
      if (remote.unknownFields.hasField(entry.key)) continue;
      if (!proposed.unknownFields.hasField(entry.key)) {
        localMissing.add('${entry.key}');
        continue;
      }
      final missing = ChimahonUnknownFieldSafety.missingOrReorderedTags(
        baseline: _messageWithOnlyUnknownField(local, entry.key),
        target: proposed,
        placement: ChimahonUnknownFieldPlacement.suffix,
      );
      if (missing.isNotEmpty) localChanged.add('${entry.key}');
    }
    fail('local_root_unknown_field_missing_from_proposed', localMissing);
    fail('local_root_unknown_field_changed_in_proposed', localChanged);
  }

  void _auditOpaqueStatistics({
    required BackupMihon local,
    required BackupMihon remote,
    required BackupMihon proposed,
    required void Function(String code, Iterable<String> affected) fail,
    required void Function(String code, Iterable<String> affected) observe,
  }) {
    fail(
      'local_manga_stat_missing_from_proposed',
      ChimahonOpaqueRows.missingExactRows(
        local.backupMangaStats,
        proposed.backupMangaStats,
      ),
    );
    fail(
      'remote_manga_stat_missing_from_proposed',
      ChimahonOpaqueRows.missingExactRows(
        remote.backupMangaStats,
        proposed.backupMangaStats,
      ),
    );
    fail(
      'local_anki_stat_missing_from_proposed',
      ChimahonOpaqueRows.missingExactRows(
        local.backupAnkiStats,
        proposed.backupAnkiStats,
      ),
    );
    fail(
      'remote_anki_stat_missing_from_proposed',
      ChimahonOpaqueRows.missingExactRows(
        remote.backupAnkiStats,
        proposed.backupAnkiStats,
      ),
    );
    observe(
      'manga_statistics_manual_backup_only',
      ChimahonOpaqueRows.opaqueDigests(proposed.backupMangaStats),
    );
    observe(
      'anki_statistics_manual_backup_only',
      ChimahonOpaqueRows.opaqueDigests(proposed.backupAnkiStats),
    );
  }

  T _messageWithOnlyUnknownField<T extends GeneratedMessage>(
    T source,
    int tag,
  ) {
    final result = source.createEmptyInstance() as T;
    final field = source.unknownFields.getField(tag);
    if (field != null) result.unknownFields.mergeField(tag, field);
    return result;
  }

  Map<String, T> _lastByKey<T extends GeneratedMessage>(
    Iterable<T> values,
    String Function(T value) keyOf,
  ) => {for (final value in values) keyOf(value): value};

  bool _sameKnownFields<T extends GeneratedMessage>(T first, T second) {
    final left = _withoutUnknownFields(first);
    final right = _withoutUnknownFields(second);
    return _sameBytes(left.writeToBuffer(), right.writeToBuffer());
  }

  T _withoutUnknownFields<T extends GeneratedMessage>(T value) {
    final copy = value.deepCopy()..unknownFields.clear();
    if (copy is BackupFeed) {
      final global = ChimahonFeedIdentity.semanticGlobal(copy);
      copy.global = global;
      if (copy.hasSavedSearch()) copy.savedSearch.unknownFields.clear();
    }
    return copy;
  }

  bool _sameBytes(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  String _sourceKey(BackupSource source) =>
      source.hasSourceId() ? source.sourceId.toString() : 'source-absent';

  String _savedSearchKey(BackupSavedSearch search) =>
      _frame([search.source.toString(), _normalized(search.name)]);

  String _normalized(String value) => value.trim().toLowerCase();

  String _frame(Iterable<String> values) =>
      values.map((value) => '${utf8.encode(value).length}:$value').join();
}
