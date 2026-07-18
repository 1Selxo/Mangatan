import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/services/sync/chimahon_local_chapter_overlay_service.dart';
import 'package:mangayomi/services/sync/chimahon_local_chapter_policy.dart';

void main() {
  late Directory databaseDirectory;
  late Isar database;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await _isarLibraryPath()},
    );
  });

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'mangatan-local-overlay-',
    );
    database = await Isar.open(
      [
        MangaSchema,
        ChapterSchema,
        HistorySchema,
        DownloadSchema,
        EpubBookProgressSchema,
      ],
      directory: databaseDirectory.path,
      name: 'chimahon_local_chapter_overlay_service_test',
    );
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test(
    'deletes the local file and row and clears the final overlay flag',
    () async {
      final archive = File('${databaseDirectory.path}/manual.cbz');
      await archive.writeAsBytes(const [1, 2, 3]);
      late Manga manga;
      late Chapter portable;
      late Chapter manual;
      late History history;

      database.writeTxnSync(() {
        manga = _manga()..hasLocalChapterOverlay = true;
        database.mangas.putSync(manga);
        portable = _chapter(manga, name: 'Source chapter', url: '/chapter-1');
        manual = _chapter(
          manga,
          name: 'Manual chapter',
          archivePath: archive.path,
        );
        database.chapters.putAllSync([portable, manual]);
        portable.manga.saveSync();
        manual.manga.saveSync();
        history = History(
          itemType: ItemType.manga,
          chapterId: manual.id,
          mangaId: manga.id,
          date: '100',
        )..chapter.value = manual;
        database.historys.putSync(history);
        history.chapter.saveSync();
        database.downloads.putSync(
          Download(
            id: manual.id,
            succeeded: 1,
            failed: 0,
            total: 1,
            isDownload: true,
            isStartDownload: false,
          ),
        );
        database.epubBookProgress.putSync(
          EpubBookProgress(
            mangaId: manga.id!,
            archivePath: archive.path,
            title: 'Manual chapter',
          ),
        );
      });

      final result = await const ChimahonLocalChapterOverlayService()
          .deleteSelected(
            database: database,
            manga: manga,
            selectedChapters: [manual],
          );

      expect(result.deleted.map((chapter) => chapter.id), [manual.id]);
      expect(result.failed, isEmpty);
      expect(result.hasRemainingOverlay, isFalse);
      expect(await archive.exists(), isFalse);
      expect(database.chapters.getSync(manual.id!), isNull);
      expect(database.chapters.getSync(portable.id!), isNotNull);
      expect(database.historys.getSync(history.id!), isNull);
      expect(database.downloads.getSync(manual.id!), isNull);
      expect(
        database.epubBookProgress
            .filter()
            .mangaIdEqualTo(manga.id!)
            .findAllSync(),
        isEmpty,
      );
      final storedManga = database.mangas.getSync(manga.id!);
      expect(storedManga?.hasLocalChapterOverlay, isFalse);
      expect(storedManga?.isVisibleInLibrary, isFalse);
    },
  );

  test(
    'keeps a shared file and flag until its final local row is deleted',
    () async {
      final archive = File('${databaseDirectory.path}/shared.epub');
      await archive.writeAsBytes(const [4, 5, 6]);
      late Manga manga;
      late Chapter first;
      late Chapter second;

      database.writeTxnSync(() {
        manga = _manga()..hasLocalChapterOverlay = true;
        database.mangas.putSync(manga);
        first = _chapter(manga, name: 'Section 1', archivePath: archive.path);
        second = _chapter(manga, name: 'Section 2', archivePath: archive.path);
        database.chapters.putAllSync([first, second]);
        first.manga.saveSync();
        second.manga.saveSync();
      });

      final firstResult = await const ChimahonLocalChapterOverlayService()
          .deleteSelected(
            database: database,
            manga: manga,
            selectedChapters: [first],
          );
      expect(firstResult.hasRemainingOverlay, isTrue);
      expect(await archive.exists(), isTrue);
      expect(database.chapters.getSync(first.id!), isNull);
      expect(database.chapters.getSync(second.id!), isNotNull);
      expect(
        database.mangas.getSync(manga.id!)?.hasLocalChapterOverlay,
        isTrue,
      );

      final secondResult = await const ChimahonLocalChapterOverlayService()
          .deleteSelected(
            database: database,
            manga: manga,
            selectedChapters: [second],
          );
      expect(secondResult.hasRemainingOverlay, isFalse);
      expect(await archive.exists(), isFalse);
      expect(database.chapters.getSync(second.id!), isNull);
      expect(
        database.mangas.getSync(manga.id!)?.hasLocalChapterOverlay,
        isFalse,
      );
    },
  );

  test(
    'refuses an archivePath directory and retains its row and flag',
    () async {
      final directory = Directory('${databaseDirectory.path}/not-an-archive');
      await directory.create();
      await File('${directory.path}/page.jpg').writeAsBytes(const [1]);
      late Manga manga;
      late Chapter manual;

      database.writeTxnSync(() {
        manga = _manga()..hasLocalChapterOverlay = true;
        database.mangas.putSync(manga);
        manual = _chapter(
          manga,
          name: 'Malformed local chapter',
          archivePath: directory.path,
        );
        database.chapters.putSync(manual);
        manual.manga.saveSync();
      });

      final result = await const ChimahonLocalChapterOverlayService()
          .deleteSelected(
            database: database,
            manga: manga,
            selectedChapters: [manual],
          );

      expect(result.deleted, isEmpty);
      expect(result.failed.map((chapter) => chapter.id), [manual.id]);
      expect(await directory.exists(), isTrue);
      expect(database.chapters.getSync(manual.id!), isNotNull);
      expect(
        database.mangas.getSync(manga.id!)?.hasLocalChapterOverlay,
        isTrue,
      );
    },
  );

  test('resolves Windows file URIs without using host path rules', () {
    final chapter = Chapter(
      mangaId: 1,
      name: 'Windows chapter',
      url: 'file:///C:/Users/Reader/Chapter%201.cbz',
    );

    expect(
      const ChimahonLocalChapterPolicy().deviceLocalPath(
        chapter,
        windows: true,
      ),
      r'C:\Users\Reader\Chapter 1.cbz',
    );
  });
}

