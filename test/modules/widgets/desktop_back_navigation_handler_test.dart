import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/widgets/desktop_back_navigation_handler.dart';

void main() {
  testWidgets('Escape navigates back from a pushed desktop page', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => DesktopBackNavigationHandler(
          canGoBack: () => navigatorKey.currentState?.canPop() ?? false,
          onBack: () => navigatorKey.currentState?.pop(),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      Scaffold(appBar: AppBar(title: const Text('Menu'))),
                ),
              ),
              child: const Text('Open menu'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Menu'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Open menu'), findsOneWidget);
    expect(find.text('Menu'), findsNothing);
  });

  testWidgets('Escape does nothing on the root page', (tester) async {
    var backCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopBackNavigationHandler(
          canGoBack: () => false,
          onBack: () => backCount++,
          child: const Scaffold(
            body: Focus(autofocus: true, child: Text('Library')),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(backCount, 0);
    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('a child back action takes precedence', (tester) async {
    var parentBackCount = 0;
    var childBackCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopBackNavigationHandler(
          canGoBack: () => true,
          onBack: () => parentBackCount++,
          child: DesktopBackNavigationScope(
            onBack: () => childBackCount++,
            child: const Scaffold(
              body: Focus(autofocus: true, child: Text('Reader')),
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(childBackCount, 1);
    expect(parentBackCount, 0);
  });

  testWidgets('holding Escape invokes back only once', (tester) async {
    var backCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopBackNavigationHandler(
          canGoBack: () => true,
          onBack: () => backCount++,
          child: const Scaffold(
            body: Focus(autofocus: true, child: Text('Menu')),
          ),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(backCount, 1);
  });
}
