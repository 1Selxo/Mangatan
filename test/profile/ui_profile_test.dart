// CPU profile and frame costs of journeys through the app's screens, on a
// copy of a real database.
//
//   MANGATAN_PROFILE_DB=<folder with a copy of mangayomiDb.isar> \
//     flutter test --enable-vmservice test/profile/ui_profile_test.dart
//
// Network requests, extensions and covers are stand-ins: these scenarios
// measure what the app itself costs. A frame time is the real time one pump
// took to build, lay out and paint, in a debug build.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/model/m_manga.dart';
import 'package:mangayomi/eval/model/m_pages.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/get_popular.dart';
import 'package:mangayomi/services/search.dart';
import 'package:material_ui/material_ui.dart';

import '../journeys/harness/journey.dart';
import 'profiler.dart';
import 'real_data.dart';

late Profiler _profiler;

class _Bench {
  _Bench(this.tester);
  final WidgetTester tester;

  /// One frame; returns how long building and painting it took.
  Future<double> frame() async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    final w = Stopwatch()..start();
    await tester.pump(const Duration(milliseconds: 16));
    return w.elapsedMicroseconds / 1000;
  }

  /// Profiles [action] and the [frames] frames after it.
  Future<void> run(
    String name,
    FutureOr<void> Function() action, {
    int frames = 60,
    Map<String, Object?> facts = const {},
  }) async {
    debugPrint('$name starting');
    await tester.runAsync(_profiler.start);
    final wall = Stopwatch()..start();
    await action();
    final times = <double>[];
    var drained = Duration.zero;
    for (var i = 0; i < frames; i++) {
      times.add(await frame());
      if (times.last > 500 || (i > 0 && i % 20 == 0)) {
        debugPrint('$name frame $i: ${times.last.round()} ms');
      }
      // A screen that costs this much per frame is measured by then.
      if (wall.elapsed > const Duration(seconds: 90)) break;
      if (wall.elapsed - drained > const Duration(seconds: 2)) {
        await tester.runAsync(_profiler.drain);
        drained = wall.elapsed;
      }
    }
    final total = times.fold<double>(0, (a, b) => a + b);
    await tester.runAsync(
      () => _profiler.stop(name, {
        ...facts,
        'frames': summary(times),
        'framesOver16ms': times.where((t) => t > 16).length,
        'frameWorkMs': total.round(),
      }),
    );
  }
}

Future<Journey> _startReal(
  WidgetTester tester, {
  bool activeSourcesOnly = false,
  List<Override> overrides = const [],
}) async {
  final journey = await Journey.start(
    tester,
    overrides: overrides,
    arrange: (seed) async {
      final db = await openRealDatabaseCopy(
        Directory('${seed.directory.path}/real'),
      );
      if (activeSourcesOnly) {
        await db.writeTxn(
          () => db.sources
              .filter()
              .isAddedEqualTo(true)
              .isActiveEqualTo(false)
              .deleteAll(),
        );
      }
      app.isar = db;
    },
  );
  journey.checkHealth = false;
  return journey;
}

/// Image loads fail in a test (there is no network); they are not what is
/// being measured. The returned function restores the handler, which
/// flutter_test requires before a test body ends.
VoidCallback _ignoreAppErrors() {
  final previous = FlutterError.onError;
  var seen = 0;
  FlutterError.onError = (details) {
    if (seen++ < 5) debugPrint('ignored: ${details.exceptionAsString()}');
  };
  return () => FlutterError.onError = previous;
}

