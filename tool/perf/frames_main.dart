// Measures the app's common flows in a real engine, including the frames
// rendered while each screen opens. Run it in profile mode:
//
//   flutter run --profile -d macos -t tool/perf/frames_main.dart
//
// It opens a throwaway database and data folder, serves a fake extension
// server from a separate isolate (so serving never costs the UI a frame),
// pushes the real screens with the app's own route type, prints one BENCH
// line per measurement and quits. The user's own data is never touched.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:image/image.dart' as img;
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/modules/anime/anime_player_view.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track_search.dart';
import 'package:mangayomi/modules/manga/detail/manga_detail_main.dart';
import 'package:mangayomi/modules/manga/detail/providers/update_manga_detail_providers.dart';
import 'package:mangayomi/modules/manga/home/manga_home_screen.dart';
import 'package:mangayomi/modules/manga/reader/reader_view.dart';
import 'package:mangayomi/modules/more/settings/appearance/providers/theme_provider.dart';
import 'package:mangayomi/providers/storage_provider.dart';
import 'package:mangayomi/router/router.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/perf/perf_metrics.dart';
import 'package:mangayomi/services/perf/perf_route_observer.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../test/perf/fake_extension_server.dart';
import '../../test/perf/temp_path_provider.dart';

const _runs = int.fromEnvironment('MANGATAN_PERF_RUNS', defaultValue: 8);
const _warmup = 2;

/// Runs only the named scenario, for profiling it.
const _only = String.fromEnvironment('MANGATAN_PERF_ONLY');

/// Seconds to stay open after the results, so a profiler can collect.
const _hold = int.fromEnvironment('MANGATAN_PERF_HOLD');
const _otherInstalledSources = 24;

/// How long the screen is left open after its data arrived, so image loads
/// and follow-up builds land inside the measured window.
const _settle = Duration(milliseconds: 1500);

final _container = ProviderContainer();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The reader asks the window plugin about full screen.
  await windowManager.ensureInitialized();
  // The episode player, as the app sets it up at launch.
  MediaKit.ensureInitialized();
  final root = Directory.systemTemp.createTempSync('mangatan_frames');
  PathProviderPlatform.instance = TempPathProvider(root.path);
  isar = await StorageProvider().initDB(
    (Directory('${root.path}/db')..createSync()).path,
  );
  final serverUrl = await _startServerIsolate();
  await _setupMpvConfig();
  // The reader's preferences live in Hive, which the app opens after launch.
  final hiveDirectory = Directory('${root.path}/hive')..createSync();
  Hive.init(hiveDirectory.path);
  MiningPreferences.configureStorageDirectory(hiveDirectory.path);
  Hive.registerAdapter(TrackSearchAdapter());

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
  final mangaSource = source(9001, ItemType.manga);
  final animeSource = source(9002, ItemType.anime);
  isar.writeTxnSync(() {
    isar.settings.putSync(
      isar.settings.getSync(227)!
        ..androidProxyServer = serverUrl
        ..downloadLocation = '${root.path}/downloads'
        ..chapterFilterUnreadList = []
        ..chapterFilterBookmarkedList = []
        ..chapterFilterDownloadedList = []
        ..sortChapterList = []
        ..filterScanlatorList = [],
    );
    isar.sources.putAllSync([
      for (var i = 0; i < _otherInstalledSources; i++)
        source(8000 + i, ItemType.values[i % 3])..name = 'Other $i',
      mangaSource,
      animeSource,
    ]);
  });

  runApp(UncontrolledProviderScope(container: _container, child: const _App()));
  // A hidden or covered window gets no vsync and renders nothing, so keep
  // the window visible, on top and at a fixed size for comparable runs.
  await windowManager.setSize(const Size(1200, 800));
  await windowManager.center();
  await windowManager.setAlwaysOnTop(true);
  await windowManager.show();
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(seconds: 2));

  final results = <String, Object?>{};
  try {
    results['browse_source'] = await _scenario(
      'browse_source',
      (i) => _open(
        MangaHomeScreen(source: mangaSource),
        name: '/mangaHome',
        flow: PerfFlow.browseSource,
      ),
    );
    results['open_entry_new'] = await _scenario('open_entry_new', (i) {
      final manga = _newManga(mangaSource);
      return _open(
        MangaReaderDetail(mangaId: manga.id!),
        name: '/manga-reader/detail',
        flow: PerfFlow.openEntry,
      );
    });
    final libraryEntry = _newManga(mangaSource);
    await _container.read(
      updateMangaDetailProvider(mangaId: libraryEntry.id, isInit: true).future,
    );
    results['open_entry_library'] = await _scenario(
      'open_entry_library',
      (i) => _open(
        MangaReaderDetail(mangaId: libraryEntry.id!),
        name: '/manga-reader/detail',
        flow: PerfFlow.openEntry,
      ),
    );
    results['open_chapter'] = await _scenario('open_chapter', (i) {
      final chapter = _newChapter(mangaSource);
      return _open(
        MangaReaderView(chapterId: chapter.id!),
        name: '/mangaReaderView',
        flow: PerfFlow.openChapter,
      );
    });
    results['open_episode'] = await _scenario('open_episode', (i) {
      final episode = _newChapter(animeSource);
      return _open(
        AnimePlayerView(episodeId: episode.id!),
        name: '/animePlayerView',
        flow: PerfFlow.openEpisode,
      );
    });
  } catch (e, s) {
    stdout.writeln('BENCH_ERROR $e\n$s');
  }
  stdout.writeln('BENCH_RESULTS ${jsonEncode(results)}');
  await stdout.flush();
  await Future<void>.delayed(Duration(seconds: _hold));
  exit(0);
}

