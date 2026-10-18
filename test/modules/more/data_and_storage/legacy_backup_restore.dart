// Verbatim copies of the backup and restore code before the performance
// changes described in docs/perf/backup-restore.md. The equivalence tests
// run these against the current code on the same data. Only the names
// changed, and the provider plumbing (keepAlive, state invalidation) was
// left out because it doesn't touch the database.
import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/custom_button.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/track_preference.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/backup_format.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAniyomi.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/restore.dart';
import 'package:mangayomi/repositories/category_repository.dart';
import 'package:mangayomi/repositories/chapter_repository.dart';
import 'package:mangayomi/repositories/custom_button_repository.dart';
import 'package:mangayomi/repositories/download_repository.dart';
import 'package:mangayomi/repositories/history_repository.dart';
import 'package:mangayomi/repositories/manga_repository.dart';
import 'package:mangayomi/repositories/restore_repository.dart';
import 'package:mangayomi/repositories/settings_repository.dart';
import 'package:mangayomi/repositories/source_preference_repository.dart';
import 'package:mangayomi/repositories/source_repository.dart';
import 'package:mangayomi/repositories/track_repository.dart';
import 'package:mangayomi/repositories/update_repository.dart';
import 'package:protobuf/protobuf.dart';

Future<void> legacyRestoreBackup(
  Map<String, dynamic> backup, {
  bool full = true,
  // When true, adds this backup's library into the existing one instead of
  // wiping it first - only categories/manga/chapters/history/updates
  // participate (mirrors what Mihon-family merge covers; device config like
  // settings/sources/customButtons is a replace-only concept either way).
  bool merge = false,
  Map<String, bool> categoryDecisions = const {},
  Map<String, int> sourceDecisions = const {},
}) async {
  final version = backup['version'];
  if (["1", "2"].any((e) => e == version)) {
    try {
      final manga = (backup["manga"] as List?)
          ?.map((e) => Manga.fromJson(e)..itemType = convertToItemType(e))
          .toList();
      final chapters = (backup["chapters"] as List?)
          ?.map((e) => Chapter.fromJson(e))
          .toList();
      final categories = (backup["categories"] as List?)
          ?.map(
            (e) =>
                Category.fromJson(e)
                  ..forItemType = convertToItemTypeCategory(e),
          )
          .toList();
      final track = (backup["tracks"] as List?)
          ?.map((e) => Track.fromJson(e)..itemType = convertToItemType(e))
          .toList();
      final trackPreferences = (backup["trackPreferences"] as List?)
          ?.map((e) => TrackPreference.fromJson(e))
          .toList();
      final history = (backup["history"] as List?)
          ?.map((e) => History.fromJson(e)..itemType = convertToItemType(e))
          .toList();
      final downloads = (backup["downloads"] as List?)
          ?.map((e) => Download.fromJson(e))
          .toList();
      final settings = (backup["settings"] as List?)
          ?.map((e) => Settings.fromJson(e))
          .toList();
      final extensions = (backup["extensions"] as List?)
          ?.map((e) => Source.fromJson(e)..itemType = convertToItemType(e))
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

      final currentSettings = settingsRepository.currentOrNull;
      await restoreRepository.run(() {
        if (merge) {
          legacyMergeMangayomiBackup(
            manga: manga,
            chapters: chapters,
            categories: categories,
            history: history,
            updates: updates,
            categoryDecisions: categoryDecisions,
            sourceDecisions: sourceDecisions,
          );
          return;
        }
        mangaRepository.clearSync();
        if (manga != null) {
          mangaRepository.putAllSync(manga);
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
              downloadRepository.clearSync();
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

            historyRepository.clearSync();
            if (history != null) {
              for (var element in history) {
                final chapter = isar.chapters.getSync(element.chapterId!);
                if (chapter != null) {
                  isar.historys.putSync(element..chapter.value = chapter);
                  element.chapter.saveSync();
                }
              }
            }

            updateRepository.clearSync();
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

          categoryRepository.clearSync();
          if (categories != null) {
            categoryRepository.putAllSync(categories);
          }
        }

        trackRepository.clearSync();
        if (track != null) {
          trackRepository.putAllSync(track);
        }

        if (full) {
          if (trackPreferences != null) {
            trackRepository.clearPreferencesSync();
            trackRepository.putAllPreferencesSync(trackPreferences);
          }
          sourceRepository.clearSync();
          if (extensions != null) {
            sourceRepository.putAllSync(extensions);
          }
          sourcePreferenceRepository.clearSync();
          if (sourcesPrefs != null) {
            sourcePreferenceRepository.putAllSync(sourcesPrefs);
          }
          settingsRepository.clearSync();
          if (settings != null) {
            isar.settings.putAllSync([
              for (final incoming in settings)
                currentSettings == null
                    ? incoming
                    : preserveDeviceLocalSettings(incoming, currentSettings),
            ]);
          }
          customButtonRepository.clearSync();
          if (customButtons != null) {
            customButtonRepository.putAllSync(customButtons);
          }
        }
      });
    } catch (e) {
      rethrow;
    }
  } else {
    throw "Failed to restore the backup";
  }
}

