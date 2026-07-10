import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupExtensionRepos.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupFeed.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSavedSearch.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';

/// Conflict resolution compatible with Komikku's version-based sync, with
/// lossless handling for Chimahon's novel, statistics, and preference fields.
class ChimahonSyncMerger {
  const ChimahonSyncMerger();

  static const _uncategorizedNovelCategoryId = 'default';

  BackupMihon merge({required BackupMihon local, required BackupMihon remote}) {
    final categories = _mergeCategories(
      local.backupCategories,
      remote.backupCategories,
    );
    final animeCategories = _mergeCategories(
      local.backupAnimeCategories,
      remote.backupAnimeCategories,
    );
    final novelCategories = _mergeNovelCategories(
      local.backupNovelCategories,
      remote.backupNovelCategories,
    );

    final merged = BackupMihon(
      backupManga: _mergeManga(
        local.backupManga,
        remote.backupManga,
        local.backupCategories,
        remote.backupCategories,
        categories,
      ),
      backupCategories: categories,
      backupSources: _mergeByKey<BackupSource, int>(
        local.backupSources,
        remote.backupSources,
        (source) => source.sourceId.toInt(),
      ),
      // Remote wins preference conflicts. This prevents a fresh target device's
      // defaults from erasing Chimahon's filled dictionary/Anki fields.
      backupPreferences: _mergeByKey<BackupPreference, String>(
        local.backupPreferences,
        remote.backupPreferences,
        (preference) => preference.key,
        remoteWins: true,
      ),
      backupSourcePreferences: _mergeSourcePreferences(
        local.backupSourcePreferences,
        remote.backupSourcePreferences,
      ),
      backupExtensionRepo: _mergeByKey<BackupExtensionRepos, String>(
        local.backupExtensionRepo,
        remote.backupExtensionRepo,
        (repo) => repo.baseUrl,
      ),
      backupAnime: _mergeAnime(
        local.backupAnime,
        remote.backupAnime,
        local.backupAnimeCategories,
        remote.backupAnimeCategories,
        animeCategories,
      ),
      backupAnimeCategories: animeCategories,
      backupAnimeSources: _mergeByKey<BackupSource, int>(
        local.backupAnimeSources,
        remote.backupAnimeSources,
        (source) => source.sourceId.toInt(),
      ),
      backupAnimeExtensionRepo: _mergeByKey<BackupExtensionRepos, String>(
        local.backupAnimeExtensionRepo,
        remote.backupAnimeExtensionRepo,
        (repo) => repo.baseUrl,
      ),
      backupSavedSearches: _mergeByKey<BackupSavedSearch, String>(
        local.backupSavedSearches,
        remote.backupSavedSearches,
        (search) => '${search.source}|${_normalized(search.name)}',
      ),
      backupFeeds: _mergeByKey<BackupFeed, String>(
        local.backupFeeds,
        remote.backupFeeds,
        (feed) =>
            '${feed.source}|${feed.global}|${feed.hasSavedSearch() ? feed.savedSearch.name : ''}',
      ),
      backupNovels: _mergeNovels(
        local.backupNovels,
        remote.backupNovels,
        local.backupNovelCategories,
        remote.backupNovelCategories,
        novelCategories,
      ),
      backupNovelCategories: novelCategories,
      backupMangaStats: _mergeMangaStats(
        local.backupMangaStats,
        remote.backupMangaStats,
      ),
      backupAnkiStats: _mergeAnkiStats(
        local.backupAnkiStats,
        remote.backupAnkiStats,
      ),
    );

    // A newer fork can add fields without Mangatan having to understand them.
    // Prefer the remote representation for shared unknown tags, while retaining
    // local-only tags.
    merged.mergeUnknownFields(remote.unknownFields);
    for (final entry in local.unknownFields.asMap().entries) {
      if (!remote.unknownFields.hasField(entry.key)) {
        merged.unknownFields.mergeField(entry.key, entry.value);
      }
    }
    return merged;
  }

  List<BackupManga> _mergeManga(
    Iterable<BackupManga> local,
    Iterable<BackupManga> remote,
    Iterable<BackupCategory> localCategories,
    Iterable<BackupCategory> remoteCategories,
    Iterable<BackupCategory> mergedCategories,
  ) {
    final localByKey = {
      for (final manga in local)
        _mangaKey(manga): _remapMangaCategories(
          manga,
          localCategories,
          mergedCategories,
        ),
    };
    final remoteByKey = {
      for (final manga in remote)
        _mangaKey(manga): _remapMangaCategories(
          manga,
          remoteCategories,
          mergedCategories,
        ),
    };
    return _orderedKeys(localByKey, remoteByKey).map((key) {
      final left = localByKey[key];
      final right = remoteByKey[key];
      if (left == null) return right!.deepCopy();
      if (right == null) return left.deepCopy();
      final latest = _mangaIsNewer(left, right) ? left : right;
      return latest.deepCopy()
        ..chapters.clear()
        ..chapters.addAll(_mergeChapters(left.chapters, right.chapters))
        ..history.clear()
        ..history.addAll(_mergeHistory(left.history, right.history));
    }).toList();
  }

