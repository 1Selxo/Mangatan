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