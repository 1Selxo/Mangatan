import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/services/sync/chimahon_generic_collection_safety_audit.dart';
import 'package:mangayomi/services/sync/chimahon_local_chapter_policy.dart';
import 'package:mangayomi/services/sync/chimahon_local_intent_safety_audit.dart';
import 'package:mangayomi/services/sync/chimahon_preference_safety_policy.dart';
import 'package:mangayomi/services/sync/chimahon_preference_value_safety_audit.dart';
import 'package:mangayomi/services/sync/chimahon_media_safety_audit.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/utils/chimahon_novel_identity.dart';

/// A read-only, deterministic safety gate for the first Chimahon cloud merge.
///
/// This audit deliberately accepts already-decoded wire projections. It has no
/// database, network, credential, or file-system access and therefore cannot
/// mutate either side while a preview is being inspected.
class ChimahonSyncSafetyAudit {
  const ChimahonSyncSafetyAudit();

  static const _uncategorizedNovelCategoryId = 'default';

  ChimahonSyncSafetyReport audit({
    BackupMihon? reference,
    required BackupMihon remote,
    required BackupMihon local,
    required BackupMihon proposed,
    ChimahonPreferenceSafetyPolicy? preferenceSafetyPolicy,
    Set<ChimahonTrackingDeletionKey> localTrackingDeletions = const {},
    bool remoteWinsTies = false,
  }) {
    final counts = <String, int>{};
    final hashes = <String, String>{};
    final failures = <ChimahonSyncSafetyFinding>[];
    final observations = <ChimahonSyncSafetyFinding>[];

    final inputs = <String, BackupMihon>{
      'reference': ?reference,
      'remote': remote,
      'local': local,
      'proposed': proposed,
    };
    counts['referencePresent'] = reference == null ? 0 : 1;
    for (final entry in inputs.entries) {
      _describeInput(entry.key, entry.value, counts, hashes);
    }

    void fail(String code, Iterable<String> affected) {
      final values = affected.toList(growable: false);
      if (values.isEmpty) return;
      failures.add(
        ChimahonSyncSafetyFinding._(
          code: code,
          affectedCount: values.length,
          affectedSha256: _digest(code, values),
        ),
      );
      counts['failure.$code'] = values.length;
    }

    void observe(String code, Iterable<String> affected) {
      final values = affected.toList(growable: false);
      counts['observation.$code'] = values.length;
      if (values.isEmpty) return;
      observations.add(
        ChimahonSyncSafetyFinding._(
          code: code,
          affectedCount: values.length,
          affectedSha256: _digest(code, values),
        ),
      );
    }

    if (reference != null) {
      _auditReferenceSubset(reference: reference, remote: remote, fail: fail);
      _auditRemoteOnlyManga(reference: reference, remote: remote, fail: fail);
    }

    const ChimahonMediaSafetyAudit().audit(
      remote: remote,
      local: local,
      proposed: proposed,
      localTrackingDeletions: localTrackingDeletions,
      remoteWinsTies: remoteWinsTies,
      fail: fail,
    );
    _auditPreferenceKeys(
      remote: remote,
      proposed: proposed,
      policy: preferenceSafetyPolicy,
      fail: fail,
    );
    if (preferenceSafetyPolicy != null) {
      counts['preferencePolicy.remoteAuthoritativeAppKeys'] =
          preferenceSafetyPolicy.remoteAuthoritativeAppKeys.length;
      counts['preferencePolicy.remoteAuthoritativeSourceKeys'] =
          preferenceSafetyPolicy.remoteAuthoritativeSourceKeys.length;
      counts['preferencePolicy.localAuthoritativeAppKeys'] =
          preferenceSafetyPolicy.localAuthoritativeAppKeys.length;
      counts['preferencePolicy.localAuthoritativeSourceKeys'] =
          preferenceSafetyPolicy.localAuthoritativeSourceKeys.length;
      counts['preferencePolicy.deletedAppKeys'] =
          preferenceSafetyPolicy.deletedAppKeys.length;
      counts['preferencePolicy.deletedSourceKeys'] =
          preferenceSafetyPolicy.deletedSourceKeys.length;
      counts['preferencePolicy.sourceGroupEnvelopes'] =
          preferenceSafetyPolicy.sourceGroupEnvelopeSelections.length;
      final preferenceFailures = const ChimahonPreferenceValueSafetyAudit()
          .audit(
            remote: remote,
            local: local,
            proposed: proposed,
            policy: preferenceSafetyPolicy,
          );
      for (final entry in preferenceFailures.entries) {
        fail(entry.key, entry.value);
      }
    }
    _auditSourceResolution(inputs: inputs, fail: fail);
    _auditLocalChapterProjection(local: local, fail: fail);
    _auditNovels(remote: remote, proposed: proposed, fail: fail);
    const ChimahonGenericCollectionSafetyAudit().audit(
      local: local,
      remote: remote,
      proposed: proposed,
      fail: fail,
      observe: observe,
    );
    const ChimahonLocalIntentSafetyAudit().audit(
      local: local,
      remote: remote,
      proposed: proposed,
      fail: fail,
      observe: observe,
    );

    _reportLocalDifferences(remote: remote, local: local, observe: observe);

    counts['hardFailureKinds'] = failures.length;
    counts['hardFailureAffectedRecords'] = failures.fold(
      0,
      (sum, finding) => sum + finding.affectedCount,
    );
    counts['observationKinds'] = observations.length;
    return ChimahonSyncSafetyReport._(
      counts: counts,
      hashes: hashes,
      hardFailures: failures,
      observations: observations,
    );
  }

