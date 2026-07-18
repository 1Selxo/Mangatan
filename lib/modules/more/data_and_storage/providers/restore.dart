import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/custom_button.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/track_preference.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAniyomi.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/services/sync/chimahon_app_settings_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_manual_restore_category_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_manual_restore_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_mining_settings_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_local_sync_projection_service.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/chimahon_manga_title_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_novel_materializer.dart';
import 'package:mangayomi/services/sync/chimahon_sync_importer.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/chimahon_restore_sync_coordinator.dart';
import 'package:mangayomi/services/sync/chimahon_source_preferences_adapter.dart';
import 'package:mangayomi/services/sync/mihon_backup_source_resolver.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/blend_level_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/animation_duration_scale_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/flex_scheme_color_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/pure_black_dark_mode_state_provider.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:mangayomi/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:mangayomi/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/router/router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'restore.g.dart';

@riverpod
Future<void> doRestore(
  Ref ref, {
  required String path,
  required BuildContext context,
}) async {
  final tachiType = _tachiBackupTypeFromPath(path);
  if (tachiType != null) {
    try {
      await ref.read(restoreTachiBkBackupProvider(path, tachiType).future);
      showBotToast("Backup restored!");
    } catch (e, s) {
      botToast('$e\n$s');
    }
    return;
  }

  final inputStream = InputFileStream(path);
  try {
    final archive = ZipDecoder().decodeStream(inputStream);
    final backupType = checkBackupType(path, archive);
    switch (backupType) {
      case BackupType.mangayomi:
        final backup =
            jsonDecode(utf8.decode(archive.files.first.content))
                as Map<String, dynamic>;
        ref.read(restoreBackupProvider(backup));
        break;
      case BackupType.kotatsu:
        ref.read(restoreKotatsuBackupProvider(archive));
        break;
      case BackupType.mihon:
      case BackupType.aniyomi:
      case BackupType.neko:
        break;
      default:
    }
    if (backupType != BackupType.unknown) {
      showBotToast("Backup restored!");
    } else {
      showBotToast("Backup Type not supported!");
    }
  } catch (e, s) {
    botToast('$e\n$s');
  } finally {
    inputStream.close();
  }
}

void showBotToast(String text) {
  BotToast.showNotification(
    animationDuration: const Duration(milliseconds: 200),
    animationReverseDuration: const Duration(milliseconds: 200),
    duration: const Duration(seconds: 5),
    backButtonBehavior: BackButtonBehavior.none,
    leading: (_) => Image.asset('assets/app_icons/icon-red.png', height: 40),
    title: (_) => Text(text, style: TextStyle(fontWeight: FontWeight.bold)),
    enableSlideOff: true,
    onlyOne: true,
    crossPage: true,
  );
}

enum BackupType { unknown, mangayomi, mihon, aniyomi, kotatsu, neko }

BackupType checkBackupType(String path, Archive archive) {
  final normalizedPath = path.toLowerCase();
  if ((normalizedPath.contains("mangatan") ||
          normalizedPath.contains("mangayomi")) &&
      (archive.files.firstOrNull?.name ?? "").endsWith(".backup.db")) {
    return BackupType.mangayomi;
  } else if (path.toLowerCase().contains("kotatsu") &&
      archive.files.where((f) {
            switch (f.name) {
              case "categories":
              case "favourites":
                return true;
              default:
                return false;
            }
          }).length ==
          2) {
    return BackupType.kotatsu;
  }
  return BackupType.unknown;
}

BackupType? _tachiBackupTypeFromPath(String path) {
  final lower = path.toLowerCase();
  if (!lower.endsWith('.tachibk') && !lower.endsWith('.proto.gz')) {
    return null;
  }
  if (lower.contains('xyz.jmir.tachiyomi.mi') ||
      lower.contains('aniyomi.mi') ||
      lower.contains('anikku')) {
    return BackupType.aniyomi;
  }
  if (lower.contains('neko')) return BackupType.neko;
  // Mihon, Komikku, Chimahon, and their forks share the same current envelope.
  return BackupType.mihon;
}

