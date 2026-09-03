import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/more/download_queue/download_queue_screen.dart';

import '../../../test_utils/isar_library.dart';

void main() {
  late Directory databaseDirectory;
  late Isar database;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
  });

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'mangatan-non-library-download-',
    );
    database = await Isar.open(
      [MangaSchema, ChapterSchema, DownloadSchema],
      directory: databaseDirectory.path,
      name: 'non_library_download_test',
    );
    app.isar = database;
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test(
    'completed download resolves after restart without adding to library',
    () {
      final manga = Manga(
        id: 10,
        source: 'Offline source',
        author: '',
        artist: '',
        genre: const [],
        imageUrl: null,
        lang: 'en',
        link: '/offline-title',
        name: 'Offline title',
        status: Status.ongoing,
        description: '',
        sourceId: 99,
        favorite: false,
      );
      final chapter = Chapter(
        id: 20,
        mangaId: manga.id,
        name: 'Chapter 1',
        url: '/chapter-1',
      )..manga.value = manga;
      final download = Download(
        id: chapter.id,
        succeeded: 1,
        failed: 0,
        total: 1,
        isDownload: true,
        isStartDownload: true,
      )..chapter.value = chapter;

      database.writeTxnSync(() {
        database.mangas.putSync(manga);
        database.chapters.putSync(chapter);
        chapter.manga.saveSync();
        database.downloads.putSync(download);
        download.chapter.saveSync();
      });

      final persisted = database.downloads.getSync(chapter.id!)!;
      expect(persisted.chapter.isLoaded, isFalse);

      final resolved = resolveDownloadedChapter(persisted);

      expect(resolved?.manga.name, 'Offline title');
      expect(resolved?.chapter.name, 'Chapter 1');
      expect(resolved?.download.isDownload, isTrue);
      expect(database.mangas.getSync(manga.id!)?.favorite, isFalse);
    },
  );
}