  void _describeInput(
    String label,
    BackupMihon backup,
    Map<String, int> counts,
    Map<String, String> hashes,
  ) {
    final mangaKeys = backup.backupManga.map(_mangaKey).toList();
    final chapterKeys = _qualifiedChapterKeys(backup).toList();
    final historyKeys = _qualifiedHistoryKeys(backup).toList();
    final sourceKeys = backup.backupSources.map(_sourceKey).toList();
    final novelKeys = backup.backupNovels.map(_novelKeyOrInvalid).toList();
    final preferenceKeys = _preferenceKeys(backup).toList();
    final sourcePreferenceKeys = _sourcePreferenceKeys(backup).toList();
    final customTitleKeys = _customTitleKeys(backup).toList();

    counts['$label.mangaRecords'] = mangaKeys.length;
    counts['$label.chapterRecords'] = chapterKeys.length;
    counts['$label.historyRecords'] = historyKeys.length;
    counts['$label.sourceRecords'] = sourceKeys.length;
    counts['$label.novelRecords'] = novelKeys.length;
    counts['$label.preferenceKeys'] = preferenceKeys.length;
    counts['$label.sourcePreferenceKeys'] = sourcePreferenceKeys.length;
    counts['$label.customTitleRecords'] = customTitleKeys.length;
    hashes['$label.mangaIdentitySha256'] = _digest('$label.manga', mangaKeys);
    hashes['$label.chapterIdentitySha256'] = _digest(
      '$label.chapter',
      chapterKeys,
    );
    hashes['$label.historyIdentitySha256'] = _digest(
      '$label.history',
      historyKeys,
    );
    hashes['$label.sourceIdentitySha256'] = _digest(
      '$label.source',
      sourceKeys,
    );
    hashes['$label.novelIdentitySha256'] = _digest('$label.novel', novelKeys);
    hashes['$label.preferenceKeySha256'] = _digest(
      '$label.preference',
      preferenceKeys,
    );
    hashes['$label.sourcePreferenceKeySha256'] = _digest(
      '$label.sourcePreference',
      sourcePreferenceKeys,
    );
    hashes['$label.customTitleSha256'] = _digest(
      '$label.customTitle',
      customTitleKeys,
    );

    final mangaCollisions = _mangaCoarseCollisions(backup);
    counts['$label.mangaCoarseCollisionGroups'] = mangaCollisions.length;
    counts['$label.mangaCoarseCollisionRecords'] = mangaCollisions.values.fold(
      0,
      (sum, records) => sum + records,
    );
    hashes['$label.mangaCoarseCollisionSha256'] = _digest(
      '$label.mangaCoarseCollision',
      mangaCollisions.keys,
    );

    final chapterCollisions = _chapterUrlCollisions(backup);
    counts['$label.chapterUrlCollisionGroups'] = chapterCollisions.length;
    counts['$label.chapterUrlCollisionRecords'] = chapterCollisions.values.fold(
      0,
      (sum, records) => sum + records,
    );
    hashes['$label.chapterUrlCollisionSha256'] = _digest(
      '$label.chapterUrlCollision',
      chapterCollisions.keys,
    );
  }

