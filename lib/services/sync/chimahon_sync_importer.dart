import 'package:fixnum/fixnum.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';
import 'package:mangayomi/services/sync/chimahon_manga_title_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_local_chapter_policy.dart';
import 'package:mangayomi/services/sync/chimahon_novel_category_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_novel_materializer.dart';
import 'package:mangayomi/services/sync/chimahon_tracking_adapter.dart';
import 'package:mangayomi/services/sync/mihon_backup_source_resolver.dart';

/// Summary of changes made by [ChimahonSyncImporter].
class ChimahonSyncImportResult {
  const ChimahonSyncImportResult({
    required this.titlesCreated,
    required this.titlesUpdated,
    required this.chaptersCreated,
    required this.chaptersUpdated,
    required this.novelsUpdated,
  });

  final int titlesCreated;
  final int titlesUpdated;
  final int chaptersCreated;
  final int chaptersUpdated;
  final int novelsUpdated;
}

/// Applies a merged Chimahon payload without treating it as a full restore.
///
/// Chimahon's own sync flow restores only changed library entries and toggles
/// matching non-favorites in place. Mirroring that behavior is important here:
/// a normal sync must not clear Mangatan's source cache, downloads, update feed,
/// tracker state, manually added chapters, or local archive/novel library data.
/// Remote manga and chapters are therefore upserted by portable source identity
/// and URL, while absence from the payload never means deletion.
class ChimahonSyncImporter {
  const ChimahonSyncImporter();

