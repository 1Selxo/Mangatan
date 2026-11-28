// The real app, for tool/perf/real_app_driver.dart. Build it in profile mode
// with the harness define, which keeps all of its data in MANGATAN_PERF_ROOT:
//
//   flutter build windows --profile -t tool/perf/real_app_main.dart \
//     --dart-define=MANGATAN_PERF_HARNESS=true
//
// It runs the app's own main unchanged. With MANGATAN_PERF_SEARCH set it also
// opens the global search for that text, MANGATAN_PERF_SEARCH_AFTER seconds
// (default 40) after launch, the way a person would from Browse.
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';

void main(List<String> args) {
  app.main(args);
  _watch();
  final query = Platform.environment['MANGATAN_PERF_SEARCH'];
  if (query == null) return;
  final after = int.tryParse(
    Platform.environment['MANGATAN_PERF_SEARCH_AFTER'] ?? '',
  );
  Timer(Duration(seconds: after ?? 40), () {
    GoRouter? router;
    void visit(Element element) {
      if (router != null) return;
      if (element.widget is Router) {
        router = GoRouter.maybeOf(element);
        if (router != null) return;
      }
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    router?.pushNamed('globalSearch', extra: (query, ItemType.manga));
    debugPrint('PERF search opened: ${router != null}');
  });
}

/// Prints, against the launch clock, every change to the tables startup
/// writes and every stretch the main isolate could not run its event loop,
/// so a driver can line the two up.
void _watch() {
  final clock = Stopwatch()..start();
  var last = 0;
  Timer.periodic(const Duration(milliseconds: 20), (_) {
    final now = clock.elapsedMilliseconds;
    if (now - last > 500) debugPrint('PERF stall ${now - last} ms ending $now');
    last = now;
  });
  Timer(const Duration(milliseconds: 500), () {
    void log(String what) =>
        debugPrint('PERF $what changed at ${clock.elapsedMilliseconds}');
    app.isar.sources.watchLazy().listen((_) => log('sources'));
    app.isar.settings.watchLazy().listen((_) => log('settings'));
    app.isar.mangas.watchLazy().listen((_) => log('mangas'));
  });
}
