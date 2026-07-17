import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/detail/widgets/media_detail_keyboard_navigation.dart';

void main() {
  testWidgets('Escape returns from a media detail page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => MediaDetailKeyboardNavigation(
                    onEscape: () => Navigator.of(context).pop(),
                    child: const Scaffold(body: Text('Media detail')),
                  ),
                ),
              );
            },
            child: const Text('Library'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Media detail'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Media detail'), findsNothing);
  });
}