  void _auditReferenceSubset({
    required BackupMihon reference,
    required BackupMihon remote,
    required void Function(String, Iterable<String>) fail,
  }) {
    fail(
      'reference_manga_missing_from_remote',
      _multisetMissing(
        reference.backupManga.map(_mangaKey),
        remote.backupManga.map(_mangaKey),
      ),
    );
    fail(
      'reference_chapter_missing_from_remote',
      _multisetMissing(
        _qualifiedChapterKeys(reference),
        _qualifiedChapterKeys(remote),
      ),
    );
    fail(
      'reference_history_missing_from_remote',
      _multisetMissing(
        _qualifiedHistoryKeys(reference),
        _qualifiedHistoryKeys(remote),
      ),
    );
    fail(
      'reference_source_missing_from_remote',
      _multisetMissing(
        reference.backupSources.map(_sourceKey),
        remote.backupSources.map(_sourceKey),
      ),
    );
    fail(
      'reference_preference_key_missing_from_remote',
      _multisetMissing(_preferenceKeys(reference), _preferenceKeys(remote)),
    );
    fail(
      'reference_source_preference_key_missing_from_remote',
      _multisetMissing(
        _sourcePreferenceKeys(reference),
        _sourcePreferenceKeys(remote),
      ),
    );
    fail(
      'reference_custom_title_missing_from_remote',
      _multisetMissing(_customTitleKeys(reference), _customTitleKeys(remote)),
    );
    _auditReferenceNovels(reference: reference, remote: remote, fail: fail);
  }

  /// Applies a maximum-cardinality multiset pairing for an exact manga key.
  ///
  /// Rows sharing Chimahon's full source+URL+normalized-title+nullable-author
  /// identity are indistinguishable for this reference subset check. The
  /// maximum valid pairing matches non-tombstones to reference slots first and
  /// reserves clocked tombstones for surplus slots. Consequently a group with
  /// `n` surplus rows needs at least `n` clocked tombstones; excess tombstones
  /// can occupy reference slots and do not manufacture additional surplus.
  void _auditRemoteOnlyManga({
    required BackupMihon reference,
    required BackupMihon remote,
    required void Function(String, Iterable<String>) fail,
  }) {
    final referenceCounts = _frequencies(reference.backupManga.map(_mangaKey));
    final remoteGroups = _groupManga(remote.backupManga);
    final invalid = <String>[];
    for (final entry in remoteGroups.entries) {
      final surplus = entry.value.length - (referenceCounts[entry.key] ?? 0);
      if (surplus <= 0) continue;
      final clockedTombstones = entry.value.where(_isClockedTombstone).length;
      final invalidCount = surplus - clockedTombstones;
      if (invalidCount <= 0) continue;
      for (var i = 0; i < invalidCount; i++) {
        invalid.add(entry.key);
      }
    }
    fail('remote_only_manga_not_clocked_tombstone', invalid);
  }

  void _auditPreferenceKeys({
    required BackupMihon remote,
    required BackupMihon proposed,
    required ChimahonPreferenceSafetyPolicy? policy,
    required void Function(String, Iterable<String>) fail,
  }) {
    final deletedAppKeys = policy?.deletedAppKeys ?? const <String>{};
    fail(
      'remote_preference_key_missing',
      _multisetMissing(
        _preferenceKeys(remote),
        _preferenceKeys(proposed),
      ).where((key) => !deletedAppKeys.contains(key)),
    );
    final deletedSourceKeys = {
      for (final key
          in policy?.deletedSourceKeys ?? const <ChimahonSourcePreferenceKey>{})
        _join([key.sourceKey, key.preferenceKey]),
    };
    fail(
      'remote_source_preference_key_missing',
      _multisetMissing(
        _sourcePreferenceKeys(remote),
        _sourcePreferenceKeys(proposed),
      ).where((key) => !deletedSourceKeys.contains(key)),
    );
  }

  void _auditSourceResolution({
    required Map<String, BackupMihon> inputs,
    required void Function(String, Iterable<String>) fail,
  }) {
    for (final entry in inputs.entries) {
      final sourceIds = entry.value.backupSources
          .where((source) => source.hasSourceId())
          .map(_sourceKey)
          .toSet();
      fail(
        '${entry.key}_manga_source_unresolved',
        entry.value.backupManga
            .where(
              (manga) =>
                  !manga.hasSource() ||
                  !sourceIds.contains(_mangaSourceKey(manga)),
            )
            .map(_mangaKey),
      );
    }
  }

