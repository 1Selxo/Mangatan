// Benchmarks the app's common flows end to end against a loopback extension
// server with a fixed artificial latency.
//
// Skipped unless MANGATAN_PERF is set, because each run takes a while:
//
//   MANGATAN_PERF=1 flutter test test/perf/flow_benchmark_test.dart
//
// MANGATAN_PERF_OUT=<file> also writes the results as JSON.
//
// The flows go through the real providers, the real Mihon service and HTTP
// stack, and a real Isar database. Only the extension server is fake. Network
// time is what PerfMetrics attributes to HTTP; processing is the rest.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/lib.dart';
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
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/track_preference.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/manga/detail/providers/update_manga_detail_providers.dart';
import 'package:mangayomi/modules/widgets/custom_extended_image_provider.dart';
import 'package:mangayomi/services/get_chapter_pages.dart';
import 'package:mangayomi/services/get_detail.dart';
import 'package:mangayomi/services/get_popular.dart';
import 'package:mangayomi/services/get_video_list.dart';
import 'package:mangayomi/services/perf/perf_metrics.dart';
import 'package:mangayomi/utils/extensions/manga_extensions.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../test_utils/isar_library.dart';
import 'fake_extension_server.dart';
import 'temp_path_provider.dart';

final _enabled = Platform.environment['MANGATAN_PERF'] != null;
final _iterations =
    int.tryParse(Platform.environment['MANGATAN_PERF_RUNS'] ?? '') ?? 12;
const _warmup = 3;
const _otherInstalledSources = 24;

/// Median and 90th percentile of one measured quantity, in milliseconds.
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

/// Longest gap between ticks of a zero-delay timer loop on this isolate,
/// which is how long the isolate was busy without yielding. No threshold is
/// applied; only the maximum is reported.
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

Future<void> _bench(
  String name,
  Future<PerfSample> Function(int iteration) run, {
  int iterations = 0,
}) async {
  final runs = iterations > 0 ? iterations : _iterations;
  final totals = <double>[];
  final networks = <double>[];
  final processing = <double>[];
  final stalls = <double>[];
  for (var i = 0; i < _warmup + runs; i++) {
    final probe = _StallProbe()..start();
    final sample = await run(i);
    final stall = probe.stop();
    if (i < _warmup) continue;
    totals.add(sample.total.inMicroseconds / 1000);
    networks.add(sample.network.inMicroseconds / 1000);
    processing.add(sample.processing.inMicroseconds / 1000);
    stalls.add(stall / 1000);
  }
  final result = {
    'runs': runs,
    'totalMs': _Stat(totals).toJson(),
    'networkMs': _Stat(networks).toJson(),
    'processingMs': _Stat(processing).toJson(),
    'longestMainIsolateStallMs': _Stat(stalls).toJson(),
  };
  _results[name] = result;
  // ignore: avoid_print
  print('BENCH $name ${jsonEncode(result)}');
}

var _traceCount = 0;

/// Runs [body] as a PerfMetrics trace and returns its sample. The trace gets
/// a unique label so samples of other traces, including the flow's own nested
/// trace, are never mistaken for it.
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