@riverpod
void restoreBackup(Ref ref, Map<String, dynamic> backup, {bool full = true}) {
  final version = backup['version'];
  if (["1", "2"].any((e) => e == version)) {
    try {
      final manga = (backup["manga"] as List?)
          ?.map((e) => Manga.fromJson(e)..itemType = _convertToItemType(e))
          .toList();
      final chapters = (backup["chapters"] as List?)
          ?.map((e) => Chapter.fromJson(e))
          .toList();
      final categories = (backup["categories"] as List?)
          ?.map(
            (e) =>
                Category.fromJson(e)
                  ..forItemType = _convertToItemTypeCategory(e),
          )
          .toList();
      final track = (backup["tracks"] as List?)
          ?.map((e) => Track.fromJson(e)..itemType = _convertToItemType(e))
          .toList();
      final trackPreferences = (backup["trackPreferences"] as List?)
          ?.map((e) => TrackPreference.fromJson(e))
          .toList();
      final history = (backup["history"] as List?)
          ?.map((e) => History.fromJson(e)..itemType = _convertToItemType(e))
          .toList();
      final downloads = (backup["downloads"] as List?)
          ?.map((e) => Download.fromJson(e))
          .toList();
      final settings = (backup["settings"] as List?)
          ?.map((e) => Settings.fromJson(e))
          .toList();
      final extensions = (backup["extensions"] as List?)
          ?.map((e) => Source.fromJson(e)..itemType = _convertToItemType(e))
          .toList();
      final sourcesPrefs = (backup["extensions_preferences"] as List?)
          ?.map((e) => SourcePreference.fromJson(e))
          .toList();
      final updates = (backup["updates"] as List?)
          ?.map((e) => Update.fromJson(e))
          .toList();
      final customButtons = (backup["customButtons"] as List?)
          ?.map((e) => CustomButton.fromJson(e))
          .toList();

      isar.writeTxnSync(() {
        isar.mangas.clearSync();
        if (manga != null) {
          isar.mangas.putAllSync(manga);
          if (chapters != null) {
            isar.chapters.clearSync();
            for (var chapter in chapters) {
              final manga = isar.mangas.getSync(chapter.mangaId!);
              if (manga != null) {
                isar.chapters.putSync(chapter..manga.value = manga);
                chapter.manga.saveSync();
              }
            }

            if (full) {
              isar.downloads.clearSync();
              if (downloads != null) {
                for (var download in downloads) {
                  final chapter = isar.chapters.getSync(download.id!);
                  if (chapter != null) {
                    isar.downloads.putSync(download..chapter.value = chapter);
                    download.chapter.saveSync();
                  }
                }
              }
            }

            isar.historys.clearSync();
            if (history != null) {
              for (var element in history) {
                final chapter = isar.chapters.getSync(element.chapterId!);
                if (chapter != null) {
                  isar.historys.putSync(element..chapter.value = chapter);
                  element.chapter.saveSync();
                }
              }
            }

            isar.updates.clearSync();
            if (updates != null) {
              final tempChapters = isar.chapters
                  .filter()
                  .idIsNotNull()
                  .findAllSync()
                  .toList();
              for (var update in updates) {
                final matchingChapter = tempChapters
                    .where(
                      (chapter) =>
                          chapter.mangaId == update.mangaId &&
                          chapter.name == update.chapterName,
                    )
                    .firstOrNull;
                if (matchingChapter != null) {
                  isar.updates.putSync(update..chapter.value = matchingChapter);
                  update.chapter.saveSync();
                }
              }
            }
          }

          isar.categorys.clearSync();
          if (categories != null) {
            isar.categorys.putAllSync(categories);
          }
        }

        isar.tracks.clearSync();
        if (track != null) {
          isar.tracks.putAllSync(track);
        }

        if (full) {
          if (trackPreferences != null) {
            isar.trackPreferences.clearSync();
            isar.trackPreferences.putAllSync(trackPreferences);
          }
          isar.sources.clearSync();
          if (extensions != null) {
            isar.sources.putAllSync(extensions);
          }
          isar.sourcePreferences.clearSync();
          if (sourcesPrefs != null) {
            isar.sourcePreferences.putAllSync(sourcesPrefs);
          }
          isar.settings.clearSync();
          if (settings != null) {
            isar.settings.putAllSync(settings);
          }
          isar.customButtons.clearSync();
          if (customButtons != null) {
            isar.customButtons.putAllSync(customButtons);
          }
          _invalidateCommonState(ref);
        }
      });
    } catch (e) {
      rethrow;
    }
  } else {
    throw "Failed to restore the backup";
  }
}

ItemType _convertToItemType(Map<String, dynamic> backup) {
  final isManga = backup['isManga'];
  return isManga == null
      ? ItemType.values[backup['itemType'] ?? 0]
      : isManga
      ? ItemType.manga
      : ItemType.anime;
}

ItemType _convertToItemTypeCategory(Map<String, dynamic> backup) {
  final forManga = backup['forManga'];
  return forManga == null
      ? ItemType.values[backup['forItemType'] ?? 0]
      : forManga
      ? ItemType.manga
      : ItemType.anime;
}

