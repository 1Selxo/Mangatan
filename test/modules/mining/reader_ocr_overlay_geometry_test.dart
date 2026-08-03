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

  // Regression guard for issue #58 ("OCR doesn't work in horizontal mode").
  // The userscript era resolved OCR geometry per reading mode, so a
  // horizontal-only path could silently break while other modes worked. The
  // Flutter rewrite intentionally funnels every reader mode through the single
  // mode-agnostic [readerOcrHitTestImageRect]. These tests pin that contract:
  // a horizontal layout must produce the same page-local OCR geometry as the
  // vertical layout of the same page, so a future refactor cannot reintroduce
  // a horizontal-only OCR failure.
  test(
    'horizontal-continuous full-width page normalizes like its vertical layout',
    () {
      // Same page rendered in a landscape viewport. In the horizontal
      // continuous list the page is laid out into a wide render box and the
      // painted image is centered within it (extended_image BoxFit.contain),
      // producing a horizontally offset painted rect. Normalization must strip
      // that offset back to page-local coordinates.
      const renderBoxSize = Size(1000, 600);
      final horizontalPainted = Rect.fromLTWH(275, 0, 450, 600);

      final horizontalNormalized = readerOcrHitTestImageRect(
        paintedImageRect: horizontalPainted,
        renderBoxSize: renderBoxSize,
        normalizePaintCoordinates: true,
      );

      // The vertical layout of the same 450x600 page also centers the painted
      // image inside its render box, here with a small horizontal letterbox.
      // Both layouts must resolve to the identical page-local rectangle so a
      // tap on the same OCR box lands the same way regardless of reading mode.
      const verticalRenderBoxSize = Size(480, 600);
      final verticalPainted = Rect.fromLTWH(15, 0, 450, 600);
      final verticalNormalized = readerOcrHitTestImageRect(
        paintedImageRect: verticalPainted,
        renderBoxSize: verticalRenderBoxSize,
        normalizePaintCoordinates: true,
      );

      // center-inscribe on both: horizontal x = (1000-450)/2 = 275 -> 275;
      // vertical x = (480-450)/2 = 15 -> 15. Both strip to page-local origin.
      expect(horizontalNormalized, Rect.fromLTWH(275, 0, 450, 600));
      expect(verticalNormalized, Rect.fromLTWH(15, 0, 450, 600));
      // The page-local size (what the block geometry is scaled against) is
      // identical, which is the mode-agnostic contract issue #58 pins.
      expect(horizontalNormalized.size, verticalNormalized.size);
    },
  );

  test(
    'horizontal painted rect normalization is independent of reading axis',
    () {
      // A page painted at the same offset must normalize to the same page-local
      // rect whether the surrounding list scrolls horizontally or vertically:
      // the normalization takes no mode/axis argument, and this asserts nobody
      // reintroduces one.
      final painted = Rect.fromLTWH(140, 30, 320, 540);
      const renderBoxSize = Size(600, 600);

      final normalized = readerOcrHitTestImageRect(
        paintedImageRect: painted,
        renderBoxSize: renderBoxSize,
        normalizePaintCoordinates: true,
      );

      // center-inscribe: x = (600-320)/2 = 140, y = (600-540)/2 = 30.
      expect(normalized, Rect.fromLTWH(140, 30, 320, 540));
    },
  );

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
