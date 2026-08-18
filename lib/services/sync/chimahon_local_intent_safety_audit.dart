import 'dart:convert';

import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_unknown_field_safety.dart';
import 'package:mangayomi/utils/chimahon_novel_identity.dart';

typedef ChimahonSafetyIdentitySink =
    void Function(String code, Iterable<String> affected);

/// Audits the effective local side of a Chimahon merge.
///
/// The caller supplies sinks which immediately aggregate and hash identities;
/// this helper never logs them or puts them in the public safety report. It is
/// separate from the main audit because root collection and local-intent
/// transition policy is substantial and independently testable.
class ChimahonLocalIntentSafetyAudit {
  const ChimahonLocalIntentSafetyAudit();

  static const _uncategorizedNovelCategoryId = 'default';

  void audit({
    required BackupMihon local,
    required BackupMihon remote,
    required BackupMihon proposed,
    required ChimahonSafetyIdentitySink fail,
    required ChimahonSafetyIdentitySink observe,
  }) {
    _auditNovels(local: local, remote: remote, proposed: proposed, fail: fail);
    _observeNovelDifferences(local: local, remote: remote, observe: observe);
  }

  void _auditNovels({
    required BackupMihon local,
    required BackupMihon remote,
    required BackupMihon proposed,
    required ChimahonSafetyIdentitySink fail,
  }) {
    fail(
      'local_novel_canonical_identity_invalid',
      local.backupNovels
          .where((novel) => _novelStableId(novel) == null)
          .map(_novelKeyOrInvalid),
    );

    final localByKey = _novelSnapshots(local.backupNovels);
    final proposedByKey = _novelSnapshots(proposed.backupNovels);
    final missingNovels = <String>[];
    final regressedProgress = <String>[];
    final missingStats = <String>[];
    final regressedStats = <String>[];
    final missingMemberships = <String>[];
    final changedLocalOnlyMetadata = <String>[];
    final novelUnknownFields = <String>[];
    final novelStatUnknownFields = <String>[];
    final remoteNovelKeys = _novelSnapshots(remote.backupNovels).keys.toSet();
    final proposedNovelRows = {
      for (final novel in proposed.backupNovels)
        if (_novelStableId(novel) case final String identity) identity: novel,
    };
    final categoryIdMap = _novelCategoryIdMap(
      baseline: local.backupNovelCategories,
      target: proposed.backupNovelCategories,
    );

    for (final entry in localByKey.entries) {
      final baseline = entry.value;
      final candidate = proposedByKey[entry.key];
      if (candidate == null) {
        missingNovels.add(entry.key);
        continue;
      }
      if (_novelProgressRegressed(baseline.progress, candidate.progress)) {
        regressedProgress.add(entry.key);
      }
      if (!remoteNovelKeys.contains(entry.key) &&
          !_localOnlyNovelMetadataPreserved(
            baseline.progress,
            candidate.progress,
          )) {
        changedLocalOnlyMetadata.add(entry.key);
      }
      for (final statEntry in baseline.stats.entries) {
        final identity = _join([entry.key, statEntry.key]);
        final candidateStat = candidate.stats[statEntry.key];
        if (candidateStat == null) {
          missingStats.add(identity);
        } else if (_novelStatRegressed(statEntry.value, candidateStat)) {
          regressedStats.add(identity);
        }
      }
      for (final categoryId in baseline.categoryIds) {
        final mappedId = categoryIdMap[categoryId] ?? categoryId;
        final defaultWasReplacedByConcreteCategory =
            categoryId == _uncategorizedNovelCategoryId &&
            candidate.categoryIds.any(
              (value) => value != _uncategorizedNovelCategoryId,
            );
        if (!candidate.categoryIds.contains(mappedId) &&
            !candidate.categoryIds.contains(categoryId) &&
            !defaultWasReplacedByConcreteCategory) {
          missingMemberships.add(_join([entry.key, categoryId]));
        }
      }
    }

    for (final novel in local.backupNovels) {
      final identity = _novelStableId(novel);
      if (identity == null) continue;
      final candidate = proposedNovelRows[identity];
      if (candidate == null) continue;
      novelUnknownFields.addAll(
        ChimahonUnknownFieldSafety.missingOrReorderedTags(
          baseline: novel,
          target: candidate,
        ).map((tag) => _join([identity, '$tag'])),
      );
      for (final stat in novel.stats) {
        final candidates = candidate.stats.where(
          (value) => value.dateKey == stat.dateKey,
        );
        final preservesUnknowns = candidates.any(
          (value) => ChimahonUnknownFieldSafety.missingOrReorderedTags(
            baseline: stat,
            target: value,
          ).isEmpty,
        );
        if (!preservesUnknowns && stat.unknownFields.asMap().isNotEmpty) {
          novelStatUnknownFields.add(_join([identity, stat.dateKey]));
        }
      }
    }

    final missingCategories = <String>[];
    final changedLocalOnlyCategories = <String>[];
    final categoryUnknownFields = <String>[];
    for (final category in local.backupNovelCategories) {
      final candidate = _matchingNovelCategory(
        category,
        proposed.backupNovelCategories,
      );
      if (candidate == null) {
        missingCategories.add(_join([category.id, _normalized(category.name)]));
        continue;
      }
      final remotePeer = _matchingNovelCategory(
        category,
        remote.backupNovelCategories,
      );
      if (remotePeer == null && !_sameNovelCategoryKnown(category, candidate)) {
        changedLocalOnlyCategories.add(
          _join([category.id, _normalized(category.name)]),
        );
      }
      for (final tag in category.unknownFields.asMap().keys) {
        final preserved = proposed.backupNovelCategories
            .where(
              (value) =>
                  value.id == category.id ||
                  _normalized(value.name) == _normalized(category.name),
            )
            .any(
              (value) => ChimahonUnknownFieldSafety.missingOrReorderedTags(
                baseline: _novelCategoryWithOnlyUnknownField(category, tag),
                target: value,
              ).isEmpty,
            );
        if (!preserved) {
          categoryUnknownFields.add(_join([category.id, '$tag']));
        }
      }
    }

    fail('local_novel_missing_from_proposed', missingNovels);
    fail('local_novel_progress_regressed_in_proposed', regressedProgress);
    fail(
      'local_only_novel_metadata_changed_in_proposed',
      changedLocalOnlyMetadata,
    );
    fail('local_novel_stat_missing_from_proposed', missingStats);
    fail('local_novel_stat_regressed_in_proposed', regressedStats);
    fail('local_novel_unknown_envelope_not_preserved', novelUnknownFields);
    fail(
      'local_novel_stat_unknown_envelope_not_preserved',
      novelStatUnknownFields,
    );
    fail('local_novel_category_missing_from_proposed', missingCategories);
    fail(
      'local_only_novel_category_changed_in_proposed',
      changedLocalOnlyCategories,
    );
    fail(
      'local_novel_category_unknown_envelope_not_preserved',
      categoryUnknownFields,
    );
    fail(
      'local_novel_category_membership_missing_from_proposed',
      missingMemberships,
    );
  }

