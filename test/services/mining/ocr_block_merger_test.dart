import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/ocr_block_merger.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';

void main() {
  test('joins broken line fragments before paragraph grouping', () {
    final blocks = [
      _block('first', 0.10, 0.10, 0.25, 0.15),
      _block('second', 0.255, 0.10, 0.45, 0.15),
    ];

    final merged = mergeOcrBlocks(blocks, language: 'ja');

    expect(merged, hasLength(1));
    expect(merged.single.lines, ['firstsecond']);
  });

  test('orders Japanese vertical columns from right to left', () {
    final blocks = [
      _block('left', 0.20, 0.10, 0.25, 0.40, vertical: true),
      _block('right', 0.27, 0.10, 0.32, 0.40, vertical: true),
    ];

    final merged = mergeOcrBlocks(blocks, language: 'ja');

    expect(merged.single.lines, ['right', 'left']);
  });

  test('merged multi-line block yields a newline-free sentence', () {
    // Regression for issue #45: auto-merged OCR lines produced a sentence with
    // a hard newline between them, so Yomitan / Anki received an incomplete
    // sentence. The merged block's `sentence` must be one continuous string.
    final blocks = [
      _block('これは', 0.30, 0.10, 0.35, 0.40, vertical: true),
      _block('文です', 0.24, 0.10, 0.29, 0.40, vertical: true),
    ];

    final merged = mergeOcrBlocks(blocks, language: 'ja');

    expect(merged, hasLength(1));
    expect(merged.single.lines.length, greaterThan(1));
    expect(merged.single.sentence, 'これは文です');
    expect(merged.single.sentence.contains('\n'), isFalse);
  });
}

OcrTextBlock _block(
  String text,
  double left,
  double top,
  double right,
  double bottom, {
  bool vertical = false,
}) {
  final geometry = OcrLineGeometry(
    xmin: left,
    ymin: top,
    xmax: right,
    ymax: bottom,
  );
  return OcrTextBlock(
    xmin: left,
    ymin: top,
    xmax: right,
    ymax: bottom,
    lines: [text],
    vertical: vertical,
    lineGeometries: [geometry],
    language: 'ja',
  );
}