/// The player's mpv config and scripts, written as the app writes them on its
/// first launch.
Future<void> _setupMpvConfig() async {
  final dir = (await StorageProvider().getMpvDirectory())!;
  final shadersDir = Directory(p.join(dir.path, 'shaders'));
  final scriptsDir = Directory(p.join(dir.path, 'scripts'));
  await Future.wait([
    shadersDir.create(recursive: true),
    scriptsDir.create(recursive: true),
  ]);
  final bytes = await rootBundle.load('assets/mangayomi_mpv.zip');
  final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());
  await Future.wait([
    for (final file in archive.files)
      if (file.name == 'mpv.conf' || file.name == 'input.conf')
        File(p.join(dir.path, file.name)).writeAsBytes(file.content)
      else if (file.name.startsWith('shaders/') && file.name.endsWith('.glsl'))
        File(p.join(shadersDir.path, p.basename(file.name)))
            .writeAsBytes(file.content)
      else if (file.name.startsWith('scripts/') &&
          (file.name.endsWith('.js') || file.name.endsWith('.lua')))
        File(p.join(scriptsDir.path, p.basename(file.name)))
            .writeAsBytes(file.content),
  ]);
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

int _entryCount = 0;

Manga _newManga(Source source) {
  final id = ++_entryCount;
  final manga = Manga(
    source: source.name,
    author: '',
    artist: '',
    genre: const [],
    imageUrl: '',
    lang: source.lang,
    link: '/series/frames-$id-${DateTime.now().microsecondsSinceEpoch}',
    name: 'Frames Entry $id',
    status: Status.unknown,
    description: '',
    sourceId: source.id,
    itemType: source.itemType,
  );
  isar.writeTxnSync(() => isar.mangas.putSync(manga));
  return manga;
}

Chapter _newChapter(Source source) {
  final manga = _newManga(source);
  final chapter = Chapter(
    mangaId: manga.id,
    name: 'Chapter 1',
    url: '${manga.link}/chapter-1',
  )..manga.value = manga;
  isar.writeTxnSync(() => isar.chapters.putSync(chapter));
  return chapter;
}

