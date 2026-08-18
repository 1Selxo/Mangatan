import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tap-up is immediate without double-tap arbitration', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (_) => tapped = true,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 200));
    await gesture.up();

    expect(tapped, isTrue);
  });

  testWidgets('double-tap arbitration holds tap-up for its timeout', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (_) => tapped = true,
          onDoubleTap: () {},
          child: const SizedBox.expand(),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 200));
    await gesture.up();
    expect(tapped, isFalse);

    await tester.pump(kDoubleTapTimeout - const Duration(milliseconds: 1));
    expect(tapped, isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    expect(tapped, isTrue);
  });

  testWidgets('raw pointer-up runs before the tap-up callback', (tester) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (_) => events.add('tap'),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerUp: (_) => events.add('raw'),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(200, 200));
    await gesture.up();

    expect(events, ['raw', 'tap']);
  });
}