  void _auditLocalChapterProjection({
    required BackupMihon local,
    required void Function(String, Iterable<String>) fail,
  }) {
    final invalid = <String>[];
    for (final manga in local.backupManga) {
      final parent = _mangaKey(manga);
      for (final chapter in manga.chapters) {
        if (!_hasPortableChapterIdentity(chapter)) {
          invalid.add(_join([parent, _chapterKey(chapter)]));
        }
      }
    }
    fail('local_nonportable_chapter_identity', invalid);
  }

  void _auditReferenceNovels({
    required BackupMihon reference,
    required BackupMihon remote,
    required void Function(String, Iterable<String>) fail,
  }) {
    fail(
      'reference_novel_canonical_identity_invalid',
      reference.backupNovels
          .where((novel) => _novelStableId(novel) == null)
          .map(_novelKeyOrInvalid),
    );
    _auditNovelTransition(
      baseline: reference,
      target: remote,
      missingNovelCode: 'reference_novel_missing_from_remote',
      progressRegressedCode: 'reference_novel_progress_regressed_in_remote',
      missingStatCode: 'reference_novel_stat_missing_from_remote',
      statRegressedCode: 'reference_novel_stat_regressed_in_remote',
      missingCategoryCode: 'reference_novel_category_missing_from_remote',
      missingMembershipCode:
          'reference_novel_category_membership_missing_from_remote',
      fail: fail,
    );
  }

  void _auditNovels({
    required BackupMihon remote,
    required BackupMihon proposed,
    required void Function(String, Iterable<String>) fail,
  }) {
    fail(
      'remote_novel_canonical_identity_invalid',
      remote.backupNovels
          .where((novel) => _novelStableId(novel) == null)
          .map(_novelKeyOrInvalid),
    );
    fail(
      'proposed_novel_canonical_id_invalid',
      proposed.backupNovels
          .where((novel) {
            final key = _novelStableId(novel);
            return key == null || !novel.hasId() || novel.id != key;
          })
          .map(_novelKeyOrInvalid),
    );
    _auditNovelTransition(
      baseline: remote,
      target: proposed,
      missingNovelCode: 'remote_novel_missing_from_proposed',
      progressRegressedCode: 'remote_novel_progress_regressed',
      missingStatCode: 'remote_novel_stat_missing',
      statRegressedCode: 'remote_novel_stat_regressed',
      missingCategoryCode: 'remote_novel_category_missing',
      missingMembershipCode: 'remote_novel_category_membership_missing',
      fail: fail,
    );
  }

  void _auditNovelTransition({
    required BackupMihon baseline,
    required BackupMihon target,
    required String missingNovelCode,
    required String progressRegressedCode,
    required String missingStatCode,
    required String statRegressedCode,
    required String missingCategoryCode,
    required String missingMembershipCode,
    required void Function(String, Iterable<String>) fail,
  }) {
    final baselineByKey = _novelSnapshots(baseline.backupNovels);
    final targetByKey = _novelSnapshots(target.backupNovels);
    final missingNovels = <String>[];
    final regressedProgress = <String>[];
    final missingStats = <String>[];
    final regressedStats = <String>[];
    final missingMemberships = <String>[];

    for (final entry in baselineByKey.entries) {
      final baselineNovel = entry.value;
      final candidate = targetByKey[entry.key];
      if (candidate == null) {
        missingNovels.add(entry.key);
        continue;
      }
      if (_novelProgressRegressed(baselineNovel.progress, candidate.progress)) {
        regressedProgress.add(entry.key);
      }

      for (final statEntry in baselineNovel.stats.entries) {
        final statKey = _join([entry.key, statEntry.key]);
        final candidateStat = candidate.stats[statEntry.key];
        if (candidateStat == null) {
          missingStats.add(statKey);
        } else if (_novelStatRegressed(statEntry.value, candidateStat)) {
          regressedStats.add(statKey);
        }
      }
      for (final categoryId in baselineNovel.categoryIds) {
        final defaultWasReplacedByConcreteCategory =
            categoryId == _uncategorizedNovelCategoryId &&
            candidate.categoryIds.any(
              (value) => value != _uncategorizedNovelCategoryId,
            );
        if (!candidate.categoryIds.contains(categoryId) &&
            !defaultWasReplacedByConcreteCategory) {
          missingMemberships.add(_join([entry.key, categoryId]));
        }
      }
    }

    final targetCategories = {
      for (final category in target.backupNovelCategories)
        _join([category.id, _normalized(category.name)]),
    };
    final missingCategories = baseline.backupNovelCategories
        .map((category) => _join([category.id, _normalized(category.name)]))
        .where((category) => !targetCategories.contains(category));

    fail(missingNovelCode, missingNovels);
    fail(progressRegressedCode, regressedProgress);
    fail(missingStatCode, missingStats);
    fail(statRegressedCode, regressedStats);
    fail(missingCategoryCode, missingCategories);
    fail(missingMembershipCode, missingMemberships);
  }

