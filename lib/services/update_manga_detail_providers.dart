import 'package:mangayomi/utils/chapter_recognition.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/repositories/chapter_repository.dart';
import 'package:mangayomi/repositories/manga_repository.dart';
import 'package:mangayomi/repositories/update_repository.dart';
import 'package:mangayomi/services/chapter_cache.dart';
import 'package:mangayomi/services/downloaded_chapter.dart';
import 'package:mangayomi/services/get_detail.dart';
import 'package:mangayomi/utils/extensions/string_extensions.dart';
import 'package:mangayomi/utils/fetch_interval.dart';
import 'package:mangayomi/utils/utils.dart';
import 'package:mangayomi/utils/error_toast.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/services/anime_seasons.dart';
import 'package:mangayomi/services/download_manager/download_gate.dart';
part 'update_manga_detail_providers.g.dart';

@riverpod
Future<dynamic> updateMangaDetail(
  Ref ref, {
  required int? mangaId,
  required bool isInit,
  bool showToast = true,
}) async {
  // Callers read this provider without listening to it, so Riverpod would
  // dispose it during the network request and every `ref.mounted` check below
  // would silently drop the fetched details. Stay alive until it finishes.
  final keepAlive = ref.keepAlive();
  try {
    final initialManga = mangaRepository.findById(mangaId!);
    if (initialManga == null) return;
    var manga = initialManga;

    manga.chapters.loadSync();

    if ((manga.isLocalArchive ?? false) ||
        (manga.chapters.isNotEmpty && isInit)) {
      return;
    }
    final source = getSource(
      manga.lang!,
      manga.source!,
      manga.sourceId,
      installedOnly: true,
    );
    if (source == null) return;
    final requestedLink = manga.link;
    final requestedSourceId = manga.sourceId;
    final requestedSource = manga.source;
    final requestedLang = manga.lang;
    final requestedItemType = manga.itemType;

    final getManga = await ref.read(
      getDetailProvider(url: manga.link!, source: source).future,
    );
    if (!ref.mounted) return;

    final genre =
        getManga.genre
            ?.map((e) => e.toString().trim())
            .toList()
            .toSet()
            .toList() ??
        [];

    final imgUrl = getManga.imageUrl.trimmedOrDefault(manga.imageUrl);
    final refreshedSourceTitle = getManga.name.trimmedOrDefault(
      manga.sourceTitle ?? manga.name,
    );
    final now = DateTime.now().millisecondsSinceEpoch;

    manga
      ..imageUrl = imgUrl == null
          ? null
          : imgUrl.startsWith('http')
          ? imgUrl
          : '${source.baseUrl ?? ''}/${imgUrl.getUrlWithoutDomain}'
      ..updateSourceTitle(refreshedSourceTitle)
      ..genre = (genre.isEmpty ? null : genre) ?? manga.genre ?? []
      ..author = getManga.author.trimmedOrDefault(manga.author) ?? ""
      ..artist = getManga.artist.trimmedOrDefault(manga.artist) ?? ""
      ..status = getManga.status == Status.unknown
          ? manga.status
          : getManga.status ?? Status.unknown
      ..description =
          getManga.description.trimmedOrDefault(manga.description) ?? ""
      ..link = getManga.link.trimmedOrDefault(manga.link)
      ..source = manga.source
      ..lang = manga.lang
      ..itemType = source.itemType
      ..lastUpdate = now
      ..updatedAt = now;

    manga
      ..animeFetchType = getManga.animeFetchType ?? manga.animeFetchType
      ..seasonNumber = getManga.seasonNumber ?? manga.seasonNumber
      ..backgroundUrl = getManga.backgroundUrl ?? manga.backgroundUrl;
    if (getManga.seasons != null) {
      final seasonIds = await storeAnimeSeasons(
        isar,
        manga,
        getManga.seasons!,
        sourceIsLocal: source.isLocal == true,
      );
      if (!ref.mounted) return;
      // Library refreshes also update each season's episodes and smart interval.
      // Initial browsing only fetches a season when it is opened.
      if (!isInit) {
        for (final id in seasonIds) {
          if (!ref.mounted) return;
          await ref.read(
            updateMangaDetailProvider(
              mangaId: id,
              isInit: false,
              showToast: showToast,
            ).future,
          );
          if (!ref.mounted) return;
        }
        // A series has no episodes of its own. Use the earliest child cadence
        // so smart library updates continue checking an actively airing season.
        final intervals = seasonIds
            .map((id) => mangaRepository.findById(id)?.smartUpdateDays)
            .whereType<int>();
        if (intervals.isNotEmpty) {
          final current = mangaRepository.findById(manga.id!);
          if (current != null) {
            current.smartUpdateDays = intervals.reduce((a, b) => a < b ? a : b);
            await mangaRepository.writeTransactionAsync(() async {
              await mangaRepository.putAsync(current);
            });
          }
        }
      }
      return;
    }

    final chaps = getManga.chapters;

    final metadata = manga;
    final aliases = <int, Chapter>{};
    await mangaRepository.writeTransactionAsync(() async {
      // Reading, another refresh, or source migration may have changed the
      // stored objects while the network request was in flight.
      final current = await mangaRepository.findByIdAsync(mangaId);
      if (current == null ||
          current.link != requestedLink ||
          current.sourceId != requestedSourceId ||
          current.source != requestedSource ||
          current.lang != requestedLang ||
          current.itemType != requestedItemType) {
        return;
      }
      final originalChapters = await chapterRepository.getAllByMangaIds([
        mangaId,
      ]);
      final consolidated = await chapterRepository.consolidateDuplicatesAsync(
        originalChapters,
        mangaName: current.name ?? '',
        now: now,
        isScheduled: isDownloadScheduled,
        resolveDirectories: downloadedMangaDirectories,
      );
      aliases.addAll(consolidated.canonicalById);
      current
        ..imageUrl = metadata.imageUrl
        // Storage paths include the work/chapter labels. Metadata changes must
        // not strand completed archives or partial download folders.
        ..name = consolidated.storageIds.isNotEmpty
            ? current.name
            : metadata.name
        ..genre = metadata.genre
        ..author = metadata.author
        ..artist = metadata.artist
        ..status = metadata.status
        ..description = metadata.description
        ..link = metadata.link
        ..itemType = metadata.itemType
        ..lastUpdate = now
        ..updatedAt = now;
      manga = current;
      final savedMangaId = await mangaRepository.putAsync(manga);

      if (chaps == null || chaps.isEmpty) return;

      final existingChapters = consolidated.chapters;
      final recognition = ChapterRecognition();

      // Season and episode together, never the episode alone. The episode
      // alone makes season 2 episode 1 the same chapter as season 1 episode 1,
      // so whichever arrives second is dropped before it reaches the library
      // and a two season show displays one season.
      //
      // Not parseChapterNumber either: that truncates, so 12, 12.1 and 12.5
      // all answer 12 and two of the three are dropped the same way.
      String? identityOf(Chapter c, {bool withScanlator = true}) {
        if (c.name == null) return null;
        return recognition.chapterIdentityKey(
          manga.name ?? '',
          c.name!,
          withScanlator ? (c.scanlator ?? '') : null,
        );
      }

      final existingByUrl = <String, Chapter>{};
      final existingByComposite = <String, Chapter>{};
      for (final c in originalChapters) {
        final candidate = consolidated.canonicalById[c.id] ?? c;
        final u = c.url?.trim();
        final urlKey = (u == null || u.isEmpty) ? null : u.getUrlWithoutDomain;
        final compositeKey = identityOf(c);

        final prior =
            (urlKey != null ? existingByUrl[urlKey] : null) ??
            (compositeKey != null ? existingByComposite[compositeKey] : null);
        if (prior == null) {
          if (urlKey != null) existingByUrl[urlKey] = candidate;
          if (compositeKey != null) {
            existingByComposite[compositeKey] = candidate;
          }
        } else {
          final priorHasState =
              (prior.isRead ?? false) || (prior.lastPageRead ?? '').isNotEmpty;
          final keep = priorHasState ? prior : candidate;
          if (urlKey != null) existingByUrl[urlKey] = keep;
          if (compositeKey != null) existingByComposite[compositeKey] = keep;
        }
      }

      // Keyed without the scanlator: the same episode from a different group
      // is still that episode, so read state carries. Keyed with the season
      // for the same reason as above.
      final readByEpisode = <String, bool>{};
      for (final c in existingChapters) {
        final key = identityOf(c, withScanlator: false);
        if (key != null) {
          readByEpisode[key] =
              (readByEpisode[key] ?? false) || (c.isRead ?? false);
        }
      }

      final newChapters = <Chapter>[];
      final seenKeys = <String>{};
      final chaptersToUpdate = <Chapter>[];

      for (final chap in chaps) {
        final url = chap.url?.trim();
        if (url == null || url.isEmpty) continue;
        final key = url.getUrlWithoutDomain;

        final compositeKey = chap.name == null
            ? null
            : recognition.chapterIdentityKey(
                manga.name!,
                chap.name!,
                chap.scanlator ?? '',
              );
        final episodeKey = chap.name == null
            ? null
            : recognition.chapterIdentityKey(manga.name!, chap.name!);

        if (!seenKeys.add(key)) continue;
        if (compositeKey != null && !seenKeys.add('c:$compositeKey')) {
          continue;
        }

        final existing =
            existingByUrl[key] ??
            (compositeKey != null ? existingByComposite[compositeKey] : null);

        if (existing == null) {
          final alreadyRead =
              episodeKey != null && (readByEpisode[episodeKey] ?? false);

          final newChapter = Chapter(
            name: chap.name!,
            url: url,
            dateUpload: chap.dateUpload == null
                ? now.toString()
                : chap.dateUpload.toString(),
            scanlator: chap.scanlator ?? '',
            chapterNumber: normalizeSourceChapterNumber(chap.chapterNumber),
            mangaId: savedMangaId,
            updatedAt: now,
            isFiller: chap.isFiller,
            thumbnailUrl: chap.thumbnailUrl,
            description: chap.description,
            downloadSize: chap.downloadSize,
            duration: chap.duration,
          )..manga.value = manga;

          if (alreadyRead) {
            newChapter.isRead = alreadyRead;
            newChapter.lastPageRead = "1";
          }

          existingByUrl[key] = newChapter;
          if (compositeKey != null) {
            existingByComposite[compositeKey] = newChapter;
          }

          newChapters.add(newChapter);
        } else {
          final active =
              consolidated.activeIds.contains(existing.id) ||
              isDownloadScheduled(existing.id);
          final stored =
              consolidated.storageIds.contains(existing.id) || active;
          if (!active && existing.url != url) {
            ChapterCache().remove(existing);
          }
          existing
            ..name = stored ? existing.name : chap.name
            ..url = active ? existing.url : url
            ..scanlator = stored ? existing.scanlator : chap.scanlator
            ..chapterNumber =
                normalizeSourceChapterNumber(chap.chapterNumber) ??
                normalizeSourceChapterNumber(existing.chapterNumber)
            ..updatedAt = now
            ..isFiller = chap.isFiller
            ..thumbnailUrl = chap.thumbnailUrl
            ..description = chap.description
            ..downloadSize = chap.downloadSize
            ..duration = chap.duration;
          chaptersToUpdate.add(existing);
        }
      }

      if (chaptersToUpdate.isNotEmpty) {
        await chapterRepository.putAllAsync(chaptersToUpdate);
      }
      if (consolidated.updates.isNotEmpty) {
        for (final update in consolidated.updates) {
          update.chapterName = update.chapter.value?.name;
        }
        await updateRepository.putAllAsync(consolidated.updates);
      }

      if (newChapters.isNotEmpty) {
        final hasExisting = existingChapters.isNotEmpty;

        final orderedNew = newChapters.reversed.toList();

        for (final chap in orderedNew) {
          chap.manga.value = manga;
        }

        await chapterRepository.putAllAsync(orderedNew);
        // Manga.chapters is the backlink of Chapter.manga, so linking the new
        // chapters from the manga's side writes the same links as saving each
        // chapter's link, in one database call instead of one per chapter.
        // The chapters are new, so they have no earlier link to reset.
        await manga.chapters.update(link: orderedNew);

        final updatesToInsert = <Update>[];
        for (final chap in orderedNew) {
          if (hasExisting && !(chap.isRead ?? false)) {
            updatesToInsert.add(
              Update(
                mangaId: savedMangaId,
                chapterName: chap.name,
                date: now.toString(),
                updatedAt: now,
              )..chapter.value = chap,
            );
          }
        }

        if (updatesToInsert.isNotEmpty) {
          await updateRepository.putAllAsync(updatesToInsert);
          await Future.wait([
            for (final upd in updatesToInsert) upd.chapter.save(),
          ]);
        }
      }

      final allChapters = newChapters.isEmpty
          ? existingChapters
          : [...existingChapters, ...newChapters];
      if (allChapters.isNotEmpty) {
        final interval = FetchInterval.calculateInterval(allChapters);
        manga
          ..id = savedMangaId
          ..smartUpdateDays = interval;
        await mangaRepository.putAsync(manga);
      }
    }, afterCommit: () => chapterRepository.publishAliases(aliases));
  } catch (e, s) {
    if (showToast) {
      toastError(e, stack: s, source: 'updateMangaDetail');
    } else {
      rethrow;
    }
  } finally {
    keepAlive.close();
  }
}
