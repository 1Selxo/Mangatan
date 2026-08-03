import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/reader_lookup_trigger.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

void main() {
  test('preserves the original hovered OCR appearance as defaults', () {
    expect(MiningPreferences.defaultOcrBackgroundOpacity, 0.70);
    expect(MiningPreferences.defaultOcrTextOpacity, 1.0);
  });

  test('keeps inactive OCR bubbles invisible', () {
    expect(
      readerOcrContentOpacities(
        backgroundOpacity: 1,
        textOpacity: 1,
        active: false,
      ),
      (background: 0.0, text: 0.0),
    );
  });

  test('applies separate opacities to the active OCR bubble', () {
    expect(
      readerOcrContentOpacities(
        backgroundOpacity: 0.70,
        textOpacity: 1,
        active: true,
      ),
      (background: 0.70, text: 1.0),
    );
    expect(
      readerOcrContentOpacities(
        backgroundOpacity: 0.25,
        textOpacity: 0.60,
        active: true,
      ),
      (background: 0.25, text: 0.60),
    );
  });

  test('clamps OCR content opacity to the slider range', () {
    expect(
      readerOcrContentOpacities(
        backgroundOpacity: -0.5,
        textOpacity: 1.5,
        active: true,
      ),
      (background: 0.0, text: 1.0),
    );
  });

  test('keeps single-page OCR paint rect unchanged', () {
    final rect = Rect.fromLTWH(24, 48, 320, 480);

    expect(
      readerOcrHitTestImageRect(
        paintedImageRect: rect,
        renderBoxSize: const Size(400, 600),
        normalizePaintCoordinates: false,
      ),
      rect,
    );
  });

  test('normalizes double-page OCR paint rect into page-local coordinates', () {
    final normalized = readerOcrHitTestImageRect(
      paintedImageRect: Rect.fromLTWH(600, 20, 480, 720),
      renderBoxSize: const Size(500, 800),
      normalizePaintCoordinates: true,
    );

    expect(normalized, Rect.fromLTWH(10, 40, 480, 720));
  });

  test('normalizes parent-offset single-page OCR paint rect', () {
    final normalized = readerOcrHitTestImageRect(
      paintedImageRect: Rect.fromLTWH(120, 0, 320, 600),
      renderBoxSize: const Size(400, 600),
      normalizePaintCoordinates: true,
    );

    expect(normalized, Rect.fromLTWH(40, 0, 320, 600));
  });

  group('OCR bounding box scaling (issue #26)', () {
    final imageRect = Rect.fromLTWH(0, 0, 400, 600);

    test('unscaled box maps normalized coords straight onto the image', () {
      final rect = readerOcrScaledBlockRect(
        xmin: 0.25,
        ymin: 0.5,
        xmax: 0.75,
        ymax: 0.75,
        imageRect: imageRect,
        scaleX: 1.0,
        scaleY: 1.0,
      );

      expect(rect.left, closeTo(100, 1e-6));
      expect(rect.top, closeTo(300, 1e-6));
      expect(rect.width, closeTo(200, 1e-6));
      expect(rect.height, closeTo(150, 1e-6));
    });

    test('enlarges the box about its center so bigger text fits', () {
      final rect = readerOcrScaledBlockRect(
        xmin: 0.25,
        ymin: 0.5,
        xmax: 0.75,
        ymax: 0.75,
        imageRect: imageRect,
        scaleX: 1.4,
        scaleY: 1.2,
      );

      // Center is preserved: ((0.25+0.75)/2*400, (0.5+0.75)/2*600) = (200, 375).
      expect(rect.center.dx, closeTo(200, 1e-6));
      expect(rect.center.dy, closeTo(375, 1e-6));
      // Width/height grow by the respective scale factors.
      expect(rect.width, closeTo(200 * 1.4, 1e-6));
      expect(rect.height, closeTo(150 * 1.2, 1e-6));
    });

    test('shrinks the box symmetrically when scaled below 1', () {
      final rect = readerOcrScaledBlockRect(
        xmin: 0.25,
        ymin: 0.5,
        xmax: 0.75,
        ymax: 0.75,
        imageRect: imageRect,
        scaleX: 0.8,
        scaleY: 0.8,
      );

      expect(rect.center.dx, closeTo(200, 1e-6));
      expect(rect.center.dy, closeTo(375, 1e-6));
      expect(rect.width, closeTo(200 * 0.8, 1e-6));
      expect(rect.height, closeTo(150 * 0.8, 1e-6));
    });

    test('clips an enlarged box to the image bounds', () {
      // A box hugging the right edge, enlarged horizontally, must not spill
      // outside the image; it is clamped by the image rect.
      final rect = readerOcrScaledBlockRect(
        xmin: 0.8,
        ymin: 0.0,
        xmax: 1.0,
        ymax: 0.2,
        imageRect: imageRect,
        scaleX: 1.5,
        scaleY: 1.5,
      );

      expect(rect.right, lessThanOrEqualTo(imageRect.right + 1e-6));
      expect(rect.top, greaterThanOrEqualTo(imageRect.top - 1e-6));
      expect(rect.left, greaterThanOrEqualTo(imageRect.left - 1e-6));
    });

    test('honors the image rect origin offset', () {
      final offsetImage = Rect.fromLTWH(50, 30, 400, 600);
      final rect = readerOcrScaledBlockRect(
        xmin: 0.0,
        ymin: 0.0,
        xmax: 0.5,
        ymax: 0.5,
        imageRect: offsetImage,
        scaleX: 1.0,
        scaleY: 1.0,
      );

      expect(rect.left, closeTo(50, 1e-6));
      expect(rect.top, closeTo(30, 1e-6));
      expect(rect.width, closeTo(200, 1e-6));
      expect(rect.height, closeTo(300, 1e-6));
    });
  });

  test('popup dismissal consumes the reader tap', () {
    expect(
      readerOcrShouldConsumeMissedTap(
        popupWasVisibleOnPointerDown: true,
        dismissedPopup: false,
      ),
      isTrue,
    );
    expect(
      readerOcrShouldConsumeMissedTap(
        popupWasVisibleOnPointerDown: false,
        dismissedPopup: true,
      ),
      isTrue,
    );
    expect(
      readerOcrShouldConsumeMissedTap(
        popupWasVisibleOnPointerDown: false,
        dismissedPopup: false,
      ),
      isFalse,
    );
  });

  test('repeated left-click lookup dismisses only the active OCR hit', () {
    expect(
      readerOcrShouldDismissRepeatedLookup(
        popupVisible: true,
        triggeredByHover: false,
        sameBlock: true,
        activeOffset: 4,
        hitOffset: 4,
      ),
      isTrue,
    );
    expect(
      readerOcrShouldDismissRepeatedLookup(
        popupVisible: true,
        triggeredByHover: false,
        sameBlock: true,
        activeOffset: 4,
        hitOffset: 5,
      ),
      isFalse,
    );
    expect(
      readerOcrShouldDismissRepeatedLookup(
        popupVisible: false,
        triggeredByHover: false,
        sameBlock: true,
        activeOffset: 4,
        hitOffset: 4,
      ),
      isFalse,
    );
    expect(
      readerOcrShouldDismissRepeatedLookup(
        popupVisible: true,
        triggeredByHover: true,
        sameBlock: true,
        activeOffset: 4,
        hitOffset: 4,
      ),
      isFalse,
    );
  });

  test('matches only the configured lookup pointer button', () {
    expect(
      readerLookupTriggerMatchesPointer(
        DictionaryLookupTrigger.leftClick,
        kPrimaryButton,
      ),
      isTrue,
    );
    expect(
      readerLookupTriggerMatchesPointer(
        DictionaryLookupTrigger.leftClick,
        kMiddleMouseButton,
      ),
      isFalse,
    );
    expect(
      readerLookupTriggerMatchesPointer(
        DictionaryLookupTrigger.middleClick,
        kMiddleMouseButton,
      ),
      isTrue,
    );
    expect(
      readerLookupTriggerMatchesPointer(
        DictionaryLookupTrigger.middleClick,
        kPrimaryButton | kMiddleMouseButton,
      ),
      isFalse,
    );
    expect(
      readerLookupTriggerMatchesPointer(
        DictionaryLookupTrigger.shift,
        kPrimaryButton,
      ),
      isFalse,
    );
    expect(
      readerLookupTriggerMatchesPointer(
        DictionaryLookupTrigger.shift,
        kPrimaryButton,
        additionalLeftClick: true,
      ),
      isTrue,
    );
    expect(
      readerLookupTriggerMatchesPointer(
        DictionaryLookupTrigger.middleClick,
        kPrimaryButton,
        additionalLeftClick: true,
      ),
      isTrue,
    );
    expect(
      readerLookupTriggerMatchesPointer(
        DictionaryLookupTrigger.middleClick,
        kPrimaryButton | kMiddleMouseButton,
        additionalLeftClick: true,
      ),
      isFalse,
    );
  });

  test('matches either Shift key on key down and key up', () {
    for (final keys in [
      (PhysicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftLeft),
      (PhysicalKeyboardKey.shiftRight, LogicalKeyboardKey.shiftRight),
    ]) {
      expect(
        readerLookupTriggerMatchesKey(
          DictionaryLookupTrigger.shift,
          KeyDownEvent(
            physicalKey: keys.$1,
            logicalKey: keys.$2,
            timeStamp: Duration.zero,
          ),
        ),
        isTrue,
      );
    }

    expect(
      readerLookupTriggerMatchesKey(
        DictionaryLookupTrigger.shift,
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.shiftRight,
          logicalKey: LogicalKeyboardKey.shiftRight,
          timeStamp: Duration.zero,
        ),
      ),
      isTrue,
    );

    expect(
      readerLookupTriggerMatchesKey(
        DictionaryLookupTrigger.shift,
        const KeyRepeatEvent(
          physicalKey: PhysicalKeyboardKey.shiftLeft,
          logicalKey: LogicalKeyboardKey.shiftLeft,
          timeStamp: Duration.zero,
        ),
      ),
      isFalse,
    );
    expect(
      readerLookupTriggerMatchesKey(
        DictionaryLookupTrigger.leftClick,
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.shiftLeft,
          logicalKey: LogicalKeyboardKey.shiftLeft,
          timeStamp: Duration.zero,
        ),
      ),
      isFalse,
    );
  });
}