  void _observeNovelDifferences({
    required BackupMihon local,
    required BackupMihon remote,
    required ChimahonSafetyIdentitySink observe,
  }) {
    final remoteIds = _novelSnapshots(remote.backupNovels).keys.toSet();
    final localIds = _novelSnapshots(local.backupNovels).keys.toSet();
    observe(
      'local_only_novel_records',
      localIds.where((identity) => !remoteIds.contains(identity)),
    );

    final titleOnlyCollisions = <String>[];
    final nearIdentityCollisions = <String>[];
    for (final localNovel in local.backupNovels) {
      final localId = _novelStableId(localNovel);
      if (localId == null) continue;
      for (final remoteNovel in remote.backupNovels) {
        final remoteId = _novelStableId(remoteNovel);
        if (remoteId == null || remoteId == localId) continue;
        final localTitle = _normalized(localNovel.title);
        final remoteTitle = _normalized(remoteNovel.title);
        if (localTitle.isNotEmpty && localTitle == remoteTitle) {
          titleOnlyCollisions.add(_join([localId, remoteId]));
          continue;
        }
        if (_nearNormalized(localNovel.title).isNotEmpty &&
            _nearNormalized(localNovel.title) ==
                _nearNormalized(remoteNovel.title) &&
            _nearNormalized(_novelAuthor(localNovel)) ==
                _nearNormalized(_novelAuthor(remoteNovel))) {
          nearIdentityCollisions.add(_join([localId, remoteId]));
        }
      }
    }
    observe(
      'local_remote_novel_title_only_collisions',
      titleOnlyCollisions.toSet(),
    );
    observe(
      'local_remote_novel_near_identity_collisions',
      nearIdentityCollisions.toSet(),
    );
  }

  Map<String, String> _novelCategoryIdMap({
    required Iterable<BackupNovelCategory> baseline,
    required Iterable<BackupNovelCategory> target,
  }) {
    final targetList = target.toList(growable: false);
    final result = <String, String>{};
    for (final category in baseline) {
      // This mirrors ChimahonSyncMerger._canonicalNovels: category display
      // identity is resolved by normalized source name before falling back to
      // an opaque ID which may have been reused by a renamed remote category.
      final sameName = targetList.where(
        (candidate) =>
            _normalized(candidate.name) == _normalized(category.name),
      );
      if (sameName.isNotEmpty) {
        result[category.id] = sameName.first.id;
        continue;
      }
      final sameId = targetList.where(
        (candidate) => candidate.id == category.id,
      );
      if (sameId.isNotEmpty) result[category.id] = sameId.first.id;
    }
    return result;
  }