void main() {
  late Directory root;
  late FakeExtensionServer server;
  late Source mangaSource;
  late Source animeSource;
  var nextId = 1;

  setUpAll(() async {
    if (!_enabled) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    root = Directory.systemTemp.createTempSync('mangatan_perf');
    PathProviderPlatform.instance = TempPathProvider(root.path);
    server = await FakeExtensionServer.start();
    server.imageBytes = File('assets/screenshots/manga-lookup.jpg')
        .readAsBytesSync();

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
      name: 'perf',
    );

    // A typical extension APK is a few hundred kilobytes; Mihon requests
    // carry it base64 encoded.
    final random = Random(7);
    final apk = base64Encode(
      List<int>.generate(400 * 1024, (_) => random.nextInt(256)),
    );
    Source source(int id, ItemType type) => Source(
      id: id,
      name: 'Bench ${type.name}',
      lang: 'en',
      baseUrl: 'https://bench.example',
      isAdded: true,
      isActive: true,
      sourceCode: apk,
      itemType: type,
    )..sourceCodeLanguage = SourceCodeLanguage.mihon;
    mangaSource = source(9001, ItemType.manga);
    animeSource = source(9002, ItemType.anime);

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
      // Other installed extensions. Lookups deserialize installed sources,
      // so their number matters even though the flows never call them.
      isar.sources.putAllSync([
        for (var i = 0; i < _otherInstalledSources; i++)
          source(8000 + i, ItemType.values[i % 3])..name = 'Other $i',
      ]);
      isar.sources.putAllSync([mangaSource, animeSource]);
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

  Manga newManga(Source source, {String? title}) {
    final id = nextId++;
    final manga = Manga(
      source: source.name,
      author: '',
      artist: '',
      genre: const [],
      imageUrl: '',
      lang: source.lang,
      link: '/series/bench-$id',
      name: title ?? 'Bench Entry $id',
      status: Status.unknown,
      description: '',
      sourceId: source.id,
      itemType: source.itemType,
    );
    isar.writeTxnSync(() => isar.mangas.putSync(manga));
    return manga;
  }

  Future<Chapter> newChapter(Source source) async {
    final manga = newManga(source);
    final chapter = Chapter(
      mangaId: manga.id,
      name: 'Chapter 1',
      url: '${manga.link}/chapter-1-${nextId++}',
    )..manga.value = manga;
    await isar.writeTxn(() async {
      await isar.chapters.put(chapter);
      await chapter.manga.save();
    });
    return chapter;
  }

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        // getDetail's own body is prepareMihonBridge plus this call; the
        // bridge check is measured by the other flows.
        getDetailProvider.overrideWith(
          (ref, args) => withExtensionService(
            args.source,
            server.baseUrl,
            (service) => service.getDetail(args.url),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('browse source: popular page', skip: !_enabled, () async {
    await _bench('browse_source', (i) async {
      final c = container();
      return _traced(
        PerfFlow.browseSource,
        () =>
            c.read(getPopularProvider(source: mangaSource, page: i + 1).future),
      );
    });
  }, timeout: const Timeout(Duration(minutes: 10)));

  test(
    'open entry: first open fetches and stores details',
    skip: !_enabled,
    () async {
      await _bench('open_entry', (i) async {
        final manga = newManga(mangaSource);
        final c = container();
        return _traced(
          PerfFlow.openEntry,
          () => c.read(
            updateMangaDetailProvider(mangaId: manga.id, isInit: true).future,
          ),
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test('library update: refresh of a stored entry', skip: !_enabled, () async {
    // What a library update does for each entry: fetch the details again
    // and merge them into the chapters already stored.
    await _bench('library_update_entry', (i) async {
      final manga = newManga(mangaSource);
      await container().read(
        updateMangaDetailProvider(mangaId: manga.id, isInit: true).future,
      );
      final c = container();
      return _traced(
        'library_update',
        () => c.read(
          updateMangaDetailProvider(
            mangaId: manga.id,
            isInit: false,
            showToast: false,
          ).future,
        ),
      );
    });
  }, timeout: const Timeout(Duration(minutes: 10)));

  test(
    'open entry: chapter list work per detail build',
    skip: !_enabled,
    () async {
      // The detail screen sorts and filters the whole chapter list on every
      // build. Measured once on a fresh title (first build after opening) and
      // again on the same title (every later rebuild).
      final cold = <double>[];
      final warm = <double>[];
      for (var i = 0; i < _warmup + _iterations; i++) {
        final manga = newManga(mangaSource);
        final c = container();
        await c.read(
          updateMangaDetailProvider(mangaId: manga.id, isInit: true).future,
        );
        final stored = isar.mangas.getSync(manga.id!)!;
        final rows = isar.chapters
            .filter()
            .mangaIdEqualTo(manga.id)
            .findAllSync();
        double build() {
          final clock = Stopwatch()..start();
          stored.getSortedFilteredChapters(sourceChapters: rows);
          stored.unrecognizedChapterNumberCount();
          return clock.elapsedMicroseconds / 1000;
        }

        final first = build();
        final later = build();
        if (i < _warmup) continue;
        cold.add(first);
        warm.add(later);
      }
      final result = {
        'chapters': server.chapterCount,
        'firstBuildMs': _Stat(cold).toJson(),
        'laterBuildMs': _Stat(warm).toJson(),
      };
      _results['entry_detail_build'] = result;
      // ignore: avoid_print
      print('BENCH entry_detail_build ${jsonEncode(result)}');
    },
  );

  test('open chapter: page list', skip: !_enabled, () async {
    await _bench('open_chapter', (i) async {
      final chapter = await newChapter(mangaSource);
      final c = container();
      return _traced(
        PerfFlow.openChapter,
        () => c.read(getChapterPagesProvider(chapter: chapter).future),
      );
    });
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('open episode: video list', skip: !_enabled, () async {
    await _bench('open_episode', (i) async {
      final episode = await newChapter(animeSource);
      final c = container();
      return _traced(
        PerfFlow.openEpisode,
        () => c.read(getVideoListProvider(episode: episode).future),
      );
    });
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('load media: cover image, cache miss then hit', skip: !_enabled, () async {
    Future<PerfSample> load(String url) async {
      final completer = Completer<PerfSample>();
      final remove = PerfMetrics.addListener((sample) {
        if (sample.flow == PerfFlow.loadMedia && !completer.isCompleted) {
          completer.complete(sample);
        }
      });
      try {
        final provider = CustomExtendedNetworkImageProvider(url);
        final stream = provider.resolve(ImageConfiguration.empty);
        final loaded = Completer<void>();
        late final ImageStreamListener listener;
        listener = ImageStreamListener(
          (_, _) => loaded.complete(),
          onError: (e, _) => loaded.completeError(e),
        );
        stream.addListener(listener);
        await loaded.future;
        stream.removeListener(listener);
        return await completer.future;
      } finally {
        remove();
      }
    }

    var n = 0;
    await _bench(
      'load_media_miss',
      (i) => load(
        '${server.baseUrl}/image/${n++}-${DateTime.now().microsecondsSinceEpoch}.jpg',
      ),
    );
    final cached = '${server.baseUrl}/image/cached.jpg';
    await load(cached);
    await _bench('load_media_hit', (i) {
      PaintingBinding.instance.imageCache.clear();
      return load(cached);
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
