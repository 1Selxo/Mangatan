import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// The app flows the metrics are grouped by.
abstract final class PerfFlow {
  static const browseSource = 'browse_source';
  static const loadMedia = 'load_media';
  static const openEntry = 'open_entry';
  static const openChapter = 'open_chapter';
  static const openEpisode = 'open_episode';
  static const transition = 'transition';
}

/// Frame statistics for one window of time.
///
/// The frame budget comes from the refresh rate the display reports. When the
/// display does not report one, the shortest gap between two consecutive
/// frames in the window stands in for it. Nothing here assumes a frame rate.
@immutable
class PerfFrameStats {
  const PerfFrameStats({
    required this.frames,
    required this.jankyFrames,
    required this.droppedFrames,
    required this.budgetMicros,
    required this.worstBuildMicros,
    required this.worstRasterMicros,
  });

  static const empty = PerfFrameStats(
    frames: 0,
    jankyFrames: 0,
    droppedFrames: 0,
    budgetMicros: null,
    worstBuildMicros: 0,
    worstRasterMicros: 0,
  );

  final int frames;

  /// Frames whose build or raster phase took longer than one budget.
  final int jankyFrames;

  /// Display refreshes missed: a frame that takes N budgets misses N - 1.
  final int droppedFrames;

  /// Null when no budget could be determined (no frames, no display rate).
  final int? budgetMicros;
  final int worstBuildMicros;
  final int worstRasterMicros;

  /// Computes the statistics for [timings] against [budgetMicros], or against
  /// an estimate from the timings themselves when it is null.
  factory PerfFrameStats.from(List<FrameTiming> timings, {int? budgetMicros}) {
    if (timings.isEmpty) return empty;
    final budget = budgetMicros ?? _estimateBudget(timings);
    var janky = 0;
    var dropped = 0;
    var worstBuild = 0;
    var worstRaster = 0;
    for (final timing in timings) {
      final build = timing.buildDuration.inMicroseconds;
      final raster = timing.rasterDuration.inMicroseconds;
      worstBuild = math.max(worstBuild, build);
      worstRaster = math.max(worstRaster, raster);
      if (budget == null || budget <= 0) continue;
      final cost = math.max(build, raster);
      if (cost > budget) {
        janky++;
        dropped += (cost / budget).ceil() - 1;
      }
    }
    return PerfFrameStats(
      frames: timings.length,
      jankyFrames: janky,
      droppedFrames: dropped,
      budgetMicros: budget,
      worstBuildMicros: worstBuild,
      worstRasterMicros: worstRaster,
    );
  }

  static int? _estimateBudget(List<FrameTiming> timings) {
    final starts =
        timings
            .map((t) => t.timestampInMicroseconds(FramePhase.vsyncStart))
            .toList()
          ..sort();
    int? shortest;
    for (var i = 1; i < starts.length; i++) {
      final gap = starts[i] - starts[i - 1];
      if (gap > 0 && (shortest == null || gap < shortest)) shortest = gap;
    }
    return shortest;
  }

  Map<String, Object?> toJson() => {
    'frames': frames,
    'jankyFrames': jankyFrames,
    'droppedFrames': droppedFrames,
    'budgetMs': budgetMicros == null ? null : budgetMicros! / 1000,
    'worstBuildMs': worstBuildMicros / 1000,
    'worstRasterMs': worstRasterMicros / 1000,
  };
}

/// One finished measurement.
@immutable
class PerfSample {
  const PerfSample({
    required this.flow,
    required this.label,
    required this.total,
    required this.network,
    required this.succeeded,
    required this.frames,
  });

  final String flow;
  final String? label;
  final Duration total;

  /// Wall time with at least one HTTP request of this flow in flight.
  /// Overlapping requests are counted once.
  final Duration network;

  final bool succeeded;

  /// Null when the flow did not watch frames.
  final PerfFrameStats? frames;

  /// Everything that was not waiting on the network: parsing, database work,
  /// widget builds, platform calls.
  Duration get processing {
    final value = total - network;
    return value.isNegative ? Duration.zero : value;
  }

  Map<String, Object?> toJson() => {
    'flow': flow,
    'label': ?label,
    'totalMs': total.inMicroseconds / 1000,
    'networkMs': network.inMicroseconds / 1000,
    'processingMs': processing.inMicroseconds / 1000,
    'ok': succeeded,
    if (frames != null) 'frames': frames!.toJson(),
  };

