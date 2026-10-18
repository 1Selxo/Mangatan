// Benchmarks global search: searching every installed source at once, the
// per-result library lookups of the result cards, and library search.
//
// Skipped unless MANGATAN_PERF is set:
//
//   MANGATAN_PERF=1 flutter test test/perf/global_search_benchmark_test.dart
//
// MANGATAN_PERF_RUNS sets the measured runs (default 12, after 3 warm-up
// runs). MANGATAN_PERF_OUT=<file> also writes the results as JSON.
//
// Everything runs on a real Isar database with many installed sources and a
// large library. Sources are searched through the real providers, the real
// Mihon service and HTTP stack, against a loopback extension server with a
// fixed latency per request, so network and processing are separated.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/m_pages.dart';
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
import 'package:mangayomi/modules/browse/global_search/global_search_screen.dart';
import 'package:mangayomi/modules/library/providers/library_filter_provider.dart';
import 'package:mangayomi/repositories/manga_repository.dart';
import 'package:mangayomi/repositories/source_repository.dart';
import 'package:mangayomi/services/perf/perf_metrics.dart';
import 'package:mangayomi/services/search.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../test_utils/isar_library.dart';
import 'fake_extension_server.dart';
import 'temp_path_provider.dart';

final _enabled = Platform.environment['MANGATAN_PERF'] != null;
final _iterations =
    int.tryParse(Platform.environment['MANGATAN_PERF_RUNS'] ?? '') ?? 12;
const _warmup = 3;

/// Installed manga sources that a global search queries.
const _mangaSources = 30;

/// Installed sources of the other item types, which the search skips.
const _otherSources = 20;

/// Library size. Most rows are entries that were browsed but never added.
const _favorites = 800;
const _browsed = 3000;

/// Result cards built per source row: what fits a desktop window plus the
/// list's cache extent.
const _cardsPerRow = 10;

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

/// Longest gap between ticks of a 1 ms timer on this isolate: how long the
/// isolate was busy without yielding. Only the maximum is reported.
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

/// One measured run: wall time, and network time when the run is traced.
class _Run {
  const _Run(this.totalMs, [this.networkMs]);
  final double totalMs;
  final double? networkMs;
}

final _results = <String, Object?>{};

Future<void> _bench(String name, Future<_Run> Function(int i) run) async {
  final totals = <double>[];
  final networks = <double>[];
  final processing = <double>[];
  final stalls = <double>[];
  for (var i = 0; i < _warmup + _iterations; i++) {
    final probe = _StallProbe()..start();
    final result = await run(i);
    final stall = probe.stop();
    if (i < _warmup) continue;
    totals.add(result.totalMs);
    if (result.networkMs != null) {
      networks.add(result.networkMs!);
      processing.add(result.totalMs - result.networkMs!);
    }
    stalls.add(stall / 1000);
  }
  final result = {
    'runs': _iterations,
    'totalMs': _Stat(totals).toJson(),
    if (networks.isNotEmpty) 'networkMs': _Stat(networks).toJson(),
    if (processing.isNotEmpty) 'processingMs': _Stat(processing).toJson(),
    'longestMainIsolateStallMs': _Stat(stalls).toJson(),
  };
  _results[name] = result;
  // ignore: avoid_print
  print('BENCH $name ${jsonEncode(result)}');
}

double _ms(Stopwatch clock) => clock.elapsedMicroseconds / 1000;

var _traceCount = 0;

Future<PerfSample> _traced(String flow, Future<void> Function() body) async {
  final label = 'bench#${_traceCount++}';
  final completer = Completer<PerfSample>();
  final remove = PerfMetrics.addListener((sample) {
    if (sample.label == label && !completer.isCompleted) {
      completer.complete(sample);
    }
  });
  try {
    await PerfMetrics.trace(flow, body, label: label);
    return await completer.future;
  } finally {
    remove();
  }
}

/// The library lookup a result card makes, as `MangaGlobalImageCard` does.
typedef _CardWatch = Stream<List<Manga>> Function(ItemType, String?);

/// Subscribes one favorites watch per card and waits until every card has
/// its first result, which is when the card can draw its library state.
Future<List<StreamSubscription<List<Manga>>>> _subscribeCards(
  List<String> titles,
  _CardWatch watch,
) async {
  final firsts = <Future<void>>[];
  final subscriptions = <StreamSubscription<List<Manga>>>[];
  for (final title in titles) {
    final first = Completer<void>();
    firsts.add(first.future);
    subscriptions.add(
      watch(ItemType.manga, title).listen((_) {
        if (!first.isCompleted) first.complete();
      }),
    );
  }
  await Future.wait(firsts);
  return subscriptions;
}

