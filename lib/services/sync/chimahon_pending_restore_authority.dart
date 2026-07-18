import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';
import 'package:mangayomi/services/sync/chimahon_opaque_rows.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:protobuf/protobuf.dart';

/// Applies an explicitly selected Chimahon backup after the ordinary
/// local/cloud merge.
///
/// The ordinary merger is deliberately newest-wins. That is correct for
/// routine sync, but not for the first upload after a user deliberately chose
/// an older `.tachibk` file. Here, only identities present in that selected
/// backup become authoritative. Current Mangatan projections are used for
/// those identities so edits made after restore are retained, while identities
/// that exist only in the cloud remain untouched.
class ChimahonPendingRestoreAuthority {
  const ChimahonPendingRestoreAuthority();

  BackupMihon apply({
    required BackupMihon pending,
    required BackupMihon localIntent,
    required BackupMihon? remote,
    required BackupMihon merged,
    Set<ChimahonTrackingDeletionKey> localTrackingDeletions = const {},
  }) {
    final result = merged.deepCopy();

    _putSelectedUnknownFieldsLast(result, pending);

    final selectedMangaCategories = _selectedRows(
      pending: pending.backupCategories,
      current: localIntent.backupCategories,
      keyOf: _categoryKey,
    );
    result.backupCategories
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: merged.backupCategories,
          selected: selectedMangaCategories,
          keyOf: _categoryKey,
          overlay: _selectedOverFallback,
        ),
      );
    final selectedAnimeCategories = _selectedRows(
      pending: pending.backupAnimeCategories,
      current: localIntent.backupAnimeCategories,
      keyOf: _categoryKey,
    );
    result.backupAnimeCategories
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: merged.backupAnimeCategories,
          selected: selectedAnimeCategories,
          keyOf: _categoryKey,
          overlay: _selectedOverFallback,
        ),
      );
    result.backupNovelCategories
      ..clear()
      ..addAll(
        _overlayNovelCategories(
          fallback: merged.backupNovelCategories,
          selected: _selectedNovelCategories(
            pending.backupNovelCategories,
            localIntent.backupNovelCategories,
          ),
        ),
      );

    final selectedManga = _selectedRows(
      pending: pending.backupManga,
      current: localIntent.backupManga,
      keyOf: _mangaKey,
    );
    final remoteManga = _lastByKey(
      remote?.backupManga ?? const <BackupManga>[],
      _mangaKey,
    );
    result.backupManga
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: merged.backupManga,
          selected: selectedManga,
          keyOf: _mangaKey,
          overlay: (selected, fallback) => _overlayManga(
            selected,
            fallback,
            remoteManga[_mangaKey(selected)],
            localTrackingDeletions,
          ),
        ),
      );

    final selectedAnime = _selectedRows(
      pending: pending.backupAnime,
      current: localIntent.backupAnime,
      keyOf: _animeKey,
    );
    final remoteAnime = _lastByKey(
      remote?.backupAnime ?? const <BackupAnime>[],
      _animeKey,
    );
    result.backupAnime
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: merged.backupAnime,
          selected: selectedAnime,
          keyOf: _animeKey,
          overlay: (selected, fallback) => _overlayAnime(
            selected,
            fallback,
            remoteAnime[_animeKey(selected)],
            localTrackingDeletions,
          ),
        ),
      );

    final remoteNovels = _lastByKey(
      remote?.backupNovels ?? const <BackupNovel>[],
      _novelKey,
    );
    result.backupNovels
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: merged.backupNovels,
          selected: _selectedRows(
            pending: pending.backupNovels,
            current: localIntent.backupNovels,
            keyOf: _novelKey,
          ),
          keyOf: _novelKey,
          overlay: (selected, fallback) => _overlayNovel(
            selected,
            fallback,
            remoteNovels[_novelKey(selected)],
          ),
        ),
      );

    result.backupMangaStats
      ..clear()
      ..addAll(
        ChimahonOpaqueRows.mergeMaxMultiplicity(
          merged.backupMangaStats,
          pending.backupMangaStats,
        ),
      );
    result.backupAnkiStats
      ..clear()
      ..addAll(
        ChimahonOpaqueRows.mergeMaxMultiplicity(
          merged.backupAnkiStats,
          pending.backupAnkiStats,
        ),
      );

    _canonicalizeCategoryOrdersAndRemapMedia<BackupManga>(
      categories: result.backupCategories,
      selectedCategories: selectedMangaCategories,
      selectedSourceCategories: localIntent.backupCategories,
      fallbackSourceCategories: merged.backupCategories,
      media: result.backupManga,
      selectedMediaKeys: selectedManga.map(_mangaKey).toSet(),
      keyOf: _mangaKey,
      categoryOrdersOf: (manga) => manga.categories,
    );
    _canonicalizeCategoryOrdersAndRemapMedia<BackupAnime>(
      categories: result.backupAnimeCategories,
      selectedCategories: selectedAnimeCategories,
      selectedSourceCategories: localIntent.backupAnimeCategories,
      fallbackSourceCategories: merged.backupAnimeCategories,
      media: result.backupAnime,
      selectedMediaKeys: selectedAnime.map(_animeKey).toSet(),
      keyOf: _animeKey,
      categoryOrdersOf: (anime) => anime.categories,
    );

    return result;
  }

  /// Confirms that all selected/current media records are represented in the
  /// exact protobuf that will be handed to storage. Additional cloud-only
  /// records and children are intentionally ignored.
  bool containsSelectedIntent({
    required BackupMihon uploaded,
    required BackupMihon pending,
    required BackupMihon localIntent,
  }) {
    if (!_unknownFieldsEndWith(uploaded, pending)) return false;

    final uploadedManga = _lastByKey(uploaded.backupManga, _mangaKey);
    for (final selected in _selectedRows(
      pending: pending.backupManga,
      current: localIntent.backupManga,
      keyOf: _mangaKey,
    )) {
      final actual = uploadedManga[_mangaKey(selected)];
      if (actual == null || !_containsManga(actual, selected)) return false;
    }

    final uploadedAnime = _lastByKey(uploaded.backupAnime, _animeKey);
    for (final selected in _selectedRows(
      pending: pending.backupAnime,
      current: localIntent.backupAnime,
      keyOf: _animeKey,
    )) {
      final actual = uploadedAnime[_animeKey(selected)];
      if (actual == null || !_containsAnime(actual, selected)) return false;
    }

    final uploadedNovels = _lastByKey(uploaded.backupNovels, _novelKey);
    for (final selected in _selectedRows(
      pending: pending.backupNovels,
      current: localIntent.backupNovels,
      keyOf: _novelKey,
    )) {
      final actual = uploadedNovels[_novelKey(selected)];
      if (actual == null || !_containsNovel(actual, selected)) return false;
    }

    if (!_containsSelectedRows(
      uploaded: uploaded.backupCategories,
      selected: _selectedRows(
        pending: pending.backupCategories,
        current: localIntent.backupCategories,
        keyOf: _categoryKey,
      ),
      keyOf: _categoryKey,
    )) {
      return false;
    }
    if (!_containsSelectedRows(
      uploaded: uploaded.backupAnimeCategories,
      selected: _selectedRows(
        pending: pending.backupAnimeCategories,
        current: localIntent.backupAnimeCategories,
        keyOf: _categoryKey,
      ),
      keyOf: _categoryKey,
    )) {
      return false;
    }
    if (!_containsSelectedNovelCategories(
      uploaded.backupNovelCategories,
      _selectedNovelCategories(
        pending.backupNovelCategories,
        localIntent.backupNovelCategories,
      ),
    )) {
      return false;
    }
    if (ChimahonOpaqueRows.missingExactRows(
      pending.backupMangaStats,
      uploaded.backupMangaStats,
    ).isNotEmpty) {
      return false;
    }
    if (ChimahonOpaqueRows.missingExactRows(
      pending.backupAnkiStats,
      uploaded.backupAnkiStats,
    ).isNotEmpty) {
      return false;
    }

    return _containsPendingPreferences(uploaded, pending, localIntent);
  }

  BackupManga _overlayManga(
    BackupManga selected,
    BackupManga fallback,
    BackupManga? competing,
    Set<ChimahonTrackingDeletionKey> localTrackingDeletions,
  ) {
    final result = _selectedOverFallback(selected, fallback);
    final competingChapters = _lastByKey(
      competing?.chapters ?? const <BackupChapter>[],
      _chapterKey,
    );
    result.chapters
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: fallback.chapters,
          selected: selected.chapters,
          keyOf: _chapterKey,
          overlay: (chapter, old) => _overlayChapter(
            chapter,
            old,
            competingChapters[_chapterKey(chapter)],
          ),
        ),
      );
    final competingHistory = _lastByKey(
      competing?.history ?? const <BackupHistory>[],
      (history) => history.url,
    );
    result.history
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: fallback.history,
          selected: selected.history,
          keyOf: (history) => history.url,
          overlay: (history, old) =>
              _overlayHistory(history, old, competingHistory[history.url]),
        ),
      );
    result.tracking
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: fallback.tracking,
          selected: selected.tracking,
          keyOf: (tracking) => tracking.syncId,
          overlay: _selectedOverFallback,
        ),
      );
    _removeExplicitlyDeletedTracking(
      result.tracking,
      selectedTracking: selected.tracking,
      source: selected.source.toInt(),
      url: selected.url,
      localTrackingDeletions: localTrackingDeletions,
    );
    if (competing != null) {
      result.version = _promoteIfNeeded(selected.version, competing.version);
      if (competing.hasFavoriteModifiedAt() ||
          selected.hasFavoriteModifiedAt()) {
        result.favoriteModifiedAt = _promoteIfNeeded(
          selected.hasFavoriteModifiedAt()
              ? selected.favoriteModifiedAt
              : Int64.ZERO,
          competing.hasFavoriteModifiedAt()
              ? competing.favoriteModifiedAt
              : Int64.ZERO,
        );
        if (result.lastModifiedAt < result.favoriteModifiedAt) {
          result.lastModifiedAt = result.favoriteModifiedAt;
        }
      }
    }
    return result;
  }

  BackupAnime _overlayAnime(
    BackupAnime selected,
    BackupAnime fallback,
    BackupAnime? competing,
    Set<ChimahonTrackingDeletionKey> localTrackingDeletions,
  ) {
    final result = _selectedOverFallback(selected, fallback);
    final competingEpisodes = _lastByKey(
      competing?.episodes ?? const <BackupEpisode>[],
      _episodeKey,
    );
    result.episodes
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: fallback.episodes,
          selected: selected.episodes,
          keyOf: _episodeKey,
          overlay: (episode, old) => _overlayEpisode(
            episode,
            old,
            competingEpisodes[_episodeKey(episode)],
          ),
        ),
      );
    final competingHistory = _lastByKey(
      competing?.history ?? const <BackupHistory>[],
      (history) => history.url,
    );
    result.history
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: fallback.history,
          selected: selected.history,
          keyOf: (history) => history.url,
          overlay: (history, old) =>
              _overlayHistory(history, old, competingHistory[history.url]),
        ),
      );
    result.tracking
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: fallback.tracking,
          selected: selected.tracking,
          keyOf: (tracking) => tracking.syncId,
          overlay: _selectedOverFallback,
        ),
      );
    _removeExplicitlyDeletedTracking(
      result.tracking,
      selectedTracking: selected.tracking,
      source: selected.source.toInt(),
      url: selected.url,
      localTrackingDeletions: localTrackingDeletions,
    );
    if (competing != null) {
      result.version = _promoteIfNeeded(selected.version, competing.version);
      if (competing.hasFavoriteModifiedAt() ||
          selected.hasFavoriteModifiedAt()) {
        result.favoriteModifiedAt = _promoteIfNeeded(
          selected.hasFavoriteModifiedAt()
              ? selected.favoriteModifiedAt
              : Int64.ZERO,
          competing.hasFavoriteModifiedAt()
              ? competing.favoriteModifiedAt
              : Int64.ZERO,
        );
        if (result.lastModifiedAt < result.favoriteModifiedAt) {
          result.lastModifiedAt = result.favoriteModifiedAt;
        }
      }
    }
    return result;
  }

  void _removeExplicitlyDeletedTracking(
    List<BackupTracking> tracking, {
    required Iterable<BackupTracking> selectedTracking,
    required int source,
    required String url,
    required Set<ChimahonTrackingDeletionKey> localTrackingDeletions,
  }) {
    // Ordinary tracking absence is upsert-only, but these keys are durable
    // evidence that the user explicitly removed a portable tracker after the
    // manual restore was selected. Do not let the fallback cloud row revive it;
    // a currently selected row still wins when the user re-added the tracker.
    final selectedSyncIds = selectedTracking.map((row) => row.syncId).toSet();
    tracking.removeWhere(
      (row) =>
          !selectedSyncIds.contains(row.syncId) &&
          _isPortableTrackingService(row.syncId) &&
          localTrackingDeletions.contains((
            source: source,
            url: url,
            syncId: row.syncId,
          )),
    );
  }

  bool _isPortableTrackingService(int syncId) =>
      syncId == 1 || syncId == 2 || syncId == 3;

  BackupChapter _overlayChapter(
    BackupChapter selected,
    BackupChapter fallback,
    BackupChapter? competing,
  ) {
    final result = _selectedOverFallback(selected, fallback);
    if (competing != null) {
      result.version = _promoteIfNeeded(selected.version, competing.version);
    }
    return result;
  }

  BackupEpisode _overlayEpisode(
    BackupEpisode selected,
    BackupEpisode fallback,
    BackupEpisode? competing,
  ) {
    final result = _selectedOverFallback(selected, fallback);
    if (competing != null) {
      result.version = _promoteIfNeeded(selected.version, competing.version);
    }
    return result;
  }

  BackupHistory _overlayHistory(
    BackupHistory selected,
    BackupHistory fallback,
    BackupHistory? competing,
  ) {
    final result = _selectedOverFallback(selected, fallback);
    if (competing != null) {
      result.lastRead = _promoteIfNeeded(selected.lastRead, competing.lastRead);
    }
    return result;
  }

  BackupNovel _overlayNovel(
    BackupNovel selected,
    BackupNovel fallback,
    BackupNovel? competing,
  ) {
    final result = _selectedOverFallback(selected, fallback);
    final competingStats = _lastByKey(
      competing?.stats ?? const <BackupNovelStat>[],
      (stat) => stat.dateKey,
    );
    result.stats
      ..clear()
      ..addAll(
        _overlaySelected(
          fallback: fallback.stats,
          selected: selected.stats,
          keyOf: (stat) => stat.dateKey,
          overlay: (stat, old) {
            final restored = _selectedOverFallback(stat, old);
            final cloud = competingStats[stat.dateKey];
            if (cloud != null) {
              restored.lastStatisticModified = _promoteIfNeeded(
                stat.lastStatisticModified,
                cloud.lastStatisticModified,
              );
            }
            return restored;
          },
        ),
      );
    if (competing != null) {
      result.lastModified = _promoteIfNeeded(
        selected.lastModified,
        competing.lastModified,
      );
    }
    return result;
  }

  bool _containsManga(BackupManga actual, BackupManga selected) {
    final actualRoot = actual.deepCopy()
      ..chapters.clear()
      ..history.clear()
      ..tracking.clear()
      ..unknownFields.clear();
    _copyMangaPromotionFields(actualRoot, selected);
    if (selected.hasFavoriteModifiedAt()) {
      actualRoot.favoriteModifiedAt = selected.favoriteModifiedAt;
    } else {
      actualRoot.clearFavoriteModifiedAt();
    }
    final selectedRoot = selected.deepCopy()
      ..chapters.clear()
      ..history.clear()
      ..tracking.clear()
      ..unknownFields.clear();
    if (!_sameBytes(actualRoot, selectedRoot) ||
        !_unknownFieldsEndWith(actual, selected)) {
      return false;
    }
    return _containsSelectedMessages(
          actual: actual.chapters,
          selected: selected.chapters,
          keyOf: _chapterKey,
          normalize: _copyChapterVersion,
        ) &&
        _containsSelectedMessages(
          actual: actual.history,
          selected: selected.history,
          keyOf: (history) => history.url,
          normalize: _copyHistoryClock,
        ) &&
        _containsSelectedMessages(
          actual: actual.tracking,
          selected: selected.tracking,
          keyOf: (tracking) => tracking.syncId,
        );
  }

  bool _containsAnime(BackupAnime actual, BackupAnime selected) {
    final actualRoot = actual.deepCopy()
      ..episodes.clear()
      ..history.clear()
      ..tracking.clear()
      ..unknownFields.clear();
    _copyAnimePromotionFields(actualRoot, selected);
    if (selected.hasFavoriteModifiedAt()) {
      actualRoot.favoriteModifiedAt = selected.favoriteModifiedAt;
    } else {
      actualRoot.clearFavoriteModifiedAt();
    }
    final selectedRoot = selected.deepCopy()
      ..episodes.clear()
      ..history.clear()
      ..tracking.clear()
      ..unknownFields.clear();
    if (!_sameBytes(actualRoot, selectedRoot) ||
        !_unknownFieldsEndWith(actual, selected)) {
      return false;
    }
    return _containsSelectedMessages(
          actual: actual.episodes,
          selected: selected.episodes,
          keyOf: _episodeKey,
          normalize: _copyEpisodeVersion,
        ) &&
        _containsSelectedMessages(
          actual: actual.history,
          selected: selected.history,
          keyOf: (history) => history.url,
          normalize: _copyHistoryClock,
        ) &&
        _containsSelectedMessages(
          actual: actual.tracking,
          selected: selected.tracking,
          keyOf: (tracking) => tracking.syncId,
        );
  }

  bool _containsNovel(BackupNovel actual, BackupNovel selected) {
    final actualRoot = actual.deepCopy()
      ..stats.clear()
      ..unknownFields.clear();
    _copyNovelClock(actualRoot, selected);
    final selectedRoot = selected.deepCopy()
      ..stats.clear()
      ..unknownFields.clear();
    if (!_sameBytes(actualRoot, selectedRoot) ||
        !_unknownFieldsEndWith(actual, selected)) {
      return false;
    }
    return _containsSelectedMessages(
      actual: actual.stats,
      selected: selected.stats,
      keyOf: (stat) => stat.dateKey,
      normalize: _copyNovelStatClock,
    );
  }

  BackupManga _copyMangaPromotionFields(
    BackupManga actual,
    BackupManga selected,
  ) {
    if (selected.hasVersion()) {
      actual.version = selected.version;
    } else {
      actual.clearVersion();
    }
    if (selected.hasLastModifiedAt()) {
      actual.lastModifiedAt = selected.lastModifiedAt;
    } else {
      actual.clearLastModifiedAt();
    }
    return actual;
  }

  BackupAnime _copyAnimePromotionFields(
    BackupAnime actual,
    BackupAnime selected,
  ) {
    if (selected.hasVersion()) {
      actual.version = selected.version;
    } else {
      actual.clearVersion();
    }
    if (selected.hasLastModifiedAt()) {
      actual.lastModifiedAt = selected.lastModifiedAt;
    } else {
      actual.clearLastModifiedAt();
    }
    return actual;
  }

  BackupChapter _copyChapterVersion(
    BackupChapter actual,
    BackupChapter selected,
  ) {
    if (selected.hasVersion()) {
      actual.version = selected.version;
    } else {
      actual.clearVersion();
    }
    return actual;
  }

  BackupEpisode _copyEpisodeVersion(
    BackupEpisode actual,
    BackupEpisode selected,
  ) {
    if (selected.hasVersion()) {
      actual.version = selected.version;
    } else {
      actual.clearVersion();
    }
    return actual;
  }

  BackupHistory _copyHistoryClock(
    BackupHistory actual,
    BackupHistory selected,
  ) {
    if (selected.hasLastRead()) {
      actual.lastRead = selected.lastRead;
    } else {
      actual.clearLastRead();
    }
    return actual;
  }

  BackupNovel _copyNovelClock(BackupNovel actual, BackupNovel selected) {
    if (selected.hasLastModified()) {
      actual.lastModified = selected.lastModified;
    } else {
      actual.clearLastModified();
    }
    return actual;
  }

  BackupNovelStat _copyNovelStatClock(
    BackupNovelStat actual,
    BackupNovelStat selected,
  ) {
    if (selected.hasLastStatisticModified()) {
      actual.lastStatisticModified = selected.lastStatisticModified;
    } else {
      actual.clearLastStatisticModified();
    }
    return actual;
  }

  bool _containsPendingPreferences(
    BackupMihon uploaded,
    BackupMihon pending,
    BackupMihon localIntent,
  ) {
    final currentPreferences = _lastByKey(
      localIntent.backupPreferences,
      (preference) => preference.key,
    );
    final uploadedPreferences = _lastByKey(
      uploaded.backupPreferences,
      (preference) => preference.key,
    );
    for (final pendingPreference in pending.backupPreferences) {
      final selected = currentPreferences[pendingPreference.key];
      final actual = uploadedPreferences[pendingPreference.key];
      if (selected == null) {
        // The engine preserves legacy/unsupported pending values in effective
        // local intent. Absence here is therefore a proven post-restore delete.
        if (actual != null) return false;
        continue;
      }
      if (actual == null || !_sameKnownWithSelectedUnknown(actual, selected)) {
        return false;
      }
      if (selected.hasValue() &&
          (!_unknownFieldsEndWith(actual.value, selected.value))) {
        return false;
      }
    }

    final currentGroups = _lastByKey(
      localIntent.backupSourcePreferences,
      (group) => group.sourceKey,
    );
    final uploadedGroups = _lastByKey(
      uploaded.backupSourcePreferences,
      (group) => group.sourceKey,
    );
    for (final pendingGroup in pending.backupSourcePreferences) {
      final selectedGroup = currentGroups[pendingGroup.sourceKey];
      final actualGroup = uploadedGroups[pendingGroup.sourceKey];
      if (selectedGroup == null) {
        if (actualGroup != null) {
          final pendingKeys = {
            for (final preference in pendingGroup.prefs) preference.key,
          };
          if (actualGroup.prefs.any(
            (preference) => pendingKeys.contains(preference.key),
          )) {
            return false;
          }
        }
        continue;
      }
      if (actualGroup == null) return false;
      if (!_unknownFieldsEndWith(actualGroup, selectedGroup)) return false;
      final selectedPreferences = _lastByKey(
        selectedGroup.prefs,
        (preference) => preference.key,
      );
      final actualPreferences = _lastByKey(
        actualGroup.prefs,
        (preference) => preference.key,
      );
      for (final pendingPreference in pendingGroup.prefs) {
        final selected = selectedPreferences[pendingPreference.key];
        final actual = actualPreferences[pendingPreference.key];
        if (selected == null) {
          if (actual != null) return false;
          continue;
        }
        if (actual == null ||
            !_sameKnownWithSelectedUnknown(actual, selected)) {
          return false;
        }
        if (selected.hasValue() &&
            !_unknownFieldsEndWith(actual.value, selected.value)) {
          return false;
        }
      }
    }
    return true;
  }

  bool _containsSelectedRows<T extends GeneratedMessage, K>({
    required Iterable<T> uploaded,
    required Iterable<T> selected,
    required K Function(T value) keyOf,
  }) => _containsSelectedMessages(
    actual: uploaded,
    selected: selected,
    keyOf: keyOf,
  );

  bool _containsSelectedMessages<T extends GeneratedMessage, K>({
    required Iterable<T> actual,
    required Iterable<T> selected,
    required K Function(T value) keyOf,
    T Function(T actual, T selected)? normalize,
  }) {
    final actualByKey = _lastByKey(actual, keyOf);
    for (final selectedValue in selected) {
      final actualValue = actualByKey[keyOf(selectedValue)];
      if (actualValue == null) return false;
      final normalized =
          normalize?.call(actualValue.deepCopy(), selectedValue) ?? actualValue;
      if (!_sameKnownWithSelectedUnknown(normalized, selectedValue)) {
        return false;
      }
    }
    return true;
  }

  bool _sameKnownWithSelectedUnknown<T extends GeneratedMessage>(
    T actual,
    T selected,
  ) {
    final actualKnown = actual.deepCopy()..unknownFields.clear();
    final selectedKnown = selected.deepCopy()..unknownFields.clear();
    return _sameBytes(actualKnown, selectedKnown) &&
        _unknownFieldsEndWith(actual, selected);
  }

  bool _containsSelectedNovelCategories(
    Iterable<BackupNovelCategory> uploaded,
    Iterable<BackupNovelCategory> selected,
  ) {
    final remaining = uploaded.toList();
    for (final selectedCategory in selected) {
      final index = remaining.indexWhere(
        (candidate) => _sameNovelCategoryIdentity(candidate, selectedCategory),
      );
      if (index < 0 ||
          !_sameKnownWithSelectedUnknown(remaining[index], selectedCategory)) {
        return false;
      }
      remaining.removeAt(index);
    }
    return true;
  }

  List<BackupNovelCategory> _selectedNovelCategories(
    Iterable<BackupNovelCategory> pending,
    Iterable<BackupNovelCategory> current,
  ) {
    final currentList = current.toList();
    return [
      for (final selected in pending)
        currentList.firstWhere(
          (candidate) => _sameNovelCategoryIdentity(candidate, selected),
          orElse: () => selected,
        ),
    ];
  }

  List<BackupNovelCategory> _overlayNovelCategories({
    required Iterable<BackupNovelCategory> fallback,
    required Iterable<BackupNovelCategory> selected,
  }) {
    final result = [for (final value in fallback) value.deepCopy()];
    for (final selectedValue in selected) {
      final index = result.indexWhere(
        (candidate) => _sameNovelCategoryIdentity(candidate, selectedValue),
      );
      if (index < 0) {
        result.add(selectedValue.deepCopy());
      } else {
        result[index] = _selectedOverFallback(selectedValue, result[index]);
      }
    }
    return result;
  }

  bool _sameNovelCategoryIdentity(
    BackupNovelCategory left,
    BackupNovelCategory right,
  ) =>
      (left.id.isNotEmpty && left.id == right.id) ||
      _normalized(left.name) == _normalized(right.name);

  List<T> _selectedRows<T extends GeneratedMessage, K>({
    required Iterable<T> pending,
    required Iterable<T> current,
    required K Function(T value) keyOf,
  }) {
    final currentByKey = _lastByKey(current, keyOf);
    return [
      for (final pendingValue in pending)
        (currentByKey[keyOf(pendingValue)] ?? pendingValue).deepCopy(),
    ];
  }

  /// Category membership in Chimahon is encoded with [BackupCategory.order].
  /// Reapplying an older selected category can therefore collide with a
  /// cloud-only category even though the ordinary merger had already made its
  /// category orders unique. Keep selected orders where possible, move only
  /// colliding fallback rows, and remap both selected and fallback media by
  /// category name so neither membership silently changes meaning.
  void _canonicalizeCategoryOrdersAndRemapMedia<T extends GeneratedMessage>({
    required List<BackupCategory> categories,
    required Iterable<BackupCategory> selectedCategories,
    required Iterable<BackupCategory> selectedSourceCategories,
    required Iterable<BackupCategory> fallbackSourceCategories,
    required Iterable<T> media,
    required Set<String> selectedMediaKeys,
    required String Function(T value) keyOf,
    required List<Int64> Function(T value) categoryOrdersOf,
  }) {
    final selectedNames = selectedCategories.map(_categoryKey).toSet();
    final selectedIndexes = <int>[];
    final fallbackIndexes = <int>[];
    for (var index = 0; index < categories.length; index++) {
      (selectedNames.contains(_categoryKey(categories[index]))
              ? selectedIndexes
              : fallbackIndexes)
          .add(index);
    }

    final usedOrders = <Int64>{};
    final finalOrderByName = <String, Int64>{};
    var nextFreeOrder = Int64.ZERO;
    for (final index in [...selectedIndexes, ...fallbackIndexes]) {
      final category = categories[index];
      var order = category.order;
      if (!usedOrders.add(order)) {
        while (usedOrders.contains(nextFreeOrder)) {
          nextFreeOrder += 1;
        }
        order = nextFreeOrder;
        category.order = order;
        usedOrders.add(order);
      }
      finalOrderByName[_categoryKey(category)] = order;
    }

    final selectedNameByOrder = {
      for (final category in selectedSourceCategories)
        category.order: _categoryKey(category),
    };
    final fallbackNameByOrder = {
      for (final category in fallbackSourceCategories)
        category.order: _categoryKey(category),
    };
    for (final value in media) {
      final nameByOrder = selectedMediaKeys.contains(keyOf(value))
          ? selectedNameByOrder
          : fallbackNameByOrder;
      final remapped = <Int64>[];
      final seen = <Int64>{};
      for (final oldOrder in categoryOrdersOf(value)) {
        final name = nameByOrder[oldOrder];
        final newOrder = name == null ? null : finalOrderByName[name];
        if (newOrder != null && seen.add(newOrder)) remapped.add(newOrder);
      }
      categoryOrdersOf(value)
        ..clear()
        ..addAll(remapped);
    }
  }

  List<T> _overlaySelected<T extends GeneratedMessage, K>({
    required Iterable<T> fallback,
    required Iterable<T> selected,
    required K Function(T value) keyOf,
    required T Function(T selected, T fallback) overlay,
  }) {
    final result = [for (final value in fallback) value.deepCopy()];
    final indexByKey = <K, int>{
      for (var index = 0; index < result.length; index++)
        keyOf(result[index]): index,
    };
    for (final selectedValue in selected) {
      final key = keyOf(selectedValue);
      final index = indexByKey[key];
      if (index == null) {
        indexByKey[key] = result.length;
        result.add(selectedValue.deepCopy());
      } else {
        result[index] = overlay(selectedValue, result[index]);
      }
    }
    return result;
  }

  Map<K, T> _lastByKey<T extends GeneratedMessage, K>(
    Iterable<T> values,
    K Function(T value) keyOf,
  ) => {for (final value in values) keyOf(value): value};

  T _selectedOverFallback<T extends GeneratedMessage>(T selected, T fallback) {
    final result = selected.deepCopy()..unknownFields.clear();
    result
      ..mergeUnknownFields(fallback.unknownFields)
      ..mergeUnknownFields(selected.unknownFields);
    return result;
  }

  void _putSelectedUnknownFieldsLast(
    GeneratedMessage target,
    GeneratedMessage selected,
  ) {
    final previous = target.unknownFields.clone();
    target.unknownFields
      ..clear()
      ..mergeFromUnknownFieldSet(previous)
      ..mergeFromUnknownFieldSet(selected.unknownFields);
  }

  bool _unknownFieldsEndWith(
    GeneratedMessage actual,
    GeneratedMessage selected,
  ) {
    for (final entry in selected.unknownFields.asMap().entries) {
      final actualField = actual.unknownFields.getField(entry.key);
      if (actualField == null ||
          !_endsWith(actualField.varints, entry.value.varints) ||
          !_endsWith(actualField.fixed32s, entry.value.fixed32s) ||
          !_endsWith(actualField.fixed64s, entry.value.fixed64s) ||
          !_endsWith(actualField.groups, entry.value.groups) ||
          !_byteListsEndWith(
            actualField.lengthDelimited,
            entry.value.lengthDelimited,
          )) {
        return false;
      }
    }
    return true;
  }

  bool _endsWith<T>(List<T> actual, List<T> suffix) {
    if (suffix.length > actual.length) return false;
    final offset = actual.length - suffix.length;
    for (var index = 0; index < suffix.length; index++) {
      if (actual[offset + index] != suffix[index]) return false;
    }
    return true;
  }

  bool _byteListsEndWith(List<List<int>> actual, List<List<int>> suffix) {
    if (suffix.length > actual.length) return false;
    final offset = actual.length - suffix.length;
    for (var index = 0; index < suffix.length; index++) {
      final actualBytes = actual[offset + index];
      final suffixBytes = suffix[index];
      if (actualBytes.length != suffixBytes.length) return false;
      for (var byte = 0; byte < suffixBytes.length; byte++) {
        if (actualBytes[byte] != suffixBytes[byte]) return false;
      }
    }
    return true;
  }

  Int64 _promoteIfNeeded(Int64 selected, Int64 competing) {
    if (selected > competing) return selected;
    if (competing == Int64.MAX_VALUE) {
      throw StateError(
        'Cannot promote a selected Chimahon restore record above Int64.MAX_VALUE.',
      );
    }
    return competing + 1;
  }

  bool _sameBytes(GeneratedMessage left, GeneratedMessage right) {
    final leftBytes = left.writeToBuffer();
    final rightBytes = right.writeToBuffer();
    if (leftBytes.length != rightBytes.length) return false;
    for (var index = 0; index < leftBytes.length; index++) {
      if (leftBytes[index] != rightBytes[index]) return false;
    }
    return true;
  }

  // Chimahon identifies ordered manga/anime categories by their exact names.
  // Names that differ only by case or surrounding whitespace can coexist and
  // must not collapse while a pending restore is reapplied.
  String _categoryKey(BackupCategory category) => category.name;

  String _mangaKey(BackupManga manga) {
    final url = manga.url.trim();
    if (url.isNotEmpty) return '${manga.source}|$url';
    return '${manga.source}||${_normalized(manga.title)}|${_normalized(manga.author)}';
  }

  String _animeKey(BackupAnime anime) =>
      '${anime.source}|${anime.url}|${_normalized(anime.title)}|${_normalized(anime.author)}';

  String _chapterKey(BackupChapter chapter) => chapter.url.isNotEmpty
      ? chapter.url
      : '${chapter.name}|${chapter.chapterNumber}';

  String _episodeKey(BackupEpisode episode) => episode.url.isNotEmpty
      ? episode.url
      : '${episode.name}|${episode.episodeNumber}';

  String _novelKey(BackupNovel novel) {
    final title = _normalized(novel.title);
    final author = _normalized(novel.author);
    if (title.isEmpty && author.isEmpty) return novel.id;
    return md5.convert(utf8.encode('$title|$author')).toString();
  }

  String _normalized(String value) => value.trim().toLowerCase();
}
