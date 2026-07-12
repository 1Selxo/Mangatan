import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/library/providers/local_archive.dart';

void main() {
  group('supportedLocalArchiveExtensions', () {
    test('matches the picker formats for every library type', () {
      expect(supportedLocalArchiveExtensions(ItemType.manga), ['cbz', 'zip']);
      expect(supportedLocalArchiveExtensions(ItemType.anime), [
        'mp4',
        'mov',
        'avi',
        'flv',
        'wmv',
        'mpeg',
        'mkv',
      ]);
      expect(supportedLocalArchiveExtensions(ItemType.novel), ['epub']);
    });
  });

  group('filterSupportedLocalArchivePaths', () {
    test('keeps supported manga files in drop order', () {
      expect(
        filterSupportedLocalArchivePaths([
          '/library/first.CBZ',
          '/library/notes.txt',
          r'C:\library\second.ZiP',
          '/library/book.epub',
        ], ItemType.manga),
        ['/library/first.CBZ', r'C:\library\second.ZiP'],
      );
    });

    test('accepts every anime format case-insensitively', () {
      final paths = [
        '/a.MP4',
        '/b.mov',
        '/c.Avi',
        '/d.flv',
        '/e.WMV',
        '/f.mpeg',
        '/g.MkV',
      ];

      expect(filterSupportedLocalArchivePaths(paths, ItemType.anime), paths);
    });

    test('only accepts epub files in the novel library', () {
      expect(
        filterSupportedLocalArchivePaths([
          '/book.EPUB',
          '/archive.zip',
          '/extensionless',
          '/trailing.',
        ], ItemType.novel),
        ['/book.EPUB'],
      );
    });
  });

  test(
    'localArchiveName handles desktop separators and uppercase extensions',
    () {
      expect(localArchiveName('/library/My Book.EPUB'), 'My Book');
      expect(localArchiveName(r'C:\library\My Anime.MKV'), 'My Anime');
    },
  );
}
