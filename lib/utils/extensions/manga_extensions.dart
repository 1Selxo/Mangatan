import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/services/epub_chapter_metadata.dart';
import 'package:mangayomi/utils/chapter_recognition.dart';

List<Chapter> sortChaptersForDisplay({
  required Iterable<Chapter> chapters,
  required String mangaTitle,
  required int sortIndex,
  required bool reverse,
}) {
  final list = chapters.toList();
  final recognition = ChapterRecognition();
  final numCache = <Chapter, double>{};
  double chapterNumber(Chapter chapter) =>
      numCache[chapter] ??= recognition.resolveChapterNumber(
        mangaTitle,
        chapter.name ?? '',
        sourceChapterNumber: chapter.chapterNumber,
      );

  switch (sortIndex) {
    case 0:
      list.sort((a, b) {
        final scanlatorOrder = (a.scanlator ?? '').compareTo(b.scanlator ?? '');
        if (scanlatorOrder != 0) return scanlatorOrder;
        return chapterNumber(a).compareTo(chapterNumber(b));
      });
      break;
    case 2:
      list.sort(
        (a, b) => (int.tryParse(a.dateUpload ?? '') ?? 0).compareTo(
          int.tryParse(b.dateUpload ?? '') ?? 0,
        ),
      );
      break;
    case 3:
      list.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      break;
    case 1:
    default:
      list.sort((a, b) => chapterNumber(a).compareTo(chapterNumber(b)));
      break;
  }

  return reverse ? list : list.reversed.toList();
}

extension MangaExtensions on Manga {
  /// Number of unread chapters, excluding chapters from scanlators the user has
  /// filtered out for this manga. Mirrors the chapter list's scanlator filter,
  /// so the library "unread" badge and the unread sort reflect what the user
  /// actually sees rather than counting duplicate chapters from hidden
  /// scanlators (#796).
  int get unreadChaptersCount {
    final filter = isar.settings
        .getSync(227)
        ?.filterScanlatorList
        ?.where((e) => e.mangaId == id)
        .firstOrNull
        ?.scanlators;
    if (filter == null || filter.isEmpty) {
      return chapters.where((c) => !(c.isRead ?? false)).length;
    }
    return chapters
        .where((c) => !(c.isRead ?? false) && !filter.contains(c.scanlator))
        .length;
  }

  /// Filtered chapters respecting the user's active filters (unread,
  /// bookmarked, downloaded, scanlator). Sorted by chapter number ascending.
  /// Base list — no user-chosen sort, no deduplication.
  List<Chapter> getFilteredChapters({Iterable<Chapter>? sourceChapters}) {
    final settings = isar.settings.getSync(227)!;

    final filterUnread =
        (settings.chapterFilterUnreadList!
                    .where((e) => e.mangaId == id)
                    .firstOrNull ??
                ChapterFilterUnread(mangaId: id, type: 0))
            .type!;

    final filterBookmarked =
        (settings.chapterFilterBookmarkedList!
                    .where((e) => e.mangaId == id)
                    .firstOrNull ??
                ChapterFilterBookmarked(mangaId: id, type: 0))
            .type!;

    final filterDownloaded =
        (settings.chapterFilterDownloadedList!
                    .where((e) => e.mangaId == id)
                    .firstOrNull ??
                ChapterFilterDownloaded(mangaId: id, type: 0))
            .type!;

    final scanlators = settings.filterScanlatorList ?? [];
    final filter = scanlators.where((e) => e.mangaId == id);
    final filterScanlator = filter.firstOrNull?.scanlators ?? [];
    final recognition = ChapterRecognition();
    final mangaTitle = name ?? '';

    // Memoize so each chapter name is parsed at most once during the sort.
    final numCache = <Chapter, double>{};
    double chapNum(Chapter c) =>
        numCache[c] ??= recognition.resolveChapterNumber(
          mangaTitle,
          c.name ?? '',
          sourceChapterNumber: c.chapterNumber,
        );

    // Sort by chapter number — DB insertion order is NOT guaranteed to be ascending
    final chapterSource = sourceChapters ?? chapters;
    final data = chapterSource.toList()
      ..sort((a, b) => chapNum(a).compareTo(chapNum(b)));

    if (isLocalEpubManga(this)) {
      data
        ..clear()
        ..addAll(epubNavigationChaptersInSpineOrder(chapterSource));
    }

    final chapterIds = data.map((c) => c.id).whereType<int>().toList();
    final downloadedIds = (filterDownloaded == 0 || chapterIds.isEmpty)
        ? const <int>{}
        : isar.downloads
              .filter()
              .anyOf(chapterIds, (q, id) => q.idEqualTo(id))
              .isDownloadEqualTo(true)
              .findAllSync()
              .map((d) => d.id!)
              .toSet();

    return data
        .where(
          (e) => filterUnread == 1
              ? e.isRead == false
              : filterUnread == 2
              ? e.isRead == true
              : true,
        )
        .where(
          (e) => filterBookmarked == 1
              ? e.isBookmarked == true
              : filterBookmarked == 2
              ? e.isBookmarked == false
              : true,
        )
        .where((e) {
          if (filterDownloaded == 0) return true;
          final dl = downloadedIds.contains(e.id);
          return filterDownloaded == 1 ? dl : !dl;
        })
        .where((e) => !filterScanlator.contains(e.scanlator))
        .toList();
  }

  /// Filtered chapters for display in the chapter list UI: same filters as
  /// [getFilteredChapters] with the user's chosen sort order and direction applied.
  List<Chapter> getSortedFilteredChapters({Iterable<Chapter>? sourceChapters}) {
    final settings = isar.settings.getSync(227)!;

    final sortChapterEntry =
        (settings.sortChapterList ?? const [])
            .where((e) => e.mangaId == id)
            .firstOrNull ??
        SortChapter(mangaId: id, index: 1);

    // Build on getFilteredChapters so filter logic lives in one place.
    return sortChaptersForDisplay(
      chapters: getFilteredChapters(sourceChapters: sourceChapters),
      mangaTitle: name ?? '',
      sortIndex: sortChapterEntry.index ?? 1,
      reverse: sortChapterEntry.reverse ?? false,
    );
  }

  /// Filtered chapters ready for sequential reading: same filters as
  /// [getFilteredChapters] but with duplicate chapter numbers collapsed to a
  /// single entry so the reader advances to the next story chapter rather than
  /// another scanlator's copy of the same one.
  List<Chapter> getChapterListForReading({Iterable<Chapter>? sourceChapters}) {
    final list = getFilteredChapters(sourceChapters: sourceChapters);
    if (isLocalEpubManga(this)) return list;
    final mangaTitle = name ?? '';
    final recognition = ChapterRecognition();
    final seen = <double>{};
    return list.where((c) {
      final number = recognition.resolveChapterNumber(
        mangaTitle,
        c.name ?? '',
        sourceChapterNumber: c.chapterNumber,
      );
      return number <= 0 || seen.add(number);
    }).toList();
  }
}
