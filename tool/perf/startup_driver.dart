// Launches the startup harness (tool/perf/startup_main.dart, built in profile
// mode) repeatedly and summarizes its phase timings.
//
//   dart tool/perf/startup_driver.dart --app <built binary>[,<binary>...] \
//     --data <scratch folder> [--runs 10] [--mode warm|fresh] [--watch 8] \
//     [--out file]
//
// Several binaries (for example before and after a change) are launched in
// turn, so machine load affects each alike. `--watch` is how many seconds each
// launch keeps measuring after its first library frame.
//
// The first call seeds a realistic library into <data>/seed. Every launch
// then runs against a copy of it in <data>/run<n>, one per binary:
//
// - `fresh`: a new copy before every launch, so each one is the first launch
//   on its data folder.
// - `warm` (default): one copy, one discarded launch, then repeated launches
//   on the same folder, as when the user reopens the app.
//
// Times are measured from just before the process is spawned, so they include
// the engine's own startup before Dart `main` runs.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

Future<void> main(List<String> args) async {
  final options = _parse(args);
  final apps = options['app']?.split(',');
  final data = options['data'];
  if (apps == null || data == null) {
    stderr.writeln('usage: --app <binary>[,<binary>...] --data <folder>');
    exit(64);
  }
  final runs = int.parse(options['runs'] ?? '10');
  final mode = options['mode'] ?? 'warm';
  _watchSeconds = options['watch'] ?? '8';
  final seed = Directory('$data/seed');

  if (!File('${seed.path}/.seeded').existsSync()) {
    seed.createSync(recursive: true);
    final result = await Process.run(
      apps.first,
      const [],
      environment: {'MANGATAN_PERF_ROOT': seed.path, 'MANGATAN_PERF_SEED': '1'},
    );
    if (!'${result.stdout}'.contains('STARTUP_SEEDED')) {
      stderr.writeln('seeding failed:\n${result.stdout}\n${result.stderr}');
      exit(1);
    }
    File('${seed.path}/.seeded').writeAsStringSync('');
  }

  Directory work(int app) => Directory('$data/run$app');
  Future<void> copySeed(int app) async {
    final dir = work(app);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    // APFS clone; falls back to a plain copy elsewhere.
    final copy = await Process.run('cp', ['-c', '-R', seed.path, dir.path]);
    if (copy.exitCode != 0) {
      await Process.run('cp', ['-R', seed.path, dir.path]);
    }
  }

  // Several apps are launched in turn, so machine load affects each alike.
  final samples = [for (final _ in apps) <Map<String, Object?>>[]];
  if (mode == 'warm') {
    for (var a = 0; a < apps.length; a++) {
      await copySeed(a);
      await _launch(apps[a], work(a).path); // discarded
    }
  }
  for (var i = 0; i < runs; i++) {
    for (var a = 0; a < apps.length; a++) {
      if (mode == 'fresh') await copySeed(a);
      final sample = await _launch(apps[a], work(a).path);
      if (sample == null) {
        stderr.writeln('app $a launch ${i + 1} produced no result');
        continue;
      }
      samples[a].add(sample);
      stdout.writeln(
        'app $a run ${i + 1}: library frame at '
        '${(sample['spawnToLibraryFrameMs'] as double).toStringAsFixed(1)} ms',
      );
    }
  }
  final summaries = [
    for (var a = 0; a < apps.length; a++)
      _summarize(samples[a])
        ..['app'] = a
        ..['mode'] = mode
        ..['runs'] = samples[a].length,
  ];
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(summaries));
  final out = options['out'];
  if (out != null) {
    File(out).writeAsStringSync(
      const JsonEncoder.withIndent('  ')
          .convert({'summaries': summaries, 'samples': samples}),
    );
  }
}

var _watchSeconds = '8';

Map<String, String> _parse(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    options[args[i].replaceFirst('--', '')] = args[i + 1];
  }
  return options;
}

