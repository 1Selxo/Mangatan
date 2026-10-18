// Benchmarks the library screen's data work on a large library.
//
// Skipped unless MANGATAN_PERF is set:
//
//   MANGATAN_PERF=1 flutter test test/perf/library_benchmark_test.dart
//
// MANGATAN_PERF_OUT=<file> also writes the results as JSON.
//
// Everything runs on a real Isar database, through the same providers and
// helpers the library widgets use. Each run starts from freshly loaded
// entries, as the library does after every database change.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
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
import 'package:mangayomi/modules/history/providers/isar_providers.dart';
import 'package:mangayomi/modules/library/providers/isar_providers.dart';
import 'package:mangayomi/modules/library/providers/library_filter_provider.dart';
import 'package:mangayomi/services/epub_chapter_metadata.dart';
import 'package:mangayomi/utils/extensions/manga_extensions.dart';

import '../test_utils/isar_library.dart';

final _enabled = Platform.environment['MANGATAN_PERF'] != null;
final _iterations =
    int.tryParse(Platform.environment['MANGATAN_PERF_RUNS'] ?? '') ?? 12;
const _warmup = 3;
const _entries = 500;
const _chaptersPerEntry = 150;

/// Library sort types, as stored in the library settings.
const _sortNames = {
  0: 'alphabetical',
  1: 'last_read',
  2: 'last_update',
  3: 'unread_count',
  4: 'total_chapters',
  5: 'latest_chapter',
  6: 'date_added',
};

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final n = sorted.length;
  return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}

double _p90(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[min(sorted.length - 1, (sorted.length * 0.9).floor())];
}

final _results = <String, Object?>{};

Future<void> _bench(String name, Future<double> Function() run) async {
  final values = <double>[];
  for (var i = 0; i < _warmup + _iterations; i++) {
    final ms = await run();
    if (i >= _warmup) values.add(ms);
  }
  final result = {
    'runs': _iterations,
    'median': double.parse(_median(values).toStringAsFixed(2)),
    'p90': double.parse(_p90(values).toStringAsFixed(2)),
  };
  _results[name] = result;
  // ignore: avoid_print
  print('BENCH $name ${jsonEncode(result)}');
}

/// The first value of an auto-disposed stream provider, held by a listener
/// the way a watching widget holds it.
Future<T> _firstValue<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) async {
  final completer = Completer<T>();
  final subscription = container.listen(provider, (_, next) {
    if (next.hasValue && !completer.isCompleted) {
      completer.complete(next.value as T);
    }
  }, fireImmediately: true);
  try {
    return await completer.future;
  } finally {
    subscription.close();
  }
}

double _ms(Stopwatch clock) => clock.elapsedMicroseconds / 1000;

/// Entries as the library stream delivers them: new objects whose chapter
/// links are not loaded yet.
List<Manga> _freshLibrary() => isar.mangas
    .filter()
    .idIsNotNull()
    .favoriteEqualTo(true)
    .and()
    .itemTypeEqualTo(ItemType.manga)
    .findAllSync();

