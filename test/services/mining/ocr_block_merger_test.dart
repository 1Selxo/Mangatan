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

  // Regression guard for issue #27 (merge close bounding boxes). Two separate
  // columns whose gap is wider than the per-line same-paragraph threshold must
  // still collapse into a single linked block/bounding box when they sit within
  // the close-group radius, so the reader draws one box and copies one run of
  // text instead of several disconnected fragments.
  test('merges separate vertical columns that sit within the close radius', () {
    final blocks = [
      _block('AA', 0.20, 0.10, 0.23, 0.50, vertical: true),
      _block('BB', 0.30, 0.10, 0.33, 0.50, vertical: true),
    ];

    final merged = mergeOcrBlocks(blocks, language: 'ja');

    // A single merged block == a single rendered bounding box.
    expect(merged, hasLength(1));
    // Right-to-left Japanese reading order links both columns in one block.
    expect(merged.single.lines, ['BB', 'AA']);
    // The merged bounding box spans the union of both columns.
    expect(merged.single.xmin, 0.20);
    expect(merged.single.xmax, 0.33);
    expect(merged.single.ymin, 0.10);
    expect(merged.single.ymax, 0.50);
  });

  test('keeps distant boxes as separate bounding boxes', () {
    final blocks = [
      _block('AA', 0.10, 0.10, 0.13, 0.50, vertical: true),
      _block('BB', 0.80, 0.10, 0.83, 0.50, vertical: true),
    ];

    final merged = mergeOcrBlocks(blocks, language: 'ja');

    // Boxes far outside the close radius must not be merged.
    expect(merged, hasLength(2));
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
