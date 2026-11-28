// Launches a profile build of tool/perf/real_app_main.dart on a prepared data
// folder and records what a person would feel: every frame's build and raster
// time, the main isolate's CPU samples, the app's startup phase marks, and
// the Mihon refresh timing it logs.
//
//   dart run tool/perf/real_app_driver.dart --exe <mangayomi.exe> \
//     --root <data folder> --out <folder> --name <run> [--seconds 60] \
//     [--search <text> --search-after 40]
//
// The data folder must already hold the app's database (copy one in; never
// point this at real data). The Mihon bridge the app starts keeps its own
// settings and caches under <root>/bridge, through JAVA_TOOL_OPTIONS, so it
// never touches the user's extension settings either.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:vm_service/vm_service.dart';
// ignore: depend_on_referenced_packages
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  final o = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    o[args[i].replaceFirst('--', '')] = args[i + 1];
  }
  final root = Directory(o['root']!).absolute.path;
  final out = Directory(o['out']!)..createSync(recursive: true);
  final name = o['name']!;
  final seconds = int.parse(o['seconds'] ?? '60');

  final clock = Stopwatch()..start();
  final lines = <String>[];
  final process = await Process.start(
    o['exe']!,
    const [],
    // Not the repository: flutter_rust_bridge looks for its library under
    // rust/target first, relative to the working directory.
    workingDirectory: File(o['exe']!).parent.path,
    environment: {
      'MANGATAN_PERF_ROOT': root,
      'JAVA_TOOL_OPTIONS':
          '-Dsuwayomi.tachidesk.config.server.rootDir=$root/bridge '
          '-Djava.io.tmpdir=$root/bridge-tmp',
      if (o['search'] != null) 'MANGATAN_PERF_SEARCH': o['search']!,
      if (o['routes'] != null) 'MANGATAN_PERF_ROUTES': o['routes']!,
      if (o['route-every'] != null)
        'MANGATAN_PERF_ROUTE_EVERY': o['route-every']!,
      if (o['routes-after'] != null)
        'MANGATAN_PERF_ROUTES_AFTER': o['routes-after']!,
      if (o['search-after'] != null)
        'MANGATAN_PERF_SEARCH_AFTER': o['search-after']!,
    },
  );
  Directory('$root/bridge-tmp').createSync(recursive: true);
  final serviceUri = Completer<Uri>();
  void onLine(String line) {
    lines.add('${clock.elapsedMilliseconds}\t$line');
    final match = RegExp(r'(http://127\.0\.0\.1:\d+/[^/\s]+/)')
        .firstMatch(line);
    if (match != null && !serviceUri.isCompleted) {
      serviceUri.complete(Uri.parse(match[1]!));
    }
  }

  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(onLine);
  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(onLine);

  final uri = await serviceUri.future.timeout(const Duration(seconds: 60));
  final service = await vmServiceConnectUri(
    uri.replace(scheme: 'ws', path: '${uri.path}ws').toString(),
  );
  final frames = <Map<String, Object?>>[];
  final marks = <Map<String, Object?>>[];
  service.onExtensionEvent.listen((event) {
    final data = event.extensionData?.data ?? const {};
    final at = clock.elapsedMilliseconds;
    if (event.extensionKind == 'Flutter.Frame') {
      frames.add({'at': at, ...data});
    } else if (event.extensionKind == 'mangatan.startup') {
      marks.add({'at': at, ...data});
    }
  });
  await service.streamListen(EventStreams.kExtension);
  // Off by default in a desktop profile build; DevTools turns it on too.
  await service.setFlag('profiler', 'true');
  await service.setFlag('profile_period', '1000');
  await service.setVMTimelineFlags(['GC', 'Dart', 'Embedder', 'API']);

  String? isolateId;
  for (var i = 0; i < 100 && isolateId == null; i++) {
    final vm = await service.getVM();
    isolateId = vm.isolates
        ?.where((iso) => iso.name == 'main')
        .map((iso) => iso.id)
        .firstOrNull;
    if (isolateId == null) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  final stacks = <String, int>{};
  final timed = <String>[];
  var samples = 0;
  var from = 0;
  Future<void> drain() async {
    final cpu = await service.getCpuSamples(isolateId!, from, 1 << 40);
    final names = [
      for (final f in cpu.functions ?? const <ProfileFunction>[]) _name(f),
    ];
    for (final sample in cpu.samples ?? const <CpuSample>[]) {
      final ts = sample.timestamp ?? 0;
      if (ts >= from) from = ts + 1;
      final stack = sample.stack ?? const <int>[];
      if (stack.isEmpty) continue;
      final key = stack.reversed.map((i) => names[i]).join(';');
      stacks[key] = (stacks[key] ?? 0) + 1;
      timed.add('$ts	$key');
      samples++;
    }
  }

  final end = clock.elapsed + Duration(seconds: seconds);
  try {
    // The VM builds the samples' JSON on the app's own UI thread: a drain
    // froze the app for about four seconds every time. Take them once, after
    // the measured window.
    while (clock.elapsed < end) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await drain();
  } finally {
    try {
      final timeline = await service.getVMTimeline();
      File('${out.path}/$name.timeline.json')
          .writeAsStringSync(jsonEncode(timeline.json));
    } catch (error) {
      stderr.writeln('timeline: $error');
    }
    await service.dispose();
    // The app and the bridge it started.
    await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
  }

  final logFile = Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('logs.txt'))
      .firstOrNull;
  final refreshLine = logFile
      ?.readAsLinesSync()
      .where((l) => l.contains('Mihon factory refresh performance'))
      .lastOrNull;

  File('${out.path}/$name.folded').writeAsStringSync(
    [for (final e in stacks.entries) '${e.key} ${e.value}'].join('\n'),
  );
  File('${out.path}/$name.samples.txt').writeAsStringSync(timed.join('\n'));
  File('${out.path}/$name.frames.json').writeAsStringSync(jsonEncode(frames));
  File('${out.path}/$name.stdout.txt').writeAsStringSync(lines.join('\n'));
  final summary = _summarize(frames, marks, lines, samples, refreshLine);
  File('${out.path}/$name.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));
  stdout.writeln('RUN $name ${jsonEncode(summary['overall'])}');
  exit(0);
}