void main() {
  late Directory root;
  late ProviderContainer container;

  setUpAll(() async {
    if (!_enabled) return;
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    root = Directory.systemTemp.createTempSync('mangatan_library_perf');
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
      name: 'library_perf',
    );

    final random = Random(11);
    final now = DateTime(2026).millisecondsSinceEpoch;
    final mangas = [
      for (var i = 0; i < _entries; i++)
        Manga(
          source: 'Source ${i % 12}',
          author: '',
          artist: '',
          genre: const [],
          imageUrl: '',
          lang: 'en',
          link: '/series/$i',
          name: 'Library Entry ${random.nextInt(1 << 30)}',
          status: Status.values[i % Status.values.length],
          description: '',
          sourceId: 9000 + i % 12,
          favorite: true,
          // Two categories and some uncategorized entries.
          categories: [if (i % 3 != 2) i % 3 + 1],
          dateAdded: now - random.nextInt(1 << 30),
          lastUpdate: now - random.nextInt(1 << 30),
          lastRead: now - random.nextInt(1 << 30),
        ),
    ];
    isar.writeTxnSync(() {
      isar.mangas.putAllSync(mangas);
      for (final manga in mangas) {
        final read = random.nextInt(_chaptersPerEntry);
        final chapters = [
          for (var c = 0; c < _chaptersPerEntry; c++)
            Chapter(
              mangaId: manga.id,
              name: 'Chapter ${c + 1}',
              url: '${manga.link}/chapter-${c + 1}',
              dateUpload: '${now - (_chaptersPerEntry - c) * 86400000}',
              scanlator: c.isEven ? 'Group A' : 'Group B',
              isRead: c < read,
              isBookmarked: c % 37 == 0,
            )..manga.value = manga,
        ];
        isar.chapters.putAllSync(chapters);
        for (final chapter in chapters) {
          chapter.manga.saveSync();
        }
      }
      // One history row per entry and recent updates, linked like the app's.
      for (final manga in mangas) {
        final chapter = isar.chapters
            .filter()
            .mangaIdEqualTo(manga.id)
            .findFirstSync()!;
        final history = History(
          mangaId: manga.id,
          chapterId: chapter.id,
          itemType: ItemType.manga,
          date: '${now - random.nextInt(1 << 30)}',
        )..chapter.value = chapter;
        isar.historys.putSync(history);
        history.chapter.saveSync();
        for (final update in [
          for (final c
              in isar.chapters
                  .filter()
                  .mangaIdEqualTo(manga.id)
                  .limit(4)
                  .findAllSync())
            Update(
              mangaId: manga.id,
              chapterName: c.name,
              date: '${now - random.nextInt(1 << 30)}',
            )..chapter.value = c,
        ]) {
          isar.updates.putSync(update);
          update.chapter.saveSync();
        }
      }
      final chapterIds = isar.chapters.where().idProperty().findAllSync();
      isar.downloads.putAllSync([
        for (final id in chapterIds)
          if (id % 9 == 0)
            Download(
              id: id,
              succeeded: 1,
              failed: 0,
              total: 1,
              isDownload: true,
              isStartDownload: false,
            ),
      ]);
      // Per-entry chapter settings accumulate as the user adjusts entries.
      isar.settings.putSync(
        Settings()
          ..chapterFilterUnreadList = [
            for (final m in mangas) ChapterFilterUnread(mangaId: m.id),
          ]
          ..chapterFilterBookmarkedList = [
            for (final m in mangas) ChapterFilterBookmarked(mangaId: m.id),
          ]
          ..chapterFilterDownloadedList = [
            for (final m in mangas) ChapterFilterDownloaded(mangaId: m.id),
          ]
          ..sortChapterList = [
            for (final m in mangas) SortChapter(mangaId: m.id),
          ]
          ..filterScanlatorList = [
            for (final m in mangas.take(_entries ~/ 5))
              FilterScanlator(mangaId: m.id, scanlators: ['Group B']),
          ],
      );
    });

    container = ProviderContainer();
    container.listen(downloadedChapterIdsProvider, (_, _) {});
    await container.read(downloadedChapterIdsProvider.future);
  });

  tearDownAll(() async {
    if (!_enabled) return;
    final out = Platform.environment['MANGATAN_PERF_OUT'];
    if (out != null) {
      File(
        out,
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_results));
    }
    container.dispose();
    await isar.close(deleteFromDisk: true);
    root.deleteSync(recursive: true);
  });

  test('library stream: first emission', skip: !_enabled, () async {
    await _bench('library_stream_emit', () async {
      final c = ProviderContainer();
      final clock = Stopwatch()..start();
      await _firstValue(
        c,
        getAllMangaStreamProvider(categoryId: null, itemType: ItemType.manga),
      );
      clock.stop();
      c.dispose();
      return _ms(clock);
    });
  });

  test('history stream: first emission', skip: !_enabled, () async {
    await _bench('history_stream_emit', () async {
      final c = ProviderContainer();
      final clock = Stopwatch()..start();
      await _firstValue(
        c,
        getAllHistoryStreamProvider(itemType: ItemType.manga),
      );
      clock.stop();
      c.dispose();
      return _ms(clock);
    });
  });

  test('updates stream: first emission', skip: !_enabled, () async {
    await _bench('updates_stream_emit', () async {
      final c = ProviderContainer();
      final clock = Stopwatch()..start();
      await _firstValue(
        c,
        getAllUpdateStreamProvider(itemType: ItemType.manga),
      );
      clock.stop();
      c.dispose();
      return _ms(clock);
    });
  });

  for (final MapEntry(key: sortType, value: sortName) in _sortNames.entries) {
    test('library filter and sort: $sortName', skip: !_enabled, () async {
      await _bench('library_filter_sort_$sortName', () async {
        final data = _freshLibrary();
        final clock = Stopwatch()..start();
        container.read(
          filteredLibraryMangaProvider(
            data: data,
            downloadFilterType: 0,
            unreadFilterType: 0,
            startedFilterType: 0,
            bookmarkedFilterType: 0,
            completedFilterType: 0,
            trackingFilterType: 0,
            sortType: sortType,
            downloadedOnly: false,
            searchQuery: '',
            ignoreFiltersOnSearch: false,
            sourceIds: const [],
          ),
        );
        clock.stop();
        return _ms(clock);
      });
    });
  }

  test(
    'library filter: unread and downloaded filters',
    skip: !_enabled,
    () async {
      await _bench('library_filter_unread_downloaded', () async {
        final data = _freshLibrary();
        final clock = Stopwatch()..start();
        container.read(
          filteredLibraryMangaProvider(
            data: data,
            downloadFilterType: 1,
            unreadFilterType: 1,
            startedFilterType: 0,
            bookmarkedFilterType: 0,
            completedFilterType: 0,
            trackingFilterType: 0,
            sortType: 0,
            downloadedOnly: false,
            searchQuery: '',
            ignoreFiltersOnSearch: false,
            sourceIds: const [],
          ),
        );
        clock.stop();
        return _ms(clock);
      });
    },
  );

  test(
    'library category tab: rebuild without data change',
    skip: !_enabled,
    () async {
      // A category tab and its count badge rebuild whenever the library screen
      // does, for example when an entry is selected, with the same entries.
      final allMangas = await _firstValue(
        container,
        getAllMangaStreamProvider(categoryId: null, itemType: ItemType.manga),
      );
      // The settings snapshot the library screen passes down.
      final settings = isar.settings.getSync(227)!;
      // Held like a watching widget holds it: the new subscription is made
      // before the previous one closes.
      ProviderSubscription<List<Manga>>? held;
      List<Manga> rebuild() {
        // As LibraryBody builds a category tab.
        final data = libraryTabEntries(allMangas, settings, categoryId: 1);
        final subscription = container.listen(
          filteredLibraryMangaProvider(
            data: data,
            downloadFilterType: 0,
            unreadFilterType: 0,
            startedFilterType: 0,
            bookmarkedFilterType: 0,
            completedFilterType: 0,
            trackingFilterType: 0,
            sortType: 3,
            downloadedOnly: false,
            searchQuery: '',
            ignoreFiltersOnSearch: false,
            sourceIds: const [],
          ),
          (_, _) {},
        );
        held?.close();
        held = subscription;
        return subscription.read();
      }

      rebuild();
      await _bench('library_category_rebuild_unread_sort', () async {
        final clock = Stopwatch()..start();
        rebuild();
        clock.stop();
        return _ms(clock);
      });
      held?.close();
    },
  );

  test(
    'library tiles: badge counts for every entry',
    skip: !_enabled,
    () async {
      final downloadedIds = container.read(downloadedChapterIdsProvider).value!;
      await _bench('library_tile_badges', () async {
        final data = _freshLibrary();
        final clock = Stopwatch()..start();
        var total = 0;
        for (final entry in data) {
          // LibraryBadgeWidget, the grid's unread label and DownloadCountBadge.
          total += entry.unreadChaptersCount;
          total += userFacingChapters(entry).where((e) => !e.isRead!).length;
          total += userFacingChapters(entry)
              .where((c) => c.id != null && downloadedIds.contains(c.id))
              .length;
        }
        clock.stop();
        expect(total, greaterThan(0));
        return _ms(clock);
      });
    },
  );
}