void main() {
  final skip = realDatabaseDir == null;

  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    (binding as AutomatedTestWidgetsFlutterBinding).defaultTestTimeout =
        const Timeout(Duration(minutes: 15));
  });

  testWidgets('screens on real data', (tester) async {
    await tester.runAsync(() async => _profiler = await Profiler.connect());
    final j = await _startReal(tester);
    final b = _Bench(tester);
    final restoreErrors = _ignoreAppErrors();
    try {
      final facts = {
        'sources': j.db.sources.countSync(),
        'mangas': j.db.mangas.countSync(),
        'chapters': j.db.chapters.countSync(),
      };

      await b.run('ui-01-boot', () => j.restart(), facts: facts);
      for (final (name, route) in [
        ('ui-02-history', '/history'),
        ('ui-03-updates', '/updates'),
        ('ui-04-browse-sources', '/browse'),
        ('ui-05-more', '/more'),
        ('ui-06-library', '/MangaLibrary'),
      ]) {
        await b.run(name, () => j.router.go(route));
      }
      j.router.go('/browse');
      await j.settle();
      await b.run(
        'ui-07-extensions-tab',
        () => tester.tap(find.byType(Tab).at(1)),
      );

      final counts = <int, int>{};
      for (final c in j.db.chapters.where().findAllSync()) {
        counts[c.mangaId!] = (counts[c.mangaId!] ?? 0) + 1;
      }
      final biggest = counts.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      await b.run(
        'ui-08-detail-longest-series',
        () => unawaited(
          j.router.push('/manga-reader/detail', extra: biggest.key),
        ),
        facts: {'chapters': biggest.value},
      );
      await b.run('ui-09-detail-scroll', () async {
        for (var i = 0; i < 15; i++) {
          await tester.drag(
            find.byType(Scrollable).last,
            const Offset(0, -600),
            warnIfMissed: false,
          );
          await b.frame();
        }
      });
      j.router.go('/MangaLibrary');
      await j.settle();
      for (final route in ['settings', 'statistics', 'dataAndStorage']) {
        await b.run('ui-10-$route', () => unawaited(j.router.pushNamed(route)));
        j.router.pop();
        await j.settle(rounds: 4);
      }
    } finally {
      restoreErrors();
      await tester.runAsync(_profiler.dispose);
    }
  }, skip: skip);

  for (final activeOnly in [false, true]) {
    final tag = activeOnly ? 'enabled-sources-only' : 'as-shipped';
    testWidgets('global search, $tag', (tester) async {
      await tester.runAsync(() async => _profiler = await Profiler.connect());
      final answer = Completer<void>();
      var started = 0;
      Future<MPages> reply(Source source) async {
        started++;
        await answer.future;
        // One source in three fails, as broken extensions do.
        if (source.id! % 3 == 0) throw StateError('HTTP 500');
        return MPages(
          list: [
            for (var i = 0; i < 20; i++)
              MManga(
                name: 'Result $i of ${source.id}',
                link: '/m/$i',
                imageUrl: '',
              ),
          ],
          hasNextPage: true,
        );
      }

      final j = await _startReal(
        tester,
        activeSourcesOnly: activeOnly,
        overrides: [
          searchProvider.overrideWith((ref, a) => reply(a.source)),
          getPopularProvider.overrideWith((ref, a) => reply(a.source)),
        ],
      );
      final b = _Bench(tester);
      final restoreErrors = _ignoreAppErrors();
      try {
        final sources = j.db.sources
            .filter()
            .isAddedEqualTo(true)
            .itemTypeEqualTo(ItemType.manga)
            .countSync();
        final facts = {'sourcesSearched': sources};

        await b.run(
          'ui-11-global-search-open-$tag',
          () => unawaited(
            j.router.pushNamed('globalSearch', extra: ('one', ItemType.manga)),
          ),
          frames: 3,
          facts: facts,
        );
        await b.run(
          'ui-12-global-search-waiting-$tag',
          () {},
          facts: {...facts, 'requestsInFlight': started},
        );
        await b.run(
          'ui-13-global-search-results-$tag',
          () => answer.complete(),
          frames: 120,
          facts: facts,
        );
        print('requests started: $started');
      } finally {
        restoreErrors();
        await tester.runAsync(_profiler.dispose);
      }
    }, skip: skip);
  }
}