@riverpod
void restoreKotatsuBackup(Ref ref, Archive archive) {
  try {
    for (var f in archive.files) {
      List<Category> cats = [];
      switch (f.name) {
        case "categories":
          final categories = jsonDecode(utf8.decode(f.content)) as List? ?? [];
          isar.writeTxnSync(() {
            isar.categorys.clearSync();
            for (var category in categories) {
              final cat = Category(
                id: category["id"],
                name: category["title"],
                forItemType: ItemType.manga,
                hide: !(category["show_in_lib"] ?? true),
              );
              isar.categorys.putSync(cat);
              cats.add(cat);
            }
          });
        case "favourites":
          final favourites = jsonDecode(utf8.decode(f.content)) as List? ?? [];
          isar.writeTxnSync(() {
            isar.mangas.clearSync();
            for (var favourite in favourites) {
              final tempManga = favourite["manga"];
              final manga = Manga(
                source: tempManga["source"],
                author: tempManga["author"],
                artist: null,
                genre:
                    (tempManga["tags"] as List?)
                        ?.map((t) => t["title"] as String)
                        .toList() ??
                    [],
                imageUrl: tempManga["large_cover_url"],
                lang: 'en',
                link: tempManga["url"],
                name: tempManga["title"],
                status: Status.values.firstWhere(
                  (s) =>
                      s.name.toLowerCase() ==
                      (tempManga["state"] as String?)?.toLowerCase(),
                  orElse: () => Status.unknown,
                ),
                description: null,
                categories: [favourite["category_id"]],
                itemType: ItemType.manga,
                favorite: true,
                sourceId: null,
              );
              isar.mangas.putSync(manga);
            }
          });
        default:
          continue;
      }
    }
    isar.writeTxnSync(() {
      isar.chapters.clearSync();
      isar.downloads.clearSync();
      isar.historys.clearSync();
      isar.updates.clearSync();
      isar.tracks.clearSync();
      isar.trackPreferences.clearSync();
      _invalidateCommonState(ref);
    });
  } catch (e) {
    rethrow;
  }
}

@riverpod
Future<void> restoreTachiBkBackup(
  Ref ref,
  String path,
  BackupType bkType,
) async {
  final inputStream = InputFileStream(path);
  late final DecodedChimahonSync decoded;
  try {
    decoded = const ChimahonSyncCodec().decode(inputStream.toUint8List());
  } finally {
    inputStream.close();
  }
  final content = decoded.protobufBytes;
  final backup = decoded.backup;
  await restoreTachiBkBackupData(ref, backup, content, bkType);
}

Future<void> restoreTachiBkBackupData(
  Ref ref,
  BackupMihon backup,
  List<int> content,
  BackupType bkType, {
  ChimahonDeferredPayloadStore? pendingManualRestoreStore,
}) => ChimahonRestoreSyncCoordinator.shared.duringManualRestore(
  () => _restoreTachiBkBackupDataExclusive(
    ref,
    backup,
    content,
    bkType,
    pendingManualRestoreStore: pendingManualRestoreStore,
  ),
);

