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
