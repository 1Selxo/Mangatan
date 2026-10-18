// Measures app startup in a real engine: the app's own `main`, from process
// launch to the first frame that shows library entries, and the frames and
// main-isolate stalls of the seconds after it. Build it in profile mode with
// the harness define, which keeps every isolate's data in a throwaway folder:
//
//   ./scripts/build_macos.sh --profile --no-open -- \
//     -t tool/perf/startup_main.dart --dart-define=MANGATAN_PERF_HARNESS=true
//
// Then drive it with tool/perf/startup_driver.dart, which seeds a library into
// a scratch folder once and launches the app repeatedly against it.
//
// Environment (read at run time):
//
// - MANGATAN_PERF_ROOT: the throwaway data folder. Required.
// - MANGATAN_PERF_SEED=1: write a realistic library into the folder and quit.
// - MANGATAN_PERF_WATCH: seconds to keep measuring after the first library
//   frame (default 8).
// - MANGATAN_PERF_HOLD: seconds to stay open after the result, for a
//   profiler (default 0).
//
// The user's own data is never touched: a harness build refuses to start
// without MANGATAN_PERF_ROOT.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/widgets/cover_view_widget.dart';
import 'package:mangayomi/providers/storage_provider.dart';
import 'package:mangayomi/services/perf/benchmark_data_root.dart';
import 'package:mangayomi/services/perf/perf_metrics.dart';
import 'package:mangayomi/services/perf/startup_trace.dart';
import 'package:window_manager/window_manager.dart';

const _entries = 500;
const _chaptersPerEntry = 150;
const _installedSources = 30;
const _readChapterPageIndexes = 20000;

Future<void> main() async {
  if (!kBenchmarkHarness) {
    stdout.writeln(
      'STARTUP_ERROR build with --dart-define=MANGATAN_PERF_HARNESS=true',
    );
    exit(2);
  }
  // Throws without MANGATAN_PERF_ROOT, before anything asks for storage.
  applyBenchmarkDataRoot();
  if (Platform.environment['MANGATAN_PERF_SEED'] == '1') {
    await _seed();
    exit(0);
  }
  final watch = Duration(
    seconds:
        int.tryParse(Platform.environment['MANGATAN_PERF_WATCH'] ?? '') ?? 8,
  );
  _Probe(watch).install();
  app.main(const []);
}

/// Watches the real startup from the outside: the first frame that shows a
/// library entry, frame timings and the longest main-isolate stalls.
class _Probe {
  _Probe(this.watch);
  final Duration watch;

  final _stalls = _StallProbe();
  PerfFrameWindow? _allFrames;
  PerfFrameWindow? _afterLibraryFrames;
  StartupMark? _libraryFrame;
  int? _libraryFrameVsync;

  void install() {
    late final VoidCallback remove;
    remove = StartupTrace.addListener((mark) {
      switch (mark.phase) {
        case 'window':
          // A hidden or covered window gets no vsync, so keep it on top.
          unawaited(windowManager.setAlwaysOnTop(true));
        case 'run_app':
          _stalls.start();
          _allFrames = PerfFrameWindow.start();
          SchedulerBinding.instance.addTimingsCallback(_timings.addAll);
          SchedulerBinding.instance.addPostFrameCallback(_afterFrame);
          remove();
      }
    });
  }

  void _afterFrame(Duration _) {
    if (_hasCover(WidgetsBinding.instance.rootElement)) {
      _libraryFrameVsync =
          SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
      StartupTrace.mark('library_frame');
      _libraryFrame = StartupTrace.marks.last;
      _afterLibraryFrames = PerfFrameWindow.start();
      unawaited(Future<void>.delayed(watch, _finish));
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback(_afterFrame);
  }

  static bool _hasCover(Element? root) {
    if (root == null) return false;
    var found = false;
    void visit(Element element) {
      if (found) return;
      if (element.widget is CoverViewWidget) {
        found = true;
        return;
      }
      element.visitChildren(visit);
    }

    visit(root);
    return found;
  }

  Future<void> _finish() async {
    final stalls = _stalls.stop();
    final libraryRaster = _rasterAfterBuild(_libraryFrameVsync);
    final all = await _allFrames!.finish();
    final after = await _afterLibraryFrames!.finish();
    final result = {
      'marks': [for (final m in StartupTrace.marks) m.toJson()],
      'libraryFrameRasterMs': libraryRaster,
      'framesFromRunApp': all.toJson(),
      'framesAfterLibrary': after.toJson(),
      'longestStallsMs': stalls,
      'libraryFrameSinceMainMs': _libraryFrame!.sinceMainMicros / 1000,
    };
    stdout.writeln('STARTUP_RESULT ${jsonEncode(result)}');
    await stdout.flush();
    // Stays open for a profiler to collect, when asked.
    final hold =
        int.tryParse(Platform.environment['MANGATAN_PERF_HOLD'] ?? '') ?? 0;
    await Future<void>.delayed(Duration(seconds: hold));
    exit(0);
  }

  final _timings = <FrameTiming>[];

  /// How long the library frame took to rasterize after its build finished.
  double? _rasterAfterBuild(int? vsync) {
    if (vsync == null) return null;
    for (final t in _timings) {
      if (t.timestampInMicroseconds(FramePhase.vsyncStart) == vsync) {
        return (t.timestampInMicroseconds(FramePhase.rasterFinish) -
                t.timestampInMicroseconds(FramePhase.buildFinish)) /
            1000;
      }
    }
    return null;
  }
}

/// The longest gaps between ticks of a 1 ms timer on the main isolate, with
/// when each started (milliseconds since the `main` mark).
class _StallProbe {
  final _clock = Stopwatch();
  int _last = 0;
  int _base = 0;
  final _gaps = <(int, int)>[];
  Timer? _timer;