Future<void> _restoreTachiBkBackupDataExclusive(
  Ref ref,
  BackupMihon backup,
  List<int> content,
  BackupType bkType, {
  ChimahonDeferredPayloadStore? pendingManualRestoreStore,
}) async {
  final localSources = isar.sources.filter().idIsNotNull().findAllSync();
  final shouldRestoreAnime =
      bkType == BackupType.aniyomi ||
      backup.backupAnime.isNotEmpty ||
      backup.backupAnimeCategories.isNotEmpty;
  final legacyAnimeBackup = shouldRestoreAnime
      ? BackupAniyomi.fromBuffer(content)
      : null;
  final List<BackupCategory> animeCategories =
      backup.backupAnimeCategories.isNotEmpty
      ? backup.backupAnimeCategories.toList()
      : legacyAnimeBackup?.backupAnimeCategories.isNotEmpty == true
      ? legacyAnimeBackup!.backupAnimeCategories.toList()
      : legacyAnimeBackup?.legacyBackupAnimeCategories.toList() ?? const [];
  final List<BackupAnime> animeEntries = backup.backupAnime.isNotEmpty
      ? backup.backupAnime.toList()
      : legacyAnimeBackup?.backupAnime.isNotEmpty == true
      ? legacyAnimeBackup!.backupAnime.toList()
      : legacyAnimeBackup?.legacyBackupAnime.toList() ?? const [];
  final List<BackupSource> animeSources = backup.backupAnimeSources.isNotEmpty
      ? backup.backupAnimeSources.toList()
      : legacyAnimeBackup?.backupAnimeSources.isNotEmpty == true
      ? legacyAnimeBackup!.backupAnimeSources.toList()
      : legacyAnimeBackup?.legacyBackupAnimeSources.toList() ?? const [];
  final pendingBackup = backup.deepCopy();
  if (pendingBackup.backupAnime.isEmpty) {
    pendingBackup.backupAnime.addAll(animeEntries);
  }
  if (pendingBackup.backupAnimeCategories.isEmpty) {
    pendingBackup.backupAnimeCategories.addAll(animeCategories);
  }
  if (pendingBackup.backupAnimeSources.isEmpty) {
    pendingBackup.backupAnimeSources.addAll(animeSources);
  }
  // Preserve the exact restore payload (including fields this Mangatan build
  // cannot project) until a conditional Chimahon upload succeeds. Persist it
  // before destructive database work so a partial restore cannot lose data.
  final pendingStore =
      pendingManualRestoreStore ??
      await defaultChimahonPendingManualRestoreStore();
  if (pendingStore case ChimahonPendingManualRestoreLifecycleStore lifecycle) {
    await lifecycle.beginPreparing(pendingBackup);
  } else {
    // Custom stores predating the lifecycle keep their legacy ready behavior.
    await pendingStore.save(pendingBackup);
  }
  const manualRestoreAdapter = ChimahonManualRestoreAdapter();
  const novelMaterializer = ChimahonNovelMaterializer();
  final localNovelProgress = isar.epubBookProgress.where().findAllSync();
  final allLocalChapters = isar.chapters.where().findAllSync();
  final allLocalArchiveMangas = isar.mangas
      .filter()
      .isLocalArchiveEqualTo(true)
      .findAllSync();
  final obsoleteCloudNovelParentIds = novelMaterializer
      .staleCloudNovelParentIds(
        localMangas: allLocalArchiveMangas,
        localProgress: localNovelProgress,
        localChapters: allLocalChapters,
        remote: backup.backupNovels,
      );
  final localArchiveMangas = allLocalArchiveMangas
      .where((manga) => !obsoleteCloudNovelParentIds.contains(manga.id))
      .toList(growable: false);
  final localArchiveIds = localArchiveMangas
      .map((manga) => manga.id)
      .whereType<int>()
      .toSet();
  final manualOverlayChapters = allLocalChapters
      .where(
        (chapter) =>
            !localArchiveIds.contains(chapter.mangaId) &&
            manualRestoreAdapter.isDeviceLocalChapter(chapter),
      )
      .toList(growable: false);
  final manualOverlayParentIds = manualOverlayChapters
      .map((chapter) => chapter.mangaId)
      .whereType<int>()
      .toSet();
  final retainedLocalMangas = [
    ...localArchiveMangas,
    ...isar.mangas.where().findAllSync().where(
      (manga) => manualOverlayParentIds.contains(manga.id),
    ),
  ];
  final retainedLocalMangaIds = retainedLocalMangas
      .map((manga) => manga.id)
      .whereType<int>()
      .toSet();
  final retainedLocalChapters = [
    ...allLocalChapters.where(
      (chapter) => localArchiveIds.contains(chapter.mangaId),
    ),
    ...manualOverlayChapters,
  ];
  final retainedLocalChapterIds = retainedLocalChapters
      .map((chapter) => chapter.id)
      .whereType<int>()
      .toSet();
  final retainedLocalHistories = isar.historys
      .where()
      .findAllSync()
      .where((history) => retainedLocalChapterIds.contains(history.chapterId))
      .toList(growable: false);
  final retainedLastReadByMangaId = <int, int>{};
  for (final manga in retainedLocalMangas) {
    final mangaId = manga.id;
    if (mangaId == null) continue;
    retainedLastReadByMangaId[mangaId] = manualRestoreAdapter.retainedLastRead(
      parentLastRead: manga.lastRead,
      histories: retainedLocalHistories.where(
        (history) => history.mangaId == mangaId,
      ),
    );
  }
  final retainedLocalTracks = manualRestoreAdapter
      .trackingRowsForRetainedParents(
        tracks: isar.tracks.where().findAllSync(),
        retainedParentIds: retainedLocalMangaIds,
      );
  final retainedTracksByMangaId = <int, List<Track>>{};
  for (final track in retainedLocalTracks) {
    final mangaId = track.mangaId;
    if (mangaId != null) {
      retainedTracksByMangaId.putIfAbsent(mangaId, () => []).add(track);
    }
  }
  final localCategories = isar.categorys.where().findAllSync();
  final retainedLocalCategoryIds = retainedLocalMangas
      .expand((manga) => manga.categories ?? const <int>[])
      .toSet();
  final categoryPlan = const ChimahonManualRestoreCategoryAdapter().build(
    localCategories: localCategories,
    retainedLocalCategoryIds: retainedLocalCategoryIds,
    mangaCategories: backup.backupCategories,
    animeCategories: animeCategories,
    novelCategories: backup.backupNovelCategories,
  );
  final retainedNovelProgress = localNovelProgress
      .where((progress) => retainedLocalMangaIds.contains(progress.mangaId))
      .toList(growable: false);
  final novelPlan = novelMaterializer.plan(
    localMangas: retainedLocalMangas,
    localProgress: retainedNovelProgress,
    localChapters: retainedLocalChapters,
    remote: backup.backupNovels,
  );
  isar.writeTxnSync(() {
    isar.categorys.clearSync();
    isar.mangas.clearSync();
    isar.chapters.clearSync();
    isar.historys.clearSync();
    isar.tracks.clearSync();
    // Progress belongs to retained local EPUB parents or to remote ghosts
    // materialized below. Clearing first prevents an orphan from suppressing
    // a remote book and then attaching to a reused auto-increment parent ID.
    isar.epubBookProgress.clearSync();
    for (final category in categoryPlan.categoriesForInsertion) {
      isar.categorys.putSync(category);
    }
    for (final manga in retainedLocalMangas) {
      manga.hasLocalChapterOverlay = manualOverlayParentIds.contains(manga.id);
      final remoteNovelCategoryIds =
          novelPlan.remoteCategoryIdsByMangaId[manga.id] ?? const <String>[];
      manga.categories = manga.itemType != ItemType.novel
          ? categoryPlan.remapLocalIds(manga.categories)
          : novelPlan.authoritativeCloudParentIds.contains(manga.id)
          ? categoryPlan.idsForNovelBackupIds(remoteNovelCategoryIds)
          : categoryPlan.idsForRetainedNovelTitle(
              localIds: manga.categories,
              backupIds: remoteNovelCategoryIds,
            );
      isar.mangas.putSync(manga);
    }
    if (retainedNovelProgress.isNotEmpty) {
      isar.epubBookProgress.putAllSync(retainedNovelProgress);
    }
    for (final cloudNovel in novelPlan.cloudNovels) {
      cloudNovel.parent.categories = categoryPlan.idsForNovelBackupIds(
        cloudNovel.remote.categoryIds,
      );
      isar.mangas.putSync(cloudNovel.parent);
      cloudNovel.progress.mangaId = cloudNovel.parent.id!;
      isar.epubBookProgress.putSync(cloudNovel.progress);
    }
    for (final chapter in retainedLocalChapters) {
      final manga = isar.mangas.getSync(chapter.mangaId!);
      if (manga == null) continue;
      isar.chapters.putSync(chapter..manga.value = manga);
      chapter.manga.saveSync();
    }
    for (final history in retainedLocalHistories) {
      final chapter = isar.chapters.getSync(history.chapterId!);
      if (chapter == null) continue;
      isar.historys.putSync(history..chapter.value = chapter);
      history.chapter.saveSync();
    }
    if (retainedLocalTracks.isNotEmpty) {
      isar.tracks.putAllSync(retainedLocalTracks);
    }
    for (var tempManga in backup.backupManga) {
      final nativeSourceId = _protoInt(tempManga.source);
      final resolvedSource = resolveMihonBackupSource(
        nativeId: nativeSourceId,
        backupSources: backup.backupSources,
        localSources: localSources,
      );
      final categoryOrders = tempManga.categories.map(_protoInt).toSet();
      final titles = const ChimahonMangaTitleAdapter().fromBackup(tempManga);
      final retained = _findRetainedRestoreTitle(
        retained: retainedLocalMangas,
        itemType: ItemType.manga,
        source: resolvedSource,
        url: tempManga.url,
        sourceTitle: titles.sourceTitle,
      );
      final manga = Manga(
        id: retained?.id,
        source: resolvedSource.name,
        author: tempManga.author,
        artist: tempManga.artist,
        genre: tempManga.genre,
        imageUrl: tempManga.thumbnailUrl,
        lang: resolvedSource.language,
        link: tempManga.url,
        name: titles.displayTitle,
        sourceTitle: titles.sourceTitle,
        status: _convertStatusFromTachiBk(tempManga.status),
        description: tempManga.description,
        categories: categoryPlan.idsForRetainedTitle(
          localIds: retained?.categories,
          itemType: ItemType.manga,
          backupOrders: categoryOrders,
        ),
        itemType: ItemType.manga,
        favorite: tempManga.hasFavorite() ? tempManga.favorite : true,
        favoriteModifiedAt: manualRestoreAdapter.mangaFavoriteModifiedAt(
          tempManga,
        ),
        dateAdded: normalizeMihonTimestamp(_protoInt(tempManga.dateAdded)),
        lastRead: retained?.id == null
            ? 0
            : retainedLastReadByMangaId[retained!.id!] ?? retained.lastRead,
        lastUpdate: normalizeMihonTimestamp(
          _protoInt(tempManga.lastModifiedAt),
        ),
        sourceId: resolvedSource.localId,
        isManga: retained?.isManga,
        isLocalArchive: retained?.isLocalArchive ?? false,
        hasLocalChapterOverlay:
            retained != null && manualOverlayParentIds.contains(retained.id),
        customCoverImage: retained?.customCoverImage,
        customCoverFromTracker: retained?.customCoverFromTracker,
        smartUpdateDays: retained?.smartUpdateDays,
        updatedAt: manualRestoreAdapter.updatedAtFromLastModified(
          _protoInt(tempManga.lastModifiedAt),
        ),
      );
      if (bkType == BackupType.neko) {
        manga.source = "MangaDex";
      }
      isar.mangas.putSync(manga);
      final chaptersByUrl = <String, Chapter>{};
      for (var tempChapter in tempManga.chapters) {
        final chapter = manualRestoreAdapter.mangaChapterRow(
          remote: tempChapter,
          mangaId: manga.id!,
          dateUpload: bkType != BackupType.neko
              ? normalizeMihonTimestamp(_protoInt(tempChapter.dateUpload))
              : DateTime.now().millisecondsSinceEpoch -
                    _protoInt(tempChapter.dateUpload).abs(),
        );
        isar.chapters.putSync(chapter..manga.value = manga);
        chapter.manga.saveSync();
        chaptersByUrl[tempChapter.url] = chapter;
      }
      var lastRead = manga.lastRead ?? 0;
      for (final tempHistory in tempManga.history) {
        final chapter = chaptersByUrl[tempHistory.url];
        if (chapter == null) continue;
        final readAt = normalizeMihonTimestamp(_protoInt(tempHistory.lastRead));
        lastRead = readAt > lastRead ? readAt : lastRead;
        final history = History(
          mangaId: manga.id,
          date: '$readAt',
          itemType: ItemType.manga,
          chapterId: chapter.id,
          readingTimeSeconds: Duration(
            milliseconds: _protoInt(tempHistory.readDuration),
          ).inSeconds,
        )..chapter.value = chapter;
        isar.historys.putSync(history);
        history.chapter.saveSync();
      }
      if (lastRead > 0) isar.mangas.putSync(manga..lastRead = lastRead);
      final restoredTracks = manualRestoreAdapter.trackingRows(
        remote: tempManga.tracking,
        mangaId: manga.id!,
        itemType: ItemType.manga,
        parentModifiedAt: _protoInt(tempManga.lastModifiedAt),
        existing: retainedTracksByMangaId[manga.id] ?? const <Track>[],
      );
      if (restoredTracks.isNotEmpty) {
        isar.tracks.putAllSync(restoredTracks);
      }
    }
  });
  if (shouldRestoreAnime) {
    isar.writeTxnSync(() {
      for (var tempAnime in animeEntries) {
        final nativeSourceId = _protoInt(tempAnime.source);
        final resolvedSource = resolveMihonBackupSource(
          nativeId: nativeSourceId,
          backupSources: animeSources,
          localSources: localSources,
        );
        final categoryOrders = tempAnime.categories.map(_protoInt).toSet();
        final retained = _findRetainedRestoreTitle(
          retained: retainedLocalMangas,
          itemType: ItemType.anime,
          source: resolvedSource,
          url: tempAnime.url,
          sourceTitle: tempAnime.title,
        );
        final anime = Manga(
          id: retained?.id,
          source: resolvedSource.name,
          author: tempAnime.author,
          artist: tempAnime.artist,
          genre: tempAnime.genre,
          imageUrl: tempAnime.thumbnailUrl,
          lang: resolvedSource.language,
          link: tempAnime.url,
          name: tempAnime.title,
          status: _convertStatusFromTachiBk(tempAnime.status),
          description: tempAnime.description,
          categories: categoryPlan.idsForRetainedTitle(
            localIds: retained?.categories,
            itemType: ItemType.anime,
            backupOrders: categoryOrders,
          ),
          itemType: ItemType.anime,
          favorite: tempAnime.hasFavorite() ? tempAnime.favorite : true,
          favoriteModifiedAt: manualRestoreAdapter.animeFavoriteModifiedAt(
            tempAnime,
          ),
          dateAdded: normalizeMihonTimestamp(_protoInt(tempAnime.dateAdded)),
          lastRead: retained?.id == null
              ? 0
              : retainedLastReadByMangaId[retained!.id!] ?? retained.lastRead,
          lastUpdate: normalizeMihonTimestamp(
            _protoInt(tempAnime.lastModifiedAt),
          ),
          sourceId: resolvedSource.localId,
          isManga: retained?.isManga,
          isLocalArchive: retained?.isLocalArchive ?? false,
          hasLocalChapterOverlay:
              retained != null && manualOverlayParentIds.contains(retained.id),
          customCoverImage: retained?.customCoverImage,
          customCoverFromTracker: retained?.customCoverFromTracker,
          smartUpdateDays: retained?.smartUpdateDays,
          updatedAt: manualRestoreAdapter.updatedAtFromLastModified(
            _protoInt(tempAnime.lastModifiedAt),
          ),
        );
        isar.mangas.putSync(anime);
        final episodesByUrl = <String, Chapter>{};
        for (var tempEpisode in tempAnime.episodes) {
          final episode = manualRestoreAdapter.animeEpisodeRow(
            remote: tempEpisode,
            mangaId: anime.id!,
            dateUpload: normalizeMihonTimestamp(
              _protoInt(tempEpisode.dateUpload),
            ),
          );
          isar.chapters.putSync(episode..manga.value = anime);
          episode.manga.saveSync();
          episodesByUrl[tempEpisode.url] = episode;
        }
        var lastRead = anime.lastRead ?? 0;
        for (final tempHistory in tempAnime.history) {
          final episode = episodesByUrl[tempHistory.url];
          if (episode == null) continue;
          final readAt = normalizeMihonTimestamp(
            _protoInt(tempHistory.lastRead),
          );
          lastRead = readAt > lastRead ? readAt : lastRead;
          final history = History(
            mangaId: anime.id,
            date: '$readAt',
            itemType: ItemType.anime,
            chapterId: episode.id,
            readingTimeSeconds: Duration(
              milliseconds: _protoInt(tempHistory.readDuration),
            ).inSeconds,
          )..chapter.value = episode;
          isar.historys.putSync(history);
          history.chapter.saveSync();
        }
        if (lastRead > 0) isar.mangas.putSync(anime..lastRead = lastRead);
        final restoredTracks = manualRestoreAdapter.trackingRows(
          remote: tempAnime.tracking,
          mangaId: anime.id!,
          itemType: ItemType.anime,
          parentModifiedAt: _protoInt(tempAnime.lastModifiedAt),
          existing: retainedTracksByMangaId[anime.id] ?? const <Track>[],
        );
        if (restoredTracks.isNotEmpty) {
          isar.tracks.putAllSync(restoredTracks);
        }
      }
    });
  }
  isar.writeTxnSync(() {
    // Chimahon has no representation for Mangatan's tracker account
    // preferences, so an explicit restore must leave that local table intact.
    isar.downloads.clearSync();
    isar.updates.clearSync();
  });
  await _importChimahonSettings(backup);
  _importChimahonMediaSelection(backup);
  ref.invalidate(synchingProvider(syncId: 1));
  if (pendingStore case ChimahonLocalPreferenceBaselineStore preferenceStore) {
    final syncPreference =
        isar.syncPreferences.getSync(1) ?? SyncPreference(syncId: 1);
    final projection = await ChimahonLocalSyncProjectionService(
      database: isar,
      mediaSelection: ChimahonMediaSyncSelection(
        manga: syncPreference.chimahonSyncManga,
        anime: syncPreference.chimahonSyncAnime,
        novels: syncPreference.chimahonSyncNovels,
      ),
      mediaSelectionInitialized:
          syncPreference.chimahonMediaSelectionInitialized,
    ).createSnapshot();
    await preferenceStore.saveLocalPreferenceBaseline(
      projection.backup.backupPreferences,
    );
    if (pendingStore
        case ChimahonLocalSourcePreferenceBaselineStore sourceStore) {
      await sourceStore.saveLocalSourcePreferenceBaseline(
        projection.backup.backupSourcePreferences,
      );
    }
  }
  if (pendingStore case ChimahonPendingManualRestoreLifecycleStore lifecycle) {
    await lifecycle.markReady();
  }
  _invalidateCommonState(ref);
}