  void _reportLocalDifferences({
    required BackupMihon remote,
    required BackupMihon local,
    required void Function(String, Iterable<String>) observe,
  }) {
    observe(
      'local_only_manga_records',
      _multisetMissing(
        local.backupManga.map(_mangaKey),
        remote.backupManga.map(_mangaKey),
      ),
    );
    observe(
      'remote_only_manga_records',
      _multisetMissing(
        remote.backupManga.map(_mangaKey),
        local.backupManga.map(_mangaKey),
      ),
    );

    final remoteExactByCoarse = _exactMangaKeysByCoarse(remote.backupManga);
    final localExactByCoarse = _exactMangaKeysByCoarse(local.backupManga);
    final mangaConflicts = <String>[];
    for (final coarse in remoteExactByCoarse.keys) {
      final remoteExact = remoteExactByCoarse[coarse]!;
      final localExact = localExactByCoarse[coarse];
      if (localExact != null && !_setsEqual(remoteExact, localExact)) {
        mangaConflicts.add(coarse);
      }
    }
    observe('local_remote_manga_identity_conflicts', mangaConflicts);

    observe(
      'local_only_chapter_records',
      _multisetMissing(
        _qualifiedChapterKeys(local),
        _qualifiedChapterKeys(remote),
      ),
    );
    observe(
      'remote_only_chapter_records',
      _multisetMissing(
        _qualifiedChapterKeys(remote),
        _qualifiedChapterKeys(local),
      ),
    );

    final remoteChapterByUrl = _chapterKeysByParentUrl(remote);
    final localChapterByUrl = _chapterKeysByParentUrl(local);
    final chapterConflicts = <String>[];
    for (final parentUrl in remoteChapterByUrl.keys) {
      final remoteExact = remoteChapterByUrl[parentUrl]!;
      final localExact = localChapterByUrl[parentUrl];
      if (localExact != null && !_setsEqual(remoteExact, localExact)) {
        chapterConflicts.add(parentUrl);
      }
    }
    observe('local_remote_chapter_identity_conflicts', chapterConflicts);
  }

  static String _mangaKey(BackupManga manga) =>
      ChimahonMediaSafetyAudit.mangaIdentity(manga);

  static String _mangaCoarseKey(BackupManga manga) =>
      _join([_mangaSourceKey(manga), manga.url]);

  static String _mangaSourceKey(BackupManga manga) =>
      manga.hasSource() ? manga.source.toString() : 'source-absent';

  static String _sourceKey(BackupSource source) =>
      source.hasSourceId() ? source.sourceId.toString() : 'source-absent';

  static String _chapterKey(BackupChapter chapter) =>
      ChimahonMediaSafetyAudit.chapterIdentity(chapter);

  static Iterable<String> _qualifiedChapterKeys(BackupMihon backup) sync* {
    for (final manga in backup.backupManga) {
      final parent = _mangaKey(manga);
      for (final chapter in manga.chapters) {
        yield _join([parent, _chapterKey(chapter)]);
      }
    }
  }

  static Iterable<String> _qualifiedHistoryKeys(BackupMihon backup) sync* {
    for (final manga in backup.backupManga) {
      final parent = _mangaKey(manga);
      for (final history in manga.history) {
        yield _join([parent, history.url]);
      }
    }
  }

  static Iterable<String> _preferenceKeys(BackupMihon backup) =>
      backup.backupPreferences.map((preference) => preference.key);

  static Iterable<String> _sourcePreferenceKeys(BackupMihon backup) sync* {
    for (final group in backup.backupSourcePreferences) {
      for (final preference in group.prefs) {
        yield _join([group.sourceKey, preference.key]);
      }
    }
  }

  static Iterable<String> _customTitleKeys(BackupMihon backup) => backup
      .backupManga
      .where((manga) => manga.hasCustomTitle())
      .map((manga) => _join([_mangaKey(manga), manga.customTitle]));