  BackupManga _remapMangaCategories(
    BackupManga manga,
    Iterable<BackupCategory> sourceCategories,
    Iterable<BackupCategory> mergedCategories,
  ) {
    final sourceByOrder = {
      for (final category in sourceCategories) category.order.toInt(): category,
    };
    final mergedByName = {
      for (final category in mergedCategories)
        _normalized(category.name): category,
    };
    final result = manga.deepCopy()..categories.clear();
    result.categories.addAll(
      manga.categories
          .map((order) => sourceByOrder[order.toInt()])
          .nonNulls
          .map((category) => mergedByName[_normalized(category.name)]?.order)
          .nonNulls,
    );
    return result;
  }

  List<BackupChapter> _mergeChapters(
    Iterable<BackupChapter> local,
    Iterable<BackupChapter> remote,
  ) {
    final localList = local.toList();
    final remoteList = remote.toList();
    final localByKey = {for (final item in localList) _chapterKey(item): item};
    final remoteByKey = {
      for (final item in remoteList) _chapterKey(item): item,
    };
    return _orderedKeys(localByKey, remoteByKey).map((key) {
      final left = localByKey[key];
      final right = remoteByKey[key];
      if (left == null) return right!.deepCopy();
      if (right == null) return left.deepCopy();
      final latest =
          _version(left.version, left.lastModifiedAt) >=
              _version(right.version, right.lastModifiedAt)
          ? left.deepCopy()
          : right.deepCopy();
      if (left.version >= right.version &&
          localList.length < remoteList.length) {
        latest.sourceOrder = right.sourceOrder;
      }
      return latest;
    }).toList();
  }

  List<BackupHistory> _mergeHistory(
    Iterable<BackupHistory> local,
    Iterable<BackupHistory> remote,
  ) {
    final localByUrl = {for (final item in local) item.url: item};
    final remoteByUrl = {for (final item in remote) item.url: item};
    return _orderedKeys(localByUrl, remoteByUrl).map((key) {
      final left = localByUrl[key];
      final right = remoteByUrl[key];
      if (left == null) return right!.deepCopy();
      if (right == null) return left.deepCopy();
      return (left.lastRead >= right.lastRead ? left : right).deepCopy();
    }).toList();
  }

  List<BackupAnime> _mergeAnime(
    Iterable<BackupAnime> local,
    Iterable<BackupAnime> remote,
    Iterable<BackupCategory> localCategories,
    Iterable<BackupCategory> remoteCategories,
    Iterable<BackupCategory> mergedCategories,
  ) {
    BackupAnime remap(
      BackupAnime anime,
      Iterable<BackupCategory> sourceCategories,
    ) {
      final sourceByOrder = {
        for (final category in sourceCategories)
          category.order.toInt(): category,
      };
      final mergedByName = {
        for (final category in mergedCategories)
          _normalized(category.name): category,
      };
      final result = anime.deepCopy()..categories.clear();
      result.categories.addAll(
        anime.categories
            .map((order) => sourceByOrder[order.toInt()])
            .nonNulls
            .map((category) => mergedByName[_normalized(category.name)]?.order)
            .nonNulls,
      );
      return result;
    }

    final localByKey = {
      for (final anime in local)
        _animeKey(anime): remap(anime, localCategories),
    };
    final remoteByKey = {
      for (final anime in remote)
        _animeKey(anime): remap(anime, remoteCategories),
    };
    return _orderedKeys(localByKey, remoteByKey).map((key) {
      final left = localByKey[key];
      final right = remoteByKey[key];
      if (left == null) return right!.deepCopy();
      if (right == null) return left.deepCopy();
      final latest =
          _version(left.version, left.lastModifiedAt) >=
              _version(right.version, right.lastModifiedAt)
          ? left
          : right;
      return latest.deepCopy()
        ..episodes.clear()
        ..episodes.addAll(_mergeEpisodes(left.episodes, right.episodes))
        ..history.clear()
        ..history.addAll(_mergeHistory(left.history, right.history));
    }).toList();
  }

  List<BackupEpisode> _mergeEpisodes(
    Iterable<BackupEpisode> local,
    Iterable<BackupEpisode> remote,
  ) {
    final localByKey = {for (final item in local) _episodeKey(item): item};
    final remoteByKey = {for (final item in remote) _episodeKey(item): item};
    return _orderedKeys(localByKey, remoteByKey).map((key) {
      final left = localByKey[key];
      final right = remoteByKey[key];
      if (left == null) return right!.deepCopy();
      if (right == null) return left.deepCopy();
      return (_version(left.version, left.lastModifiedAt) >=
                  _version(right.version, right.lastModifiedAt)
              ? left
              : right)
          .deepCopy();
    }).toList();
  }

