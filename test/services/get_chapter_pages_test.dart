import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/services/get_chapter_pages.dart';
import 'package:path/path.dart' as p;

import '../test_utils/isar_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory databaseDirectory;
  late Directory downloadsDirectory;
  late Isar database;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
  });

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'mangatan-chapter-pages-db-',
    );
    downloadsDirectory = await Directory.systemTemp.createTemp(
      'mangatan-chapter-pages-downloads-',
    );
    database = await Isar.open(
      [
        MangaSchema,
        ChapterSchema,
        DownloadSchema,
        SettingsSchema,
        SourceSchema,
      ],
      directory: databaseDirectory.path,
      name: 'chapter_pages_test',
    );
    app.isar = database;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return downloadsDirectory.path;
          }
          return null;
        });
    database.writeTxnSync(() {
      database.settings.putSync(
        Settings()..downloadLocation = downloadsDirectory.path,
      );
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await database.close(deleteFromDisk: true);
    for (final directory in [databaseDirectory, downloadsDirectory]) {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });

  test(
    'opens a completed downloaded image folder without resolving its source',
    () async {
      final manga = Manga(
        id: 1,
        source: 'Unavailable source',
        author: '',
        artist: '',
        genre: const [],
        imageUrl: null,
        lang: 'ja',
        link: '/title',
        name: 'Downloaded title',
        status: Status.ongoing,
        description: '',
        sourceId: 1,
      );
      final chapter = Chapter(
        id: 1,
        mangaId: manga.id,
        name: 'Chapter 1',
        url: '/chapter-1',
      )..manga.value = manga;
      final chapterDirectory = Directory(
        p.join(
          downloadsDirectory.path,
          'Mangatan',
          'downloads',
          'Manga',
          'Unavailable source (JA)',
          'Downloaded title',
          'Chapter 1',
        ),
      );
      await chapterDirectory.create(recursive: true);
      await File(p.join(chapterDirectory.path, '001.jpg')).writeAsBytes([1]);
      await File(p.join(chapterDirectory.path, '002.jpg')).writeAsBytes([2]);

      database.writeTxnSync(() {
        database.downloads.putSync(
          Download(
            id: chapter.id,
            succeeded: 100,
            failed: 0,
            total: 100,
            isDownload: true,
            isStartDownload: true,
          ),
        );
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final pages = await container.read(
        getChapterPagesProvider(chapter: chapter).future,
      );

      expect(pages.pageUrls.map((page) => page.url), ['', '']);
      expect(pages.isLocaleList, [true, true]);
      expect(pages.archiveImages, [null, null]);
      expect(pages.uChapDataPreload, hasLength(2));
      expect(
        pages.uChapDataPreload.first.localArtifactPath,
        chapterDirectory.path,
      );
    },
  );

  test('opens a downloaded CBZ without resolving its source', () async {
    final manga = Manga(
      id: 1,
      source: 'Unavailable source',
      author: '',
      artist: '',
      genre: const [],
      imageUrl: null,
      lang: 'ja',
      link: '/title',
      name: 'Downloaded title',
      status: Status.ongoing,
      description: '',
      sourceId: 1,
    );
    final chapter = Chapter(
      id: 1,
      mangaId: manga.id,
      name: 'Chapter 1',
      url: '/chapter-1',
    )..manga.value = manga;
    final mangaDirectory = Directory(
      p.join(
        downloadsDirectory.path,
        'Mangatan',
        'downloads',
        'Manga',
        'Unavailable source (JA)',
        'Downloaded title',
      ),
    );
    await mangaDirectory.create(recursive: true);
    final archive = Archive()
      ..add(ArchiveFile.bytes('001.jpg', [1]))
      ..add(ArchiveFile.bytes('002.jpg', [2]));
    await File(
      p.join(mangaDirectory.path, 'Chapter 1.cbz'),
    ).writeAsBytes(ZipEncoder().encode(archive));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final pages = await container.read(
      getChapterPagesProvider(chapter: chapter).future,
    );

    expect(pages.pageUrls.map((page) => page.url), ['', '']);
    expect(pages.isLocaleList, [true, true]);
    expect(pages.archiveImages, everyElement(isNotNull));
    expect(pages.uChapDataPreload, hasLength(2));
    expect(
      pages.uChapDataPreload.first.localArtifactPath,
      p.join(mangaDirectory.path, 'Chapter 1.cbz'),
    );
  });
}