  static String? _novelStableId(BackupNovel novel) =>
      ChimahonNovelIdentity.stableIdOrNull(
        title: novel.title,
        author: novel.hasAuthor() ? novel.author : null,
        fallbackId: novel.hasId() ? novel.id : null,
      );

  static String _novelKeyOrInvalid(BackupNovel novel) =>
      _novelStableId(novel) ??
      _join(['invalid-novel', _normalized(novel.title), novel.id]);

  /// Canonicalizes duplicate novel rows using Chimahon's merge clocks before
  /// comparing two payloads. Progress is whole-record LWW, daily statistics
  /// are LWW per date, and category membership is a normalized union.
  static Map<String, _NovelAuditSnapshot> _novelSnapshots(
    Iterable<BackupNovel> novels,
  ) {
    final result = <String, _NovelAuditSnapshot>{};
    for (final novel in novels) {
      final key = _novelStableId(novel);
      if (key == null) continue;
      final snapshot = result.putIfAbsent(
        key,
        () => _NovelAuditSnapshot(progress: novel),
      );
      if (novel.lastModified > snapshot.progress.lastModified) {
        snapshot.progress = novel;
      }
      for (final stat in novel.stats) {
        final current = snapshot.stats[stat.dateKey];
        if (current == null ||
            stat.lastStatisticModified > current.lastStatisticModified) {
          snapshot.stats[stat.dateKey] = stat;
        }
      }
      snapshot.categoryIds.addAll(
        novel.categoryIds.where((id) => id.isNotEmpty),
      );
    }
    for (final snapshot in result.values) {
      if (snapshot.categoryIds.any(
        (id) => id != _uncategorizedNovelCategoryId,
      )) {
        snapshot.categoryIds.remove(_uncategorizedNovelCategoryId);
      }
    }
    return result;
  }

  static bool _novelProgressRegressed(
    BackupNovel remote,
    BackupNovel proposed,
  ) {
    if (proposed.lastModified < remote.lastModified) return true;
    if (proposed.lastModified > remote.lastModified) return false;
    return proposed.chapterIndex != remote.chapterIndex ||
        proposed.progress != remote.progress ||
        proposed.characterCount != remote.characterCount;
  }

  static bool _novelStatRegressed(
    BackupNovelStat remote,
    BackupNovelStat proposed,
  ) {
    if (proposed.lastStatisticModified < remote.lastStatisticModified) {
      return true;
    }
    if (proposed.lastStatisticModified > remote.lastStatisticModified) {
      return false;
    }
    return proposed.charactersRead != remote.charactersRead ||
        proposed.readingTime != remote.readingTime ||
        proposed.minReadingSpeed != remote.minReadingSpeed ||
        proposed.altMinReadingSpeed != remote.altMinReadingSpeed ||
        proposed.lastReadingSpeed != remote.lastReadingSpeed ||
        proposed.maxReadingSpeed != remote.maxReadingSpeed;
  }

  static bool _isClockedTombstone(BackupManga manga) =>
      manga.hasFavorite() &&
      !manga.favorite &&
      _hasPositiveFavoriteClock(manga);

  static bool _hasPositiveFavoriteClock(BackupManga manga) =>
      manga.hasFavoriteModifiedAt() && manga.favoriteModifiedAt.toInt() > 0;

  static bool _hasPortableChapterIdentity(BackupChapter chapter) {
    return const ChimahonLocalChapterPolicy().hasPortableWireIdentity(
      url: chapter.hasUrl() ? chapter.url : null,
      name: chapter.hasName() ? chapter.name : null,
      chapterNumber: chapter.chapterNumber,
    );
  }

  static Map<String, List<BackupManga>> _groupManga(
    Iterable<BackupManga> manga,
  ) {
    final result = <String, List<BackupManga>>{};
    for (final item in manga) {
      result.putIfAbsent(_mangaKey(item), () => []).add(item);
    }
    return result;
  }

  static Map<String, Set<String>> _exactMangaKeysByCoarse(
    Iterable<BackupManga> manga,
  ) {
    final result = <String, Set<String>>{};
    for (final item in manga) {
      result.putIfAbsent(_mangaCoarseKey(item), () => {}).add(_mangaKey(item));
    }
    return result;
  }

