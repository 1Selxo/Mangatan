// Checks that the faster download repository calls give exactly the results
// of the previous implementation, which is copied verbatim below.
import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/repositories/db_write_queue.dart';
import 'package:mangayomi/repositories/download_repository.dart';

import '../test_utils/isar_library.dart';

// ---- Previous implementation, verbatim -------------------------------------

Future<void> _oldEnqueue(Chapter chapter) => dbWriteQueue.run(() {
  isar.writeTxnSync(() {
    final existing = isar.downloads.getSync(chapter.id!);
    if (existing?.isDownload == true || existing?.isStartDownload == true) {
      return;
    }
    final download =
        existing ??
        Download(
          id: chapter.id,
          total: 100,
          succeeded: 0,
          failed: 0,
          isDownload: false,
          isStartDownload: true,
        );
    download
      ..succeeded = 0
      ..failed = 0
      ..isDownload = false
      ..isStartDownload = true
      ..chapter.value = chapter;
    isar.downloads.putSync(download);
    download.chapter.saveSync();
    final settings = isar.settings.getSync(227) ?? Settings();
    final order = [...?settings.downloadQueueOrder];
    for (final pending
        in isar.downloads
            .filter()
            .isDownloadEqualTo(false)
            .isStartDownloadEqualTo(true)
            .findAllSync()) {
      if (pending.id != chapter.id &&
          pending.id != null &&
          !order.contains(pending.id)) {
        order.add(pending.id!);
      }
    }
    if (!order.contains(chapter.id!)) {
      order.add(chapter.id!);
      settings.downloadQueueOrder = order;
      settings.updatedAt = DateTime.now().millisecondsSinceEpoch;
      isar.settings.putSync(settings);
    }
  });
});

Download? _oldGetByChapterId(int? chapterId) =>
    isar.downloads.filter().idEqualTo(chapterId).findFirstSync();

Stream<List<Download>> _oldWatchByChapterId(int? chapterId) =>
    isar.downloads.filter().idEqualTo(chapterId).watch(fireImmediately: true);

// -----------------------------------------------------------------------------

/// Everything enqueue can change, as comparable values.
Map<String, Object?> _snapshot() {
  final downloads = isar.downloads.where().findAllSync();
  final settings = isar.settings.getSync(227);
  return {
    'downloads': [
      for (final d in downloads)
        {...d.toJson(), 'chapter': (d.chapter..loadSync()).value?.id},
    ],
    'order': settings?.downloadQueueOrder,
    'settingsExists': settings != null,
  };
}