Future<Map<String, Object?>?> _launch(String app, String root) async {
  final spawnedAt = DateTime.now().microsecondsSinceEpoch;
  final process = await Process.start(
    app,
    const [],
    environment: {
      'MANGATAN_PERF_ROOT': root,
      'MANGATAN_PERF_WATCH': _watchSeconds,
    },
  );
  unawaited(process.stderr.drain<void>());
  Map<String, Object?>? result;
  await for (final line
      in process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(
            const Duration(seconds: 90),
            onTimeout: (sink) => sink.close(),
          )) {
    if (line.startsWith('STARTUP_RESULT ')) {
      result = jsonDecode(
        line.substring('STARTUP_RESULT '.length),
      ) as Map<String, Object?>;
    }
  }
  process.kill();
  await process.exitCode.timeout(
    const Duration(seconds: 10),
    onTimeout: () => -1,
  );
  if (result == null) return null;
  final marks = (result['marks'] as List).cast<Map<String, Object?>>();
  final sinceSpawn = <String, double>{
    for (final m in marks)
      m['phase'] as String: ((m['epochUs'] as int) - spawnedAt) / 1000,
  };
  final sinceMain = <String, double>{
    for (final m in marks)
      m['phase'] as String: (m['sinceMainMs'] as num).toDouble(),
  };
  final stalls = (result['longestStallsMs'] as List)
      .cast<Map<String, Object?>>();
  return {
    ...result,
    'sinceSpawnMs': sinceSpawn,
    'sinceMainMs': sinceMain,
    'spawnToLibraryFrameMs': sinceSpawn['library_frame'],
    'longestStallMs': stalls.isEmpty ? 0.0 : stalls.first['ms'],
  };
}

Map<String, Object?> _summarize(List<Map<String, Object?>> samples) {
  Map<String, double> stat(Iterable<double> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return const {};
    final n = sorted.length;
    final median = n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    final p90 = sorted[min(n - 1, (n * 0.9).floor())];
    return {
      'median': double.parse(median.toStringAsFixed(1)),
      'p90': double.parse(p90.toStringAsFixed(1)),
    };
  }

  final phases = <String>[];
  for (final s in samples) {
    for (final phase in (s['sinceMainMs'] as Map).keys) {
      if (!phases.contains(phase)) phases.add(phase as String);
    }
  }
  double frames(Map<String, Object?> s, String window, String key) =>
      ((s[window] as Map)[key] as num?)?.toDouble() ?? 0;
  return {
    'spawnToMainMs': stat(
      samples.map((s) => (s['sinceSpawnMs'] as Map)['main'] as double),
    ),
    'sinceMainMs': {
      for (final phase in phases)
        phase: stat([
          for (final s in samples)
            if ((s['sinceMainMs'] as Map)[phase] != null)
              (s['sinceMainMs'] as Map)[phase] as double,
        ]),
    },
    'spawnToLibraryFrameMs': stat(
      samples.map((s) => s['spawnToLibraryFrameMs'] as double),
    ),
    'libraryFrameRasterMs': stat([
      for (final s in samples)
        if (s['libraryFrameRasterMs'] != null)
          (s['libraryFrameRasterMs'] as num).toDouble(),
    ]),
    'longestStallMs': stat(
      samples.map((s) => (s['longestStallMs'] as num).toDouble()),
    ),
    'framesFromRunApp': {
      for (final key in [
        'frames',
        'droppedFrames',
        'worstBuildMs',
        'worstRasterMs',
      ])
        key: stat(samples.map((s) => frames(s, 'framesFromRunApp', key))),
    },
    'framesAfterLibrary': {
      for (final key in [
        'frames',
        'droppedFrames',
        'worstBuildMs',
        'worstRasterMs',
      ])
        key: stat(samples.map((s) => frames(s, 'framesAfterLibrary', key))),
    },
  };
}
