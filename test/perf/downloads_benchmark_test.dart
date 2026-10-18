// Benchmarks the download area's main-isolate work on a realistic database.
//
// Skipped unless MANGATAN_PERF is set:
//
//   MANGATAN_PERF=1 flutter test test/perf/downloads_benchmark_test.dart
//
// MANGATAN_PERF_RUNS sets the measured runs (default 12, after 3 warm-up
// runs). MANGATAN_PERF_OUT=<file> also writes the results as JSON.
//
// Everything runs on a real Isar database and real files in a temporary
// folder, through the same repository calls and helpers the download code
// uses. The library holds 3,000 finished downloads; one entry has 300
// chapters, which are queued as "download all" does. Network transfers run
// in the download isolates and are not measured here.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/changed.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/custom_button.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/track_preference.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/manga/download/providers/convert_to_cbz.dart';
import 'package:mangayomi/modules/more/download_queue/download_queue_screen.dart';
import 'package:mangayomi/repositories/db_write_queue.dart';
import 'package:mangayomi/repositories/download_repository.dart';
import 'package:mangayomi/services/download_manager/download_queue_order.dart';
import 'package:mangayomi/services/download_manager/next_downloads.dart';
import 'package:mangayomi/services/downloaded_chapter.dart';
import 'package:mangayomi/utils/downloaded_page_file.dart';
import 'package:mangayomi/utils/extensions/string_extensions.dart';
import 'package:mangayomi/utils/reg_exp_matcher.dart';
import 'package:path/path.dart' as p;

import '../test_utils/isar_library.dart';

final _enabled = Platform.environment['MANGATAN_PERF'] != null;
final _iterations =
    int.tryParse(Platform.environment['MANGATAN_PERF_RUNS'] ?? '') ?? 12;
const _warmup = 3;

/// Library entries that already have finished downloads.
const _libraryEntries = 200;

/// Finished downloads per library entry (3,000 in total).
const _downloadsPerEntry = 15;

/// Chapters of the entry that gets queued with "download all".
const _queuedChapters = 300;

/// Pages of a downloaded chapter.
const _pagesPerChapter = 60;

/// Chapter tiles visible at once, each with its own download-state stream.
const _visibleTiles = 30;

class _Stat {
  _Stat(List<double> values) : _sorted = [...values]..sort();
  final List<double> _sorted;

  double get median {
    final n = _sorted.length;
    return n.isOdd
        ? _sorted[n ~/ 2]
        : (_sorted[n ~/ 2 - 1] + _sorted[n ~/ 2]) / 2;
  }

  double get p90 =>
      _sorted[min(_sorted.length - 1, (_sorted.length * 0.9).floor())];

  Map<String, double> toJson() => {
    'median': double.parse(median.toStringAsFixed(2)),
    'p90': double.parse(p90.toStringAsFixed(2)),
  };
}

/// Longest gap between ticks of a 1 ms periodic timer on this isolate, which
/// is how long the isolate was busy without yielding.
class _StallProbe {
  final _clock = Stopwatch();
  int _last = 0;
  int longest = 0;
  Timer? _timer;

  void start() {
    longest = 0;
    _clock
      ..reset()
      ..start();
    _last = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = _clock.elapsedMicroseconds;
    longest = max(longest, now - _last);
    _last = now;
  }

  int stop() {
    _timer?.cancel();
    _tick();
    return longest;
  }
}

final _results = <String, Object?>{};

/// Runs [setUp] (unmeasured), then [run] (measured), [_warmup] + runs times.
Future<void> _bench(
  String name,
  Future<void> Function() run, {
  Future<void> Function()? setUp,
  int iterations = 0,
}) async {
  final runs = iterations > 0 ? iterations : _iterations;
  final totals = <double>[];
  final stalls = <double>[];
  for (var i = 0; i < _warmup + runs; i++) {
    await setUp?.call();
    final probe = _StallProbe()..start();
    final clock = Stopwatch()..start();
    await run();
    clock.stop();
    final stall = probe.stop();
    if (i < _warmup) continue;
    totals.add(clock.elapsedMicroseconds / 1000);
    stalls.add(stall / 1000);
  }
  final result = {
    'runs': runs,
    'totalMs': _Stat(totals).toJson(),
    'longestMainIsolateStallMs': _Stat(stalls).toJson(),
  };
  _results[name] = result;
  // ignore: avoid_print
  print('BENCH $name ${jsonEncode(result)}');
}