  ChimahonSyncImportResult apply({
    required Isar database,
    required BackupMihon backup,
  }) {
    final localSources = database.sources.where().findAllSync();
    final localMangas = database.mangas.where().findAllSync();
    final localChapters = database.chapters.where().findAllSync();
    final localHistories = database.historys.where().findAllSync();
    final localTracks = database.tracks.where().findAllSync();
    final localCategories = database.categorys.where().findAllSync();
    final localNovelProgress = database.epubBookProgress.where().findAllSync();
    const novelMaterializer = ChimahonNovelMaterializer();
    final staleCloudNovelParentIds = novelMaterializer.staleCloudNovelParentIds(
      localMangas: localMangas,
      localProgress: localNovelProgress,
      localChapters: localChapters,
      remote: backup.backupNovels,
    );
    final activeLocalMangas = localMangas
        .where((manga) => !staleCloudNovelParentIds.contains(manga.id))
        .toList();
    final activeLocalNovelProgress = localNovelProgress
        .where(
          (progress) => !staleCloudNovelParentIds.contains(progress.mangaId),
        )
        .toList();
    final remoteMangaSourceUrlCounts = _sourceUrlCounts(
      backup.backupManga.map(
        (manga) => (source: manga.source.toInt(), url: manga.url),
      ),
    );
    final remoteAnimeSourceUrlCounts = _sourceUrlCounts(
      backup.backupAnime.map(
        (anime) => (source: anime.source.toInt(), url: anime.url),
      ),
    );
    final localArchiveParentIds = localMangas
        .where((manga) => manga.isLocalArchive == true)
        .map((manga) => manga.id)
        .nonNulls
        .toSet();
    final localOverlayParentIds = localChapters
        .where(
          (chapter) =>
              !localArchiveParentIds.contains(chapter.mangaId) &&
              const ChimahonLocalChapterPolicy().isDeviceLocal(chapter),
        )
        .map((chapter) => chapter.mangaId)
        .nonNulls
        .toSet();
    final novelPlan = novelMaterializer.plan(
      localMangas: activeLocalMangas,
      localProgress: activeLocalNovelProgress,
      localChapters: localChapters,
      remote: backup.backupNovels,
    );

    var titlesCreated = 0;
    var titlesUpdated = 0;
    var chaptersCreated = 0;
    var chaptersUpdated = 0;

    database.writeTxnSync(() {
      for (final progress in localNovelProgress.where(
        (progress) =>
            staleCloudNovelParentIds.contains(progress.mangaId) &&
            novelMaterializer.isCloudOnlyProgress(progress),
      )) {
        if (progress.id != null) {
          database.epubBookProgress.deleteSync(progress.id!);
        }
      }
      for (final mangaId in staleCloudNovelParentIds) {
        database.mangas.deleteSync(mangaId);
      }
      localMangas.removeWhere(
        (manga) => staleCloudNovelParentIds.contains(manga.id),
      );
      // Migrate and continuously reconcile the local-overlay visibility bit.
      // It is not part of the Chimahon wire model and therefore cannot turn a
      // remote unfavorite tombstone back into a portable favorite.
      for (final manga in localMangas) {
        final hasOverlay = localOverlayParentIds.contains(manga.id);
        if ((manga.hasLocalChapterOverlay ?? false) == hasOverlay) continue;
        manga.hasLocalChapterOverlay = hasOverlay;
        database.mangas.putSync(manga);
      }
      final mangaCategories = _upsertCategories(
        database: database,
        localCategories: localCategories,
        remoteCategories: backup.backupCategories,
        itemType: ItemType.manga,
      );
      final animeCategories = _upsertCategories(
        database: database,
        localCategories: localCategories,
        remoteCategories: backup.backupAnimeCategories,
        itemType: ItemType.anime,
      );
      final novelCategories = _upsertNovelCategories(
        database: database,
        localCategories: localCategories,
        remoteCategories: backup.backupNovelCategories,
      );

      for (final cloudNovel in novelPlan.cloudNovels) {
        cloudNovel.parent.categories = cloudNovel.remote.categoryIds
            .map((id) => novelCategories[id])
            .nonNulls
            .toSet()
            .toList();
        database.mangas.putSync(cloudNovel.parent);
        localMangas.add(cloudNovel.parent);
        cloudNovel.progress.mangaId = cloudNovel.parent.id!;
        database.epubBookProgress.putSync(cloudNovel.progress);
        titlesCreated++;
      }
      if (novelPlan.updatedCloudParents.isNotEmpty) {
        database.mangas.putAllSync(novelPlan.updatedCloudParents);
      }

      for (final remote in backup.backupManga) {
        final resolvedSource = resolveMihonBackupSource(
          nativeId: remote.source.toInt(),
          backupSources: backup.backupSources,
          localSources: localSources,
        );
        var local = _findLocalTitle(
          localMangas: localMangas,
          itemType: ItemType.manga,
          resolvedSource: resolvedSource,
          url: remote.url,
          sourceTitle: remote.title,
          author: remote.hasAuthor() ? remote.author : null,
          allowSourceUrlFallback:
              remoteMangaSourceUrlCounts[_sourceUrlKey(
                remote.source.toInt(),
                remote.url,
              )] ==
              1,
        );
        final isFavorite = remote.hasFavorite() ? remote.favorite : true;
        if (!isFavorite) {
          if (local != null) {
            local.favorite = false;
            _applyFavoriteVersion(local, remote);
            database.mangas.putSync(local);
            _upsertTracking(
              database: database,
              manga: local,
              remoteTracking: remote.tracking,
              parentModifiedAt: remote.lastModifiedAt,
              localTracks: localTracks,
            );
            titlesUpdated++;
          }
          continue;
        }

        if (local == null) {
          local = _newManga(remote, resolvedSource, mangaCategories);
          database.mangas.putSync(local);
          localMangas.add(local);
          titlesCreated++;
        } else {
          _applyManga(
            local,
            remote,
            resolvedSource,
            mangaCategories,
            categoriesAreAuthoritative: backup.backupCategories.isNotEmpty,
          );
          database.mangas.putSync(local);
          titlesUpdated++;
        }
        final chapterChanges = _upsertMangaChapters(
          database: database,
          manga: local,
          remoteChapters: remote.chapters,
          localChapters: localChapters,
        );
        chaptersCreated += chapterChanges.$1;
        chaptersUpdated += chapterChanges.$2;
        _upsertHistory(
          database: database,
          manga: local,
          remoteHistory: remote.history,
          localChapters: localChapters,
          localHistories: localHistories,
        );
        _upsertTracking(
          database: database,
          manga: local,
          remoteTracking: remote.tracking,
          parentModifiedAt: remote.lastModifiedAt,
          localTracks: localTracks,
        );
      }

      for (final remote in backup.backupAnime) {
        final resolvedSource = resolveMihonBackupSource(
          nativeId: remote.source.toInt(),
          backupSources: backup.backupAnimeSources,
          localSources: localSources,
        );
        var local = _findLocalTitle(
          localMangas: localMangas,
          itemType: ItemType.anime,
          resolvedSource: resolvedSource,
          url: remote.url,
          sourceTitle: remote.title,
          author: remote.hasAuthor() ? remote.author : null,
          allowSourceUrlFallback:
              remoteAnimeSourceUrlCounts[_sourceUrlKey(
                remote.source.toInt(),
                remote.url,
              )] ==
              1,
        );
        final isFavorite = remote.hasFavorite() ? remote.favorite : true;
        if (!isFavorite) {
          if (local != null) {
            local.favorite = false;
            _applyAnimeFavoriteVersion(local, remote);
            database.mangas.putSync(local);
            _upsertTracking(
              database: database,
              manga: local,
              remoteTracking: remote.tracking,
              parentModifiedAt: remote.lastModifiedAt,
              localTracks: localTracks,
            );
            titlesUpdated++;
          }
          continue;
        }

        if (local == null) {
          local = _newAnime(remote, resolvedSource, animeCategories);
          database.mangas.putSync(local);
          localMangas.add(local);
          titlesCreated++;
        } else {
          _applyAnime(
            local,
            remote,
            resolvedSource,
            animeCategories,
            categoriesAreAuthoritative: backup.backupAnimeCategories.isNotEmpty,
          );
          database.mangas.putSync(local);
          titlesUpdated++;
        }
        final chapterChanges = _upsertAnimeEpisodes(
          database: database,
          anime: local,
          remoteEpisodes: remote.episodes,
          localChapters: localChapters,
        );
        chaptersCreated += chapterChanges.$1;
        chaptersUpdated += chapterChanges.$2;
        _upsertHistory(
          database: database,
          manga: local,
          remoteHistory: remote.history,
          localChapters: localChapters,
          localHistories: localHistories,
        );
        _upsertTracking(
          database: database,
          manga: local,
          remoteTracking: remote.tracking,
          parentModifiedAt: remote.lastModifiedAt,
          localTracks: localTracks,
        );
      }

      for (final entry in novelPlan.remoteCategoryIdsByMangaId.entries) {
        final local = localMangas
            .where(
              (manga) =>
                  manga.id == entry.key && manga.itemType == ItemType.novel,
            )
            .firstOrNull;
        if (local == null) continue;
        final remoteCategoryIds = entry.value
            .map((id) => novelCategories[id])
            .nonNulls
            .toSet();
        // A still-empty synthetic parent is remote cache. Replace its
        // categories exactly so an earlier Drive account cannot bleed into
        // the current one. Real EPUB parents retain their local memberships.
        final isAuthoritativeCloudParent = novelPlan.authoritativeCloudParentIds
            .contains(entry.key);
        if (!isAuthoritativeCloudParent && remoteCategoryIds.isEmpty) continue;
        final mergedCategoryIds = isAuthoritativeCloudParent
            ? remoteCategoryIds.toList()
            : _unionIds(local.categories, remoteCategoryIds);
        if (_sameIds(local.categories, mergedCategoryIds)) continue;
        local.categories = mergedCategoryIds;
        database.mangas.putSync(local);
      }

      if (novelPlan.updatedProgress.isNotEmpty) {
        database.epubBookProgress.putAllSync(novelPlan.updatedProgress);
      }
    });

    return ChimahonSyncImportResult(
      titlesCreated: titlesCreated,
      titlesUpdated: titlesUpdated,
      chaptersCreated: chaptersCreated,
      chaptersUpdated: chaptersUpdated,
      novelsUpdated: novelPlan.novelsUpdated,
    );
  }