  @override
  String toString() {
    String ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(1);
    final frameText = frames == null
        ? ''
        : ' frames=${frames!.frames} janky=${frames!.jankyFrames}'
              ' dropped=${frames!.droppedFrames}';
    return '[perf] $flow${label == null ? '' : ' ($label)'}'
        ' total=${ms(total)}ms network=${ms(network)}ms'
        ' processing=${ms(processing)}ms${succeeded ? '' : ' failed'}'
        '$frameText';
  }
}

/// A running measurement. Work started inside [PerfMetrics.trace] finds its
/// trace through the zone, so concurrent flows never share network time.
class PerfTrace {
  PerfTrace._(this.flow, this.label, this._parent) : _clock = Stopwatch() {
    _clock.start();
  }

  final String flow;
  final String? label;
  final PerfTrace? _parent;
  final Stopwatch _clock;
  final _intervals = <(int, int)>[];

  void _addNetwork(int start, int end) {
    for (PerfTrace? trace = this; trace != null; trace = trace._parent) {
      trace._intervals.add((start, end));
    }
  }

  Duration _networkTime() {
    if (_intervals.isEmpty) return Duration.zero;
    final sorted = [..._intervals]..sort((a, b) => a.$1.compareTo(b.$1));
    var total = 0;
    var (start, end) = sorted.first;
    for (final (s, e) in sorted.skip(1)) {
      if (s > end) {
        total += end - start;
        start = s;
        end = e;
      } else if (e > end) {
        end = e;
      }
    }
    total += end - start;
    return Duration(microseconds: total);
  }
}

/// Collects timing for the app's common flows.
///
/// Samples stay in memory and go to the developer timeline. Debug and profile
/// builds also print them. Nothing reaches the user-visible log or the UI, so
/// measuring does not change what the app does.
abstract final class PerfMetrics {
  static bool enabled = true;

  static const _zoneKey = #mangatanPerfTrace;
  static final _clock = Stopwatch()..start();
  static const _historyLimit = 200;
  static final _history = ListQueue<PerfSample>();
  static final _listeners = <void Function(PerfSample)>[];

  /// The most recent samples, oldest first.
  static List<PerfSample> get samples => List.unmodifiable(_history);

  static void clear() => _history.clear();

  /// Called with every finished sample. Returns a function that unsubscribes.
  static VoidCallback addListener(void Function(PerfSample) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  static final _untracedMarker = Object();

  static PerfTrace? get current {
    final value = Zone.current[_zoneKey];
    return value is PerfTrace ? value : null;
  }

  /// Runs [body] without measuring it, for background work that reuses a
  /// flow's code path, such as preloading the next chapter or downloading.
  static Future<T> untraced<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: {_zoneKey: _untracedMarker});

  /// Measures [body] as one sample of [flow].
  ///
  /// With [watchFrames], frames rendered while [body] runs are added to the
  /// sample. The result and any error of [body] pass through unchanged.
  static Future<T> trace<T>(
    String flow,
    Future<T> Function() body, {
    String? label,
    bool watchFrames = false,
  }) async {
    if (!enabled || identical(Zone.current[_zoneKey], _untracedMarker)) {
      return body();
    }
    final trace = PerfTrace._(flow, label, current);
    final frames = watchFrames ? PerfFrameWindow.start() : null;
    var succeeded = false;
    try {
      final result = await runZoned(body, zoneValues: {_zoneKey: trace});
      succeeded = true;
      return result;
    } finally {
      trace._clock.stop();
      final total = trace._clock.elapsed;
      final network = trace._networkTime();
      if (frames == null) {
        _record(
          PerfSample(
            flow: flow,
            label: label,
            total: total,
            network: network,
            succeeded: succeeded,
            frames: null,
          ),
        );
      } else {
        final ok = succeeded;
        unawaited(
          frames.finish().then(
            (stats) => _record(
              PerfSample(
                flow: flow,
                label: label,
                total: total,
                network: network,
                succeeded: ok,
                frames: stats,
              ),
            ),
          ),
        );
      }
    }
  }

