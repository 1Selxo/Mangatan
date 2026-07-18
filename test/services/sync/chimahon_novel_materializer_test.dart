import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_novel_materializer.dart';
import 'package:mangayomi/utils/chimahon_novel_identity.dart';

void main() {
  const materializer = ChimahonNovelMaterializer();

  test('plans a visible database-only book for an unmatched remote novel', () {
    final remote = BackupNovel(
      id: 'wire-id-is-recanonicalized',
      title: '  Cloud Book  ',
      author: ' Writer ',
      cover: 'content://old-device/cover.jpg',
      lang: 'ja',
      chapterIndex: 4,
      progress: 0.75,
      characterCount: 900,
      lastModified: Int64(1700000000000),
      categoryIds: const ['reading'],
      stats: [
        BackupNovelStat(
          dateKey: '2026-07-18',
          charactersRead: 123,
          lastStatisticModified: Int64(1700000000100),
        ),
      ],
    );

    final plan = materializer.plan(
      localMangas: const [],
      localProgress: const [],
      remote: [remote],
    );

    expect(plan.novelsUpdated, 1);
    final cloud = plan.cloudNovels.single;
    expect(cloud.parent.itemType, ItemType.novel);
    expect(cloud.parent.favorite, isTrue);
    expect(cloud.parent.isLocalArchive, isTrue);
    expect(cloud.parent.source, chimahonCloudNovelSource);
    expect(cloud.parent.link, startsWith(chimahonCloudNovelLinkPrefix));
    expect(cloud.parent.name, '  Cloud Book  ');
    expect(cloud.progress.archivePath, isEmpty);
    expect(cloud.progress.mangaId, Isar.autoIncrement);
    expect(cloud.progress.chimahonId, cloud.stableId);
    expect(cloud.progress.title, remote.title);
    expect(cloud.progress.author, remote.author);
    expect(cloud.progress.chapterIndex, 4);
    expect(cloud.progress.progress, 0.75);
    expect(cloud.progress.characterCount, 900);
    expect(cloud.remote.stats.single.charactersRead, 123);
    expect(cloud.remote.categoryIds, ['reading']);
  });

  test('uses a display fallback without changing exact remote title', () {
    final plan = materializer.plan(
      localMangas: const [],
      localProgress: const [],
      remote: [
        BackupNovel(
          id: 'retained-empty-wire-id',
          title: '',
          lastModified: Int64(10),
        ),
      ],
    );

    final cloud = plan.cloudNovels.single;
    expect(cloud.parent.name, 'Cloud novel');
    expect(cloud.parent.sourceTitle, isEmpty);
    expect(cloud.progress.title, isEmpty);
    expect(cloud.progress.chimahonId, 'retained-empty-wire-id');
  });

  test('matching EPUB adopts the ghost row and preserves its bookmark', () {
    final id = ChimahonNovelIdentity.newBookId(title: 'Book', author: 'Author');
    final ghost = EpubBookProgress(
      id: 77,
      mangaId: 5,
      archivePath: '',
      title: 'Book',
      author: 'Author',
      chimahonId: id,
      chapterIndex: 8,
      progress: 0.42,
      characterCount: 321,
      lastModified: 500,
    );

    final imported = materializer.progressForImportedEpub(
      progresses: [ghost],
      mangaId: 5,
      archivePath: '/books/book.epub',
      title: ' book ',
      author: 'AUTHOR',
      lang: 'ja',
    );

    expect(identical(imported, ghost), isTrue);
    expect(imported.id, 77);
    expect(imported.archivePath, '/books/book.epub');
    expect(imported.chimahonId, id);
    expect(imported.chapterIndex, 8);
    expect(imported.progress, 0.42);
    expect(imported.characterCount, 321);
    expect(imported.lastModified, 500);
  });

  test('mismatched EPUB does not consume the selected ghost row', () {
    final ghost = EpubBookProgress(
      id: 9,
      mangaId: 5,
      archivePath: '',
      title: 'Expected',
      author: 'Writer',
      chimahonId: ChimahonNovelIdentity.newBookId(
        title: 'Expected',
        author: 'Writer',
      ),
    );

    expect(
      materializer.matchingCloudProgress(
        progresses: [ghost],
        title: 'Different',
        author: 'Writer',
        preferredMangaId: 5,
        allowUnidentifiablePreferredParent: true,
      ),
      isNull,
    );
    expect(ghost.archivePath, isEmpty);
  });

  test('new empty metadata uses Chimahon md5 pipe identity', () {
    expect(
      ChimahonNovelIdentity.newBookId(title: ' ', author: '\t'),
      'b99834bc19bbad24580b3adfa04fb947',
    );

    final oldFallbackGhost = EpubBookProgress(
      id: 11,
      mangaId: 6,
      archivePath: '',
      title: '',
      chimahonId: 'older-retained-wire-id',
    );
    expect(
      materializer.matchingCloudProgress(
        progresses: [oldFallbackGhost],
        title: '',
        preferredMangaId: 6,
        allowUnidentifiablePreferredParent: true,
      ),
      same(oldFallbackGhost),
      reason:
          'An older arbitrary empty-metadata ID is reconcilable only from '
          'the explicitly selected parent.',
    );
  });

  test('orphan progress cannot suppress visible remote materialization', () {
    final orphan = EpubBookProgress(
      mangaId: 99,
      archivePath: '/orphan.epub',
      title: 'Remote Book',
      author: 'Writer',
    );
    final plan = materializer.plan(
      localMangas: const [],
      localProgress: [orphan],
      remote: [BackupNovel(title: 'Remote Book', author: 'Writer')],
    );

    expect(plan.cloudNovels, hasLength(1));
    expect(plan.updatedProgress, isEmpty);
  });

  test('current remote replaces a newer exact cloud-cache bookmark', () {
    final parent = _parent(id: 7)
      ..categories = const [91]
      ..name = 'Account A display'
      ..sourceTitle = 'Shared Book'
      ..author = 'Writer'
      ..imageUrl = 'a-cover'
      ..lang = 'ja';
    final cached = EpubBookProgress(
      id: 12,
      mangaId: 7,
      archivePath: '',
      title: 'Shared Book',
      author: 'Writer',
      chimahonId: ChimahonNovelIdentity.newBookId(
        title: 'Shared Book',
        author: 'Writer',
      ),
      lang: 'ja',
      chapterIndex: 9,
      progress: 0.9,
      characterCount: 900,
      lastModified: 900,
    );

    final plan = materializer.plan(
      localMangas: [parent],
      localProgress: [cached],
      remote: [
        BackupNovel(
          title: ' shared book ',
          author: 'WRITER',
          cover: 'b-cover',
          lang: 'en',
          chapterIndex: 1,
          progress: 0.1,
          characterCount: 100,
          lastModified: Int64(100),
          categoryIds: const ['account-b'],
        ),
      ],
    );

    expect(plan.authoritativeCloudParentIds, {7});
    expect(plan.updatedProgress, [same(cached)]);
    expect(plan.updatedCloudParents, [same(parent)]);
    expect(plan.novelsUpdated, 1);
    expect(plan.remoteCategoryIdsByMangaId[7], ['account-b']);
    expect(parent.name, ' shared book ');
    expect(parent.sourceTitle, ' shared book ');
    expect(parent.author, 'WRITER');
    expect(parent.imageUrl, 'b-cover');
    expect(parent.lang, 'en');
    expect(parent.updatedAt, 100);
    expect(cached.chapterIndex, 1);
    expect(cached.progress, 0.1);
    expect(cached.characterCount, 100);
    expect(cached.lastModified, 100);
    expect(cached.lang, 'en');

    final noOp = materializer.plan(
      localMangas: [parent],
      localProgress: [cached],
      remote: [
        BackupNovel(
          title: ' shared book ',
          author: 'WRITER',
          cover: 'b-cover',
          lang: 'en',
          chapterIndex: 1,
          progress: 0.1,
          characterCount: 100,
          lastModified: Int64(100),
          categoryIds: const ['account-b'],
        ),
      ],
    );
    expect(noOp.updatedProgress, isEmpty);
    expect(noOp.updatedCloudParents, isEmpty);
    expect(noOp.novelsUpdated, 0);
  });

  test('real EPUB bookmark still uses Chimahon last-write-wins', () {
    final parent = _parent(id: 8);
    final real = EpubBookProgress(
      id: 13,
      mangaId: 8,
      archivePath: '/books/shared.epub',
      title: 'Shared Book',
      author: 'Writer',
      chapterIndex: 9,
      progress: 0.9,
      lastModified: 900,
    );
    final plan = materializer.plan(
      localMangas: [parent],
      localProgress: [real],
      remote: [
        BackupNovel(
          title: 'Shared Book',
          author: 'Writer',
          chapterIndex: 1,
          progress: 0.1,
          lastModified: Int64(100),
        ),
      ],
    );

    expect(plan.authoritativeCloudParentIds, isEmpty);
    expect(plan.updatedProgress, [same(real)]);
    expect(real.chimahonId, isNotNull);
    expect(real.chapterIndex, 9);
    expect(real.progress, 0.9);
  });

  test('stale pruning accepts only the exact synthetic ghost shape', () {
    final stale = _parent(id: 1);
    final retained = _parent(id: 2);
    final mixed = _parent(id: 3);
    final withChapter = _parent(id: 4);
    final staleProgress = _ghostProgress(1, 'Stale');
    final retainedProgress = _ghostProgress(2, 'Retained');
    final mixedGhost = _ghostProgress(3, 'Mixed ghost');
    final mixedReal = EpubBookProgress(
      mangaId: 3,
      archivePath: '/books/real.epub',
      title: 'Real',
    );
    final chapter = Chapter(mangaId: 4, name: 'Unexpected local row');

    final ids = materializer.staleCloudNovelParentIds(
      localMangas: [stale, retained, mixed, withChapter],
      localProgress: [
        staleProgress,
        retainedProgress,
        mixedGhost,
        mixedReal,
        _ghostProgress(4, 'Has chapter'),
      ],
      localChapters: [chapter],
      remote: [BackupNovel(title: retainedProgress.title)],
    );

    expect(ids, {1});
  });
}

Manga _parent({required int id}) => Manga(
  id: id,
  source: chimahonCloudNovelSource,
  author: null,
  artist: null,
  genre: const [],
  imageUrl: null,
  lang: '',
  link: '$chimahonCloudNovelLinkPrefix$id',
  name: 'Cloud $id',
  status: Status.unknown,
  description: chimahonMissingEpubGuidance,
  sourceId: null,
  itemType: ItemType.novel,
  favorite: true,
  isLocalArchive: true,
);

EpubBookProgress _ghostProgress(int mangaId, String title) => EpubBookProgress(
  mangaId: mangaId,
  archivePath: '',
  title: title,
  chimahonId: ChimahonNovelIdentity.newBookId(title: title),
);