  Map<int, int> _upsertCategories({
    required Isar database,
    required List<Category> localCategories,
    required Iterable<BackupCategory> remoteCategories,
    required ItemType itemType,
  }) {
    final localByName = <String, Category>{
      for (final category in localCategories.where(
        (category) => category.forItemType == itemType,
      ))
        _normalized(category.name): category,
    };
    final result = <int, int>{};
    for (final remote in remoteCategories) {
      final order = remote.order.toInt();
      final key = _normalized(remote.name);
      var local = localByName[key];
      if (local == null) {
        local = Category(
          name: remote.name,
          forItemType: itemType,
          pos: order,
          hide: remote.hidden,
        );
        database.categorys.putSync(local);
        localCategories.add(local);
        localByName[key] = local;
      } else if (local.pos != order || local.hide != remote.hidden) {
        // Keep Mangatan-only state and the stable local ID. Order and hidden
        // are the two category fields shared with Chimahon.
        local
          ..pos = order
          ..hide = remote.hidden;
        database.categorys.putSync(local);
      }
      if (local.id != null) result[order] = local.id!;
    }
    return result;
  }

  Map<String, int> _upsertNovelCategories({
    required Isar database,
    required List<Category> localCategories,
    required Iterable<BackupNovelCategory> remoteCategories,
  }) {
    const adapter = ChimahonNovelCategoryAdapter();
    final localByName = <String, Category>{
      for (final category in localCategories.where(
        (category) => category.forItemType == ItemType.novel,
      ))
        adapter.normalizeName(category.name): category,
    };
    final result = <String, int>{};
    for (final local in localByName.values) {
      final localId = local.id;
      if (localId == null || adapter.normalizeName(local.name).isEmpty) {
        continue;
      }
      result[adapter.stableId(local.name)] = localId;
    }

    for (final remote in remoteCategories) {
      if (remote.id == ChimahonNovelCategoryAdapter.uncategorizedId) {
        continue;
      }
      final key = adapter.normalizeName(remote.name);
      if (key.isEmpty) continue;
      final order = remote.order.toInt();
      var local = localByName[key];
      if (local == null) {
        local = Category(
          name: remote.name,
          forItemType: ItemType.novel,
          pos: order,
        );
        database.categorys.putSync(local);
        localCategories.add(local);
        localByName[key] = local;
      } else if (local.pos != order) {
        // Chimahon's flags encode library-view state which has no safe
        // equivalent in Mangatan. Keep Mangatan-only category state and apply
        // only the shared ordering field.
        local.pos = order;
        database.categorys.putSync(local);
      }
      final localId = local.id;
      if (localId != null) {
        result[remote.id] = localId;
        result[adapter.stableId(remote.name)] = localId;
      }
    }
    return result;
  }