void _importChimahonMediaSelection(BackupMihon backup) {
  final preferences = backup.backupPreferences;
  if (!ChimahonMediaSyncSelection.hasAnyPreference(preferences)) {
    return;
  }
  isar.writeTxnSync(() {
    final preference =
        isar.syncPreferences.getSync(1) ?? SyncPreference(syncId: 1);
    final selection = chimahonMediaSelectionForExplicitRestore(
      preferences: preferences,
      current: ChimahonMediaSyncSelection(
        manga: preference.chimahonSyncManga,
        anime: preference.chimahonSyncAnime,
        novels: preference.chimahonSyncNovels,
      ),
    );
    final malformed = ChimahonMediaSyncSelection.hasMalformedPreference(
      preferences,
    );
    final nextGeneration = preference.chimahonMediaSelectionGeneration + 1;
    preference
      ..chimahonSyncManga = selection.manga
      ..chimahonSyncAnime = selection.anime
      ..chimahonSyncNovels = selection.novels
      ..chimahonMediaSelectionInitialized = !malformed
      ..chimahonMediaSelectionUserSelected = !malformed
      ..chimahonMediaSelectionScopeToken = null
      ..chimahonMediaSelectionGeneration = nextGeneration;
    isar.syncPreferences.putSync(preference);
  });
}