void legacyMergeMangayomiBackup({
  required List<Manga>? manga,
  required List<Chapter>? chapters,
  required List<Category>? categories,
  required List<History>? history,
  required List<Update>? updates,
  required Map<String, bool> categoryDecisions,
  required Map<String, int> sourceDecisions,
}) {
  final oldToNewCategoryId = <int, int>{};
  if (categories != null) {
    final existingCategories = categoryRepository.getAll();
    for (final category in categories) {
      final oldId = category.id;
      final existing = existingCategories.firstWhereOrNull(
        (c) => c.name == category.name && c.forItemType == category.forItemType,
      );
      if (existing != null) {
        if (oldId != null) oldToNewCategoryId[oldId] = existing.id!;
        continue;
      }
      if (categoryDecisions[category.name] == false) continue;
      category.id = null;
      categoryRepository.putSync(category);
      if (oldId != null) oldToNewCategoryId[oldId] = category.id!;
    }
  }

  final oldToNewMangaId = <int, int>{};
  final newMangaIds = <int>{};
  String restoreIdentity(Manga entry) {
    final source = entry.itemType == ItemType.anime
        ? entry.mihonSourceId?.toString() ?? '${entry.source}|${entry.lang}'
        : '';
    return '${entry.itemType.index}|$source|${entry.link}';
  }

  if (manga != null) {
    final existingMangaByKey = {
      for (final m in mangaRepository.getAll())
        if (m.link != null) restoreIdentity(m): m,
    };
    for (final tempManga in manga) {
      final oldId = tempManga.id;
      final key = restoreIdentity(tempManga);
      final existing = tempManga.link != null ? existingMangaByKey[key] : null;
      final remappedCategories = (tempManga.categories ?? [])
          .map((id) => oldToNewCategoryId[id])
          .whereType<int>()
          .toList();
      if (existing != null) {
        if (existing.itemType == ItemType.anime) {
          if (existing.animeFetchType == null) {
            existing.animeParentUrl = tempManga.animeParentUrl;
          }
          existing.animeFetchType ??= tempManga.animeFetchType;
          existing.seasonNumber ??= tempManga.seasonNumber;
          existing.seasonSourceOrder ??= tempManga.seasonSourceOrder;
          existing.seasonFlags ??= tempManga.seasonFlags;
          existing.backgroundUrl ??= tempManga.backgroundUrl;
        }
        existing.favorite =
            existing.favorite == true || tempManga.favorite == true;
        existing.categories = {
          ...?existing.categories,
          ...remappedCategories,
        }.toList();
        mangaRepository.putSync(existing);
        if (oldId != null) oldToNewMangaId[oldId] = existing.id!;
        continue;
      }
      final originalSourceName = tempManga.source ?? "Unknown";
      final decidedSourceId = sourceDecisions[originalSourceName];
      final boundSource = decidedSourceId != null
          ? sourceRepository.getById(decidedSourceId)
          : installedSourcesFor(tempManga.itemType).firstWhereOrNull(
              (s) => s.name?.toLowerCase() == originalSourceName.toLowerCase(),
            );
      tempManga.id = null;
      tempManga.categories = remappedCategories;
      tempManga.favorite ??= true;
      if (boundSource != null) {
        tempManga.sourceId = boundSource.id;
        tempManga.source = boundSource.name;
      } else {
        tempManga.sourceId = null;
      }
      mangaRepository.putSync(tempManga);
      if (oldId != null) oldToNewMangaId[oldId] = tempManga.id!;
      newMangaIds.add(tempManga.id!);
    }
  }

  final oldToNewChapterId = <int, int>{};
  if (chapters != null) {
    final existingUrlsByMangaId = <int, Set<String>>{};
    for (final tempChapter in chapters) {
      final newMangaId = tempChapter.mangaId != null
          ? oldToNewMangaId[tempChapter.mangaId]
          : null;
      if (newMangaId == null) continue;
      // Only ever landed on genuinely new manga above - an existing manga's
      // own chapters (with real read/download state) are left untouched.
      if (!newMangaIds.contains(newMangaId)) continue;
      final existingUrls = existingUrlsByMangaId.putIfAbsent(
        newMangaId,
        () => chapterRepository
            .getAllByMangaId(newMangaId)
            .map((c) => c.url)
            .whereType<String>()
            .toSet(),
      );
      if (tempChapter.url != null && existingUrls.contains(tempChapter.url)) {
        continue;
      }
      final mangaRef = mangaRepository.findById(newMangaId);
      if (mangaRef == null) continue;
      final oldId = tempChapter.id;
      tempChapter.id = null;
      tempChapter.mangaId = newMangaId;
      chapterRepository.putSync(tempChapter..manga.value = mangaRef);
      tempChapter.manga.saveSync();
      if (tempChapter.url != null) existingUrls.add(tempChapter.url!);
      if (oldId != null) oldToNewChapterId[oldId] = tempChapter.id!;
    }
  }

  if (history != null) {
    for (final tempHistory in history) {
      final newChapterId = tempHistory.chapterId != null
          ? oldToNewChapterId[tempHistory.chapterId]
          : null;
      final newMangaId = tempHistory.mangaId != null
          ? oldToNewMangaId[tempHistory.mangaId]
          : null;
      // Only for chapters we just inserted above - an existing chapter's
      // history already reflects this device's own progress.
      if (newChapterId == null || newMangaId == null) continue;
      final chapterRef = chapterRepository.findByIdSync(newChapterId);
      if (chapterRef == null) continue;
      tempHistory.id = null;
      tempHistory.mangaId = newMangaId;
      tempHistory.chapterId = newChapterId;
      historyRepository.putSync(tempHistory..chapter.value = chapterRef);
      tempHistory.chapter.saveSync();
    }
  }

  if (updates != null) {
    for (final tempUpdate in updates) {
      final newMangaId = tempUpdate.mangaId != null
          ? oldToNewMangaId[tempUpdate.mangaId]
          : null;
      if (newMangaId == null || !newMangaIds.contains(newMangaId)) continue;
      final chapter = chapterRepository.findByMangaIdAndName(
        newMangaId,
        tempUpdate.chapterName,
      );
      if (chapter == null) continue;
      tempUpdate.id = null;
      tempUpdate.mangaId = newMangaId;
      updateRepository.putSync(tempUpdate..chapter.value = chapter);
      tempUpdate.chapter.saveSync();
    }
  }
}

