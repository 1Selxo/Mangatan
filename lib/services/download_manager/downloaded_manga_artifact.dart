import 'dart:io';

import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/utils/reg_exp_matcher.dart';
import 'package:mangayomi/utils/extensions/string_extensions.dart';
import 'package:path/path.dart' as p;

String downloadedMangaChapterBaseName(Chapter chapter) {
  return (chapter.name ?? '').replaceForbiddenCharacters(' ');
}

File downloadedMangaChapterCbz(Directory mangaDirectory, Chapter chapter) {
  return File(
    p.join(
      mangaDirectory.path,
      '${downloadedMangaChapterBaseName(chapter)}.cbz',
    ),
  );
}

/// Counts the contiguous image pages created by the manga downloader.
///
/// A completed folder uses fixed `001.jpg`, `002.jpg`, ... names. Stopping at
/// the first gap prevents a damaged or incomplete folder from being treated as
/// a usable offline chapter.
Future<int> downloadedMangaChapterImagePageCount(
  Directory chapterDirectory,
) async {
  final pageNames =
      (await chapterDirectory
              .list()
              .where(
                (entity) =>
                    entity is File &&
                    p.extension(entity.path).toLowerCase() == '.jpg',
              )
              .cast<File>()
              .map((file) => p.basename(file.path))
              .toList())
          .toSet();
  var count = 0;
  while (pageNames.remove('${padIndex(count)}.jpg')) {
    count++;
  }
  return pageNames.isEmpty ? count : 0;
}
