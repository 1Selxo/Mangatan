import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/src/rust/api/epub.dart';
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

/// Reconciles old local imports with the parser's spine/TOC metadata.
///
/// Existing rows are updated in place so bookmarks and reading progress are
/// retained. Raw internal spine rows stay in Isar for seamless page turns,
/// while only navigation rows are exposed by the chapter-list extension.
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
    if (entry.value.every(isManagedEpubChapter)) continue;

    EpubNovel book;
    try {
      book = await parseEpubFromPath(epubPath: entry.key, fullData: true);
    } catch (_) {
      continue;
    }

    final oldRows = entry.value
      ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    final updates = <Chapter>[];
    final usedRows = <Chapter>{};
    for (final epubChapter in book.chapters) {
      Chapter? chapter;
      for (final candidate in oldRows) {
        if (usedRows.contains(candidate)) continue;
        if (_epubReferencesMatch(candidate.url, epubChapter.path) ||
            _epubReferencesMatch(candidate.url, epubChapter.href)) {
          chapter = candidate;
          break;
        }
      }
      chapter ??= oldRows.cast<Chapter?>().firstWhere(
        (candidate) =>
            candidate != null &&
            !usedRows.contains(candidate) &&
            int.tryParse(candidate.dateUpload ?? '') == epubChapter.spineIndex,
        orElse: () => null,
      );
      if (chapter == null && epubChapter.isNavigationEntry) {
        chapter = oldRows.cast<Chapter?>().firstWhere(
          (candidate) =>
              candidate != null &&
              !usedRows.contains(candidate) &&
              (candidate.url?.isEmpty ?? true),
          orElse: () => null,
        );
      }
      chapter ??= Chapter(
        mangaId: mangaId,
        name: epubChapter.name,
        archivePath: entry.key,
        url: epubChapter.path,
      )..manga.value = manga;
      usedRows.add(chapter);

      chapter
        ..name = epubChapter.name
        ..url = epubChapter.path
        ..archivePath = entry.key
        ..dateUpload = epubChapter.spineIndex.toString()
        ..description = epubChapterMetadata(
          spineIndex: epubChapter.spineIndex,
          navigationEntry: epubChapter.isNavigationEntry,
        )
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      updates.add(chapter);
    }

    for (final stale in oldRows.where((row) => !usedRows.contains(row))) {
      stale
        ..description = epubChapterMetadata(
          spineIndex: -1,
          navigationEntry: false,
        )
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      updates.add(stale);
    }

    if (updates.isEmpty) continue;
    await isar.writeTxn(() async {
      await isar.chapters.putAll(updates);
      for (final chapter in updates) {
        if (!chapter.manga.isLoaded || chapter.manga.value == null) {
          chapter.manga.value = manga;
        }
        await chapter.manga.save();
      }
    });
  }
}

bool _epubReferencesMatch(String? left, String right) {
  final normalizedLeft = _normalizeEpubReference(left);
  final normalizedRight = _normalizeEpubReference(right);
  if (normalizedLeft.isEmpty || normalizedRight.isEmpty) return false;
  return normalizedLeft == normalizedRight ||
      normalizedLeft.endsWith('/$normalizedRight') ||
      normalizedRight.endsWith('/$normalizedLeft');
}

String _normalizeEpubReference(String? value) {
  if (value == null || value.isEmpty) return '';
  final withoutSuffix = value.split('#').first.split('?').first;
  String decoded;
  try {
    decoded = Uri.decodeComponent(withoutSuffix);
  } catch (_) {
    decoded = withoutSuffix;
  }
  final parts = <String>[];
  for (final part in decoded.replaceAll('\\', '/').split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(part);
    }
  }
  return parts.join('/');
}