Manga _manga() => Manga(
  source: 'Remote source',
  sourceId: 1,
  author: '',
  artist: '',
  genre: const [],
  imageUrl: '',
  lang: 'ja',
  link: '/title',
  name: 'Title',
  status: Status.ongoing,
  description: '',
  favorite: false,
);

Chapter _chapter(
  Manga manga, {
  required String name,
  String url = '',
  String archivePath = '',
}) =>
    Chapter(mangaId: manga.id, name: name, url: url, archivePath: archivePath)
      ..manga.value = manga;

Future<String> _isarLibraryPath() async {
  final packageConfig = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  final config = jsonDecode(await packageConfig.readAsString());
  final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
  final package = packages
      .where((entry) => entry['name'] == 'isar_community_flutter_libs')
      .firstOrNull;
  if (package == null) {
    throw StateError('Could not locate isar_community_flutter_libs');
  }
  final rootUri = Uri.parse(package['rootUri'] as String);
  final packageDirectory = Directory.fromUri(
    rootUri.isAbsolute ? rootUri : packageConfig.parent.uri.resolveUri(rootUri),
  );
  if (Platform.isMacOS) {
    return '${packageDirectory.path}/macos/libisar.dylib';
  }
  if (Platform.isLinux) {
    return '${packageDirectory.path}/linux/libisar.so';
  }
  if (Platform.isWindows) {
    return '${packageDirectory.path}/windows/libisar.dll';
  }
  throw UnsupportedError('Isar test is unsupported on this platform');
}
