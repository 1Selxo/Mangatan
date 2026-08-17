// ignore_for_file: avoid_print

import 'dart:ffi';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_importer.dart';

import '../test/test_utils/isar_library.dart';

const _mangaCount = 300;
const _chaptersPerManga = 100;
const _measuredRuns = 7;

void main() {
  test(
    'disk-backed Chimahon full import benchmark',
    () async {
      await Isar.initializeIsarCore(
        libraries: {Abi.current(): await isarTestLibraryPath()},
      );
      final directory = await Directory.systemTemp.createTemp(
        'mangatan-full-sync-benchmark-',
      );
      final database = await Isar.open(
        [
          MangaSchema,
          ChapterSchema,
          CategorySchema,
          HistorySchema,
          SourceSchema,
          EpubBookProgressSchema,
          DownloadSchema,
          UpdateSchema,
          TrackSchema,
        ],
        directory: directory.path,
        name: 'chimahon_full_sync_benchmark',
      );
      try {
        database.writeTxnSync(
          () => database.sources.putSync(
            Source(
              id: 42,
              name: 'Benchmark source',
              lang: 'ja',
              sourceCode: 'installed',
              isAdded: true,
              additionalParams: encodeMihonSourceMetadata(
                sourceId: 9001,
                packageName: 'benchmark.extension',
              ),
            ),
          ),
        );
        final backup = _representativeBackup();
        const importer = ChimahonSyncImporter();
        final seedWatch = Stopwatch()..start();
        importer.apply(database: database, backup: backup);
        seedWatch.stop();

        final samples = <int>[];
        for (var run = 0; run < _measuredRuns; run++) {
          final watch = Stopwatch()..start();
          importer.apply(database: database, backup: backup);
          watch.stop();
          samples.add(watch.elapsedMicroseconds);
        }
        samples.sort();
        final average =
            samples.fold<int>(0, (sum, value) => sum + value) /
            samples.length /
            Duration.microsecondsPerMillisecond;
        print(
          'Chimahon full import benchmark: $_mangaCount manga, '
          '${_mangaCount * _chaptersPerManga} chapters',
        );
        print(
          'initial=${_milliseconds(seedWatch.elapsedMicroseconds)}ms '
          'runs=$_measuredRuns avg=${average.toStringAsFixed(2)}ms '
          'median=${_milliseconds(samples[samples.length ~/ 2])}ms '
          'min=${_milliseconds(samples.first)}ms '
          'max=${_milliseconds(samples.last)}ms',
        );
      } finally {
        await database.close(deleteFromDisk: true);
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

String _milliseconds(int microseconds) =>
    (microseconds / Duration.microsecondsPerMillisecond).toStringAsFixed(2);

BackupMihon _representativeBackup() => BackupMihon(
  backupSources: [
    BackupSource(sourceId: Int64(9001), name: 'Benchmark source'),
  ],
  backupManga: [
    for (var mangaIndex = 0; mangaIndex < _mangaCount; mangaIndex++)
      BackupManga(
        source: Int64(9001),
        url: '/manga/$mangaIndex',
        title: 'Benchmark manga $mangaIndex',
        author: 'Author ${mangaIndex % 40}',
        favorite: true,
        version: Int64(10),
        lastModifiedAt: Int64(10000 + mangaIndex),
        chapters: [
          for (
            var chapterIndex = 0;
            chapterIndex < _chaptersPerManga;
            chapterIndex++
          )
            BackupChapter(
              url: '/manga/$mangaIndex/chapter/$chapterIndex',
              name: 'Chapter $chapterIndex',
              chapterNumber: chapterIndex.toDouble(),
              read: chapterIndex.isEven,
              lastPageRead: Int64(chapterIndex % 12),
              version: Int64(5),
              lastModifiedAt: Int64(20000 + chapterIndex),
            ),
        ],
      ),
  ],
);
