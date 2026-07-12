import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:path/path.dart' as p;

const _epubChapterMetadataPrefix = 'mangatan:epub:v3:';

String epubChapterMetadata({
  required int spineIndex,
  required bool navigationEntry,
}) =>
    '$_epubChapterMetadataPrefix'
    '${navigationEntry ? 'navigation' : 'internal'}:'
    '$spineIndex';

String epubUnsplitChapterMetadata() => '${_epubChapterMetadataPrefix}unsplit:0';

bool isManagedEpubChapter(Chapter chapter) =>
    chapter.description?.startsWith(_epubChapterMetadataPrefix) ?? false;

bool isInternalEpubSpineChapter(Chapter chapter) =>
    chapter.description?.startsWith('${_epubChapterMetadataPrefix}internal:') ??
    false;

bool isEpubNavigationChapter(Chapter chapter) =>
    chapter.description?.startsWith(
      '${_epubChapterMetadataPrefix}navigation:',
    ) ??
    false;

bool isUnsplitEpubChapter(Chapter chapter) =>
    chapter.description?.startsWith('${_epubChapterMetadataPrefix}unsplit:') ??
    false;

int? epubChapterSpineIndex(Chapter chapter) {
  final description = chapter.description;
  if (description != null &&
      description.startsWith(_epubChapterMetadataPrefix)) {
    return int.tryParse(description.split(':').last);
  }
  return int.tryParse(chapter.dateUpload ?? '');
}

List<Chapter> epubNavigationChaptersInSpineOrder(Iterable<Chapter> chapters) {
  final all = chapters.toList();
  final byArchive = <String, List<Chapter>>{};
  for (final chapter in all) {
    final archive = p.normalize(chapter.archivePath ?? '').toLowerCase();
    byArchive.putIfAbsent(archive, () => []).add(chapter);
  }

  final groups = byArchive.entries.toList()
    ..sort((a, b) {
      int firstId(List<Chapter> rows) => rows
          .map((row) => row.id ?? 0x7fffffff)
          .reduce((left, right) => left < right ? left : right);
      final byImportOrder = firstId(a.value).compareTo(firstId(b.value));
      return byImportOrder != 0 ? byImportOrder : a.key.compareTo(b.key);
    });

  final result = <Chapter>[];
  for (final group in groups) {
    final unsplitRows = group.value.where(isUnsplitEpubChapter).toList();
    if (unsplitRows.isNotEmpty) {
      // A legacy import is intentionally one reader entry per EPUB. If stale
      // spine rows are present beside it, never surface them again.
      unsplitRows.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
      result.add(unsplitRows.first);
      continue;
    }
    final hasManagedRows = group.value.any(isManagedEpubChapter);
    final visibleRows =
        group.value
            .where(
              (chapter) => hasManagedRows
                  ? isEpubNavigationChapter(chapter) ||
                        isUnsplitEpubChapter(chapter)
                  : !isInternalEpubSpineChapter(chapter),
            )
            .toList()
          ..sort((a, b) {
            final aIndex = epubChapterSpineIndex(a);
            final bIndex = epubChapterSpineIndex(b);
            if (aIndex != null && bIndex != null) {
              final order = aIndex.compareTo(bIndex);
              if (order != 0) return order;
            } else if (aIndex != null) {
              return -1;
            } else if (bIndex != null) {
              return 1;
            }
            return (a.id ?? 0).compareTo(b.id ?? 0);
          });
    result.addAll(visibleRows);
  }
  return result;
}

bool isLocalEpubManga(Manga manga) =>
    manga.itemType == ItemType.novel && (manga.isLocalArchive ?? false);

/// Restores the legacy one-entry-per-EPUB import contract.
///
/// The short-lived spine migration expanded old local EPUBs merely by opening
/// their detail screen. Local import no longer offers that mode, so normalize
/// both old rows and rows produced by that migration back to one chapter.
Future<void> repairLocalEpubChapterMetadata(Manga manga) async {
  if (manga.itemType != ItemType.novel || !(manga.isLocalArchive ?? false)) {
    return;
  }
  final mangaId = manga.id;
  if (mangaId == null) return;

  final existing = await isar.chapters
      .filter()
      .mangaIdEqualTo(mangaId)
      .findAll();
  final epubRows = existing
      .where(
        (chapter) =>
            p.extension(chapter.archivePath ?? '').toLowerCase() == '.epub',
      )
      .toList();
  if (epubRows.isEmpty) return;

  final byArchive = <String, List<Chapter>>{};
  for (final chapter in epubRows) {
    final archive = chapter.archivePath;
    if (archive == null || archive.isEmpty) continue;
    byArchive.putIfAbsent(archive, () => []).add(chapter);
  }

  for (final entry in byArchive.entries) {
    final rows = entry.value..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    if (rows.length == 1 && isUnsplitEpubChapter(rows.single)) continue;

    // The earliest row is the original imported chapter when a legacy row was
    // expanded. Retain its identity so history/bookmarks stay attached.
    final canonical = rows.first;
    canonical
      ..mangaId = mangaId
      ..manga.value = manga
      ..name = manga.name?.trim().isNotEmpty == true
          ? manga.name
          : canonical.name
      ..archivePath = entry.key
      ..url = null
      ..dateUpload = '0'
      ..description = epubUnsplitChapterMetadata()
      ..updatedAt = DateTime.now().millisecondsSinceEpoch;
    final staleIds = rows
        .skip(1)
        .map((chapter) => chapter.id)
        .whereType<int>()
        .toList(growable: false);
    await isar.writeTxn(() async {
      await isar.chapters.put(canonical);
      if (staleIds.isNotEmpty) await isar.chapters.deleteAll(staleIds);
      await canonical.manga.save();
    });
  }
}