TachiBkImportPreview? legacyPreviewTachiBkImport(String path) {
  final backupType = peekBackupType(path);
  if (backupType != BackupType.mihon &&
      backupType != BackupType.aniyomi &&
      backupType != BackupType.neko) {
    return null;
  }
  final inputStream = InputFileStream(path);
  final content = GZipDecoder().decodeBytes(inputStream.toUint8List());
  inputStream.close();
  final backup = BackupMihon.create();
  backup.mergeFromCodedBufferReader(
    CodedBufferReader(content, sizeLimit: 250 << 20),
  );

  final existingCategoryNames = categoryRepository
      .getAll()
      .map((c) => c.name)
      .whereType<String>()
      .toSet();
  final categoryNames = <String>{for (var c in backup.backupCategories) c.name};

  final installedSourceNames = sourceRepository
      .getAll()
      .where((s) => s.isAdded ?? false)
      .map((s) => (s.itemType, s.name?.toLowerCase()))
      .toSet();
  final unmatchedSources = <String, ItemType>{};

  final existingMangaByLink = {
    for (var m in mangaRepository.getByItemType(ItemType.manga))
      if (m.link != null) m.link!: m,
  };
  int newSeries = 0, updatedSeries = 0, newChapters = 0;
  for (var m in backup.backupManga) {
    final sourceId = protoInt(m.source);
    final srcName =
        backup.backupSources
            .firstWhereOrNull((s) => protoInt(s.sourceId) == sourceId)
            ?.name ??
        "Unknown";
    if (!installedSourceNames.contains((
      ItemType.manga,
      srcName.toLowerCase(),
    ))) {
      unmatchedSources[srcName] = ItemType.manga;
    }
    final existing = existingMangaByLink[m.url];
    if (existing != null) {
      updatedSeries++;
      final existingUrls = chapterRepository
          .getAllByMangaId(existing.id)
          .map((c) => c.url)
          .whereType<String>()
          .toSet();
      newChapters += m.chapters
          .where((c) => !existingUrls.contains(c.url))
          .length;
    } else {
      newSeries++;
      newChapters += m.chapters.length;
    }
  }

  if (backupType == BackupType.aniyomi) {
    final backupAnime = BackupAniyomi.fromBuffer(content);
    final animeCategories = backupAnime.backupAnimeCategories.isNotEmpty
        ? backupAnime.backupAnimeCategories
        : backupAnime.legacyBackupAnimeCategories;
    final animeEntries = backupAnime.backupAnime.isNotEmpty
        ? backupAnime.backupAnime
        : backupAnime.legacyBackupAnime;
    final animeSources = backupAnime.backupAnimeSources.isNotEmpty
        ? backupAnime.backupAnimeSources
        : backupAnime.legacyBackupAnimeSources;
    categoryNames.addAll(animeCategories.map((c) => c.name));
    final existingAnimeByLink = {
      for (var m in mangaRepository.getByItemType(ItemType.anime))
        if (m.link != null) m.link!: m,
    };
    for (var a in animeEntries) {
      final sourceId = protoInt(a.source);
      final srcName =
          animeSources
              .firstWhereOrNull((s) => protoInt(s.sourceId) == sourceId)
              ?.name ??
          "Unknown";
      if (!installedSourceNames.contains((
        ItemType.anime,
        srcName.toLowerCase(),
      ))) {
        unmatchedSources[srcName] = ItemType.anime;
      }
      final existing = existingAnimeByLink[a.url];
      if (existing != null) {
        updatedSeries++;
        final existingUrls = chapterRepository
            .getAllByMangaId(existing.id)
            .map((c) => c.url)
            .whereType<String>()
            .toSet();
        newChapters += a.episodes
            .where((c) => !existingUrls.contains(c.url))
            .length;
      } else {
        newSeries++;
        newChapters += a.episodes.length;
      }
    }
  }

  return TachiBkImportPreview(
    conflictingCategories: categoryNames
        .where(existingCategoryNames.contains)
        .toList(),
    unmatchedSourceNames: unmatchedSources,
    newSeriesCount: newSeries,
    updatedSeriesCount: updatedSeries,
    newChapterCount: newChapters,
  );
}