  Manga? _findLocalTitle({
    required Iterable<Manga> localMangas,
    required ItemType itemType,
    required ResolvedMihonBackupSource resolvedSource,
    required String url,
    required String sourceTitle,
    required String? author,
    required bool allowSourceUrlFallback,
  }) {
    final candidates = localMangas.where(
      (manga) => manga.itemType == itemType && !(manga.isLocalArchive ?? false),
    );
    bool sourceMatches(Manga manga) {
      if (resolvedSource.localId != null) {
        return manga.sourceId == resolvedSource.localId ||
            (manga.sourceId == null && manga.source == resolvedSource.name);
      }
      return manga.source == resolvedSource.name;
    }

    if (url.isNotEmpty) {
      final matchingUrl = candidates
          .where((manga) => manga.link == url && sourceMatches(manga))
          .toList(growable: false);
      for (final manga in matchingUrl) {
        if (_normalized(manga.sourceTitle ?? manga.name) ==
                _normalized(sourceTitle) &&
            _normalized(manga.author) == _normalized(author)) {
          return manga;
        }
      }
      if (allowSourceUrlFallback && matchingUrl.length == 1) {
        return matchingUrl.single;
      }
      // A source can expose more than one entry with the same title. Falling
      // back to the title after a portable URL miss can therefore apply an
      // older entry's tombstone or progress to a different current entry.
      return null;
    }
    for (final manga in candidates) {
      if (sourceMatches(manga) &&
          (manga.sourceTitle == sourceTitle || manga.name == sourceTitle) &&
          _normalized(manga.author) == _normalized(author)) {
        return manga;
      }
    }
    return null;
  }

  Manga _newManga(
    BackupManga remote,
    ResolvedMihonBackupSource source,
    Map<int, int> categories,
  ) {
    final titles = const ChimahonMangaTitleAdapter().fromBackup(remote);
    final manga = Manga(
      source: source.name,
      sourceId: source.localId,
      author: remote.hasAuthor() ? remote.author : null,
      artist: remote.hasArtist() ? remote.artist : null,
      genre: remote.genre.toList(),
      imageUrl: remote.hasThumbnailUrl() ? remote.thumbnailUrl : null,
      lang: source.language,
      link: remote.url,
      name: titles.displayTitle,
      sourceTitle: titles.sourceTitle,
      status: _status(remote.status),
      description: remote.hasDescription() ? remote.description : null,
      categories: _categoryIds(remote.categories, categories),
      itemType: ItemType.manga,
      favorite: true,
      dateAdded: normalizeMihonTimestamp(remote.dateAdded.toInt()),
      lastUpdate: normalizeMihonTimestamp(remote.lastModifiedAt.toInt()),
      updatedAt: normalizeMihonTimestamp(remote.lastModifiedAt.toInt()),
    );
    _applyFavoriteVersion(manga, remote);
    return manga;
  }