void main() {
  late Directory root;
  var instance = 0;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
  });

  /// A fresh database: 40 chapters, some finished, some queued (with and
  /// without a saved order), some failed. [seed] varies the mix.
  Future<List<Chapter>> openDatabase(
    int seed, {
    bool withSettings = true,
  }) async {
    root = Directory.systemTemp.createTempSync('download_repo_eq');
    isar = await Isar.open(
      [
        MangaSchema,
        ChapterSchema,
        DownloadSchema,
        SettingsSchema,
        SourceSchema,
      ],
      directory: root.path,
      name: 'eq_${instance++}',
    );
    final random = Random(seed);
    final manga = Manga(
      source: 'S',
      author: '',
      artist: '',
      genre: const [],
      imageUrl: '',
      lang: 'en',
      link: '/m',
      name: 'M',
      status: Status.ongoing,
      description: '',
      sourceId: 1,
    );
    // Ids descend, as sources often insert newest first.
    final chapters = [
      for (var i = 0; i < 40; i++)
        Chapter(id: 500 - i * 3, name: 'Chapter $i', mangaId: 1),
    ];
    isar.writeTxnSync(() {
      isar.mangas.putSync(manga);
      if (withSettings) {
        isar.settings.putSync(
          Settings()
            ..downloadQueueOrder = [
              for (final c in chapters)
                if (random.nextInt(4) == 0) c.id!,
            ],
        );
      }
      isar.chapters.putAllSync(chapters);
      for (final c in chapters) {
        c.manga.value = manga;
        c.manga.saveSync();
        switch (random.nextInt(5)) {
          case 0:
            isar.downloads.putSync(
              Download(
                id: c.id,
                succeeded: 100,
                failed: 0,
                total: 100,
                isDownload: true,
                isStartDownload: false,
              ),
            );
          case 1:
            isar.downloads.putSync(
              Download(
                id: c.id,
                succeeded: 37,
                failed: 0,
                total: 100,
                isDownload: false,
                isStartDownload: true,
              ),
            );
          case 2:
            isar.downloads.putSync(
              Download(
                id: c.id,
                succeeded: 0,
                failed: 1,
                total: 100,
                isDownload: false,
                isStartDownload: false,
              ),
            );
        }
      }
    });
    return chapters;
  }

  Future<void> closeDatabase() async {
    await isar.close(deleteFromDisk: true);
    root.deleteSync(recursive: true);
  }

  /// The chapter batches "download all", "next N" and selections produce.
  List<Chapter> batchFor(List<Chapter> chapters, int seed) {
    final random = Random(seed * 31);
    final batch = [
      for (final c in chapters)
        if (random.nextBool()) c,
    ]..shuffle(random);
    // Repeats within one batch, as repeated taps would give.
    if (batch.isNotEmpty) batch.add(batch.first);
    return batch;
  }

  for (var seed = 0; seed < 12; seed++) {
    test(
      'enqueueAll matches one old enqueue per chapter (seed $seed)',
      () async {
        final withSettings = seed % 4 != 3;
        var chapters = await openDatabase(seed, withSettings: withSettings);
        for (final c in batchFor(chapters, seed)) {
          await _oldEnqueue(c);
        }
        final expected = _snapshot();
        await closeDatabase();

        chapters = await openDatabase(seed, withSettings: withSettings);
        await downloadRepository.enqueueAll(batchFor(chapters, seed));
        final actual = _snapshot();
        await closeDatabase();

        expect(actual, expected);
        expect((expected['order'] as List?)?.isNotEmpty, isTrue);
      },
    );

    test('enqueue matches old enqueue (seed $seed)', () async {
      var chapters = await openDatabase(seed);
      for (final c in batchFor(chapters, seed)) {
        await _oldEnqueue(c);
      }
      final expected = _snapshot();
      await closeDatabase();

      chapters = await openDatabase(seed);
      for (final c in batchFor(chapters, seed)) {
        await downloadRepository.enqueue(c);
      }
      final actual = _snapshot();
      await closeDatabase();

      expect(actual, expected);
    });
  }

  test(
    'enqueueAll keeps the old partial result and error on failure',
    () async {
      // A chapter without an id fails in the middle of the batch.
      var chapters = await openDatabase(3);
      final broken = Chapter(name: 'No id', mangaId: 1)..id = null;
      final batch = [...chapters.take(10), broken, ...chapters.skip(10)];
      Object? oldError;
      try {
        for (final c in batch) {
          await _oldEnqueue(c);
        }
      } catch (e) {
        oldError = e;
      }
      final expected = _snapshot();
      await closeDatabase();

      chapters = await openDatabase(3);
      final newBatch = [...chapters.take(10), broken, ...chapters.skip(10)];
      Object? newError;
      try {
        await downloadRepository.enqueueAll(newBatch);
      } catch (e) {
        newError = e;
      }
      final actual = _snapshot();
      await closeDatabase();

      expect(oldError, isNotNull);
      expect(newError.runtimeType, oldError.runtimeType);
      expect(actual, expected);
    },
  );

  test('getByChapterId returns the same row as the old filter', () async {
    final chapters = await openDatabase(5);
    for (final id in [null, -1, 0, 1 << 40, for (final c in chapters) c.id]) {
      expect(
        downloadRepository.getByChapterId(id)?.toJson(),
        _oldGetByChapterId(id)?.toJson(),
        reason: 'id $id',
      );
    }
    await closeDatabase();
  });

  test('watchByChapterId emits what the old stream emits', () async {
    final chapters = await openDatabase(7);
    final watched = [chapters[0].id, chapters[1].id, chapters[2].id, null];
    final oldEvents = <String>[];
    final newEvents = <String>[];
    String render(int? id, List<Download> list) =>
        '$id:${list.map((d) => d.toJson()).toList()}';
    final subscriptions = [
      for (final id in watched) ...[
        _oldWatchByChapterId(id)
            .listen((list) => oldEvents.add(render(id, list))),
        downloadRepository
            .watchByChapterId(id)
            .listen((list) => newEvents.add(render(id, list))),
      ],
    ];
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 30));
    await settle();
    // Writes to watched rows, to other rows, deletions and re-creation.
    final target = chapters[0];
    await downloadRepository.enqueue(target);
    await settle();
    await dbWriteQueue.run(
      () => isar.writeTxnSync(() {
        final d = isar.downloads.getSync(target.id!)!;
        isar.downloads.putSync(d..succeeded = 50);
      }),
    );
    await settle();
    await downloadRepository.enqueue(chapters[20]);
    await settle();
    await downloadRepository.delete(chapters[1].id!);
    await settle();
    await downloadRepository.enqueue(chapters[1]);
    await settle();
    await downloadRepository.deleteAll([target.id!, chapters[2].id!]);
    await settle();
    for (final s in subscriptions) {
      await s.cancel();
    }
    expect(newEvents..sort(), oldEvents..sort());
    expect(oldEvents.length, greaterThan(watched.length));
    await closeDatabase();
  });
}