void main() {
  late Directory root;
  late FakeExtensionServer server;
  late List<String> resultTitles;

  setUpAll(() async {
    if (!_enabled) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    root = Directory.systemTemp.createTempSync('mangatan_global_search_perf');
    PathProviderPlatform.instance = TempPathProvider(root.path);
    server = await FakeExtensionServer.start();

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
      name: 'global_search_perf',
    );

    // A typical extension APK is a few hundred kilobytes; Mihon requests
    // carry it base64 encoded.
    final random = Random(7);
    final apk = base64Encode(
      List<int>.generate(400 * 1024, (_) => random.nextInt(256)),
    );
    Source source(int id, String name, ItemType type) => Source(
      id: id,
      name: name,
      lang: 'en',
      baseUrl: 'https://bench.example',
      isAdded: true,
      isActive: true,
      sourceCode: apk,
      itemType: type,
    )..sourceCodeLanguage = SourceCodeLanguage.mihon;

    isar.writeTxnSync(() {
      isar.settings.putSync(
        Settings()
          ..androidProxyServer = server.baseUrl
          ..downloadLocation = '${root.path}/downloads'
          ..chapterFilterUnreadList = []
          ..chapterFilterBookmarkedList = []
          ..chapterFilterDownloadedList = []
          ..sortChapterList = []
          ..filterScanlatorList = [],
      );
      isar.sources.putAllSync([
        for (var i = 0; i < _mangaSources; i++)
          source(9000 + i, 'Manga Source $i', ItemType.manga)
            ..isPinned = i.isEven,
        for (var i = 0; i < _otherSources; i++)
          source(
            8000 + i,
            'Other Source $i',
            i.isEven ? ItemType.anime : ItemType.novel,
          ),
      ]);
    });

    // The titles every source returns for a search.
    final pages = await ProviderContainer().read(
      searchProvider(
        source: sourceRepository.getAddedByItemType(ItemType.manga).first,
        query: 'warm',
        page: 1,
        filterList: const [],
      ).future,
    );
    resultTitles = [for (final m in pages!.list) m.name!];

    // A library where some results are already favorited, some under the
    // same source and some under another one, among many unrelated rows.
    Manga entry(int i, {required bool favorite, String? name, String? src}) =>
        Manga(
          source: src ?? 'Manga Source ${i % _mangaSources}',
          author: 'Author',
          artist: 'Artist',
          genre: const ['Action', 'Drama'],
          imageUrl: 'https://bench.example/cover/$i.jpg',
          lang: 'en',
          link: '/series/library-$i',
          name: name ?? 'Library Entry $i ${random.nextInt(1 << 30)}',
          status: Status.ongoing,
          description: 'A description of entry $i, ' * 8,
          sourceId: 9000 + i % _mangaSources,
          favorite: favorite,
          itemType: i % 10 == 9 ? ItemType.anime : ItemType.manga,
          dateAdded: 1600000000000 + i,
        );
    isar.writeTxnSync(() {
      isar.mangas.putAllSync([
        for (var i = 0; i < _favorites; i++)
          entry(
            i,
            favorite: true,
            // Every fifth favorite is one of the search results.
            name: i % 5 == 0 ? resultTitles[i % resultTitles.length] : null,
          ),
        for (var i = 0; i < _browsed; i++)
          entry(
            _favorites + i,
            favorite: false,
            name: i % 7 == 0 ? resultTitles[i % resultTitles.length] : null,
          ),
      ]);
    });
  });

  tearDownAll(() async {
    if (!_enabled) return;
    final out = Platform.environment['MANGATAN_PERF_OUT'];
    if (out != null) {
      File(
        out,
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_results));
    }
    await server.close();
    await isar.close(deleteFromDisk: true);
    root.deleteSync(recursive: true);
  });

  test('open screen: load the searched sources', skip: !_enabled, () async {
    await _bench('source_list_all', (i) async {
      final clock = Stopwatch()..start();
      final sources = sourceRepository.getAddedByItemType(ItemType.manga);
      clock.stop();
      expect(sources, hasLength(_mangaSources));
      return _Run(_ms(clock));
    });
    await _bench('source_list_pinned', (i) async {
      final clock = Stopwatch()..start();
      final sources = sourceRepository.getPinnedByItemType(ItemType.manga);
      clock.stop();
      expect(sources, hasLength(_mangaSources ~/ 2));
      return _Run(_ms(clock));
    });
  });

  test(
    'global search: every source through the fetch gate',
    skip: !_enabled,
    () async {
      final sources = sourceRepository.getAddedByItemType(ItemType.manga);
      await _bench('global_search_all_sources', (i) async {
        final container = ProviderContainer();
        final gate = FetchGate(3);
        final clock = Stopwatch()..start();
        final sample = await _traced(PerfFlow.browseSource, () async {
          // As each SourceSearchScreen row does in initState.
          final results = await Future.wait([
            for (final source in sources)
              () async {
                await gate.acquire();
                try {
                  return await container.read(
                    searchProvider(
                      source: source,
                      page: 1,
                      query: 'bench $i',
                      filterList: const [],
                    ).future,
                  );
                } finally {
                  gate.release();
                }
              }(),
          ]);
          expect(results.whereType<MPages>(), hasLength(sources.length));
        });
        clock.stop();
        container.dispose();
        return _Run(_ms(clock), sample.network.inMicroseconds / 1000);
      });
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );

  List<String> visibleCards() => [
    for (var row = 0; row < _mangaSources; row++)
      for (var i = 0; i < _cardsPerRow; i++)
        resultTitles[(row + i) % resultTitles.length],
  ];

  test('result cards: first library lookup', skip: !_enabled, () async {
    final titles = visibleCards();
    await _bench('cards_first_lookup', (i) async {
      final clock = Stopwatch()..start();
      final subscriptions = await _subscribeCards(
        titles,
        mangaRepository.watchFavoritesByItemTypeAndName,
      );
      clock.stop();
      for (final s in subscriptions) {
        await s.cancel();
      }
      return _Run(_ms(clock));
    });
  });

  test(
    'result cards: resubscribe every card once (previous rebuild)',
    skip: !_enabled,
    () async {
      // Before, every rebuild of a card handed its StreamBuilder a new
      // stream, so the card dropped its watch and ran the query again. The
      // whole result list rebuilds whenever a source finishes with nothing to
      // show. This is the cost of one such rebuild.
      final titles = visibleCards();
      var held = await _subscribeCards(
        titles,
        mangaRepository.watchFavoritesByItemTypeAndName,
      );
      await _bench('cards_resubscribe_all', (i) async {
        final clock = Stopwatch()..start();
        final next = await _subscribeCards(
          titles,
          mangaRepository.watchFavoritesByItemTypeAndName,
        );
        for (final s in held) {
          await s.cancel();
        }
        clock.stop();
        held = next;
        return _Run(_ms(clock));
      });
      for (final s in held) {
        await s.cancel();
      }
    },
  );

  test(
    'result cards: a library write while results are open',
    skip: !_enabled,
    () async {
      final titles = visibleCards();
      var emissions = 0;
      final subscriptions = <StreamSubscription<List<Manga>>>[];
      final firsts = <Future<void>>[];
      for (final title in titles) {
        final first = Completer<void>();
        firsts.add(first.future);
        subscriptions.add(
          mangaRepository
              .watchFavoritesByItemTypeAndName(ItemType.manga, title)
              .listen((_) {
                emissions++;
                if (!first.isCompleted) first.complete();
              }),
        );
      }
      await Future.wait(firsts);
      final target = isar.mangas
          .filter()
          .favoriteEqualTo(true)
          .nameEqualTo(titles.first)
          .findFirstSync()!;
      await _bench('cards_after_library_write', (i) async {
        emissions = 0;
        final clock = Stopwatch()..start();
        // Toggle a favorite that one card shows, as the detail screen does.
        await isar.writeTxn(
          () => isar.mangas.put(target..dateAdded = target.dateAdded! + 1),
        );
        // Wait until the watches have answered: a quiet period with no new
        // emissions after the write.
        var seen = -1;
        while (seen != emissions) {
          seen = emissions;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        clock.stop();
        return _Run(_ms(clock) - 20);
      });
      // ignore: avoid_print
      print('BENCH cards_after_library_write emissions=$emissions');
      for (final s in subscriptions) {
        await s.cancel();
      }
    },
  );

  test(
    'library search: filter the library by a query',
    skip: !_enabled,
    () async {
      final container = ProviderContainer();
      container.listen(downloadedChapterIdsProvider, (_, _) {});
      await container.read(downloadedChapterIdsProvider.future);
      for (final (name, ignoreFilters) in [
        ('library_search', false),
        ('library_search_ignore_filters', true),
      ]) {
        await _bench(name, (i) async {
          final data = isar.mangas
              .filter()
              .favoriteEqualTo(true)
              .and()
              .itemTypeEqualTo(ItemType.manga)
              .findAllSync();
          final clock = Stopwatch()..start();
          final found = container.read(
            filteredLibraryMangaProvider(
              data: data,
              downloadFilterType: 0,
              unreadFilterType: 0,
              startedFilterType: 0,
              bookmarkedFilterType: 0,
              completedFilterType: 0,
              trackingFilterType: 0,
              sortType: 0,
              downloadedOnly: false,
              searchQuery: 'series, drama $i',
              ignoreFiltersOnSearch: ignoreFilters,
              sourceIds: const [],
            ),
          );
          clock.stop();
          expect(found, isNotEmpty);
          return _Run(_ms(clock));
        });
      }
      container.dispose();
    },
  );
}
