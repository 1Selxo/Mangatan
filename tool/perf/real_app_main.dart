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
  _visitRoutes();
  final query = Platform.environment['MANGATAN_PERF_SEARCH'];
  if (query == null) return;
  final after = int.tryParse(
    Platform.environment['MANGATAN_PERF_SEARCH_AFTER'] ?? '',
  );
  Timer(Duration(seconds: after ?? 40), () {
    final router = _router();
    router?.pushNamed('globalSearch', extra: (query, ItemType.manga));
    debugPrint('PERF search opened: ${router != null}');
  });
}

GoRouter? _router() {
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
  return router;
}

/// MANGATAN_PERF_ROUTES: locations to open one after another, each
/// MANGATAN_PERF_ROUTE_EVERY seconds (default 6), starting
/// MANGATAN_PERF_ROUTES_AFTER seconds after launch (default 20). An entry
/// "push:<name>" pushes a named route instead; "pop" goes back.
void _visitRoutes() {
  final env = Platform.environment;
  final routes = env['MANGATAN_PERF_ROUTES']?.split(',');
  if (routes == null) return;
  final every = int.tryParse(env['MANGATAN_PERF_ROUTE_EVERY'] ?? '') ?? 6;
  final after = int.tryParse(env['MANGATAN_PERF_ROUTES_AFTER'] ?? '') ?? 20;
  for (var i = 0; i < routes.length; i++) {
    Timer(Duration(seconds: after + i * every), () {
      final router = _router();
      final route = routes[i];
      if (route == 'pop') {
        router?.pop();
      } else if (route.startsWith('push:')) {
        router?.pushNamed(route.substring(5));
      } else {
        router?.go(route);
      }
      debugPrint('PERF route $route');
    });
  }
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