  Map<String, _NovelSnapshot> _novelSnapshots(Iterable<BackupNovel> novels) {
    final result = <String, _NovelSnapshot>{};
    for (final novel in novels) {
      final identity = _novelStableId(novel);
      if (identity == null) continue;
      final snapshot = result.putIfAbsent(
        identity,
        () => _NovelSnapshot(progress: novel),
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
        novel.categoryIds.where((id) => id.trim().isNotEmpty),
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

  bool _novelProgressRegressed(BackupNovel baseline, BackupNovel candidate) {
    if (candidate.lastModified < baseline.lastModified) return true;
    if (candidate.lastModified > baseline.lastModified) return false;
    return candidate.chapterIndex != baseline.chapterIndex ||
        candidate.progress != baseline.progress ||
        candidate.characterCount != baseline.characterCount;
  }

  bool _novelStatRegressed(
    BackupNovelStat baseline,
    BackupNovelStat candidate,
  ) {
    if (candidate.lastStatisticModified < baseline.lastStatisticModified) {
      return true;
    }
    if (candidate.lastStatisticModified > baseline.lastStatisticModified) {
      return false;
    }
    return candidate.charactersRead != baseline.charactersRead ||
        candidate.readingTime != baseline.readingTime ||
        candidate.minReadingSpeed != baseline.minReadingSpeed ||
        candidate.altMinReadingSpeed != baseline.altMinReadingSpeed ||
        candidate.lastReadingSpeed != baseline.lastReadingSpeed ||
        candidate.maxReadingSpeed != baseline.maxReadingSpeed;
  }

  bool _localOnlyNovelMetadataPreserved(
    BackupNovel baseline,
    BackupNovel candidate,
  ) =>
      candidate.title == baseline.title &&
      _optionalStringPreserved(
        baseline.hasAuthor(),
        baseline.author,
        candidate.hasAuthor(),
        candidate.author,
      ) &&
      _optionalStringPreserved(
        baseline.hasCover(),
        baseline.cover,
        candidate.hasCover(),
        candidate.cover,
      ) &&
      _optionalStringPreserved(
        baseline.hasLang(),
        baseline.lang,
        candidate.hasLang(),
        candidate.lang,
      );

  bool _optionalStringPreserved(
    bool baselinePresent,
    String baseline,
    bool candidatePresent,
    String candidate,
  ) => !baselinePresent || (candidatePresent && candidate == baseline);

  BackupNovelCategory? _matchingNovelCategory(
    BackupNovelCategory baseline,
    Iterable<BackupNovelCategory> candidates,
  ) {
    final list = candidates.toList(growable: false);
    for (final candidate in list) {
      if (_normalized(candidate.name) == _normalized(baseline.name)) {
        return candidate;
      }
    }
    for (final candidate in list) {
      if (candidate.id == baseline.id) return candidate;
    }
    return null;
  }

  bool _sameNovelCategoryKnown(
    BackupNovelCategory baseline,
    BackupNovelCategory candidate,
  ) =>
      baseline.id == candidate.id &&
      baseline.name == candidate.name &&
      baseline.order == candidate.order &&
      baseline.flags == candidate.flags;

  BackupNovelCategory _novelCategoryWithOnlyUnknownField(
    BackupNovelCategory source,
    int tag,
  ) {
    final result = BackupNovelCategory();
    final field = source.unknownFields.getField(tag);
    if (field != null) result.unknownFields.mergeField(tag, field);
    return result;
  }

  String? _novelStableId(BackupNovel novel) =>
      ChimahonNovelIdentity.stableIdOrNull(
        title: novel.title,
        author: novel.hasAuthor() ? novel.author : null,
        fallbackId: novel.hasId() ? novel.id : null,
      );

  String _novelKeyOrInvalid(BackupNovel novel) =>
      _novelStableId(novel) ??
      _join(['invalid-novel', _normalized(novel.title), novel.id]);

  String _novelAuthor(BackupNovel novel) =>
      novel.hasAuthor() ? novel.author : '';

  String _nearNormalized(String value) => value.trim().toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]+', unicode: true),
    '',
  );

  String _normalized(String value) => value.trim().toLowerCase();

  String _join(Iterable<String> values) =>
      values.map((value) => '${utf8.encode(value).length}:$value').join();
}

class _NovelSnapshot {
  _NovelSnapshot({required this.progress});

  BackupNovel progress;
  final Map<String, BackupNovelStat> stats = {};
  final Set<String> categoryIds = {};
}
