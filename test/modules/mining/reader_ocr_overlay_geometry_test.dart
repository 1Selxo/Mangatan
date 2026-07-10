import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';

void main() {
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
}
