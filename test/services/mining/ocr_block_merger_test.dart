import 'dart:math';

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

  test(
    'inserts a space when joining broken fragments for spaced languages',
    () {
      final blocks = [
        _block('hello', 0.10, 0.10, 0.25, 0.15),
        _block('world', 0.255, 0.10, 0.45, 0.15),
      ];

      final merged = mergeOcrBlocks(blocks, language: 'en');

      expect(merged, hasLength(1));
      expect(merged.single.lines, ['hello world']);
    },
  );

  group('joinOcrLines', () {
    test('joins CJK lines without a separator', () {
      expect(joinOcrLines(['今日は', 'いい天気'], language: 'ja'), '今日はいい天気');
      expect(joinOcrLines(['你好', '世界'], language: 'zh'), '你好世界');
    });

    test('joins spaced-language lines with a single space', () {
      expect(joinOcrLines(['hello', 'world'], language: 'en'), 'hello world');
    });

    test(
      'does not add a space when a line already ends or starts with one',
      () {
        expect(
          joinOcrLines(['hello ', 'world'], language: 'en'),
          'hello world',
        );
        expect(
          joinOcrLines(['hello', ' world'], language: 'en'),
          'hello world',
        );
      },
    );

    test('drops empty lines without leaving stray separators', () {
      expect(
        joinOcrLines(['hello', '', 'world'], language: 'en'),
        'hello world',
      );
    });

    test('treats an unknown/empty language as spaced', () {
      expect(joinOcrLines(['foo', 'bar'], language: ''), 'foo bar');
    });
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

  // Regression suite for issue #34: the cross-box Japanese reading order must
  // be a mathematically valid total ordering. PR #79's comparator mixed an
  // overlap-conditional axis flip (compare on x when two boxes shared a row,
  // else on y), which is not transitive and mis-ordered multi-row grids. These
  // tests pin the full expected order for a grid, the original staggered-bubble
  // case, and determinism under shuffling.
  group('issue #34 reading order (valid total ordering)', () {
    test('orders a >=6-box multi-row Japanese layout the old comparator '
        'mis-sorted', () {
      // Six separated blocks (they survive paragraph/close-group merging as
      // distinct blocks, so the reading-order comparator is exercised on all
      // six). This is the multi-row adversarial layout PR #79's
      // overlap-conditional comparator got wrong: its non-transitive relation
      // produced order [B4, B0, B2, B1, B5, B3] — B1 (y=0.672..0.917) sorted
      // ahead of the higher B5 (y=0.610..0.688). The issue #44 banding reads
      // the top-right pair first (B4 above B0 in the right column), then sweeps
      // the lower cluster right-to-left / top-to-bottom, giving the
      // deterministic total order [B4, B0, B3, B2, B1, B5].
      List<OcrTextBlock> layout() => [
        _sep('B0', 0.843, 0.096, 0.976, 0.414),
        _sep('B1', 0.164, 0.672, 0.268, 0.917),
        _sep('B2', 0.381, 0.476, 0.522, 0.645),
        _sep('B3', 0.749, 0.703, 0.858, 0.895),
        _sep('B4', 0.788, 0.011, 0.919, 0.096),
        _sep('B5', 0.006, 0.610, 0.091, 0.688),
      ];

      final merged = mergeOcrBlocks(layout(), language: 'ja');

      expect(merged.map((block) => block.lines.single).toList(), [
        'B4',
        'B0',
        'B3',
        'B2',
        'B1',
        'B5',
      ]);
    });

    test('orders a clean 3-column x 2-row Japanese grid right-to-left', () {
      // A textbook clean grid: two well-separated rows of three columns each.
      // Japanese reads each row right-to-left, top row before bottom row.
      final blocks = [
        _sep('r1c1', 0.05, 0.05, 0.20, 0.15),
        _sep('r1c2', 0.42, 0.05, 0.57, 0.15),
        _sep('r1c3', 0.80, 0.05, 0.95, 0.15),
        _sep('r2c1', 0.05, 0.55, 0.20, 0.65),
        _sep('r2c2', 0.42, 0.55, 0.57, 0.65),
        _sep('r2c3', 0.80, 0.55, 0.95, 0.65),
      ];

      final merged = mergeOcrBlocks(blocks, language: 'ja');

      expect(merged.map((block) => block.lines.single).toList(), [
        'r1c3',
        'r1c2',
        'r1c1',
        'r2c3',
        'r2c2',
        'r2c1',
      ]);
    });

    test('orders two staggered Japanese bubbles right-to-left', () {
      // The original narrow two-bubble fixture PR #79 was built around: two
      // vertically-staggered bubbles that still share the same reading row, so
      // the right one is read first under right-to-left Japanese order.
      final blocks = [
        _sep('left', 0.05, 0.12, 0.25, 0.30),
        _sep('right', 0.60, 0.08, 0.80, 0.26),
      ];

      final merged = mergeOcrBlocks(blocks, language: 'ja');

      expect(merged.map((block) => block.lines.single).toList(), [
        'right',
        'left',
      ]);
    });

    test('sorting is deterministic and consistent under shuffled input', () {
      // Three separated blocks whose vertical extents form the exact
      // non-transitive triple that PR #79's overlap-flip comparator mis-sorts:
      // P0/P1 share a row band while P2 does not overlap P0, so the old
      // pairwise relation had cmp(P0,P1)<0, cmp(P1,P2)<0 but cmp(P0,P2)>0 — a
      // cycle. Fed to List.sort that yields input-order-dependent output. The
      // banded key is a valid total ordering, so every permutation must yield
      // the identical reading order.
      List<OcrTextBlock> triple() => [
        _sep('P0', 0.583, 0.507, 0.678, 0.907),
        _sep('P1', 0.347, 0.481, 0.537, 0.592),
        _sep('P2', 0.701, 0.692, 0.807, 0.748),
      ];

      List<String> order(List<OcrTextBlock> blocks) => mergeOcrBlocks(
        blocks,
        language: 'ja',
      ).map((block) => block.lines.single).toList();

      // The fixture must reach reading order as three distinct blocks (not
      // merged) for this to exercise the comparator.
      expect(order(triple()), hasLength(3));

      // Full expected reading order under the issue #44 banding: P2 is the
      // right-most bubble and sits within one line-height of P0's sweep, so all
      // three share one reading band and are read right-to-left: P2, then P0,
      // then P1.
      const expected = ['P2', 'P0', 'P1'];
      expect(order(triple()), expected);

      // Deterministic across many shuffles — no dependence on input order.
      final random = Random(1234);
      for (var i = 0; i < 100; i++) {
        expect(order(triple()..shuffle(random)), expected);
      }

      // Idempotent: sorting the produced order again is a fixed point.
      expect(order(mergeOcrBlocks(triple(), language: 'ja')), expected);
    });

    test('left-to-right (non-Japanese) grid reads rows left-to-right', () {
      final blocks = [
        _sep('r1c1', 0.05, 0.05, 0.20, 0.15),
        _sep('r1c2', 0.42, 0.05, 0.57, 0.15),
        _sep('r1c3', 0.80, 0.05, 0.95, 0.15),
        _sep('r2c1', 0.05, 0.55, 0.20, 0.65),
        _sep('r2c2', 0.42, 0.55, 0.57, 0.65),
      ];

      final merged = mergeOcrBlocks(blocks, language: 'en');

      expect(merged.map((block) => block.lines.single).toList(), [
        'r1c1',
        'r1c2',
        'r1c3',
        'r2c1',
        'r2c2',
      ]);
    });
  });

  // Regression suite for issue #44: the auto-merger emitted Japanese text
  // left-to-right instead of right-to-left. PR #89's row banding removed the
  // non-transitive comparator but still split vertically-separated staggered
  // bubbles into separate bands, so the higher (left) bubble won and the
  // maintainer's adversarial fixture read [left, right] instead of the correct
  // [right, left]. These tests pin the staggered right-to-left sweep, the
  // multi-band grid traversal, and determinism.
  group('issue #44 right-to-left staggered ordering', () {
    test("maintainer counterexample: vertically separated staggered bubbles "
        'read right-to-left', () {
      // The exact failure the maintainer demonstrated when closing PR #89: two
      // bubbles that are BOTH horizontally offset AND vertically separated (no
      // vertical overlap), with the left bubble sitting higher. A human reads
      // the right bubble first; the pre-fix banding put the higher-left bubble
      // in an earlier band and emitted [left, right].
      final blocks = [
        _sep('left', 0.05, 0.05, 0.25, 0.20),
        _sep('right', 0.60, 0.30, 0.80, 0.45),
      ];

      final merged = mergeOcrBlocks(blocks, language: 'ja');

      expect(merged.map((block) => block.lines.single).toList(), [
        'right',
        'left',
      ]);
    });

    test('vertically separated staggered bubbles read right-to-left with the '
        'right bubble higher', () {
      // The mirror image of the maintainer fixture: the right bubble is higher
      // and the left lower, still vertically separated. Right must still read
      // first, so the assertion is symmetric with the previous test and does
      // not merely depend on which bubble happens to be higher.
      final blocks = [
        _sep('left', 0.05, 0.30, 0.25, 0.45),
        _sep('right', 0.60, 0.05, 0.80, 0.20),
      ];

      final merged = mergeOcrBlocks(blocks, language: 'ja');

      expect(merged.map((block) => block.lines.single).toList(), [
        'right',
        'left',
      ]);
    });

    test('vertically stacked column still splits into separate rows', () {
      // Negative case pinning the other side of the band-assignment rule:
      // boxes that horizontally overlap (a genuine column) with a vertical gap
      // must NOT be swept into one right-to-left band — the upper box reads
      // first, top-to-bottom, so the fix does not collapse real rows.
      final blocks = [
        _sep('top', 0.40, 0.05, 0.60, 0.18),
        _sep('middle', 0.40, 0.35, 0.60, 0.48),
        _sep('bottom', 0.40, 0.65, 0.60, 0.78),
      ];

      final merged = mergeOcrBlocks(blocks, language: 'ja');

      expect(merged.map((block) => block.lines.single).toList(), [
        'top',
        'middle',
        'bottom',
      ]);
    });

    test('multi-band grid is traversed top-to-bottom, right-to-left in each '
        'band', () {
      // A 3-column x 2-row grid whose rows are cleanly separated: bands must be
      // read top row before bottom row, and right-to-left within each row. This
      // proves the staggered-sweep relaxation did not merge distinct grid rows
      // into one band.
      final blocks = [
        _sep('r1L', 0.05, 0.05, 0.25, 0.18),
        _sep('r1M', 0.40, 0.05, 0.60, 0.18),
        _sep('r1R', 0.75, 0.05, 0.95, 0.18),
        _sep('r2L', 0.05, 0.60, 0.25, 0.73),
        _sep('r2M', 0.40, 0.60, 0.60, 0.73),
        _sep('r2R', 0.75, 0.60, 0.95, 0.73),
      ];

      final merged = mergeOcrBlocks(blocks, language: 'ja');

      expect(merged.map((block) => block.lines.single).toList(), [
        'r1R',
        'r1M',
        'r1L',
        'r2R',
        'r2M',
        'r2L',
      ]);
    });

    test(
      'staggered right-to-left order is deterministic under shuffled input',
      () {
        // The reading order must be a valid total ordering: independent of the
        // order the blocks arrive in. Shuffle the maintainer's staggered fixture
        // (plus an extra staggered bubble) many times and require an identical
        // result every time.
        List<OcrTextBlock> layout() => [
          _sep('left', 0.05, 0.05, 0.25, 0.20),
          _sep('mid', 0.35, 0.18, 0.55, 0.33),
          _sep('right', 0.70, 0.30, 0.90, 0.45),
        ];

        List<String> order(List<OcrTextBlock> blocks) => mergeOcrBlocks(
          blocks,
          language: 'ja',
        ).map((block) => block.lines.single).toList();

        const expected = ['right', 'mid', 'left'];
        expect(order(layout()), expected);

        final random = Random(44);
        for (var i = 0; i < 100; i++) {
          expect(order(layout()..shuffle(random)), expected);
        }

        // Idempotent: re-sorting the produced order is a fixed point.
        expect(order(mergeOcrBlocks(layout(), language: 'ja')), expected);
      },
    );
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

/// A single separated (non-merging) block for reading-order tests.
///
/// Reading order runs on the blocks that survive paragraph/close-group
/// merging, so these fixtures are spaced far enough apart to stay distinct and
/// exercise the comparator directly on every box.
OcrTextBlock _sep(
  String text,
  double left,
  double top,
  double right,
  double bottom,
) {
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
    lineGeometries: [geometry],
    language: 'ja',
  );
}
