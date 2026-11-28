/// CPU sampling for journeys: the Dart VM's own sampling profiler, read over
/// the VM service while a scenario runs, written out as folded stacks (one
/// `a;b;c count` line per distinct stack) that tool/perf/flamegraph.py draws.
///
/// Needs `flutter test --enable-vmservice`. The numbers come from a debug,
/// JIT build: compare them with each other, not with a release app.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate' as dart_isolate;

// ignore: depend_on_referenced_packages
import 'package:vm_service/vm_service.dart';
// ignore: depend_on_referenced_packages
import 'package:vm_service/vm_service_io.dart';

final profileOut = Directory(
  Platform.environment['MANGATAN_PROFILE_OUT'] ?? 'build/perf_profile',
)..createSync(recursive: true);

class Profiler {
  Profiler._(this._service, this._isolateId);

  final VmService _service;
  final String _isolateId;
  final _stacks = <String, int>{};
  var _samples = 0;
  var _from = 0;

  /// How often a sample is taken.
  static const periodMicros = 1000;

  static Future<Profiler> connect() async {
    final uri = (await developer.Service.getInfo()).serverUri;
    if (uri == null) {
      throw StateError('Run with: flutter test --enable-vmservice');
    }
    final service = await vmServiceConnectUri(
      uri.replace(scheme: 'ws', path: '${uri.path}ws').toString(),
    );
    await service.setFlag('profile_period', '$periodMicros');
    return Profiler._(
      service,
      developer.Service.getIsolateId(dart_isolate.Isolate.current)!,
    );
  }

  Future<void> start() async {
    await _service.clearCpuSamples(_isolateId);
    _stacks.clear();
    _samples = 0;
    _from = developer.Timeline.now;
  }

  /// Takes the samples collected so far. The VM keeps them in a ring buffer,
  /// so long scenarios call this every few seconds.
  Future<void> drain() async {
    final now = developer.Timeline.now;
    final cpu = await _service.getCpuSamples(_isolateId, _from, now - _from);
    _from = now;
    final functions = cpu.functions ?? const <ProfileFunction>[];
    final names = [for (final f in functions) _name(f)];
    for (final sample in cpu.samples ?? const <CpuSample>[]) {
      final stack = sample.stack ?? const <int>[];
      if (stack.isEmpty) continue;
      final key = stack.reversed.map((i) => names[i]).join(';');
      _stacks[key] = (_stacks[key] ?? 0) + 1;
      _samples++;
    }
  }

  /// Writes `<name>.folded` and one line of [facts] to `metrics.jsonl`.
  Future<void> stop(String name, Map<String, Object?> facts) async {
    await drain();
    File('${profileOut.path}/$name.folded').writeAsStringSync(
      [for (final e in _stacks.entries) '${e.key} ${e.value}'].join('\n'),
    );
    final row = {
      'scenario': name,
      'cpuMs': _samples * periodMicros / 1000,
      ...facts,
    };
    File('${profileOut.path}/metrics.jsonl')
        .writeAsStringSync('${jsonEncode(row)}\n', mode: FileMode.append);
    print('PROFILE ${jsonEncode(row)}');
  }

  Future<void> dispose() => _service.dispose();

  static String _name(ProfileFunction f) {
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
    } else if (function != null) {
      name = (function.name as String?) ?? '?';
    }
    var url = f.resolvedUrl ?? '';
    if (url.isNotEmpty) {
      final lib = url.indexOf('/lib/');
      final package = RegExp(r'/([^/]+?)(-\d[^/]*)?/lib/').firstMatch(url);
      url = url.startsWith('org-dartlang-sdk')
          ? 'dart'
          : url.contains('/Mangatan/lib/')
          ? 'app:${url.substring(lib + 5)}'
          : package?.group(1) ?? url.split('/').last;
    }
    final full = owner == null ? name : '$owner.$name';
    return (url.isEmpty ? full : '$full [$url]')
        .replaceAll(';', ',')
        .replaceAll('\n', ' ');
  }
}

/// Median, 95th percentile and worst of [values].
Map<String, num> summary(List<num> values) {
  if (values.isEmpty) return const {};
  final sorted = [...values]..sort();
  num at(double q) => sorted[(q * (sorted.length - 1)).round()];
  num round(num v) => (v * 10).round() / 10;
  return {
    'n': sorted.length,
    'median': round(at(0.5)),
    'p95': round(at(0.95)),
    'max': round(sorted.last),
  };
}