  void _applyManga(
    Manga local,
    BackupManga remote,
    ResolvedMihonBackupSource source,
    Map<int, int> categories, {
    required bool categoriesAreAuthoritative,
  }) {
    final titles = const ChimahonMangaTitleAdapter().fromBackup(remote);
    final remoteCategoryIds = _categoryIds(remote.categories, categories);
    final localHasCustomTitle =
        local.name != null &&
        local.sourceTitle != null &&
        local.name != local.sourceTitle;
    final preserveLocalCategories =
        remoteCategoryIds.isEmpty ||
        !categoriesAreAuthoritative ||
        local.sourceId == null;
    local
      ..source = source.name
      ..sourceId = source.localId ?? local.sourceId
      ..lang = source.installed ? source.language : local.lang
      ..link = remote.url
      ..sourceTitle = titles.sourceTitle
      ..name = remote.hasCustomTitle() || !localHasCustomTitle
          ? titles.displayTitle
          : local.name
      ..genre = remote.genre.toList()
      ..status = _status(remote.status)
      ..categories = preserveLocalCategories
          ? _unionIds(local.categories, remoteCategoryIds)
          : remoteCategoryIds
      ..favorite = true;
    if (remote.hasAuthor()) local.author = remote.author;
    if (remote.hasArtist()) local.artist = remote.artist;
    if (remote.hasDescription()) local.description = remote.description;
    if (remote.hasThumbnailUrl()) local.imageUrl = remote.thumbnailUrl;
    if (remote.hasDateAdded()) {
      local.dateAdded = normalizeMihonTimestamp(remote.dateAdded.toInt());
    }
    if (remote.hasLastModifiedAt()) {
      final modified = normalizeMihonTimestamp(remote.lastModifiedAt.toInt());
      local
        ..lastUpdate = modified
        ..updatedAt = modified;
    }
    _applyFavoriteVersion(local, remote);
  }

  Manga _newAnime(
    BackupAnime remote,
    ResolvedMihonBackupSource source,
    Map<int, int> categories,
  ) {
    final anime = Manga(
      source: source.name,
      sourceId: source.localId,
      author: remote.hasAuthor() ? remote.author : null,
      artist: remote.hasArtist() ? remote.artist : null,
      genre: remote.genre.toList(),
      imageUrl: remote.hasThumbnailUrl() ? remote.thumbnailUrl : null,
      lang: source.language,
      link: remote.url,
      name: remote.title,
      sourceTitle: remote.title,
      status: _status(remote.status),
      description: remote.hasDescription() ? remote.description : null,
      categories: _categoryIds(remote.categories, categories),
      itemType: ItemType.anime,
      favorite: true,
      dateAdded: normalizeMihonTimestamp(remote.dateAdded.toInt()),
      lastUpdate: normalizeMihonTimestamp(remote.lastModifiedAt.toInt()),
      updatedAt: normalizeMihonTimestamp(remote.lastModifiedAt.toInt()),
    );
    _applyAnimeFavoriteVersion(anime, remote);
    return anime;
  }

  void _applyAnime(
    Manga local,
    BackupAnime remote,
    ResolvedMihonBackupSource source,
    Map<int, int> categories, {
    required bool categoriesAreAuthoritative,
  }) {
    final remoteCategoryIds = _categoryIds(remote.categories, categories);
    final preserveLocalCategories =
        remoteCategoryIds.isEmpty ||
        !categoriesAreAuthoritative ||
        local.sourceId == null;
    local
      ..source = source.name
      ..sourceId = source.localId ?? local.sourceId
      ..lang = source.installed ? source.language : local.lang
      ..link = remote.url
      ..sourceTitle = remote.title
      ..name = remote.title
      ..genre = remote.genre.toList()
      ..status = _status(remote.status)
      ..categories = preserveLocalCategories
          ? _unionIds(local.categories, remoteCategoryIds)
          : remoteCategoryIds
      ..favorite = true;
    if (remote.hasAuthor()) local.author = remote.author;
    if (remote.hasArtist()) local.artist = remote.artist;
    if (remote.hasDescription()) local.description = remote.description;
    if (remote.hasThumbnailUrl()) local.imageUrl = remote.thumbnailUrl;
    if (remote.hasDateAdded()) {
      local.dateAdded = normalizeMihonTimestamp(remote.dateAdded.toInt());
    }
    if (remote.hasLastModifiedAt()) {
      final modified = normalizeMihonTimestamp(remote.lastModifiedAt.toInt());
      local
        ..lastUpdate = modified
        ..updatedAt = modified;
    }
    _applyAnimeFavoriteVersion(local, remote);
  }

