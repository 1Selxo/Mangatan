import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';

void main() {
  group('OcrTextBlock.sentence', () {
    test('joins merged OCR lines into one continuous sentence', () {
      // A single OCR text block whose lines were auto-merged from separate
      // detected fragments. Regression for issue #45: Yomitan / Anki received
      // an incomplete sentence because a hard newline sat between the merged
      // lines, so downstream sentence extraction stopped at the first line.
      final block = OcrTextBlock(
        xmin: 0,
        ymin: 0,
        xmax: 1,
        ymax: 1,
        lines: const ['これは', '一つの文です'],
      );

      expect(block.sentence, 'これは一つの文です');
      expect(block.sentence.contains('\n'), isFalse);
    });

    test('drops blank lines when building the sentence', () {
      final block = OcrTextBlock(
        xmin: 0,
        ymin: 0,
        xmax: 1,
        ymax: 1,
        lines: const ['前半', '   ', '後半'],
      );

      expect(block.sentence, '前半後半');
    });

    test('text getter still exposes the newline-joined form', () {
      final block = OcrTextBlock(
        xmin: 0,
        ymin: 0,
        xmax: 1,
        ymax: 1,
        lines: const ['A', 'B'],
      );

      expect(block.text, 'A\nB');
    });
  });
}