  void start() {
    _base = StartupTrace.marks.last.sinceMainMicros;
    _clock.start();
    _timer = Timer.periodic(const Duration(milliseconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = _clock.elapsedMicroseconds;
    _gaps.add((now - _last, _last));
    if (_gaps.length > 64) {
      _gaps.sort((a, b) => b.$1.compareTo(a.$1));
      _gaps.removeRange(16, _gaps.length);
    }
    _last = now;
  }

  List<Map<String, double>> stop() {
    _timer?.cancel();
    _tick();
    _gaps.sort((a, b) => b.$1.compareTo(a.$1));
    return [
      for (final (gap, at) in _gaps.take(8))
        {'ms': gap / 1000, 'atMs': (_base + at) / 1000},
    ];
  }
}

/// A library like an active reader's: entries with chapters, history,
/// updates, downloads, categories, installed extensions and the per-entry
/// settings that accumulate over time.
Future<void> _seed() async {
  final isar = await StorageProvider().initDB(null);
  app.isar = isar;
  final random = Random(11);
  final now = DateTime(2026).millisecondsSinceEpoch;
  final apk = base64Encode(
    List<int>.generate(400 * 1024, (_) => random.nextInt(256)),
  );
  final mangas = [
    for (var i = 0; i < _entries; i++)
      Manga(
        source: 'Source ${i % 10}',
        author: 'Author ${i % 50}',
        artist: '',
        genre: const ['Action', 'Drama'],
        imageUrl: '',
        lang: 'en',
        link: '/series/$i',
        name: 'Library Entry ${random.nextInt(1 << 30)}',
        status: Status.values[i % Status.values.length],
        description: 'Description of entry $i',
        sourceId: 8000 + i % 10,
        favorite: true,
        categories: [if (i % 3 != 2) i % 3 + 1],
        dateAdded: now - random.nextInt(1 << 30),
        lastUpdate: now - random.nextInt(1 << 30),
        lastRead: now - random.nextInt(1 << 30),
      ),
  ];
  isar.writeTxnSync(() {
    isar.categorys.putAllSync([
      for (var c = 1; c <= 3; c++)
        Category(
          id: c,
          name: 'Category $c',
          forItemType: ItemType.manga,
          pos: c - 1,
        ),
    ]);
    isar.sources.putAllSync([
      for (var i = 0; i < _installedSources; i++)
        Source(
          id: 8000 + i,
          name: 'Source $i',
          lang: 'en',
          baseUrl: 'https://source$i.example',
          isAdded: true,
          isActive: true,
          sourceCode: apk,
          itemType: ItemType.values[i % 3],
        )..sourceCodeLanguage = SourceCodeLanguage.mihon,
    ]);
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
      final history = History(
        mangaId: manga.id,
        chapterId: chapters.first.id,
        itemType: ItemType.manga,
        date: '${now - random.nextInt(1 << 30)}',
      )..chapter.value = chapters.first;
      isar.historys.putSync(history);
      history.chapter.saveSync();
      for (final c in chapters.take(4)) {
        final update = Update(
          mangaId: manga.id,
          chapterName: c.name,
          date: '${now - random.nextInt(1 << 30)}',
        )..chapter.value = c;
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
    isar.settings.putSync(
      isar.settings.getSync(227)!
        ..onboardingCompleted = true
        ..chapterFilterUnreadList = [
          for (final m in mangas) ChapterFilterUnread(mangaId: m.id),
        ]
        ..chapterFilterBookmarkedList = [
          for (final m in mangas) ChapterFilterBookmarked(mangaId: m.id),
        ]
        ..chapterFilterDownloadedList = [
          for (final m in mangas) ChapterFilterDownloaded(mangaId: m.id),
        ]
        ..sortChapterList = [for (final m in mangas) SortChapter(mangaId: m.id)]
        ..filterScanlatorList = [
          for (final m in mangas.take(_entries ~/ 5))
            FilterScanlator(mangaId: m.id, scanlators: ['Group B']),
        ]
        ..personalReaderModeList = [
          for (final m in mangas.take(300))
            PersonalReaderMode()..mangaId = m.id,
        ]
        ..personalPageModeList = [
          for (final m in mangas.take(300)) PersonalPageMode(mangaId: m.id),
        ]
        ..chapterPageIndexList = [
          for (var i = 0; i < _readChapterPageIndexes; i++)
            ChapterPageIndex(chapterId: chapterIds[i], index: i % 20),
        ]
        ..cookiesList = [
          for (var i = 0; i < 30; i++)
            MCookie(host: 'source$i.example', cookie: 'session=${'x' * 64}'),
        ],
    );
  });
  await isar.close();
  // The window opens at the same size and place on every launch.
  final supportDir = Directory(
    '${Platform.environment[benchmarkDataRootVariable]}/support',
  )..createSync(recursive: true);
  File('${supportDir.path}/window_geometry.json').writeAsStringSync(
    jsonEncode({
      'width': 1200,
      'height': 800,
      'x': 100,
      'y': 100,
      'isMaximized': false,
    }),
  );
  stdout.writeln('STARTUP_SEEDED');
}
