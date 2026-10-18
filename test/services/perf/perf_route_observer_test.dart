import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/perf/perf_metrics.dart';
import 'package:mangayomi/services/perf/perf_route_observer.dart';

void main() {
  testWidgets('measures a push and a pop until their animations settle', (
    tester,
  ) async {
    final samples = <PerfSample>[];
    final remove = PerfMetrics.addListener(samples.add);
    addTearDown(remove);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [PerfRouteObserver()],
        home: const SizedBox(),
      ),
    );

    key.currentState!.push(
      CupertinoPageRoute<void>(
        settings: const RouteSettings(name: '/manga-reader/detail'),
        builder: (_) => const SizedBox(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(samples, isEmpty, reason: 'the push is still animating');
    await tester.pumpAndSettle();
    key.currentState!.pop();
    await tester.pumpAndSettle();
    // Frame statistics complete after the report wait.
    await tester.pump(const Duration(seconds: 3));

    expect(samples.map((s) => s.label), [
      'push /manga-reader',
      'pop /manga-reader',
    ]);
    for (final sample in samples) {
      expect(sample.flow, PerfFlow.transition);
      expect(sample.succeeded, isTrue);
    }
  });
}