void main() {
  late Directory root;
  late Manga queuedManga;
  late List<Chapter> queuedChapters;
  late List<int> finishedIds;
  late List<int> libraryChapterIds;
  late List<int> pageBytes;

  /// Removes the queued entry's downloads and the saved queue order.
  Future<void> clearQueue() => dbWriteQueue.run(
    () => isar.writeTxnSync(() {
      isar.downloads.deleteAllSync([for (final c in queuedChapters) c.id!]);
      final settings = isar.settings.getSync(227)!;
      settings.downloadQueueOrder = [];
      isar.settings.putSync(settings);
    }),
  );

  Future<void> queueAll() async {
    for (final chapter in queuedChapters) {
      await downloadRepository.enqueue(chapter);
    }
  }

  setUpAll(() async {
    if (!_enabled) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    root = Directory.systemTemp.createTempSync('mangatan_downloads_perf');
    pageBytes = File('assets/screenshots/manga-lookup.jpg').readAsBytesSync();
    isar = await Isar.open(
      [
        MangaSchema,
        ChangedPartSchema,
        ChapterSchema,
        CategorySchema,
        CustomButtonSchema,
        UpdateSchema,
        HistorySchema,
        DownloadSchema,
        SourceSchema,
        SettingsSchema,
        TrackPreferenceSchema,
        TrackSchema,
        SourcePreferenceSchema,
        SourcePreferenceStringValueSchema,
      ],
      directory: root.path,
      name: 'downloads_perf',
    );

    final random = Random(5);
    Manga manga(int i) => Manga(
      source: 'Source ${i % 12}',
      author: 'Author',
      artist: 'Artist',
      genre: const ['Action'],
      imageUrl: '',
      lang: 'en',
      link: '/series/$i',
      name: 'Downloaded Entry ${random.nextInt(1 << 30)}',
      status: Status.ongoing,
      description: 'A description long enough to be realistic.',
      sourceId: 9000 + i % 12,
      favorite: true,
      itemType: ItemType.manga,
    );

    final mangas = [for (var i = 0; i < _libraryEntries; i++) manga(i)];
    queuedManga = manga(_libraryEntries);
    isar.writeTxnSync(() {
      isar.settings.putSync(
        Settings()
          ..downloadLocation = '${root.path}/downloads'
          ..downloadQueueOrder = []
          ..chapterFilterUnreadList = []
          ..chapterFilterBookmarkedList = []
          ..chapterFilterDownloadedList = []
          ..sortChapterList = []
          ..filterScanlatorList = [],
      );
      isar.mangas.putAllSync([...mangas, queuedManga]);
      final downloads = <Download>[];
      for (final m in mangas) {
        final chapters = [
          for (var c = 0; c < _downloadsPerEntry; c++)
            Chapter(
              mangaId: m.id,
              name: 'Chapter ${c + 1}',
              url: '${m.link}/chapter-${c + 1}',
              dateUpload: '0',
              isRead: false,
            )..manga.value = m,
        ];
        isar.chapters.putAllSync(chapters);
        for (final chapter in chapters) {
          chapter.manga.saveSync();
          downloads.add(
            Download(
              id: chapter.id,
              succeeded: 100,
              failed: 0,
              total: 100,
              isDownload: true,
              isStartDownload: false,
            )..chapter.value = chapter,
          );
        }
      }
      isar.downloads.putAllSync(downloads);
      for (final download in downloads) {
        download.chapter.saveSync();
      }
      queuedChapters = [
        for (var c = 0; c < _queuedChapters; c++)
          Chapter(
            mangaId: queuedManga.id,
            name: 'Chapter ${c + 1}: Part ${c % 3}',
            url: '${queuedManga.link}/chapter-${c + 1}',
            dateUpload: '0',
            isRead: false,
          )..manga.value = queuedManga,
      ];
      isar.chapters.putAllSync(queuedChapters);
      for (final chapter in queuedChapters) {
        chapter.manga.saveSync();
      }
    });
    finishedIds = isar.downloads.where().idProperty().findAllSync();
    libraryChapterIds = finishedIds.take(_visibleTiles).toList();
  });

  tearDownAll(() async {
    if (!_enabled) return;
    final out = Platform.environment['MANGATAN_PERF_OUT'];
    if (out != null) {
      File(
        out,
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_results));
    }
    await isar.close(deleteFromDisk: true);
    root.deleteSync(recursive: true);
  });

  test('download all: check and queue 300 chapters', skip: !_enabled, () async {
    // MangaDetailView._downloadChaptersWithDestination: skip chapters already
    // downloaded, then queue the rest one by one.
    await _bench('download_all_300', () async {
      final toQueue = queuedChapters.where((chapter) {
        final entry = downloadRepository.getByChapterId(chapter.id);
        return entry == null || !entry.isDownload!;
      }).toList();
      await downloadRepository.enqueueAll(toQueue);
    }, setUp: clearQueue);
  });

  test('queue 300 chapters one tap at a time', skip: !_enabled, () async {
    // Separate taps each queue one chapter in its own transaction.
    await _bench('enqueue_300_one_by_one', queueAll, setUp: clearQueue);
  });

  test('queue one chapter behind 300 queued', skip: !_enabled, () async {
    final extra = queuedChapters.last;
    await _bench(
      'enqueue_one_behind_299',
      () => downloadRepository.enqueue(extra),
      setUp: () async {
        await clearQueue();
        for (final chapter in queuedChapters.take(_queuedChapters - 1)) {
          await downloadRepository.enqueue(chapter);
        }
      },
    );
  });

  test('download state lookups for 300 chapters', skip: !_enabled, () async {
    await queueAll();
    await _bench('get_by_chapter_id_300', () async {
      var found = 0;
      for (final chapter in queuedChapters) {
        if (downloadRepository.getByChapterId(chapter.id) != null) found++;
      }
      expect(found, _queuedChapters);
    });
  });

  test('chapter tiles: first download state', skip: !_enabled, () async {
    // ChapterPageDownload: each visible tile watches its own download row.
    await _bench('tile_streams_first_emit_30', () async {
      await Future.wait([
        for (final id in libraryChapterIds)
          downloadRepository.watchByChapterId(id).first,
      ]);
    });
  });

  test('chapter tiles: progress write fan-out', skip: !_enabled, () async {
    // A progress write for one tile while every visible tile is listening.
    final events = <int>[];
    final subscriptions = [
      for (final id in libraryChapterIds)
        downloadRepository.watchByChapterId(id).listen((_) => events.add(id)),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final target = libraryChapterIds.first;
    var percent = 0;
    await _bench('tile_streams_progress_write', () async {
      events.clear();
      percent = (percent + 1) % 100;
      await dbWriteQueue.run(
        () => isar.writeTxnSync(() {
          final download = isar.downloads.getSync(target)!;
          isar.downloads.putSync(download..succeeded = percent);
        }),
      );
      while (events.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
    });
    for (final s in subscriptions) {
      await s.cancel();
    }
    isar.writeTxnSync(() {
      final download = isar.downloads.getSync(target)!;
      isar.downloads.putSync(download..succeeded = 100);
    });
  });

  test('download queue screen: one emission', skip: !_enabled, () async {
    await queueAll();
    // _DownloadQueueScreenState.build for one snapshot of the stream.
    await _bench('queue_screen_emission', () async {
      final snapshot = isar.downloads.filter().idIsNotNull().findAllSync();
      final resolved = snapshot.map(resolveDownloadedChapter).nonNulls.toList();
      final completed = resolved
          .where((entry) => entry.download.isDownload ?? false)
          .toList();
      final queued = DownloadQueueOrder.sorted(
        resolved
            .where((entry) => !(entry.download.isDownload ?? false))
            .map((entry) => entry.download)
            .toList(),
      );
      expect(completed.length, finishedIds.length);
      expect(queued.length, _queuedChapters);
    });
  });

  test('process downloads: start the queue', skip: !_enabled, () async {
    await queueAll();
    await _bench('process_downloads_prepare', () async {
      final pending = DownloadQueueOrder.sorted(
        await downloadRepository.getPendingStarted(),
      );
      for (final item in pending) {
        if (!item.chapter.isLoaded) item.chapter.loadSync();
      }
      expect(pending.length, _queuedChapters);
    });
  });

  test('progress write', skip: !_enabled, () async {
    await queueAll();
    final id = queuedChapters.first.id!;
    var percent = 0;
    await _bench('progress_write', () async {
      percent = (percent + 1) % 100;
      await dbWriteQueue.run(
        () => isar.writeTxnSync(() {
          final download = isar.downloads.getSync(id);
          if (download == null) return;
          isar.downloads.putSync(
            download
              ..succeeded = percent
              ..total = 100
              ..failed = 0
              ..isDownload = false,
          );
        }),
      );
    });
  });

  test('next downloads: pick 25', skip: !_enabled, () async {
    await queueAll();
    await _bench('select_next_downloads_25', () async {
      selectNextDownloads(
        queuedChapters,
        count: 25,
        downloads: downloadRepository.getAll(),
      );
    });
  });

  Directory writePages(String name) {
    final dir = Directory(p.join(root.path, 'pages', name))
      ..createSync(recursive: true);
    for (var i = 0; i < _pagesPerChapter; i++) {
      File(p.join(dir.path, '${padIndex(i)}.jpg')).writeAsBytesSync(pageBytes);
    }
    return dir;
  }

  test('page preparation: probe a fresh chapter', skip: !_enabled, () async {
    // downloadChapter checks every page index for an existing file before it
    // queues the page.
    final dir = Directory(p.join(root.path, 'fresh'))..createSync();
    await _bench('page_probe_fresh_60', () async {
      var missing = 0;
      for (var i = 0; i < _pagesPerChapter; i++) {
        if (findDownloadedPageFile(dir, i) == null) missing++;
      }
      expect(missing, _pagesPerChapter);
    });
  });

  test('downloaded chapter lookup (page folder)', skip: !_enabled, () async {
    final mangaDir = Directory(p.join(root.path, 'pages'));
    writePages('Chapter 1');
    await _bench('downloaded_chapter_lookup_60', () async {
      final found = findDownloadedChapterIn(
        [mangaDir],
        chapterName: 'Chapter 1',
        chapterDirectoryName: 'Chapter 1',
        isComplete: true,
      );
      expect(found?.pageCount, _pagesPerChapter);
    });
  });

  test('convert 60 pages to CBZ', skip: !_enabled, () async {
    final container = ProviderContainer();
    final mangaDir = Directory(p.join(root.path, 'cbz'))..createSync();
    late Directory dir;
    await _bench(
      'convert_to_cbz_60',
      () async {
        await container.read(
          convertToCBZProvider(dir.path, mangaDir.path, 'Chapter 2', [
            for (var i = 0; i < _pagesPerChapter; i++) 'x',
          ], comicInfo: const ComicInfoData(title: 'Chapter 2')).future,
        );
      },
      setUp: () async {
        dir = writePages('Chapter 2');
        final cbz = File(p.join(mangaDir.path, 'Chapter 2.cbz'));
        if (cbz.existsSync()) cbz.deleteSync();
        container.invalidate(convertToCBZProvider);
      },
      iterations: max(4, _iterations ~/ 3),
    );
    container.dispose();
  });

  test('chapter folder name', skip: !_enabled, () async {
    await _bench('forbidden_character_names_300', () async {
      for (final chapter in queuedChapters) {
        chapter.name!.replaceForbiddenCharacters(' ');
      }
    });
  });
}