List<Source> installedSourcesFor(ItemType itemType) => sourceRepository
    .getAll()
    .where((s) => s.itemType == itemType && (s.isAdded ?? false))
    .toList();

/// Same preview shape as previewTachiBkImport, but for the native
/// mangayomi backup format - already-decoded (and, for encrypted backups,
/// already-decrypted) JSON rather than a path to re-read from disk.
TachiBkImportPreview legacyPreviewMangayomiBackup(Map<String, dynamic> backup) {
  final mangaList = (backup["manga"] as List?)
      ?.map((e) => Manga.fromJson(e)..itemType = convertToItemType(e))
      .toList();
  final chapterList = (backup["chapters"] as List?)
      ?.map((e) => Chapter.fromJson(e))
      .toList();
  final categoryList = (backup["categories"] as List?)
      ?.map(
        (e) => Category.fromJson(e)..forItemType = convertToItemTypeCategory(e),
      )
      .toList();

  final existingCategoryNames = categoryRepository
      .getAll()
      .map((c) => c.name)
      .whereType<String>()
      .toSet();
  final categoryNames = <String>{
    for (final c in categoryList ?? <Category>[])
      if (c.name != null) c.name!,
  };

  final installedSourceNames = sourceRepository
      .getAll()
      .where((s) => s.isAdded ?? false)
      .map((s) => (s.itemType, s.name?.toLowerCase()))
      .toSet();
  final unmatchedSources = <String, ItemType>{};

  final existingMangaByKey = {
    for (final m in mangaRepository.getAll())
      if (m.link != null) '${m.itemType.index}|${m.link}': m,
  };
  final chaptersByMangaId = <int, List<Chapter>>{};
  for (final c in chapterList ?? <Chapter>[]) {
    if (c.mangaId == null) continue;
    chaptersByMangaId.putIfAbsent(c.mangaId!, () => []).add(c);
  }

  int newSeries = 0, updatedSeries = 0, newChapters = 0;
  for (final m in mangaList ?? <Manga>[]) {
    final srcName = m.source ?? "Unknown";
    if (!installedSourceNames.contains((m.itemType, srcName.toLowerCase()))) {
      unmatchedSources[srcName] = m.itemType;
    }
    final key = '${m.itemType.index}|${m.link}';
    final existing = m.link != null ? existingMangaByKey[key] : null;
    final mangaChapters = m.id != null
        ? chaptersByMangaId[m.id!] ?? const <Chapter>[]
        : const <Chapter>[];
    if (existing != null) {
      updatedSeries++;
      final existingUrls = chapterRepository
          .getAllByMangaId(existing.id)
          .map((c) => c.url)
          .whereType<String>()
          .toSet();
      newChapters += mangaChapters
          .where((c) => c.url != null && !existingUrls.contains(c.url))
          .length;
    } else {
      newSeries++;
      newChapters += mangaChapters.length;
    }
  }

  return TachiBkImportPreview(
    conflictingCategories: categoryNames
        .where(existingCategoryNames.contains)
        .toList(),
    unmatchedSourceNames: unmatchedSources,
    newSeriesCount: newSeries,
    updatedSeriesCount: updatedSeries,
    newChapterCount: newChapters,
  );
}