  (int, int) _upsertMangaChapters({
    required Isar database,
    required Manga manga,
    required Iterable<BackupChapter> remoteChapters,
    required List<Chapter> localChapters,
  }) {
    var created = 0;
    var updated = 0;
    final portableLocal = localChapters
        .where(
          (chapter) =>
              chapter.mangaId == manga.id &&
              const ChimahonLocalChapterPolicy().hasPortableIdentity(chapter),
        )
        .toList(growable: false);
    final localByKey = <String, Chapter>{
      for (final chapter in portableLocal) _localChapterKey(chapter): chapter,
    };
    final localByUrl = <String, List<Chapter>>{};
    for (final chapter in portableLocal) {
      localByUrl.putIfAbsent(chapter.url!, () => <Chapter>[]).add(chapter);
    }
    final remoteList = remoteChapters.toList(growable: false);
    final remoteUrlCounts = <String, int>{};
    for (final remote in remoteList) {
      remoteUrlCounts[remote.url] = (remoteUrlCounts[remote.url] ?? 0) + 1;
    }
    for (final remote in remoteList) {
      // A machine-local path from another device is neither readable here nor
      // a safe Chimahon identity. Ignore malformed/nonportable rows instead of
      // overwriting (or duplicating) Mangatan's retained local overlay.
      if (!const ChimahonLocalChapterPolicy().hasPortableWireIdentity(
        url: remote.hasUrl() ? remote.url : null,
        name: remote.hasName() ? remote.name : null,
        chapterNumber: remote.chapterNumber,
      )) {
        continue;
      }
      final remoteKey = _remoteChapterKey(remote);
      var local = localByKey[remoteKey];
      final sameUrl = localByUrl[remote.url];
      if (local == null &&
          remoteUrlCounts[remote.url] == 1 &&
          sameUrl?.length == 1) {
        // Mangatan source refreshes can rename or renumber a portable chapter.
        // Fall back by URL only when both sides prove it is unambiguous.
        local = sameUrl!.single;
      }
      if (local == null) {
        local = Chapter(
          mangaId: manga.id,
          name: remote.name,
          url: remote.url,
          dateUpload: '${normalizeMihonTimestamp(remote.dateUpload.toInt())}',
          scanlator: remote.hasScanlator() ? remote.scanlator : '',
          chapterNumber: remote.chapterNumber,
          isBookmarked: remote.bookmark,
          isRead: remote.read,
          lastPageRead: _progressString(remote.lastPageRead.toInt()),
          updatedAt: normalizeMihonTimestamp(remote.lastModifiedAt.toInt()),
        )..manga.value = manga;
        database.chapters.putSync(local);
        local.manga.saveSync();
        localChapters.add(local);
        localByUrl.putIfAbsent(remote.url, () => <Chapter>[]).add(local);
        created++;
      } else {
        // Preserve archive paths and Mangatan-only source metadata. Keeping the
        // same row ID also keeps Download and Update links intact.
        local
          ..name = remote.name
          ..dateUpload = '${normalizeMihonTimestamp(remote.dateUpload.toInt())}'
          ..scanlator = remote.hasScanlator()
              ? remote.scanlator
              : local.scanlator
          ..chapterNumber = remote.chapterNumber
          ..isBookmarked = remote.bookmark
          ..isRead = remote.read
          ..lastPageRead = _progressString(remote.lastPageRead.toInt())
          ..updatedAt = normalizeMihonTimestamp(remote.lastModifiedAt.toInt());
        database.chapters.putSync(local);
        updated++;
      }
      localByKey.removeWhere((_, candidate) => candidate.id == local!.id);
      localByKey[remoteKey] = local;
    }
    return (created, updated);
  }