/// Pushes [page], waits for its flow sample and its transition, leaves it
/// open for [_settle], then pops it. Returns every sample recorded meanwhile.
Future<List<PerfSample>> _open(
  Widget page, {
  required String name,
  required String flow,
}) async {
  // PerfRouteObserver labels a route by its first path segment.
  final label = '/${name.split('/').where((e) => e.isNotEmpty).first}';
  final samples = <PerfSample>[];
  final flowDone = Completer<void>();
  final pushDone = Completer<void>();
  final popDone = Completer<void>();
  final remove = PerfMetrics.addListener((sample) {
    samples.add(sample);
    if (sample.flow == flow && !flowDone.isCompleted) flowDone.complete();
    if (sample.flow == PerfFlow.transition) {
      if (sample.label == 'push $label' && !pushDone.isCompleted) {
        pushDone.complete();
      } else if (sample.label == 'pop $label' && !popDone.isCompleted) {
        popDone.complete();
      }
    }
  });
  try {
    final navigator = navigatorKey.currentState!;
    // Every frame from the push until the screen has loaded and settled.
    final window = PerfFrameWindow.start()!;
    final clock = Stopwatch()..start();
    unawaited(
      navigator.push(
        CupertinoPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => page,
        ),
      ),
    );
    // A screen can answer from a provider that is still alive, in which case
    // no new flow sample arrives; the frames are measured either way.
    await Future.wait([flowDone.future, pushDone.future])
        .timeout(const Duration(seconds: 10), onTimeout: () => const []);
    await Future<void>.delayed(_settle);
    clock.stop();
    final frames = await window.finish();
    samples.add(
      PerfSample(
        flow: 'screen_open',
        label: label,
        total: clock.elapsed,
        network: Duration.zero,
        succeeded: true,
        frames: frames,
      ),
    );
    navigator.pop();
    await popDone.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    // Let late frame reports and media samples arrive.
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    return samples;
  } finally {
    remove();
  }
}

Future<Map<String, Object?>> _scenario(
  String name,
  Future<List<PerfSample>> Function(int i) once,
) async {
  if (_only.isNotEmpty && _only != name) return const {};
  final byKey = <String, List<PerfSample>>{};
  for (var i = 0; i < _warmup + _runs; i++) {
    final samples = await once(i);
    if (i < _warmup) continue;
    for (final sample in samples) {
      final key = sample.flow == PerfFlow.transition
          ? 'transition ${sample.label}'
          : sample.flow;
      byKey.putIfAbsent(key, () => []).add(sample);
    }
  }
  final result = <String, Object?>{};
  for (final MapEntry(:key, :value) in byKey.entries) {
    double ms(Duration d) => d.inMicroseconds / 1000;
    final framed = value.where((s) => s.frames != null).toList();
    result[key] = {
      'samples': value.length,
      'totalMs': _stat(value.map((s) => ms(s.total))),
      'networkMs': _stat(value.map((s) => ms(s.network))),
      'processingMs': _stat(value.map((s) => ms(s.processing))),
      if (framed.isNotEmpty) ...{
        'samplesWithoutFrames': framed
            .where((s) => s.frames!.frames == 0)
            .length,
        'frames': _stat(framed.map((s) => s.frames!.frames.toDouble())),
        'jankyFrames': _stat(
          framed.map((s) => s.frames!.jankyFrames.toDouble()),
        ),
        'droppedFrames': _stat(
          framed.map((s) => s.frames!.droppedFrames.toDouble()),
        ),
        'droppedFramesTotal': framed.fold<int>(
          0,
          (sum, s) => sum + s.frames!.droppedFrames,
        ),
        'worstBuildMs': _stat(
          framed.map((s) => s.frames!.worstBuildMicros / 1000),
        ),
        'budgetMs': framed.first.frames!.budgetMicros == null
            ? null
            : framed.first.frames!.budgetMicros! / 1000,
      },
    };
  }
  stdout.writeln('BENCH ${jsonEncode(result)}');
  return result;
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
  final image = img.Image(width: 600, height: 900);
  for (final pixel in image) {
    pixel
      ..r = random.nextInt(256)
      ..g = random.nextInt(256)
      ..b = random.nextInt(256);
  }
  server.imageBytes = img.encodeJpg(image, quality: 80);
  reply.send(server.baseUrl);
}
