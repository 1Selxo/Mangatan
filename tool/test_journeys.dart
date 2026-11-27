// Runs the journey suite and prints a short report: totals, then each failing
// journey with the first lines of what went wrong, then the known issues the
// suite skips. Meant to be read in a terminal or by an agent in a few hundred
// tokens instead of thousands of lines of test log.
//
//   dart run tool/test_journeys.dart                 # the whole suite
//   dart run tool/test_journeys.dart test/journeys/reader_journey_test.dart
//   dart run tool/test_journeys.dart --name "every reading mode"
//
// Exit code: 0 when nothing failed, 1 otherwise.
import 'dart:convert';
import 'dart:io';

/// Lines of a failure log worth reading: what was thrown, expected and
/// found, the reason given, and where in the app it came from.
final _keyLine = RegExp(
  r'^(The following|Expected:|Actual:|Which:|Reason:|waited for|.*overflowed by|'
  r'.*Null check|.*RangeError|.*is covered by|.*error view|.*raw value|'
  r'.*absurd date|.*file:///.*/lib/|\w*(Error|Exception): )',
);

Future<void> main(List<String> args) async {
  final paths = args.where((a) => a.startsWith('test')).toList();
  final rest = args.where((a) => !a.startsWith('test')).toList();
  final report = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'mangatan-journeys-${DateTime.now().millisecondsSinceEpoch}.json',
  );
  final clock = Stopwatch()..start();
  final process = await Process.start(
    Platform.isWindows ? 'flutter.bat' : 'flutter',
    [
      'test',
      ...(paths.isEmpty ? ['test/journeys'] : paths),
      ...rest,
      '-r',
      'silent',
      '--file-reporter',
      'json:${report.path}',
    ],
    runInShell: true,
  );
  // The silent reporter still lets compile errors through on stderr.
  final stderrLines = <String>[];
  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(stderrLines.add);
  await process.stdout.drain<void>();
  final exitCode = await process.exitCode;

  if (!report.existsSync()) {
    stdout.writeln('No report written (exit $exitCode).');
    stdout.writeln(stderrLines.take(30).join('\n'));
    exit(1);
  }

  final names = <int, String>{};
  final errors = <int, List<String>>{};
  final prints = <int, List<String>>{};
  final passed = <int>[];
  final failed = <int>[];
  final skipped = <int, String?>{};
  for (final line in report.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final event = jsonDecode(line) as Map<String, dynamic>;
    switch (event['type']) {
      case 'testStart':
        final test = event['test'] as Map<String, dynamic>;
        names[test['id'] as int] = test['name'] as String;
        final skip = test['metadata']?['skipReason'];
        if (test['metadata']?['skip'] == true) {
          skipped[test['id'] as int] = skip as String?;
        }
      case 'print':
        prints
            .putIfAbsent(event['testID'] as int, () => [])
            .addAll((event['message'] as String).split('\n'));
      case 'error':
        errors
            .putIfAbsent(event['testID'] as int, () => [])
            .add(event['error'] as String);
      case 'testDone':
        final id = event['testID'] as int;
        if (event['hidden'] == true) continue;
        if (event['skipped'] == true) {
          skipped.putIfAbsent(id, () => null);
        } else if (event['result'] == 'success') {
          passed.add(id);
        } else {
          failed.add(id);
        }
    }
  }
  // Kept when something failed: it holds every failure's full log.
  if (failed.isEmpty) report.deleteSync();

  // Loading failures (compile errors) are reported as a failed "loading" test.
  final seconds = clock.elapsed.inSeconds;
  stdout.writeln(
    'Journeys: ${passed.length} passed, ${failed.length} failed, '
    '${skipped.length} skipped (known issues) in ${seconds}s',
  );
  if (failed.isNotEmpty) stdout.writeln('Full log: ${report.path}');
  for (final id in failed) {
    stdout.writeln('\nFAIL ${names[id]}');
    // Flutter prints the useful part of a failure (what was thrown, what was
    // expected) to the log; the error event itself often only says "see
    // above".
    final logged = (prints[id] ?? const <String>[])
        .map((l) => l.trim())
        .where(_keyLine.hasMatch);
    final thrown = (errors[id] ?? const <String>[])
        .expand((e) => e.split('\n'))
        .map((l) => l.trimRight())
        .where(
          (l) =>
              l.isNotEmpty &&
              !l.startsWith('#') &&
              !l.startsWith('Test failed. See exception logs') &&
              !l.startsWith('The test description was'),
        );
    final lines = {...logged, ...thrown}.take(10);
    for (final l in lines) {
      stdout.writeln('  ${l.length > 200 ? '${l.substring(0, 200)}…' : l}');
    }
  }
  if (skipped.isNotEmpty) {
    stdout.writeln('\nSkipped (suspected bugs; each skip says why):');
    for (final id in skipped.keys) {
      stdout.writeln('  - ${names[id]}');
    }
  }
  exit(failed.isEmpty && exitCode == 0 ? 0 : 1);
}