  (int, int) _upsertAnimeEpisodes({
    required Isar database,
    required Manga anime,
    required Iterable<BackupEpisode> remoteEpisodes,
    required List<Chapter> localChapters,
  }) {
    var created = 0;
    var updated = 0;
    final portableLocal = localChapters
        .where(
          (episode) =>
              episode.mangaId == anime.id &&
              const ChimahonLocalChapterPolicy().hasPortableIdentity(episode),
        )
        .toList(growable: false);
    final localByKey = <String, Chapter>{
      for (final episode in portableLocal) _localEpisodeKey(episode): episode,
    };
    final localByUrl = <String, List<Chapter>>{};
    for (final episode in portableLocal) {
      localByUrl.putIfAbsent(episode.url!, () => <Chapter>[]).add(episode);
    }
    final remoteList = remoteEpisodes.toList(growable: false);
    final remoteUrlCounts = <String, int>{};
    for (final remote in remoteList) {
      remoteUrlCounts[remote.url] = (remoteUrlCounts[remote.url] ?? 0) + 1;
    }
    for (final remote in remoteList) {
      if (!const ChimahonLocalChapterPolicy().hasPortableWireIdentity(
        url: remote.hasUrl() ? remote.url : null,
        name: remote.hasName() ? remote.name : null,
        chapterNumber: remote.episodeNumber,
      )) {
        continue;
      }
      final remoteKey = _remoteEpisodeKey(remote);
      var local = localByKey[remoteKey];
      final sameUrl = localByUrl[remote.url];
      if (local == null &&
          remoteUrlCounts[remote.url] == 1 &&
          sameUrl?.length == 1) {
        local = sameUrl!.single;
      }
      if (local == null) {
        local = Chapter(
          mangaId: anime.id,
          name: remote.name,
          url: remote.url,
          dateUpload: '${normalizeMihonTimestamp(remote.dateUpload.toInt())}',
          scanlator: remote.hasScanlator() ? remote.scanlator : '',
          chapterNumber: remote.episodeNumber,
          isBookmarked: remote.bookmark,
          isRead: remote.seen,
          lastPageRead: _progressString(remote.lastSecondSeen.toInt()),
          isFiller: remote.fillermark,
          thumbnailUrl: remote.hasPreviewUrl() ? remote.previewUrl : null,
          description: remote.hasSummary() ? remote.summary : null,
          duration: remote.totalSeconds == Int64.ZERO
              ? null
              : '${remote.totalSeconds}',
          updatedAt: normalizeMihonTimestamp(remote.lastModifiedAt.toInt()),
        )..manga.value = anime;
        database.chapters.putSync(local);
        local.manga.saveSync();
        localChapters.add(local);
        localByUrl.putIfAbsent(remote.url, () => <Chapter>[]).add(local);
        created++;
      } else {
        local
          ..name = remote.name
          ..dateUpload = '${normalizeMihonTimestamp(remote.dateUpload.toInt())}'
          ..scanlator = remote.hasScanlator()
              ? remote.scanlator
              : local.scanlator
          ..chapterNumber = remote.episodeNumber
          ..isBookmarked = remote.bookmark
          ..isRead = remote.seen
          ..lastPageRead = _progressString(remote.lastSecondSeen.toInt())
          ..isFiller = remote.fillermark
          ..updatedAt = normalizeMihonTimestamp(remote.lastModifiedAt.toInt());
        if (remote.hasPreviewUrl()) local.thumbnailUrl = remote.previewUrl;
        if (remote.hasSummary()) local.description = remote.summary;
        if (remote.totalSeconds != Int64.ZERO) {
          local.duration = '${remote.totalSeconds}';
        }
        database.chapters.putSync(local);
        updated++;
      }
      localByKey.removeWhere((_, candidate) => candidate.id == local!.id);
      localByKey[remoteKey] = local;
    }
    return (created, updated);
  }

  void _upsertHistory({
    required Isar database,
    required Manga manga,
    required Iterable<BackupHistory> remoteHistory,
    required List<Chapter> localChapters,
    required List<History> localHistories,
  }) {
    final chaptersByUrl = <String, Chapter>{
      for (final chapter in localChapters.where(
        (chapter) => chapter.mangaId == manga.id,
      ))
        if (const ChimahonLocalChapterPolicy().hasPortableIdentity(chapter))
          chapter.url!: chapter,
    };
    final historiesByChapter = <int, History>{
      for (final history in localHistories.where(
        (history) => history.mangaId == manga.id,
      ))
        if (history.chapterId != null) history.chapterId!: history,
    };
    var lastRead = manga.lastRead ?? 0;
    for (final remote in remoteHistory) {
      final chapter = chaptersByUrl[remote.url];
      if (chapter?.id == null) continue;
      final readAt = normalizeMihonTimestamp(remote.lastRead.toInt());
      final existing = historiesByChapter[chapter!.id!];
      if (existing != null &&
          (int.tryParse(existing.date ?? '') ?? 0) > readAt) {
        lastRead = _max(lastRead, int.tryParse(existing.date ?? '') ?? 0);
        continue;
      }
      final history =
          existing ??
          History(
            mangaId: manga.id,
            date: '$readAt',
            itemType: manga.itemType,
            chapterId: chapter.id,
          );
      history
        ..mangaId = manga.id
        ..chapterId = chapter.id
        ..itemType = manga.itemType
        ..date = '$readAt'
        ..updatedAt = readAt
        ..readingTimeSeconds = remote.readDuration.toInt() ~/ 1000
        ..chapter.value = chapter;
      database.historys.putSync(history);
      history.chapter.saveSync();
      if (existing == null) {
        localHistories.add(history);
        historiesByChapter[chapter.id!] = history;
      }
      lastRead = _max(lastRead, readAt);
    }
    if (lastRead > (manga.lastRead ?? 0)) {
      manga.lastRead = lastRead;
      database.mangas.putSync(manga);
    }
  }