/// Applies a Chimahon sync payload incrementally.
///
/// Unlike an explicitly requested backup restore, routine sync must preserve
/// local cache rows, downloads, updates, tracker state, local archives, and
/// novel library organization. The database importer never deletes by remote
/// absence and keeps matching Manga/Chapter IDs stable.
Future<void> restoreChimahonSyncData(Ref ref, BackupMihon backup) async {
  const ChimahonSyncImporter().apply(database: isar, backup: backup);
  await _importChimahonSettings(
    backup,
    preserveUnrepresentableLocalSettings: true,
  );
  _invalidateCommonState(ref);
}

Future<void> _importChimahonSettings(
  BackupMihon backup, {
  bool preserveUnrepresentableLocalSettings = false,
}) async {
  isar.writeTxnSync(() {
    final settings = isar.settings.getSync(227);
    if (settings != null) {
      const adapter = ChimahonAppSettingsAdapter();
      final preserveLocalKeys = preserveUnrepresentableLocalSettings
          ? adapter.project(settings).unrepresentableKeys
          : const <String>{};
      adapter.importInto(
        settings,
        backup.backupPreferences,
        preserveLocalKeys: preserveLocalKeys,
      );
      isar.settings.putSync(settings);
    }
  });
  const ChimahonSourcePreferencesAdapter().importInto(
    database: isar,
    sourcePreferences: backup.backupSourcePreferences,
  );
  final sources = isar.sources.filter().idIsNotNull().findAllSync();
  const miningAdapter = ChimahonMiningSettingsAdapter();
  final portableSourceIds = chimahonPortableSourceOverrideIds(sources);
  final preserveLocalMiningKeys = preserveUnrepresentableLocalSettings
      ? (await miningAdapter.project(
          portableSourceIds: portableSourceIds,
        )).unrepresentableKeys
      : const <String>{};
  await miningAdapter.import(
    backup.backupPreferences,
    portableSourceIds: portableSourceIds,
    preserveLocalKeys: preserveLocalMiningKeys,
  );
}

