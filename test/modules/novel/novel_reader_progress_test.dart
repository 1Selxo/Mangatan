import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/novel/novel_reader_progress.dart';

void main() {
  test('formats novel progress with one decimal digit', () {
    expect(formatNovelProgressPercentage(0), '0.0 %');
    expect(formatNovelProgressPercentage(0.1236), '12.4 %');
    expect(formatNovelProgressPercentage(1), '100.0 %');
  });

  test('clamps invalid and out-of-range progress', () {
    expect(formatNovelProgressPercentage(-0.2), '0.0 %');
    expect(formatNovelProgressPercentage(1.2), '100.0 %');
    expect(formatNovelProgressPercentage(double.nan), '0.0 %');
  });

  test('estimates chapter characters from progress', () {
    expect(
      novelProgressCharacterCount(progress: 0.456, totalCharacterCount: 1000),
      456,
    );
  });

  test('prefers an exact EPUB character count', () {
    expect(
      formatNovelReaderProgress(
        progress: 0.1236,
        totalCharacterCount: 1000,
        exactCharacterCount: 4321,
      ),
      '12.4 % / 4321',
    );
  });
}
