import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/manga/archive_reader/models/models.dart';
import 'package:mangayomi/modules/manga/archive_reader/providers/archive_reader_providers.dart';
import 'package:mangayomi/services/epub_chapter_metadata.dart';
import 'package:mangayomi/src/rust/api/epub.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'local_archive.g.dart';

@riverpod
Future importArchivesFromFile(
  Ref ref,
  Manga? mManga, {
  required ItemType itemType,
  required bool init,
  bool splitChapters = false,
}) async {
  final keepAlive = ref.keepAlive();
  try {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: supportedLocalArchiveExtensions(itemType),
    );
    if (result == null) return;

    final filePaths = result.files
        .map((file) => file.path)
        .whereType<String>()
        .toList();
    await _importArchivesFromPaths(
      ref,
      mManga,
      filePaths: filePaths,
      itemType: itemType,
      init: init,
      splitChapters: splitChapters,
    );
  } finally {
    keepAlive.close();
  }
}

/// Imports paths supplied by a non-picker source, such as desktop drag-and-drop.
@riverpod
Future<void> importArchivesFromPaths(
  Ref ref,
  Manga? mManga, {
  required List<String> filePaths,
  required ItemType itemType,
  required bool init,
  bool splitChapters = false,
}) async {
  final keepAlive = ref.keepAlive();
  try {
    await _importArchivesFromPaths(
      ref,
      mManga,
      filePaths: filterSupportedLocalArchivePaths(filePaths, itemType),
      itemType: itemType,
      init: init,
      splitChapters: splitChapters,
    );
  } finally {
    keepAlive.close();
  }
}

Future<void> _importArchivesFromPaths(
  Ref ref,
  Manga? mManga, {
  required List<String> filePaths,
  required ItemType itemType,
  required bool init,
  required bool splitChapters,
}) async {
  if (filePaths.isEmpty) return;

  final dateNow = DateTime.now().millisecondsSinceEpoch;
  // Novel chapters are always persisted now. Keep honoring the legacy flag
  // in the shared import API so older callers remain source-compatible.
  final persistEpubChapters = itemType == ItemType.novel || splitChapters;
  final manga =
      mManga ??
      Manga(
        favorite: true,
        source: 'archive',
        author: '',
        itemType: itemType,
        genre: [],
        imageUrl: '',
        lang: '',
        link: '',
        name: localArchiveName(filePaths.first),
        dateAdded: dateNow,
        lastUpdate: dateNow,
        status: Status.unknown,
        description: '',
        isLocalArchive: true,
        artist: '',
        updatedAt: dateNow,
        sourceId: null,
      );

  for (final filePath in filePaths.reversed) {
    final (String, LocalExtensionType, Uint8List, String)? data =
        itemType == ItemType.manga
        ? await ref.watch(getArchivesDataFromFileProvider(filePath).future)
        : null;
    final name = localArchiveName(filePath);

    if (init && itemType == ItemType.manga) {
      manga.customCoverImage = data!.$3.getCoverImage;
    }
    await isar.writeTxn(() async {
      final mangaId = await isar.mangas.put(manga);
      final List<Chapter> chapters = [];
      if (itemType == ItemType.novel) {
        final book = await parseEpubFromPath(
          epubPath: filePath,
          fullData: persistEpubChapters,
        );

        if (book.cover != null) {
          await isar.mangas.put(
            manga..customCoverImage = book.cover!.getCoverImage,
          );
        }
        chapters.addAll(
          epubShortcutChapters(
            book: book,
            manga: manga,
            mangaId: mangaId,
            archivePath: filePath,
          ),
        );
        final existingProgress = await isar.epubBookProgress
            .filter()
            .mangaIdEqualTo(mangaId)
            .archivePathEqualTo(filePath)
            .findFirst();
        final progress =
            existingProgress ??
            EpubBookProgress(
              mangaId: mangaId,
              archivePath: filePath,
              title: book.name,
              author: book.author,
              lang: book.language,
            );
        progress
          ..title = book.name
          ..author = book.author;
        progress.lang ??= book.language;
        await isar.epubBookProgress.put(progress);
      } else {
        chapters.add(
          Chapter(
            name: itemType == ItemType.manga ? data!.$1 : name,
            archivePath: itemType == ItemType.manga ? data!.$4 : filePath,
            mangaId: manga.id,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )..manga.value = manga,
        );
      }
      for (final chapter in chapters) {
        await isar.chapters.put(chapter);
        await chapter.manga.save();
      }
    });
  }
}

List<String> supportedLocalArchiveExtensions(ItemType itemType) {
  return switch (itemType) {
    ItemType.manga => const ['cbz', 'zip'],
    ItemType.anime => const ['mp4', 'mov', 'avi', 'flv', 'wmv', 'mpeg', 'mkv'],
    ItemType.novel => const ['epub'],
  };
}

List<String> filterSupportedLocalArchivePaths(
  Iterable<String> filePaths,
  ItemType itemType,
) {
  final extensions = supportedLocalArchiveExtensions(itemType).toSet();
  return filePaths.where((filePath) {
    final name = filePath.split(RegExp(r'[/\\]')).last;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == name.length - 1) return false;
    return extensions.contains(name.substring(dotIndex + 1).toLowerCase());
  }).toList();
}

String localArchiveName(String path) {
  return path
      .split('/')
      .last
      .split("\\")
      .last
      .replaceAll(
        RegExp(
          r'\.(mp4|mov|avi|flv|wmv|mpeg|mkv|cbz|zip|cbt|tar|epub)$',
          caseSensitive: false,
        ),
        '',
      );
}

extension Uint8ListExtensions on Uint8List {
  Uint8List? get getCoverImage {
    final length = lengthInBytes / (1024 * 1024);
    if (length < 5) {
      return this;
    }
    botToast(
      "Cover image is larger than 5MB (${length.toStringAsFixed(2)}MB). Skipping cover image.",
    );
    return null;
  }
}