int _protoInt(Object value) {
  if (value is int) {
    return value;
  }
  return (value as dynamic).toInt() as int;
}

void _invalidateCommonState(Ref ref) {
  // Sync markers are durable local intent. In particular, tracker deletion
  // tombstones are cleared by SyncServer only after a successful upload.
  // A restore/import must not clear unrelated or concurrently-created rows.
  ref.invalidate(followSystemThemeStateProvider);
  ref.invalidate(themeModeStateProvider);
  ref.invalidate(animationDurationScaleProvider);
  ref.invalidate(blendLevelStateProvider);
  ref.invalidate(flexSchemeColorStateProvider);
  ref.invalidate(pureBlackDarkModeStateProvider);
  ref.invalidate(l10nLocaleStateProvider);
  ref.invalidate(navigationOrderStateProvider);
  ref.invalidate(hideItemsStateProvider);
  ref.invalidate(extensionsRepoStateProvider(ItemType.manga));
  ref.invalidate(extensionsRepoStateProvider(ItemType.anime));
  ref.invalidate(extensionsRepoStateProvider(ItemType.novel));
  ref.read(routerCurrentLocationStateProvider.notifier).refresh();
}

Manga? _findRetainedRestoreTitle({
  required Iterable<Manga> retained,
  required ItemType itemType,
  required ResolvedMihonBackupSource source,
  required String url,
  required String sourceTitle,
}) => const ChimahonManualRestoreAdapter().retainedTitle(
  retained: retained,
  itemType: itemType,
  source: source,
  url: url,
  sourceTitle: sourceTitle,
);

Status _convertStatusFromTachiBk(int idx) {
  switch (idx) {
    case 1:
      return Status.ongoing;
    case 2:
      return Status.completed;
    case 4:
      return Status.publishingFinished;
    case 5:
      return Status.canceled;
    case 6:
      return Status.onHiatus;
    default:
      return Status.unknown;
  }
}
