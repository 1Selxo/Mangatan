import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/archive_reader/providers/archive_reader_providers.dart';

void main() {
  test('local folders and archives recognize modern image pages', () {
    expect(isArchiveReaderImagePath('001.avif'), isTrue);
    expect(isArchiveReaderImagePath('pages/002.AVIF'), isTrue);
    expect(isArchiveReaderImagePath('003.webp'), isTrue);
    expect(isArchiveReaderImagePath('004.heic'), isTrue);
    expect(isArchiveReaderImagePath('005.HEIF'), isTrue);
    expect(isArchiveReaderImagePath('006.jxl'), isTrue);
    expect(isArchiveReaderImagePath('metadata.json'), isFalse);
  });
}
