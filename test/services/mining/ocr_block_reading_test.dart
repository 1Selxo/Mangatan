import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/ocr_block_reading.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';

void main() {
  group('orderedBlockSentence', () {
    test('concatenates CJK lines without separators', () {
      final block = OcrTextBlock(
        xmin: 0,
        ymin: 0,
        xmax: 1,
        ymax: 1,
        lines: ['今日は', 'いい天気'],
        lineGeometries: [
          OcrLineGeometry(xmin: 0, ymin: 0.0, xmax: 1, ymax: 0.4),
          OcrLineGeometry(xmin: 0, ymin: 0.5, xmax: 1, ymax: 0.9),
        ],
        language: 'ja',
      );

      expect(orderedBlockSentence(block), '今日はいい天気');
    });

    test('joins spaced-language lines with a single space', () {
      final block = OcrTextBlock(
        xmin: 0,
        ymin: 0,
        xmax: 1,
        ymax: 1,
        lines: ['the quick', 'brown fox'],
        lineGeometries: [
          OcrLineGeometry(xmin: 0, ymin: 0.0, xmax: 1, ymax: 0.4),
          OcrLineGeometry(xmin: 0, ymin: 0.5, xmax: 1, ymax: 0.9),
        ],
        language: 'en',
      );

      expect(orderedBlockSentence(block), 'the quick brown fox');
    });

    test('orders horizontal lines top to bottom', () {
      final block = OcrTextBlock(
        xmin: 0,
        ymin: 0,
        xmax: 1,
        ymax: 1,
        lines: ['second', 'first'],
        lineGeometries: [
          OcrLineGeometry(xmin: 0, ymin: 0.5, xmax: 1, ymax: 0.9),
          OcrLineGeometry(xmin: 0, ymin: 0.0, xmax: 1, ymax: 0.4),
        ],
        language: 'en',
      );

      expect(orderedBlockSentence(block), 'first second');
    });
  });

  group('toOrderedOffset', () {
    test('maps raw offset within first line unchanged', () {
      final block = _spacedTwoLineBlock();
      // raw offset 2 => inside "the" ('e'), ordered string "the brown"
      expect(toOrderedOffset(block, 2), 2);
    });

    test('accounts for the inserted separator on later lines (spaced)', () {
      // lines: ['the', 'brown'] -> ordered "the brown"
      // raw offset 3 is start of "brown" (raw concat "thebrown").
      // In the ordered "the brown", "brown" starts at index 4 (after space).
      final block = _spacedTwoLineBlock();
      expect(toOrderedOffset(block, 3), 4);
    });

    test('does not shift offsets for CJK (no separators)', () {
      final block = OcrTextBlock(
        xmin: 0,
        ymin: 0,
        xmax: 1,
        ymax: 1,
        lines: ['あい', 'うえ'],
        lineGeometries: [
          OcrLineGeometry(xmin: 0, ymin: 0.0, xmax: 1, ymax: 0.4),
          OcrLineGeometry(xmin: 0, ymin: 0.5, xmax: 1, ymax: 0.9),
        ],
        language: 'ja',
      );
      // raw concat "あいうえ", offset 2 == start of second line, ordered same.
      expect(toOrderedOffset(block, 2), 2);
    });
  });
}

OcrTextBlock _spacedTwoLineBlock() => OcrTextBlock(
  xmin: 0,
  ymin: 0,
  xmax: 1,
  ymax: 1,
  lines: ['the', 'brown'],
  lineGeometries: [
    OcrLineGeometry(xmin: 0, ymin: 0.0, xmax: 1, ymax: 0.4),
    OcrLineGeometry(xmin: 0, ymin: 0.5, xmax: 1, ymax: 0.9),
  ],
  language: 'en',
);
