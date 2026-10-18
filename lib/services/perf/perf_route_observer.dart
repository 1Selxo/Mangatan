import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:mangayomi/services/perf/perf_metrics.dart';

/// Measures each route transition and the frames rendered during it.
///
/// A sample starts when a route is pushed or popped and ends when its
/// animation settles. Only the first path segment is kept as the label, never
/// ids or arguments.
class PerfRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _watch(route, 'push', AnimationStatus.completed);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _watch(route, 'pop', AnimationStatus.dismissed);

  void _watch(Route<dynamic> route, String kind, AnimationStatus settled) {
    if (!PerfMetrics.enabled || route is! TransitionRoute) return;
    final animation = route.animation;
    if (animation == null || animation.status == settled) return;
    final window = PerfFrameWindow.start();
    if (window == null) return;
    final clock = Stopwatch()..start();
    final label = '$kind ${_name(route) ?? route.runtimeType}';

    // The route can report its starting status before it starts moving, so
    // the opposite end only counts as an interrupted transition once the
    // animation has run.
    var moving = animation.isAnimating;
    late final AnimationStatusListener listener;
    late final void Function(AnimationStatus) finish;
    listener = (status) {
      if (status == AnimationStatus.forward ||
          status == AnimationStatus.reverse) {
        moving = true;
        return;
      }
      if (status != settled && !moving) return;
      animation.removeStatusListener(listener);
      // A route that appears without animating still renders its first
      // frame afterwards; include that frame.
      if (!moving) {
        SchedulerBinding.instance.addPostFrameCallback((_) => finish(status));
      } else {
        finish(status);
      }
    };
    finish = (status) {
      clock.stop();
      window.finish().then(
        (frames) => PerfMetrics.record(
          PerfSample(
            flow: PerfFlow.transition,
            label: label,
            total: clock.elapsed,
            network: Duration.zero,
            succeeded: status == settled,
            frames: frames,
          ),
        ),
      );
    };
    animation.addStatusListener(listener);
  }

  static String? _name(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return null;
    final first = name.split('/').where((e) => e.isNotEmpty).firstOrNull;
    return first == null ? '/' : '/$first';
  }
}
