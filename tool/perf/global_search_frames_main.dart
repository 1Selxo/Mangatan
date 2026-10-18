// Measures the frames the global search screen renders while it searches
// every installed source. Run it in profile mode:
//
//   ./scripts/build_macos.sh --profile --no-open -- \
//     -t tool/perf/global_search_frames_main.dart
//   build/macos/Build/Products/Profile/Mangatan.app/Contents/MacOS/Mangatan
//
// It opens a throwaway database and data folder, serves the fake extension
// server from a separate isolate, installs many sources (a third of which
// fail, like broken extensions do) and a large library, then opens the real
// GlobalSearchScreen with the app's route type. It prints one BENCH line and
// quits. The user's own data is never touched.
//
// Dart defines: MANGATAN_PERF_RUNS (measured opens, default 8, after 2
// warm-up opens) and MANGATAN_PERF_HOLD (seconds to stay open afterwards).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:window_manager/window_manager.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/browse/global_search/global_search_screen.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/theme_provider.dart';
import 'package:mangayomi/providers/storage_provider.dart';
import 'package:mangayomi/router/router.dart';
import 'package:mangayomi/services/perf/perf_metrics.dart';
import 'package:mangayomi/services/perf/perf_route_observer.dart';
import 'package:mangayomi/services/search.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../test/perf/fake_extension_server.dart';
import '../../test/perf/temp_path_provider.dart';

const _runs = int.fromEnvironment('MANGATAN_PERF_RUNS', defaultValue: 8);
const _warmup = 2;
const _hold = int.fromEnvironment('MANGATAN_PERF_HOLD');

const _mangaSources = 30;
const _otherSources = 20;
const _favorites = 800;
const _browsed = 3000;

/// How long the screen stays open after every source has answered, so image
/// loads and the follow-up builds land in the measured window.
const _settle = Duration(milliseconds: 1500);

/// Every third manga source fails after one round trip of latency, as a
/// broken extension does.
bool _broken(Source source) => (source.id! - 9000) % 3 == 2;

/// Counts finished source searches, failed or not.
var _finished = 0;
final _finishedChanged = StreamController<void>.broadcast();

final _container = ProviderContainer(
  overrides: [
    searchProvider.overrideWith((ref, args) async {
      try {
        if (_broken(args.source)) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          throw const HttpException('Bench extension failed: HTTP 500');
        }
        return await search(
          ref,
          source: args.source,
          query: args.query,
          page: args.page,
          filterList: args.filterList,
        );
      } finally {
        _finished++;
        _finishedChanged.add(null);
      }
    }),
  ],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final root = Directory.systemTemp.createTempSync('mangatan_gs_frames');
  PathProviderPlatform.instance = TempPathProvider(root.path);
  isar = await StorageProvider().initDB(
    (Directory('${root.path}/db')..createSync()).path,
  );
  final serverUrl = await _startServerIsolate();

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
      isar.settings.getSync(227)!
        ..androidProxyServer = serverUrl
        ..downloadLocation = '${root.path}/downloads',
    );
    isar.sources.putAllSync([
      for (var i = 0; i < _mangaSources; i++)
        source(9000 + i, 'Manga Source $i', ItemType.manga),
      for (var i = 0; i < _otherSources; i++)
        source(
          8000 + i,
          'Other Source $i',
          i.isEven ? ItemType.anime : ItemType.novel,
        ),
    ]);
  });

  // The titles every working source returns, so part of the library matches
  // the results.
  final firstSource = isar.sources.getSync(9000)!;
  final pages = await _container.read(
    searchProvider(
      source: firstSource,
      query: 'warm',
      page: 1,
      filterList: const [],
    ).future,
  );
  final titles = [for (final m in pages!.list) m.name!];
  Manga entry(int i, {required bool favorite, String? name}) => Manga(
    source: 'Manga Source ${i % _mangaSources}',
    author: 'Author',
    artist: 'Artist',
    genre: const ['Action', 'Drama'],
    imageUrl: '$serverUrl/image/library/$i.jpg',
    lang: 'en',
    link: '/series/library-$i',
    name: name ?? 'Library Entry $i',
    status: Status.ongoing,
    description: 'A description of entry $i, ' * 8,
    sourceId: 9000 + i % _mangaSources,
    favorite: favorite,
    itemType: i % 10 == 9 ? ItemType.anime : ItemType.manga,
  );
  isar.writeTxnSync(() {
    isar.mangas.putAllSync([
      for (var i = 0; i < _favorites; i++)
        entry(
          i,
          favorite: true,
          name: i % 5 == 0 ? titles[i % titles.length] : null,
        ),
      for (var i = 0; i < _browsed; i++)
        entry(
          _favorites + i,
          favorite: false,
          name: i % 7 == 0 ? titles[i % titles.length] : null,
        ),
    ]);
  });

  runApp(UncontrolledProviderScope(container: _container, child: const _App()));
  await windowManager.setSize(const Size(1200, 800));
  await windowManager.center();
  await windowManager.setAlwaysOnTop(true);
  await windowManager.show();
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(seconds: 2));

  final opens = <PerfFrameStats>[];
  final searchMs = <double>[];
  try {
    for (var i = 0; i < _warmup + _runs; i++) {
      final (frames, ms) = await _open('bench $i');
      if (i < _warmup) continue;
      opens.add(frames);
      searchMs.add(ms);
    }
  } catch (e, s) {
    stdout.writeln('BENCH_ERROR $e\n$s');
  }
  final result = {
    'opens': opens.length,
    'searchAllSourcesMs': _stat(searchMs),
    'frames': _stat(opens.map((f) => f.frames.toDouble())),
    'jankyFrames': _stat(opens.map((f) => f.jankyFrames.toDouble())),
    'droppedFrames': _stat(opens.map((f) => f.droppedFrames.toDouble())),
    'droppedFramesTotal': opens.fold<int>(0, (s, f) => s + f.droppedFrames),
    'jankyFramesTotal': opens.fold<int>(0, (s, f) => s + f.jankyFrames),
    'worstBuildMs': _stat(opens.map((f) => f.worstBuildMicros / 1000)),
    'worstRasterMs': _stat(opens.map((f) => f.worstRasterMicros / 1000)),
    'budgetMs': opens.isEmpty || opens.first.budgetMicros == null
        ? null
        : opens.first.budgetMicros! / 1000,
  };
  stdout.writeln('BENCH global_search_screen ${jsonEncode(result)}');
  await stdout.flush();
  await Future<void>.delayed(Duration(seconds: _hold));
  exit(0);
}

