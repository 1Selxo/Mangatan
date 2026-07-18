import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/library/providers/file_scanner.dart';
import 'package:mangayomi/modules/library/providers/local_archive.dart';
import 'package:mangayomi/services/sync/chimahon_novel_materializer.dart';

void main() {
  group('supportedLocalArchiveExtensions', () {
    test('matches the picker formats for every library type', () {
      expect(supportedLocalArchiveExtensions(ItemType.manga), [
        'cbz',
        'zip',
        'epub',
      ]);
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
        ['/library/first.CBZ', r'C:\library\second.ZiP', '/library/book.epub'],
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

  test(
    'missing-EPUB picker is single-file while normal imports stay grouped',
    () {
      final ghost = Manga(
        id: 7,
        source: chimahonCloudNovelSource,
        author: null,
        artist: null,
        genre: const [],
        imageUrl: null,
        lang: '',
        link: '${chimahonCloudNovelLinkPrefix}book',
        name: 'Cloud book',
        status: Status.unknown,
        description: chimahonMissingEpubGuidance,
        sourceId: null,
        itemType: ItemType.novel,
        favorite: true,
        isLocalArchive: true,
      );
      final progress = EpubBookProgress(
        mangaId: 7,
        archivePath: '',
        title: 'Cloud book',
      );

      expect(allowMultipleArchiveImport(ghost, [progress]), isFalse);
      expect(allowMultipleArchiveImport(ghost, const []), isTrue);
      expect(allowMultipleArchiveImport(null, [progress]), isTrue);
    },
  );

  test(
    'novel parent selection reconciles ghosts without resurrecting them',
    () {
      final normal = _novelParent(id: 1, source: 'archive', link: '/group');
      final ghost = _novelParent(
        id: 2,
        source: chimahonCloudNovelSource,
        link: '${chimahonCloudNovelLinkPrefix}book',
      );
      final ghostProgress = EpubBookProgress(
        id: 20,
        mangaId: 2,
        archivePath: '',
        title: 'Book',
      );

      expect(
        resolveExistingNovelImportParent(
          requestedParent: normal,
          matchingCloudParent: ghost,
          matchingRequestedProgress: null,
          requestedParentWasMissing: false,
        ),
        same(ghost),
        reason: 'A matching ghost wins instead of being orphaned by row moves.',
      );
      expect(
        resolveExistingNovelImportParent(
          requestedParent: ghost,
          matchingCloudParent: ghost,
          matchingRequestedProgress: ghostProgress,
          requestedParentWasMissing: true,
        ),
        same(ghost),
      );
      expect(
        resolveExistingNovelImportParent(
          requestedParent: ghost,
          matchingCloudParent: null,
          matchingRequestedProgress: null,
          requestedParentWasMissing: true,
        ),
        isNull,
        reason:
            'Mismatch creates a separate parent and leaves the ghost intact.',
      );
      expect(
        resolveExistingNovelImportParent(
          requestedParent: null,
          matchingCloudParent: null,
          matchingRequestedProgress: null,
          requestedParentWasMissing: true,
        ),
        isNull,
        reason:
            'A ghost pruned while the picker was open is never resurrected.',
      );
    },
  );

  test('folder scanning never moves progress out of another cloud parent', () {
    final first = EpubBookProgress(mangaId: 1, archivePath: '', title: 'First');
    final second = EpubBookProgress(
      mangaId: 2,
      archivePath: '',
      title: 'Second',
    );

    expect(canAutoLinkScannedCloudNovel(1), isTrue);
    expect(canAutoLinkScannedCloudNovel(2), isFalse);
    expect(scannedNovelProgressCandidates([first, second], 1), [same(first)]);
  });
}

Manga _novelParent({
  required int id,
  required String source,
  required String link,
}) => Manga(
  id: id,
  source: source,
  author: null,
  artist: null,
  genre: const [],
  imageUrl: null,
  lang: '',
  link: link,
  name: 'Book',
  status: Status.unknown,
  description: '',
  sourceId: null,
  itemType: ItemType.novel,
  favorite: true,
  isLocalArchive: true,
);
