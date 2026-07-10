import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';

void main() {
  group('dictionary popup dismissal policy', () {
    test('Escape, Backspace, and browser back dismiss the popup', () {
      expect(dictionaryPopupIsDismissKey(LogicalKeyboardKey.escape), isTrue);
      expect(dictionaryPopupIsDismissKey(LogicalKeyboardKey.backspace), isTrue);
      expect(
        dictionaryPopupIsDismissKey(LogicalKeyboardKey.browserBack),
        isTrue,
      );
      expect(dictionaryPopupIsDismissKey(LogicalKeyboardKey.enter), isFalse);
    });

    test('an outside primary click dismisses without a modal barrier', () {
      const popup = Rect.fromLTWH(100, 100, 300, 250);

      expect(
        dictionaryPopupShouldDismissForPointer(
          visible: true,
          dismissOnOutsideTap: true,
          popupBounds: popup,
          position: const Offset(40, 40),
          buttons: kPrimaryMouseButton,
        ),
        isTrue,
      );
      expect(
        dictionaryPopupShouldDismissForPointer(
          visible: true,
          dismissOnOutsideTap: true,
          popupBounds: popup,
          position: const Offset(200, 200),
          buttons: kPrimaryMouseButton,
        ),
        isFalse,
      );
    });

    test('mouse back is reserved for the app-level popup-first handler', () {
      expect(
        dictionaryPopupShouldDismissForPointer(
          visible: true,
          dismissOnOutsideTap: true,
          popupBounds: const Rect.fromLTWH(100, 100, 300, 250),
          position: Offset.zero,
          buttons: kBackMouseButton,
        ),
        isFalse,
      );
    });
  });
}
