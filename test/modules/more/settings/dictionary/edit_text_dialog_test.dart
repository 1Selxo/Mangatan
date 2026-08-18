import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/settings/dictionary/widgets/edit_text_dialog.dart';

void main() {
  testWidgets('Escape safely dismisses the text editor', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      String? result = 'not dismissed';

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showEditTextDialog(
                  context: context,
                  title: 'Default tags',
                  initialValue: 'mangatan manga',
                );
              },
              child: const Text('Edit tags'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Edit tags'));
      await tester.pumpAndSettle();
      expect(find.text('Default tags'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);

      // Dismissal must not mutate the route while Flutter is still dispatching
      // the key event through the focused text field.
      expect(result, 'not dismissed');

      await tester.pumpAndSettle();

      expect(find.text('Default tags'), findsNothing);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