  void _upsertTracking({
    required Isar database,
    required Manga manga,
    required Iterable<BackupTracking> remoteTracking,
    required Int64 parentModifiedAt,
    required List<Track> localTracks,
  }) {
    if (manga.id == null) return;
    const adapter = ChimahonTrackingAdapter();
    final remoteRows = remoteTracking.toList(growable: false);
    final localByTracker = <int, Track>{
      for (final track in localTracks.where(
        (track) => track.mangaId == manga.id,
      ))
        if (track.syncId != null) track.syncId!: track,
    };
    for (final remote in remoteRows) {
      if (!adapter.isSupportedTracker(remote.syncId)) continue;
      final existing = localByTracker[remote.syncId];
      final imported = adapter.fromBackup(
        remote,
        mangaId: manga.id!,
        itemType: manga.itemType,
        existing: existing,
      );
      if (imported == null) continue;
      final parentModified = normalizeMihonTimestamp(parentModifiedAt.toInt());
      if (parentModified > 0) imported.updatedAt = parentModified;
      database.tracks.putSync(imported);
      if (existing == null) localTracks.add(imported);
      localByTracker[remote.syncId] = imported;
    }
    // Chimahon restore treats tracking as an upsert-only collection. Absence
    // can mean the tracker was excluded by sync settings or came from a
    // projection which cannot represent it; it is not a deletion signal.
    // Explicit local deletion intent is handled by the merger before upload.
  }

  void _applyFavoriteVersion(Manga local, BackupManga remote) {
    if (remote.hasFavoriteModifiedAt()) {
      local.favoriteModifiedAt = remote.favoriteModifiedAt.toInt();
    }
  }

  void _applyAnimeFavoriteVersion(Manga local, BackupAnime remote) {
    if (remote.hasFavoriteModifiedAt()) {
      local.favoriteModifiedAt = remote.favoriteModifiedAt.toInt();
    }
  }

  List<int> _categoryIds(
    Iterable<Int64> remoteOrders,
    Map<int, int> categories,
  ) => remoteOrders
      .map((order) => order.toInt())
      .map((order) => categories[order])
      .nonNulls
      .toSet()
      .toList();

  List<int> _unionIds(Iterable<int>? local, Iterable<int> remote) =>
      {...?local, ...remote}.toList();

  bool _sameIds(Iterable<int>? first, Iterable<int> second) {
    final firstSet = first?.toSet() ?? const <int>{};
    final secondSet = second.toSet();
    return firstSet.length == secondSet.length &&
        firstSet.containsAll(secondSet);
  }

  Map<String, int> _sourceUrlCounts(
    Iterable<({int source, String url})> identities,
  ) {
    final result = <String, int>{};
    for (final identity in identities) {
      final key = _sourceUrlKey(identity.source, identity.url);
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  String _sourceUrlKey(int source, String url) => '$source|$url';

  String _localChapterKey(Chapter chapter) =>
      '${chapter.url}|${chapter.name ?? ''}|${chapter.chapterNumber ?? 0.0}';

  String _remoteChapterKey(BackupChapter chapter) =>
      '${chapter.url}|${chapter.name}|${chapter.chapterNumber}';

  String _localEpisodeKey(Chapter episode) =>
      '${episode.url}|${episode.name ?? ''}|${episode.chapterNumber ?? 0.0}';

  String _remoteEpisodeKey(BackupEpisode episode) =>
      '${episode.url}|${episode.name}|${episode.episodeNumber}';

  String _progressString(int value) => value == 0 ? '1' : '$value';

  Status _status(int value) => switch (value) {
    1 => Status.ongoing,
    2 => Status.completed,
    4 => Status.publishingFinished,
    5 => Status.canceled,
    6 => Status.onHiatus,
    _ => Status.unknown,
  };

  String _normalized(String? value) => (value ?? '').trim().toLowerCase();

  int _max(int first, int second) => first >= second ? first : second;
}