  List<BackupCategory> _mergeCategories(
    Iterable<BackupCategory> local,
    Iterable<BackupCategory> remote,
  ) {
    final result = <String, BackupCategory>{};
    for (final category in [...local, ...remote]) {
      final key = _normalized(category.name);
      final existing = result[key];
      if (existing == null || category.order > existing.order) {
        result[key] = category.deepCopy();
      }
    }
    return result.values.toList();
  }

  List<BackupSourcePreferences> _mergeSourcePreferences(
    Iterable<BackupSourcePreferences> local,
    Iterable<BackupSourcePreferences> remote,
  ) {
    final localByKey = {for (final item in local) item.sourceKey: item};
    final remoteByKey = {for (final item in remote) item.sourceKey: item};
    return _orderedKeys(localByKey, remoteByKey).map((key) {
      final left = localByKey[key];
      final right = remoteByKey[key];
      if (left == null) return right!.deepCopy();
      if (right == null) return left.deepCopy();
      return BackupSourcePreferences(
        sourceKey: key,
        prefs: _mergeByKey<BackupPreference, String>(
          left.prefs,
          right.prefs,
          (preference) => preference.key,
          remoteWins: true,
        ),
      );
    }).toList();
  }

  List<BackupNovelCategory> _mergeNovelCategories(
    Iterable<BackupNovelCategory> local,
    Iterable<BackupNovelCategory> remote,
  ) {
    final result = <String, BackupNovelCategory>{};
    for (final category in [...local, ...remote]) {
      final matchingKey = result.entries
          .where(
            (entry) =>
                entry.value.id == category.id ||
                _normalized(entry.value.name) == _normalized(category.name),
          )
          .map((entry) => entry.key)
          .firstOrNull;
      final key = matchingKey ?? category.id;
      final existing = result[key];
      if (existing == null || category.order > existing.order) {
        result[key] = category.deepCopy();
      }
    }
    return result.values.toList();
  }

  List<BackupNovel> _mergeNovels(
    Iterable<BackupNovel> local,
    Iterable<BackupNovel> remote,
    Iterable<BackupNovelCategory> localCategories,
    Iterable<BackupNovelCategory> remoteCategories,
    Iterable<BackupNovelCategory> mergedCategories,
  ) {
    final localByKey = _canonicalNovels(
      local,
      localCategories,
      mergedCategories,
    );
    final remoteByKey = _canonicalNovels(
      remote,
      remoteCategories,
      mergedCategories,
    );
    return _orderedKeys(localByKey, remoteByKey).map((key) {
      final left = localByKey[key];
      final right = remoteByKey[key];
      if (left == null) return right!.deepCopy();
      if (right == null) return left.deepCopy();
      final latest = left.lastModified >= right.lastModified ? left : right;
      return latest.deepCopy()
        ..id = key
        ..categoryIds.clear()
        ..categoryIds.addAll(
          _normalizeNovelCategoryIds([
            ...left.categoryIds,
            ...right.categoryIds,
          ]),
        )
        ..stats.clear()
        ..stats.addAll(_mergeNovelStats(left.stats, right.stats));
    }).toList();
  }

  Map<String, BackupNovel> _canonicalNovels(
    Iterable<BackupNovel> novels,
    Iterable<BackupNovelCategory> sourceCategories,
    Iterable<BackupNovelCategory> mergedCategories,
  ) {
    final sourceById = {
      for (final category in sourceCategories) category.id: category,
    };
    final mergedById = {
      for (final category in mergedCategories) category.id: category,
    };
    final mergedByName = {
      for (final category in mergedCategories)
        _normalized(category.name): category,
    };
    final result = <String, BackupNovel>{};
    for (final novel in novels) {
      final stableId = _stableNovelId(novel);
      final remapped = novel.deepCopy()
        ..id = stableId
        ..categoryIds.clear();
      remapped.categoryIds.addAll(
        _normalizeNovelCategoryIds(
          novel.categoryIds.map((id) {
            if (id == _uncategorizedNovelCategoryId) return id;
            final source = sourceById[id];
            return source == null
                ? mergedById[id]?.id ?? id
                : mergedByName[_normalized(source.name)]?.id ??
                      mergedById[id]?.id ??
                      id;
          }).nonNulls,
        ),
      );
      final existing = result[stableId];
      result[stableId] = existing == null
          ? remapped
          : _mergeDuplicateNovel(existing, remapped);
    }
    return result;
  }

