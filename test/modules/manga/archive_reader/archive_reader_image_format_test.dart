import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/archive_reader/models/models.dart';
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

  test('archive pages use natural numeric filename order', () {
    final paths = [
      'pages/10.webp',
      'pages/2.webp',
      'pages/01.webp',
      'pages/1.webp',
      'pages/11.webp',
    ]..sort(compareArchiveReaderPaths);

    expect(paths, [
      'pages/1.webp',
      'pages/01.webp',
      'pages/2.webp',
      'pages/10.webp',
      'pages/11.webp',
    ]);
  });

  test('archive page sorting handles numeric runs larger than an integer', () {
    final paths = ['100000000000000000000.webp', '9.webp', '10.webp']
      ..sort(compareArchiveReaderPaths);

    expect(paths, ['9.webp', '10.webp', '100000000000000000000.webp']);
  });

  test('RAR comic extensions keep their archive type', () {
    expect(setTypeExtension('cbr'), LocalExtensionType.cbr);
    expect(setTypeExtension('RAR'), LocalExtensionType.rar);
    expect(getTypeExtension(LocalExtensionType.cbr), 'cbr');
    expect(getTypeExtension(LocalExtensionType.rar), 'rar');
  });
}
