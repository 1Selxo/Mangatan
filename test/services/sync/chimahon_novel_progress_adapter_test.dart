import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_novel_progress_adapter.dart';

void main() {
  const adapter = ChimahonNovelProgressAdapter();

  EpubBookProgress progress({int modified = 100}) => EpubBookProgress(
    mangaId: 1,
    archivePath: '/books/volume.epub',
    title: '  Koyomimonogatari ',
    author: ' NISIOISIN ',
    lang: 'ja',
    chapterIndex: 4,
    progress: 0.25,
    characterCount: 1234,
    lastModified: modified,
  );

  test('exports the exact Chimahon bookmark tuple and stable identity', () {
    final backup = adapter.export(progress());

    expect(backup.id, '76e76b4aba7622e007300e36978b4a10');
    expect(backup.chapterIndex, 4);
    expect(backup.progress, 0.25);
    expect(backup.characterCount, 1234);
    expect(backup.lastModified, Int64(100));
    expect(backup.lang, 'ja');
    expect(backup.categoryIds, ['default']);
  });

  test('populated metadata keeps Chimahon hashing despite a retained ID', () {
    final local = progress()..chimahonId = 'stored-book-id';

    expect(adapter.export(local).id, '76e76b4aba7622e007300e36978b4a10');
  });

  test('empty metadata round-trips the exact retained Chimahon ID', () {
    final local = progress()
      ..title = '  '
      ..author = '\t'
      ..chimahonId = ' exact-book-id ';

    final backup = adapter.export(local);

    expect(backup.id, ' exact-book-id ');
    expect(backup.title, '  ');
    expect(backup.author, '\t');
  });

  test('unidentified legacy empty rows are omitted instead of colliding', () {
    final first = progress()
      ..title = ''
      ..author = null
      ..archivePath = '/books/first.epub';
    final second = progress()
      ..title = ' '
      ..author = '\t'
      ..archivePath = '/books/second.epub';

    expect(adapter.exportAll([first, second]), isEmpty);
    expect(() => adapter.export(first), throwsStateError);
  });

  test('distinct retained IDs keep metadata-empty books distinct', () {
    final first = progress()
      ..title = ''
      ..author = null
      ..chimahonId = 'book-a';
    final second = progress()
      ..title = ' '
      ..author = '\t'
      ..chimahonId = 'book-b';

    expect(adapter.exportAll([first, second]).map((novel) => novel.id), [
      'book-a',
      'book-b',
    ]);
  });

  test('local UI identity retains an imported metadata-empty book ID', () {
    final local = progress()
      ..title = ' '
      ..author = '\t'
      ..chimahonId = 'imported-book-id';

    expect(adapter.stableLocalIdOrNull(local), 'imported-book-id');
  });

  test('local UI identity is nullable before a progress row exists', () {
    expect(
      adapter.stableLocalIdOrNull(
        null,
        fallbackTitle: ' ',
        fallbackAuthor: '\t',
      ),
      isNull,
    );
    expect(
      adapter.stableLocalIdOrNull(
        null,
        fallbackTitle: '  Koyomimonogatari ',
        fallbackAuthor: ' NISIOISIN ',
      ),
      '76e76b4aba7622e007300e36978b4a10',
    );
  });

  test('new imports retain Chimahon-compatible IDs without refresh churn', () {
    final populated = EpubBookProgress.forImportedEpub(
      mangaId: 1,
      archivePath: '/books/populated.epub',
      title: '  Koyomimonogatari ',
      author: ' NISIOISIN ',
    );
    final empty = EpubBookProgress.forImportedEpub(
      mangaId: 1,
      archivePath: '/books/empty.epub',
      title: ' ',
      author: '\t',
    );
    final retainedEmptyId = empty.chimahonId;

    expect(populated.chimahonId, '76e76b4aba7622e007300e36978b4a10');
    expect(retainedEmptyId, 'b99834bc19bbad24580b3adfa04fb947');
    expect(adapter.export(empty).id, retainedEmptyId);

    empty
      ..title = 'Now populated'
      ..author = 'Author';
    expect(empty.chimahonId, retainedEmptyId);
    expect(adapter.export(empty).id, isNot(retainedEmptyId));
  });

  test('restore uses whole-record timestamp ordering and keeps ties local', () {
    final local = progress();
    final remote = BackupNovel(
      id: adapter.stableId(title: local.title, author: local.author),
      title: local.title,
      author: local.author,
      chapterIndex: 7,
      progress: 0.75,
      characterCount: 4321,
      lastModified: Int64(101),
      lang: 'en',
    );

    expect(adapter.applyIfNewer(local, remote), isTrue);
    expect(
      (local.chapterIndex, local.progress, local.characterCount),
      (7, 0.75, 4321),
    );
    expect(local.lang, 'en');

    remote
      ..chapterIndex = 9
      ..lastModified = Int64(101);
    expect(adapter.applyIfNewer(local, remote), isFalse);
    expect(local.chapterIndex, 7);
  });

  test('restore keeps local language when backup omits it', () {
    final local = progress()..lang = 'ja';
    final remote = BackupNovel(
      title: local.title,
      author: local.author,
      chapterIndex: 7,
      lastModified: Int64(101),
    );

    expect(adapter.applyIfNewer(local, remote), isTrue);
    expect(local.lang, 'ja');
  });

  test('language metadata restores independently from older bookmark data', () {
    final local = progress()..lang = 'ja';
    final remote = BackupNovel(
      title: local.title,
      author: local.author,
      chapterIndex: 9,
      lastModified: Int64(99),
      lang: 'en',
    );

    expect(adapter.applyIfNewer(local, remote), isTrue);
    expect(local.chapterIndex, 4);
    expect(local.lastModified, 100);
    expect(local.lang, 'en');
  });

  test('author metadata restores independently from older bookmark data', () {
    final local = progress();
    final remote = BackupNovel(
      title: local.title.trim().toLowerCase(),
      author: local.author!.trim().toLowerCase(),
      chapterIndex: 9,
      lastModified: Int64(99),
    );

    expect(adapter.applyIfNewer(local, remote), isTrue);
    expect(local.chapterIndex, 4);
    expect(local.lastModified, 100);
    expect(local.author, 'nisioisin');
  });

  test('duplicate remote records retain language from the fallback record', () {
    final local = progress()
      ..lang = null
      ..lastModified = 0;
    final older = BackupNovel(
      title: local.title,
      author: local.author,
      chapterIndex: 1,
      lastModified: Int64(100),
      lang: 'ja',
    );
    final latest = BackupNovel(
      title: local.title,
      author: local.author,
      chapterIndex: 8,
      lastModified: Int64(200),
    );

    final changed = adapter.mergeIntoLocal(
      local: [local],
      remote: [older, latest],
    );

    expect(changed, [local]);
    expect(local.chapterIndex, 8);
    expect(local.lang, 'ja');
  });

  test('import captures the canonical wire ID for a populated novel', () {
    final local = progress()..chimahonId = null;
    final remote = BackupNovel(
      id: adapter.stableId(title: local.title, author: local.author),
      title: local.title,
      author: local.author,
      lastModified: Int64(local.lastModified!),
    );

    expect(adapter.applyIfNewer(local, remote), isTrue);
    expect(local.chimahonId, remote.id);
  });

  test('empty metadata imports only by exact retained ID', () {
    final local = progress()
      ..title = ''
      ..author = null
      ..chimahonId = 'book-a';
    final matching = BackupNovel(
      id: 'book-a',
      title: '',
      chapterIndex: 8,
      lastModified: Int64(200),
    );
    final other = BackupNovel(
      id: 'book-b',
      title: '',
      chapterIndex: 9,
      lastModified: Int64(300),
    );

    expect(adapter.applyIfNewer(local, other), isFalse);
    expect(adapter.applyIfNewer(local, matching), isTrue);
    expect(local.chapterIndex, 8);
    expect(local.chimahonId, 'book-a');
  });

  test('unions per-book remote categories on their coarser parent', () {
    final firstBook = progress()
      ..title = 'First book'
      ..mangaId = 7;
    final secondBook = progress()
      ..title = 'Second book'
      ..mangaId = 7;
    final unmatchedBook = progress()
      ..title = 'Local only'
      ..mangaId = 8;

    final categories = adapter.remoteCategoryIdsByMangaId(
      local: [firstBook, secondBook, unmatchedBook],
      remote: [
        BackupNovel(
          title: firstBook.title,
          author: firstBook.author,
          categoryIds: const ['default', 'reading'],
        ),
        BackupNovel(
          title: secondBook.title,
          author: secondBook.author,
          categoryIds: const ['study'],
          lastModified: Int64(10),
        ),
        BackupNovel(
          title: secondBook.title,
          author: secondBook.author,
          categoryIds: const ['reference'],
          lastModified: Int64(20),
        ),
      ],
    );

    expect(categories[7], unorderedEquals(['reading', 'study', 'reference']));
    expect(categories, isNot(contains(8)));
  });
}