Map<String, Object?> _summarize(
  List<Map<String, Object?>> frames,
  List<Map<String, Object?>> marks,
  List<String> lines,
  int samples,
  String? refreshLine,
) {
  int? markAt(String phase) => marks
      .where((m) => m['phase'] == phase)
      .map((m) => m['at'] as int)
      .firstOrNull;
  final searchAt = lines
      .where((l) => l.contains('PERF search opened'))
      .map((l) => int.parse(l.split('\t').first))
      .firstOrNull;

  Map<String, Object?> window(String label, int from, int to) {
    final inWindow = [
      for (final f in frames)
        if ((f['at'] as int) >= from && (f['at'] as int) < to) f,
    ];
    double ms(Object? us) => ((us as num?) ?? 0) / 1000;
    final elapsed = [for (final f in inWindow) ms(f['elapsed'])];
    final build = [for (final f in inWindow) ms(f['build'])];
    final raster = [for (final f in inWindow) ms(f['raster'])];
    num pct(List<double> v, double q) {
      if (v.isEmpty) return 0;
      final s = [...v]..sort();
      return (s[(q * (s.length - 1)).round()] * 10).round() / 10;
    }

    return {
      'window': label,
      'fromMs': from,
      'toMs': to,
      'frames': inWindow.length,
      'over16ms': elapsed.where((e) => e > 16.7).length,
      'over100ms': elapsed.where((e) => e > 100).length,
      'worstMs': pct(elapsed, 1),
      'p95Ms': pct(elapsed, .95),
      'medianMs': pct(elapsed, .5),
      'worstBuildMs': pct(build, 1),
      'worstRasterMs': pct(raster, 1),
      'jankMs': elapsed
          .where((e) => e > 16.7)
          .fold<double>(0, (a, e) => a + e - 16.7)
          .round(),
    };
  }

  final last = frames.isEmpty ? 0 : frames.last['at'] as int;
  final firstFrame = markAt('first_frame') ?? 0;
  return {
    'overall': {
      'firstFrameMs': firstFrame,
      'postLaunchDoneMs': markAt('post_launch_done'),
      'bridgeReadyMs': lines
          .where((l) => l.contains('Mihon bridge is ready'))
          .map((l) => int.parse(l.split('\t').first))
          .firstOrNull,
      'mainIsolateCpuMs': samples,
      'refresh': refreshLine?.replaceAll(RegExp(r'^.*performance: '), ''),
      ...window('all', 0, last + 1),
    },
    'marks': marks,
    'windows': [
      window('to first frame', 0, firstFrame),
      window('first 15 s after first frame', firstFrame, firstFrame + 15000),
      for (final (at, route, next) in _routeWindows(lines, last))
        window('route $route', at, next),
      if (searchAt != null) ...[
        window('before search', firstFrame + 15000, searchAt),
        window('search, first 20 s', searchAt, searchAt + 20000),
        window('search, after 20 s', searchAt + 20000, last + 1),
      ],
    ],
  };
}

/// Each visited route with when it was opened and when the next one was.
List<(int, String, int)> _routeWindows(List<String> lines, int last) {
  final opened = [
    for (final l in lines)
      if (l.contains('PERF route '))
        (int.parse(l.split('	').first), l.split('PERF route ').last.trim()),
  ];
  return [
    for (var i = 0; i < opened.length; i++)
      (
        opened[i].$1,
        opened[i].$2,
        i + 1 < opened.length ? opened[i + 1].$1 : last + 1,
      ),
  ];
}

String _name(ProfileFunction f) {
  final dynamic function = f.function;
  var name = '?';
  String? owner;
  if (function is FuncRef) {
    name = function.name ?? '?';
    final dynamic o = function.owner;
    if (o is ClassRef) owner = o.name;
    if (o is FuncRef) owner = o.name;
  } else if (function is NativeFunction) {
    name = function.name ?? '?';
  }
  var url = f.resolvedUrl ?? '';
  if (url.contains('/lib/')) {
    final package = RegExp(r'/([^/]+?)(-\d[^/]*)?/lib/').firstMatch(url);
    url = url.contains('/Mangatan/lib/')
        ? 'app:${url.substring(url.indexOf('/lib/') + 5)}'
        : package?.group(1) ?? url;
  } else if (url.startsWith('org-dartlang-sdk')) {
    url = 'dart';
  }
  final full = owner == null ? name : '$owner.$name';
  return (url.isEmpty ? full : '$full [$url]').replaceAll(';', ',');
}
