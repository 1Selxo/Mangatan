import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:mangayomi/services/perf/benchmark_data_root.dart';

/// One startup phase boundary.
@immutable
class StartupMark {
  const StartupMark(
    this.phase,
    this.sinceMainMicros,
    this.epochMicros,
    this.timelineMicros,
  );

  final String phase;

  /// Time since the `main` mark, on a monotonic clock.
  final int sinceMainMicros;

  /// Wall-clock time, so a harness can relate the mark to process launch.
  final int epochMicros;

  /// The VM's timeline clock, which CPU profile samples also use.
  final int timelineMicros;

  Map<String, Object?> toJson() => {
    'phase': phase,
    'sinceMainMs': sinceMainMicros / 1000,
    'epochUs': epochMicros,
    'timelineUs': timelineMicros,
  };
}

/// Phase boundaries of app startup, from `main` to the first frame and the
/// post-launch work after it.
///
/// Each mark goes to the developer timeline and `postEvent` (visible in
/// DevTools) and is printed only in a benchmark harness build. Marks never
/// reach the console or the user-visible log of an ordinary build, and
/// recording one has no other effect.
abstract final class StartupTrace {
  static final _clock = Stopwatch();
  static final _marks = <StartupMark>[];
  static final _listeners = <void Function(StartupMark)>[];

  static List<StartupMark> get marks => List.unmodifiable(_marks);

  static VoidCallback addListener(void Function(StartupMark) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  static void mark(String phase) {
    if (!_clock.isRunning) _clock.start();
    final mark = StartupMark(
      phase,
      _clock.elapsedMicroseconds,
      DateTime.now().microsecondsSinceEpoch,
      developer.Timeline.now,
    );
    _marks.add(mark);
    developer.Timeline.instantSync('startup:$phase');
    developer.postEvent('mangatan.startup', mark.toJson());
    if (kBenchmarkHarness) {
      debugPrint(
        'startup $phase +${(mark.sinceMainMicros / 1000).toStringAsFixed(1)} ms',
      );
    }
    for (final listener in List.of(_listeners)) {
      listener(mark);
    }
  }
}
