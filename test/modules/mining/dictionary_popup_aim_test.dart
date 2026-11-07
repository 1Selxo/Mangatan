import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_popup_aim.dart';

void main() {
  // A popup to the right of a vertical speech bubble line.
  const popup = Rect.fromLTRB(710, 360, 980, 670);

  group('dictionaryPopupAimsAt', () {
    test('moving right toward the popup aims at it', () {
      expect(
        dictionaryPopupAimsAt(
          const Offset(640, 530),
          const Offset(660, 528),
          popup,
        ),
        isTrue,
      );
    });

    test('moving down the column beside the popup does not', () {
      expect(
        dictionaryPopupAimsAt(
          const Offset(640, 400),
          const Offset(640, 430),
          popup,
        ),
        isFalse,
      );
    });

    test('moving away from the popup does not', () {
      expect(
        dictionaryPopupAimsAt(
          const Offset(640, 530),
          const Offset(620, 530),
          popup,
        ),
        isFalse,
      );
    });

    test('a diagonal approach from above and left aims at it', () {
      expect(
        dictionaryPopupAimsAt(
          const Offset(600, 300),
          const Offset(620, 315),
          popup,
        ),
        isTrue,
      );
    });
  });

  group('DictionaryPopupAimGuard', () {
    testWidgets('skips text on the way and looks it up after a rest', (
      tester,
    ) async {
      {
        Rect? bounds = popup;
        final guard = DictionaryPopupAimGuard(popupBounds: () => bounds);
        final dwelled = <Offset>[];
        expect(guard.defer(const Offset(640, 530), dwelled.add), isFalse);
        expect(guard.defer(const Offset(660, 529), dwelled.add), isTrue);
        // Jitter while resting keeps the pending dwell.
        await tester.pump(const Duration(milliseconds: 60));
        expect(guard.defer(const Offset(661, 529), dwelled.add), isTrue);
        await tester.pump(const Duration(milliseconds: 60));
        expect(dwelled, [const Offset(661, 529)]);
        expect(guard.aiming, isFalse);
        bounds = null;
        expect(guard.defer(const Offset(700, 529), dwelled.add), isFalse);
      }
    });

    testWidgets('turning away looks text up immediately', (tester) async {
      {
        final guard = DictionaryPopupAimGuard(popupBounds: () => popup);
        final dwelled = <Offset>[];
        guard.defer(const Offset(640, 530), dwelled.add);
        expect(guard.defer(const Offset(660, 529), dwelled.add), isTrue);
        expect(guard.defer(const Offset(660, 560), dwelled.add), isFalse);
        await tester.pump(const Duration(seconds: 1));
        expect(dwelled, isEmpty);
      }
    });

    test('does nothing without a popup', () {
      final guard = DictionaryPopupAimGuard(popupBounds: () => null);
      expect(guard.defer(const Offset(640, 530), (_) {}), isFalse);
      expect(guard.defer(const Offset(660, 529), (_) {}), isFalse);
    });
  });
}
