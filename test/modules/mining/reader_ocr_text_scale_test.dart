import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';

void main() {
  // Regression for issue #39: "Merged text becomes too small".
  //
  // When a merged/large OCR box is wide relative to the single-line text it
  // holds, the old renderer laid the text out on ONE line and scaled it by
  // `min(rect.width / width, rect.height / height)`. A short line inside a big
  // panel therefore collapsed to a tiny font even though the box had ample
  // room. The reporter asked to "let the box wrap the text without shrinking
  // it". The helper must never shrink text that already fits the box, and must
  // prefer wrapping over shrinking.

  group('readerOcrHorizontalTextScale', () {
    test('does not shrink text that already fits the box', () {
      // Wrapped text comfortably fits inside a large panel.
      final scale = readerOcrHorizontalTextScale(
        rect: const Size(400, 300),
        wrappedTextSize: const Size(200, 60),
      );
      expect(scale, 1.0);
    });

    test('keeps full size when a wide panel wraps a short line', () {
      // The classic issue #39 case: box is far wider/taller than the text
      // needs after wrapping. The old min-scale logic would have blown the
      // text up or (for the single-line variant) shrunk it. Wrapped text that
      // fits must render at the natural size, never scaled down.
      final scale = readerOcrHorizontalTextScale(
        rect: const Size(780, 305),
        wrappedTextSize: const Size(300, 44),
      );
      expect(scale, 1.0);
    });

    test('shrinks only enough to fit when wrapped text overflows height', () {
      // Even after wrapping, the text is taller than the box, so it must be
      // scaled down by the limiting (height) ratio — and only that far.
      final scale = readerOcrHorizontalTextScale(
        rect: const Size(200, 100),
        wrappedTextSize: const Size(180, 200),
      );
      expect(scale, closeTo(0.5, 1e-9));
    });

    test('shrinks by width when wrapped text still overflows horizontally', () {
      // A single long unbreakable token can overflow width even after wrap.
      final scale = readerOcrHorizontalTextScale(
        rect: const Size(100, 400),
        wrappedTextSize: const Size(250, 40),
      );
      expect(scale, closeTo(0.4, 1e-9));
    });

    test('never returns a non-positive scale for degenerate boxes', () {
      final scale = readerOcrHorizontalTextScale(
        rect: const Size(0, 0),
        wrappedTextSize: const Size(120, 40),
      );
      expect(scale, greaterThan(0));
    });
  });
}