class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: ref.watch(lightThemeProvider),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: BotToastInit(),
      navigatorObservers: [BotToastNavigatorObserver(), PerfRouteObserver()],
      home: const Scaffold(body: Center(child: Text('Measuring'))),
    );
  }
}

/// Opens the screen on [query], waits until every source has answered and
/// the screen has settled, then closes it. Returns the frames rendered from
/// the push until then, and how long the sources took to answer.
Future<(PerfFrameStats, double)> _open(String query) async {
  final navigator = navigatorKey.currentState!;
  _finished = 0;
  final window = PerfFrameWindow.start()!;
  final clock = Stopwatch()..start();
  unawaited(
    navigator.push(
      CupertinoPageRoute<void>(
        settings: const RouteSettings(name: '/globalSearch'),
        builder: (_) =>
            GlobalSearchScreen(search: query, itemType: ItemType.manga),
      ),
    ),
  );
  while (_finished < _mangaSources) {
    await _finishedChanged.stream.first.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('sources did not answer'),
    );
  }
  final searchMs = clock.elapsedMicroseconds / 1000;
  await Future<void>.delayed(_settle);
  final frames = await window.finish();
  navigator.pop();
  await Future<void>.delayed(const Duration(milliseconds: 2500));
  return (frames, searchMs);
}

Map<String, double> _stat(Iterable<double> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) return const {};
  final n = sorted.length;
  final median = n.isOdd
      ? sorted[n ~/ 2]
      : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  final p90 = sorted[min(n - 1, (n * 0.9).floor())];
  return {
    'median': double.parse(median.toStringAsFixed(2)),
    'p90': double.parse(p90.toStringAsFixed(2)),
  };
}

Future<String> _startServerIsolate() async {
  final port = ReceivePort();
  await Isolate.spawn(_serverMain, port.sendPort);
  return await port.first as String;
}

Future<void> _serverMain(SendPort reply) async {
  final server = await FakeExtensionServer.start();
  final random = Random(3);
  final image = img.Image(width: 300, height: 450);
  for (final pixel in image) {
    pixel
      ..r = random.nextInt(256)
      ..g = random.nextInt(256)
      ..b = random.nextInt(256);
  }
  server.imageBytes = img.encodeJpg(image, quality: 80);
  reply.send(server.baseUrl);
}