  BackupNovel _mergeDuplicateNovel(BackupNovel first, BackupNovel second) {
    final latest = first.lastModified >= second.lastModified ? first : second;
    return latest.deepCopy()
      ..categoryIds.clear()
      ..categoryIds.addAll(
        _normalizeNovelCategoryIds([
          ...first.categoryIds,
          ...second.categoryIds,
        ]),
      )
      ..stats.clear()
      ..stats.addAll(_mergeNovelStats(first.stats, second.stats));
  }

  List<BackupNovelStat> _mergeNovelStats(
    Iterable<BackupNovelStat> local,
    Iterable<BackupNovelStat> remote,
  ) {
    final localByDate = {for (final item in local) item.dateKey: item};
    final remoteByDate = {for (final item in remote) item.dateKey: item};
    return _orderedKeys(localByDate, remoteByDate).map((date) {
      final left = localByDate[date];
      final right = remoteByDate[date];
      if (left == null) return right!.deepCopy();
      if (right == null) return left.deepCopy();
      return (left.lastStatisticModified >= right.lastStatisticModified
              ? left
              : right)
          .deepCopy();
    }).toList();
  }

  List<BackupMangaStats> _mergeMangaStats(
    Iterable<BackupMangaStats> local,
    Iterable<BackupMangaStats> remote,
  ) {
    final result = <String, BackupMangaStats>{};
    for (final stat in [...local, ...remote]) {
      final key = '${stat.dateKey}|${stat.mangaId}';
      final existing = result[key];
      if (existing == null) {
        result[key] = stat.deepCopy();
      } else {
        existing
          ..charactersRead = _max(existing.charactersRead, stat.charactersRead)
          ..readingTime = Int64(
            _max(existing.readingTime.toInt(), stat.readingTime.toInt()),
          );
      }
    }
    return result.values.toList();
  }

  List<BackupAnkiStats> _mergeAnkiStats(
    Iterable<BackupAnkiStats> local,
    Iterable<BackupAnkiStats> remote,
  ) {
    final result = <String, BackupAnkiStats>{};
    for (final stat in [...local, ...remote]) {
      final key = '${stat.dateKey}|${stat.profileId}|${stat.titleId}';
      final existing = result[key];
      if (existing == null) {
        result[key] = stat.deepCopy();
      } else {
        existing
          ..mangaCards = _max(existing.mangaCards, stat.mangaCards)
          ..novelCards = _max(existing.novelCards, stat.novelCards);
      }
    }
    return result.values.toList();
  }

  List<T> _mergeByKey<T, K>(
    Iterable<T> local,
    Iterable<T> remote,
    K Function(T value) keyOf, {
    bool remoteWins = false,
  }) {
    final values = <K, T>{};
    for (final value in local) {
      values[keyOf(value)] = value;
    }
    for (final value in remote) {
      final key = keyOf(value);
      if (remoteWins || !values.containsKey(key)) values[key] = value;
    }
    return values.values.toList();
  }

  Iterable<K> _orderedKeys<K, T>(Map<K, T> first, Map<K, T> second) sync* {
    final seen = <K>{};
    for (final key in [...first.keys, ...second.keys]) {
      if (seen.add(key)) yield key;
    }
  }

  bool _mangaIsNewer(BackupManga left, BackupManga right) =>
      _version(left.version, left.lastModifiedAt) >=
      _version(right.version, right.lastModifiedAt);

  int _version(Int64 version, Int64 modified) =>
      version != Int64.ZERO ? version.toInt() : modified.toInt();

  String _mangaKey(BackupManga manga) =>
      '${manga.source}|${manga.url}|${_normalized(manga.title)}|${_normalized(manga.author)}';

  String _animeKey(BackupAnime anime) =>
      '${anime.source}|${anime.url}|${_normalized(anime.title)}|${_normalized(anime.author)}';

  String _chapterKey(BackupChapter chapter) =>
      '${chapter.url}|${chapter.name}|${chapter.chapterNumber}';

  String _episodeKey(BackupEpisode episode) =>
      '${episode.url}|${episode.name}|${episode.episodeNumber}';

  String _stableNovelId(BackupNovel novel) {
    final title = _normalized(novel.title);
    final author = _normalized(novel.author);
    if (title.isEmpty && author.isEmpty) return novel.id;
    return md5.convert(utf8.encode('$title|$author')).toString();
  }

  List<String> _normalizeNovelCategoryIds(Iterable<String> ids) {
    final values = ids.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (values.any((id) => id != _uncategorizedNovelCategoryId)) {
      values.remove(_uncategorizedNovelCategoryId);
    }
    return values;
  }

  String _normalized(String value) => value.trim().toLowerCase();

  int _max(int first, int second) => first >= second ? first : second;
}
