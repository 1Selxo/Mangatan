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
  group('horizontal OCR line sizing', () {
    test('a block without line geometry starts at its own line height', () {
      // A two-line block 80 px tall: each line is 40 px, not a fixed 20 px.
      expect(readerOcrBlockFontSize(boxHeight: 80, lineCount: 2), 34);
      expect(readerOcrBlockFontSize(boxHeight: 4, lineCount: 1), 8);
    });

    test('CJK lines are painted in the hit-test character cells', () {
      expect(readerOcrUsesCharacterCells('请欺负我吧，恶役小姐！'), isTrue);
      expect(readerOcrUsesCharacterCells('こんにちは'), isTrue);
      expect(readerOcrUsesCharacterCells('Hello world'), isFalse);
      expect(readerOcrUsesCharacterCells(''), isFalse);
    });

    test('a CJK glyph fills its cell in a wide line box', () {
      // A 10-glyph line in a 400 x 36 box: cells are 40 px wide, so the line
      // height, not a fixed 20 px, bounds the glyph.
      final fontSize = readerOcrVerticalFontSize(
        boxWidth: 36,
        boxHeight: 400,
        glyphCount: 10,
      );
      expect(fontSize, closeTo(34.2, 0.01));
    });
  });

  group('reader OCR character cells', () {
    test('uses engine edges that fit the line, equal cells otherwise', () {
      expect(readerOcrCellEdges(2, const [0.0, 0.3, 1.0]), [0.0, 0.3, 1.0]);
      expect(readerOcrCellEdges(2, const [0.0, 1.0]), [0.0, 0.5, 1.0]);
      expect(readerOcrCellEdges(4, null), [0.0, 0.25, 0.5, 0.75, 1.0]);
    });

    test('finds the cell under a point along the line', () {
      const edges = [0.0, 0.2, 0.4, 0.725, 1.0];
      expect(readerOcrCellAt(edges, -0.1), 0);
      expect(readerOcrCellAt(edges, 0.1), 0);
      expect(readerOcrCellAt(edges, 0.2), 1);
      expect(readerOcrCellAt(edges, 0.7), 2);
      expect(readerOcrCellAt(edges, 0.9), 3);
      expect(readerOcrCellAt(edges, 1.5), 3);
    });

    test('sizes glyphs past the ink-tight line height', () {
      // Six even cells of 37 px on a 32 px line: the glyph's ink matches
      // the line, so the em is a ninth larger, still inside its cell.
      final fontSize = readerOcrCellFontSize(
        lineThickness: 32,
        lineLength: 222,
        cellEdges: readerOcrCellEdges(6, null),
      );
      expect(fontSize, closeTo(35.56, 0.01));
    });

    test('never lets glyphs outgrow a typical cell', () {
      final fontSize = readerOcrCellFontSize(
        lineThickness: 60,
        lineLength: 120,
        cellEdges: readerOcrCellEdges(4, null),
      );
      expect(fontSize, 30);
    });
  });
}
