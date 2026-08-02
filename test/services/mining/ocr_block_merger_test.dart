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

  test('orders staggered Japanese blocks right-to-left despite partial '
      'vertical overlap between neighbours', () {
    // A descending "staircase" of vertical text blocks. Each neighbour shares
    // a little vertical overlap with the next, but the leftmost and rightmost
    // blocks do not overlap at all. A pairwise right-to-left comparator that
    // falls back to top-to-bottom only when two blocks fail to overlap is
    // non-transitive here (A<C by y, B<A by x-overlap, C<B by x-overlap forms
    // a cycle), so List.sort produces a corrupted order that drops the
    // right-most block out of first place. Japanese must always read the
    // right-most block first.
    final blocks = [
      _block('A', 0.10, 0.10, 0.18, 0.30, vertical: true), // left
      _block('B', 0.40, 0.25, 0.48, 0.45, vertical: true), // middle
      _block('C', 0.70, 0.40, 0.78, 0.60, vertical: true), // right
    ];

    final merged = mergeOcrBlocks(blocks, language: 'ja');

    expect(merged.map((block) => block.lines.single).toList(), ['C', 'B', 'A']);
  });

  test(
    'orders a grid of Japanese blocks right-to-left, then top-to-bottom',
    () {
      // Two rows of three vertical blocks each, supplied out of order. Manga
      // reading order is right-to-left within a row, then down to the next row.
      final blocks = [
        _block('R2b', 0.40, 0.62, 0.50, 0.82, vertical: true),
        _block('R1c', 0.70, 0.11, 0.80, 0.31, vertical: true),
        _block('R1a', 0.10, 0.10, 0.20, 0.30, vertical: true),
        _block('R2c', 0.70, 0.61, 0.80, 0.81, vertical: true),
        _block('R1b', 0.40, 0.12, 0.50, 0.32, vertical: true),
        _block('R2a', 0.10, 0.60, 0.20, 0.80, vertical: true),
      ];

      final merged = mergeOcrBlocks(blocks, language: 'ja');

      expect(merged.map((block) => block.lines.single).toList(), [
        'R1c',
        'R1b',
        'R1a',
        'R2c',
        'R2b',
        'R2a',
      ]);
    },
  );

  test('orders non-Japanese staggered blocks left-to-right', () {
    // Same staggered geometry as the Japanese staircase, but a left-to-right
    // language must read the left-most block first.
    final blocks = [
      _block('A', 0.10, 0.10, 0.18, 0.30, vertical: true), // left
      _block('B', 0.40, 0.25, 0.48, 0.45, vertical: true), // middle
      _block('C', 0.70, 0.40, 0.78, 0.60, vertical: true), // right
    ];

    final merged = mergeOcrBlocks(blocks, language: 'en');

    expect(merged.map((block) => block.lines.single).toList(), ['A', 'B', 'C']);
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
