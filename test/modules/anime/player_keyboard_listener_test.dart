import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/utils/player_keyboard_listener.dart';
import 'package:mangayomi/services/player_hotkeys.dart';

void main() {
  testWidgets('receives keys when focus is outside the player subtree', (
    tester,
  ) async {
    var presses = 0;
    final externalFocusNode = FocusNode();
    addTearDown(externalFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            PlayerHardwareKeyboardListener(
              onKeyEvent: (event) {
                if (event is KeyDownEvent) presses++;
                return true;
              },
              child: const SizedBox(),
            ),
            Focus(focusNode: externalFocusNode, child: const SizedBox()),
          ],
        ),
      ),
    );
    externalFocusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);

    expect(presses, 1);
  });

  testWidgets('removes its hardware handler when unmounted', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      PlayerHardwareKeyboardListener(
        onKeyEvent: (_) {
          presses++;
          return true;
        },
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(const SizedBox());

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);

    expect(presses, 0);
  });

  test('matches configured key and modifiers exactly', () {
    final binding = PlayerHotkeyBinding(
      action: PlayerHotkeyAction.seekForward5,
      keyId: LogicalKeyboardKey.arrowRight.keyId,
      control: true,
    );
    final event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.arrowRight,
      logicalKey: LogicalKeyboardKey.arrowRight,
      timeStamp: Duration.zero,
    );

    expect(
      playerHotkeyMatches(
        binding,
        event,
        controlPressed: true,
        altPressed: false,
        shiftPressed: false,
        metaPressed: false,
      ),
      isTrue,
    );
    expect(
      playerHotkeyMatches(
        binding,
        event,
        controlPressed: false,
        altPressed: false,
        shiftPressed: false,
        metaPressed: false,
      ),
      isFalse,
    );
  });

  test('maps page keys to mpv input.conf names', () {
    expect(mpvInputKeyForPlayerShortcut(LogicalKeyboardKey.pageUp), 'PGUP');
    expect(mpvInputKeyForPlayerShortcut(LogicalKeyboardKey.pageDown), 'PGDWN');
    expect(mpvInputKeyForPlayerShortcut(LogicalKeyboardKey.arrowLeft), isNull);
  });
}