  static Map<String, int> _mangaCoarseCollisions(BackupMihon backup) {
    final groups = <String, int>{};
    for (final manga in backup.backupManga) {
      final key = _mangaCoarseKey(manga);
      groups[key] = (groups[key] ?? 0) + 1;
    }
    groups.removeWhere((_, count) => count < 2);
    return groups;
  }

  static Map<String, int> _chapterUrlCollisions(BackupMihon backup) {
    final groups = <String, int>{};
    for (final manga in backup.backupManga) {
      final parent = _mangaKey(manga);
      for (final chapter in manga.chapters) {
        if (chapter.url.trim().isEmpty) continue;
        final key = _join([parent, chapter.url]);
        groups[key] = (groups[key] ?? 0) + 1;
      }
    }
    groups.removeWhere((_, count) => count < 2);
    return groups;
  }

  static Map<String, Set<String>> _chapterKeysByParentUrl(BackupMihon backup) {
    final result = <String, Set<String>>{};
    for (final manga in backup.backupManga) {
      final parent = _mangaKey(manga);
      for (final chapter in manga.chapters) {
        if (chapter.url.trim().isEmpty) continue;
        final parentUrl = _join([parent, chapter.url]);
        result.putIfAbsent(parentUrl, () => {}).add(_chapterKey(chapter));
      }
    }
    return result;
  }

  static Map<String, int> _frequencies(Iterable<String> values) {
    final result = <String, int>{};
    for (final value in values) {
      result[value] = (result[value] ?? 0) + 1;
    }
    return result;
  }

  static List<String> _multisetMissing(
    Iterable<String> required,
    Iterable<String> available,
  ) {
    final remaining = _frequencies(available);
    final missing = <String>[];
    for (final key in required) {
      final count = remaining[key] ?? 0;
      if (count == 0) {
        missing.add(key);
      } else {
        remaining[key] = count - 1;
      }
    }
    return missing;
  }

  static bool _setsEqual(Set<String> first, Set<String> second) =>
      first.length == second.length && first.containsAll(second);

  static String _normalized(String value) => value.trim().toLowerCase();

  /// Length framing avoids delimiter ambiguity without exposing the framed
  /// value: canonical identities are only emitted through aggregate hashes.
  static String _join(Iterable<String> values) =>
      values.map((value) => '${utf8.encode(value).length}:$value').join();

  static String _digest(String domain, Iterable<String> values) {
    final sorted = values.toList()..sort();
    final bytes = utf8.encode(_join([domain, ...sorted]));
    return sha256.convert(bytes).toString();
  }
}

class _NovelAuditSnapshot {
  _NovelAuditSnapshot({required this.progress});

  BackupNovel progress;
  final Map<String, BackupNovelStat> stats = {};
  final Set<String> categoryIds = {};
}

/// Safe-to-log output from [ChimahonSyncSafetyAudit].
///
/// No collection in this object contains a title, URL, source key, preference
/// key, or raw Chimahon ID. Affected identities are represented only by an
/// aggregate count and a domain-separated SHA-256 digest.
class ChimahonSyncSafetyReport {
  ChimahonSyncSafetyReport._({
    required Map<String, int> counts,
    required Map<String, String> hashes,
    required List<ChimahonSyncSafetyFinding> hardFailures,
    required List<ChimahonSyncSafetyFinding> observations,
  }) : counts = Map.unmodifiable(counts),
       hashes = Map.unmodifiable(hashes),
       hardFailures = List.unmodifiable(hardFailures),
       observations = List.unmodifiable(observations);

  final Map<String, int> counts;
  final Map<String, String> hashes;
  final List<ChimahonSyncSafetyFinding> hardFailures;
  final List<ChimahonSyncSafetyFinding> observations;

  bool get safeToUpload => hardFailures.isEmpty;

  Map<String, Object> toSafeJson() => {
    'safeToUpload': safeToUpload,
    'counts': counts,
    'hashes': hashes,
    'hardFailures': [for (final finding in hardFailures) finding.toSafeJson()],
    'observations': [for (final finding in observations) finding.toSafeJson()],
  };
}

class ChimahonSyncSafetyFinding {
  const ChimahonSyncSafetyFinding._({
    required this.code,
    required this.affectedCount,
    required this.affectedSha256,
  });

  final String code;
  final int affectedCount;
  final String affectedSha256;

  Map<String, Object> toSafeJson() => {
    'code': code,
    'affectedCount': affectedCount,
    'affectedSha256': affectedSha256,
  };
}