  /// Counts [request] as network time of the current trace, if there is one.
  static Future<T> network<T>(Future<T> Function() request) async {
    final trace = enabled ? current : null;
    if (trace == null) return request();
    final start = _clock.elapsedMicroseconds;
    try {
      return await request();
    } finally {
      trace._addNetwork(start, _clock.elapsedMicroseconds);
    }
  }

  /// Starts a network interval for the current trace and returns the call
  /// that ends it, or null when no trace is running. For responses whose body
  /// arrives after the request future completes.
  static void Function()? beginNetwork() {
    final trace = enabled ? current : null;
    if (trace == null) return null;
    final start = _clock.elapsedMicroseconds;
    var ended = false;
    return () {
      if (ended) return;
      ended = true;
      trace._addNetwork(start, _clock.elapsedMicroseconds);
    };
  }

  /// Records a sample measured elsewhere, such as a route transition.
  static void record(PerfSample sample) {
    if (enabled) _record(sample);
  }

  static void _record(PerfSample sample) {
    _history.addLast(sample);
    while (_history.length > _historyLimit) {
      _history.removeFirst();
    }
    developer.Timeline.instantSync(
      'perf:${sample.flow}',
      arguments: sample.toJson(),
    );
    developer.postEvent('mangatan.perf', sample.toJson());
    if (!kReleaseMode) debugPrint(sample.toString());
    for (final listener in List.of(_listeners)) {
      listener(sample);
    }
  }
}

/// Collects the engine's frame timings between [start] and [finish].
///
/// Both ends are placed on the engine's own clock (the raw vsync timestamp the
/// scheduler receives), the same clock [FrameTiming] uses, so no conversion
/// between clocks is needed.
class PerfFrameWindow {
  PerfFrameWindow._(this._startMicros);

  static final _open = <PerfFrameWindow>{};
  static bool _listening = false;

  /// Overridable for tests.
  @visibleForTesting
  static int? Function() refreshBudgetMicros = _displayBudgetMicros;

  /// How long [finish] waits for the engine to report the window's last
  /// frames. The engine batches reports, so they arrive after the frame.
  static const _reportWait = Duration(seconds: 2);

  final int _startMicros;
  int? _endMicros;
  final _timings = <FrameTiming>[];
  Completer<PerfFrameStats>? _done;
  Timer? _timeout;

  static int _engineNowMicros() {
    final binding = SchedulerBinding.instance;
    return binding.currentSystemFrameTimeStamp.inMicroseconds;
  }

  static PerfFrameWindow? start() {
    if (!PerfMetrics.enabled) return null;
    final window = PerfFrameWindow._(_engineNowMicros());
    _open.add(window);
    _listen();
    return window;
  }

  static void _listen() {
    if (_listening) return;
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _stopListeningIfIdle() {
    if (!_listening || _open.isNotEmpty) return;
    _listening = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final window in List.of(_open)) {
      window._take(timings);
    }
  }

  void _take(List<FrameTiming> timings) {
    var sawLaterFrame = false;
    for (final timing in timings) {
      final vsync = timing.timestampInMicroseconds(FramePhase.vsyncStart);
      if (vsync < _startMicros) continue;
      final end = _endMicros;
      if (end != null && vsync >= end) {
        sawLaterFrame = true;
        continue;
      }
      _timings.add(timing);
    }
    if (sawLaterFrame) _complete();
  }

  /// Closes the window. The statistics complete once the engine has reported
  /// a frame after the window, or after a short wait when nothing renders.
  Future<PerfFrameStats> finish() {
    final existing = _done;
    if (existing != null) return existing.future;
    final done = _done = Completer<PerfFrameStats>();
    _endMicros = _engineNowMicros();
    _timeout = Timer(_reportWait, _complete);
    return done.future;
  }

  void _complete() {
    final done = _done;
    if (done == null || done.isCompleted) return;
    _timeout?.cancel();
    _open.remove(this);
    _stopListeningIfIdle();
    done.complete(
      PerfFrameStats.from(_timings, budgetMicros: refreshBudgetMicros()),
    );
  }

  static int? _displayBudgetMicros() {
    final dispatcher = SchedulerBinding.instance.platformDispatcher;
    final view = dispatcher.implicitView ?? dispatcher.views.firstOrNull;
    final rate = view?.display.refreshRate ?? 0;
    if (!rate.isFinite || rate <= 0) return null;
    return (Duration.microsecondsPerSecond / rate).round();
  }
}
