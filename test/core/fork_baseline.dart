import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard-rail findings the fork already had when it adopted upstream's rules.
///
/// Upstream's architecture and design tests expect zero findings. The fork's
/// own screens predate those rules, so each rule keeps a baseline of what was
/// there: those findings pass, a new one fails, and a finding that has gone
/// away fails too until the baseline is regenerated, so the list only
/// shrinks. Regenerate after fixing some with
/// `UPDATE_FORK_BASELINE=1 flutter test test/core`.
///
/// Findings are compared per file and content, not per line number, so
/// unrelated edits that move code do not count as new findings.
void expectWithinForkBaseline(
  String name,
  Iterable<String> findings, {
  required String reason,
}) {
  final current = _count(findings.map(_key));
  final file = File('test/core/fork_baseline/$name.txt');

  if (Platform.environment['UPDATE_FORK_BASELINE'] == '1') {
    final keys = current.keys.toList()..sort();
    if (keys.isEmpty) {
      if (file.existsSync()) file.deleteSync();
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${keys.map((k) => '${current[k]} $k').join('\n')}\n',
    );
    return;
  }

  final baseline = <String, int>{};
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      final split = line.indexOf(' ');
      if (split <= 0) continue;
      baseline[line.substring(split + 1)] = int.parse(line.substring(0, split));
    }
  }

  final added = [
    for (final MapEntry(:key, :value) in current.entries)
      if (value > (baseline[key] ?? 0))
        '$key (${baseline[key] ?? 0} -> $value)',
  ];
  final fixed = [
    for (final MapEntry(:key, :value) in baseline.entries)
      if ((current[key] ?? 0) < value) '$key ($value -> ${current[key] ?? 0})',
  ];
  expect(added, isEmpty, reason: '$reason\nNew findings:\n${added.join('\n')}');
  expect(
    fixed,
    isEmpty,
    reason:
        'These findings were fixed; regenerate the baseline with '
        'UPDATE_FORK_BASELINE=1 flutter test test/core:\n${fixed.join('\n')}',
  );
}

/// `lib/a.dart:12: code` -> `lib/a.dart: code`; `lib/a.dart:12` and
/// `lib/a.dart (1500 lines > 1400)` -> `lib/a.dart`. Windows paths use `/`
/// like the baselines, so the tests pass on every desktop.
String _key(String finding) => finding
    .replaceAll(r'\', '/')
    .replaceFirst(RegExp(r':\d+(?=:|$)'), '')
    .replaceFirst(RegExp(r' \(\d+ lines > \d+\)$'), '');

Map<String, int> _count(Iterable<String> keys) {
  final counts = <String, int>{};
  for (final key in keys) {
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}
