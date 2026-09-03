import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/manga/reader/mixins/chapter_controller_mixin.dart';

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
      'mangatan-reader-history-',
    );
    database = await Isar.open(
      [MangaSchema, ChapterSchema, HistorySchema],
      directory: databaseDirectory.path,
      name: 'reader_history_test',
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
    'reader initialization writes history in an async transaction',
    () async {
      final manga = Manga(
        source: 'Source',
        author: '',
        artist: '',
        genre: const [],
        imageUrl: null,
        lang: 'en',
        link: '/title',
        name: 'Title',
        status: Status.ongoing,
        description: '',
        sourceId: 1,
      );
      await database.writeTxn(() => database.mangas.put(manga));
      final chapter = Chapter(
        mangaId: manga.id,
        name: 'Chapter 1',
        isRead: false,
      );
      await database.writeTxn(() => database.chapters.put(chapter));

      await _TestChapterController(chapter).setHistoryUpdate(elapsedSeconds: 7);

      final savedManga = await database.mangas.get(manga.id!);
      final history = await database.historys.where().findFirst();
      expect(savedManga?.lastRead, isPositive);
      expect(history?.mangaId, manga.id);
      expect(history?.chapterId, chapter.id);
      expect(history?.readingTimeSeconds, 7);
    },
  );
}

class _TestChapterController with ChapterControllerMixin {
  _TestChapterController(this.chapter);

  @override
  final Chapter chapter;

  @override
  bool get incognitoMode => false;
}
