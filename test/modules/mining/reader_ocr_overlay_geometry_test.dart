import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/reader_lookup_trigger.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

void main() {
  test('matches Chimahon OCR opacity defaults', () {
    expect(MiningPreferences.defaultOcrBackgroundOpacity, 0.0);
    expect(MiningPreferences.defaultOcrTextOpacity, 1.0);
    expect(MiningPreferences.defaultActiveOcrBackgroundOpacity, 0.7);
  });

  test('uses configured background and opaque text for passive boxes', () {
    expect(readerOcrContentOpacities(boxOpacity: 0.25, active: false), (
      background: 0.25,
      text: 1.0,
    ));
  });

  test('uses independent text and background opacity for active boxes', () {
    final opacity = readerOcrContentOpacities(
      boxOpacity: 0.25,
      activeTextOpacity: .6,
      activeBackgroundOpacity: .8,
      active: true,
    );
    expect(opacity.background, 0.8);
    expect(opacity.text, 0.6);
  });

  test('clamps OCR content opacity to the slider range', () {
    expect(
      readerOcrContentOpacities(
        boxOpacity: .5,
        activeTextOpacity: 2,
        activeBackgroundOpacity: -1,
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

  group('vertical OCR text never clips its box', () {
    test('a small mobile box keeps the glyph column inside the box height', () {
      // A tall, narrow vertical block on a phone: 9 characters in a box only
      // 40px high. The legacy 8.0px font floor forced 8*9 = 72px of glyphs
      // into a 40px box, clipping the bottom characters off screen.
      const box = Rect.fromLTWH(0, 0, 18, 40);
      const glyphCount = 9;

      final fontSize = readerOcrVerticalFontSize(
        boxWidth: box.width,
        boxHeight: box.height,
        glyphCount: glyphCount,
      );

      // Stacked glyphs must fit the box height, otherwise text clips.
      expect(
        fontSize * glyphCount,
        lessThanOrEqualTo(box.height + 0.001),
        reason: 'stacked glyph column must not exceed the box height',
      );
      // And a single glyph must fit the box width.
      expect(
        fontSize,
        lessThanOrEqualTo(box.width + 0.001),
        reason: 'a glyph must not exceed the box width',
      );
    });

    test('a roomy box still scales the font up to fill the rows', () {
      const box = Rect.fromLTWH(0, 0, 60, 400);
      const glyphCount = 8;

      final fontSize = readerOcrVerticalFontSize(
        boxWidth: box.width,
        boxHeight: box.height,
        glyphCount: glyphCount,
      );

      // rowHeight = 400/8 = 50; width 60. The font should track the smaller
      // dimension and stay well above the old 8px floor, but never overflow.
      expect(fontSize, greaterThan(8.0));
      expect(fontSize * glyphCount, lessThanOrEqualTo(box.height + 0.001));
      expect(fontSize, lessThanOrEqualTo(box.width + 0.001));
    });

    test('an empty block yields a safe non-negative font size', () {
      final fontSize = readerOcrVerticalFontSize(
        boxWidth: 10,
        boxHeight: 10,
        glyphCount: 0,
      );
      expect(fontSize, greaterThanOrEqualTo(0.0));
    });
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
