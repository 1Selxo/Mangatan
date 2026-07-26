import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_importer.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/services/sync/chimahon_novel_materializer.dart';
import 'package:mangayomi/services/sync/mihon_backup_exporter.dart';
import 'package:protobuf/protobuf.dart';

void main() {
  late Directory databaseDirectory;
  late Isar database;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await _isarLibraryPath()},
    );
  });

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'mangatan-chimahon-import-',
    );
    database = await Isar.open(
      [
        MangaSchema,
        ChapterSchema,
        CategorySchema,
        HistorySchema,
        SourceSchema,
        EpubBookProgressSchema,
        DownloadSchema,
        UpdateSchema,
        TrackSchema,
      ],
      directory: databaseDirectory.path,
      name: 'chimahon_sync_importer_test',
    );
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test(
    'upserts portable progress without deleting local-only desktop state',
    () async {
      late Manga portable;
      late Manga cached;
      late Manga unexportable;
      late Manga archive;
      late Manga novel;
      late Chapter syncedChapter;
      late Chapter manualChapter;
      late Chapter orphanedManualChapter;
      late History manualHistory;
      late Chapter archiveChapter;
      late Category syncedCategory;
      late Category archiveCategory;
      late Category novelCategory;
      late EpubBookProgress novelProgress;

      database.writeTxnSync(() {
        database.sources.putSync(_source());
        syncedCategory = Category(
          name: 'Learning',
          forItemType: ItemType.manga,
          pos: 9,
          hide: true,
          shouldUpdate: false,
        );
        archiveCategory = Category(
          name: 'Local shelf',
          forItemType: ItemType.manga,
          pos: 10,
        );
        novelCategory = Category(
          name: 'Books',
          forItemType: ItemType.novel,
          pos: 0,
        );
        database.categorys.putAllSync([
          syncedCategory,
          archiveCategory,
          novelCategory,
        ]);

        portable = _manga(
          name: 'Old source title',
          sourceTitle: 'Old source title',
          link: '/portable',
          sourceId: 42,
          categories: [syncedCategory.id!],
          smartUpdateDays: 14,
          customCoverImage: [1, 2, 3],
        );
        cached = _manga(
          name: 'Cached only',
          sourceTitle: 'Cached only',
          link: '/cached',
          sourceId: 42,
          favorite: false,
        );
        unexportable = _manga(
          name: 'Unexportable local copy',
          sourceTitle: 'Unexportable local copy',
          link: '/unexportable',
          sourceId: null,
          categories: [archiveCategory.id!],
        )..source = 'Remote source';
        archive = _manga(
          name: 'Local archive',
          sourceTitle: 'Local archive',
          link: '/portable',
          sourceId: 42,
          categories: [archiveCategory.id!],
          isLocalArchive: true,
        );
        novel = _manga(
          name: 'Local novel',
          sourceTitle: 'Local novel',
          link: '/book.epub',
          sourceId: null,
          categories: [novelCategory.id!],
          itemType: ItemType.novel,
          isLocalArchive: true,
        );
        database.mangas.putAllSync([
          portable,
          cached,
          unexportable,
          archive,
          novel,
        ]);

        syncedChapter = _chapter(
          portable,
          name: 'Old chapter name',
          url: '/chapter-1',
          archivePath: '/downloads/chapter-1.cbz',
        );
        manualChapter =
            _chapter(
                portable,
                name: 'Chapter 2 collision',
                url: '',
                archivePath: r'C:\Users\reader\Books\manual-chapter.cbz',
                isRead: true,
              )
              ..chapterNumber = 2
              ..isBookmarked = true
              ..lastPageRead = '14';
        orphanedManualChapter = _chapter(
          portable,
          name: 'Legacy URL-only local chapter',
          url: '/Users/reader/Books/url-only-local.cbz',
          archivePath: '',
          isRead: true,
        );
        final cachedChapter = _chapter(
          cached,
          name: 'Cached chapter',
          url: '/cached-chapter',
        );
        archiveChapter = _chapter(
          archive,
          name: 'Archive chapter',
          url: '/archive-chapter',
          archivePath: '/archive/book.cbz',
        );
        database.chapters.putAllSync([
          syncedChapter,
          manualChapter,
          orphanedManualChapter,
          cachedChapter,
          archiveChapter,
        ]);
        for (final chapter in [
          syncedChapter,
          manualChapter,
          orphanedManualChapter,
          cachedChapter,
          archiveChapter,
        ]) {
          chapter.manga.saveSync();
        }

        manualHistory = History(
          mangaId: portable.id,
          chapterId: manualChapter.id,
          itemType: ItemType.manga,
          date: '2222',
          readingTimeSeconds: 17,
        )..chapter.value = manualChapter;
        database.historys.putSync(manualHistory);
        manualHistory.chapter.saveSync();

        final download = Download(
          id: 11,
          succeeded: 4,
          failed: 0,
          total: 4,
          isDownload: true,
          isStartDownload: false,
        )..chapter.value = syncedChapter;
        database.downloads.putSync(download);
        download.chapter.saveSync();

        final update = Update(
          id: 12,
          mangaId: portable.id,
          chapterName: syncedChapter.name,
          date: '50',
        )..chapter.value = syncedChapter;
        database.updates.putSync(update);
        update.chapter.saveSync();

        database.tracks.putSync(
          Track(
            id: 13,
            mangaId: portable.id,
            title: portable.name,
            status: TrackStatus.reading,
          ),
        );

        final archiveHistory = History(
          mangaId: archive.id,
          chapterId: archiveChapter.id,
          itemType: ItemType.manga,
          date: '1234',
        )..chapter.value = archiveChapter;
        database.historys.putSync(archiveHistory);
        archiveHistory.chapter.saveSync();

        novelProgress = EpubBookProgress(
          mangaId: novel.id!,
          archivePath: '/books/book.epub',
          title: 'Book title',
          author: 'Author',
          lang: 'ja',
          chapterIndex: 1,
          progress: 0.1,
          characterCount: 100,
          lastModified: 100,
        );
        database.epubBookProgress.putSync(novelProgress);
      });

      final result = const ChimahonSyncImporter().apply(
        database: database,
        backup: BackupMihon(
          backupCategories: [
            BackupCategory(name: 'Learning', order: Int64.ZERO, hidden: true),
          ],
          backupSources: [
            BackupSource(sourceId: Int64(9001), name: 'Remote source'),
          ],
          backupManga: [
            BackupManga(
              source: Int64(9001),
              url: '/portable',
              title: 'Remote source title',
              customTitle: 'Custom display title',
              favorite: true,
              favoriteModifiedAt: Int64(777),
              categories: [Int64.ZERO],
              author: 'Remote author',
              status: 1,
              lastModifiedAt: Int64(200),
              version: Int64(8),
              chapters: [
                BackupChapter(
                  url: '/chapter-1',
                  name: 'Remote chapter name',
                  read: true,
                  bookmark: true,
                  lastPageRead: Int64(7),
                  dateUpload: Int64(150),
                  lastModifiedAt: Int64(200),
                  version: Int64(4),
                ),
                BackupChapter(
                  url: '/chapter-2',
                  name: 'Chapter 2 collision',
                  chapterNumber: 2,
                  lastModifiedAt: Int64(200),
                ),
                BackupChapter(
                  url: '',
                  name: 'Malformed chapter without a portable identity',
                  lastModifiedAt: Int64(200),
                ),
                BackupChapter(
                  url: '/Users/reader/Books/url-only-local.cbz',
                  name: 'Machine-local path from a wire payload',
                  lastModifiedAt: Int64(200),
                ),
              ],
              history: [
                BackupHistory(
                  url: '/chapter-1',
                  lastRead: Int64(300),
                  readDuration: Int64(9000),
                ),
              ],
            ),
            BackupManga(
              source: Int64(9001),
              url: '/unexportable',
              title: 'Now portable',
              favorite: true,
              categories: [Int64.ZERO],
              status: 1,
              lastModifiedAt: Int64(200),
            ),
          ],
          backupNovels: [
            BackupNovel(
              title: 'Book title',
              author: 'Author',
              lang: 'en',
              chapterIndex: 5,
              progress: 0.8,
              characterCount: 900,
              lastModified: Int64(200),
            ),
          ],
        ),
      );

      expect(result.titlesUpdated, 2);
      expect(result.chaptersCreated, 1);
      expect(result.chaptersUpdated, 1);
      expect(result.novelsUpdated, 1);

      final restoredPortable = database.mangas.getSync(portable.id!);
      expect(restoredPortable?.name, 'Custom display title');
      expect(restoredPortable?.sourceTitle, 'Remote source title');
      expect(restoredPortable?.author, 'Remote author');
      expect(restoredPortable?.favoriteModifiedAt, 777);
      expect(restoredPortable?.categories, [syncedCategory.id]);
      expect(restoredPortable?.customCoverImage, [1, 2, 3]);
      expect(restoredPortable?.smartUpdateDays, 14);

      final restoredSyncedChapter = database.chapters.getSync(
        syncedChapter.id!,
      );
      expect(restoredSyncedChapter?.name, 'Remote chapter name');
      expect(restoredSyncedChapter?.isRead, isTrue);
      expect(restoredSyncedChapter?.lastPageRead, '7');
      expect(restoredSyncedChapter?.archivePath, '/downloads/chapter-1.cbz');
      final restoredHistory = database.historys
          .filter()
          .mangaIdEqualTo(portable.id)
          .chapterIdEqualTo(syncedChapter.id)
          .findFirstSync();
      expect(restoredHistory?.date, '300000');
      expect(restoredHistory?.readingTimeSeconds, 9);
      expect(
        database.chapters.getSync(manualChapter.id!)?.name,
        'Chapter 2 collision',
      );
      final restoredManualChapter = database.chapters.getSync(
        manualChapter.id!,
      );
      expect(
        restoredManualChapter?.archivePath,
        r'C:\Users\reader\Books\manual-chapter.cbz',
      );
      expect(restoredManualChapter?.url, isEmpty);
      expect(restoredManualChapter?.isRead, isTrue);
      expect(restoredManualChapter?.isBookmarked, isTrue);
      expect(restoredManualChapter?.lastPageRead, '14');
      final restoredOrphanedManualChapter = database.chapters.getSync(
        orphanedManualChapter.id!,
      );
      expect(
        restoredOrphanedManualChapter?.name,
        'Legacy URL-only local chapter',
      );
      expect(restoredOrphanedManualChapter?.isRead, isTrue);
      expect(
        database.chapters
            .filter()
            .mangaIdEqualTo(portable.id)
            .urlEqualTo('/Users/reader/Books/url-only-local.cbz')
            .countSync(),
        1,
      );
      final collidingRemoteChapter = database.chapters
          .filter()
          .mangaIdEqualTo(portable.id)
          .urlEqualTo('/chapter-2')
          .findFirstSync();
      expect(collidingRemoteChapter, isNotNull);
      expect(collidingRemoteChapter?.id, isNot(manualChapter.id));
      expect(collidingRemoteChapter?.name, restoredManualChapter?.name);
      expect(
        collidingRemoteChapter?.chapterNumber,
        restoredManualChapter?.chapterNumber,
      );
      expect(
        database.chapters
            .filter()
            .mangaIdEqualTo(portable.id)
            .urlEqualTo('')
            .countSync(),
        1,
      );
      expect(database.historys.getSync(manualHistory.id!)?.date, '2222');
      expect(
        database.historys.getSync(manualHistory.id!)?.readingTimeSeconds,
        17,
      );

      final restoredDownload = database.downloads.getSync(11)!;
      restoredDownload.chapter.loadSync();
      expect(restoredDownload.chapter.value?.id, syncedChapter.id);
      final restoredUpdate = database.updates.getSync(12)!;
      restoredUpdate.chapter.loadSync();
      expect(restoredUpdate.chapter.value?.id, syncedChapter.id);
      expect(database.tracks.getSync(13)?.mangaId, portable.id);

      expect(database.mangas.getSync(cached.id!)?.name, 'Cached only');
      final restoredUnexportable = database.mangas.getSync(unexportable.id!);
      expect(restoredUnexportable?.sourceId, 42);
      expect(restoredUnexportable?.categories?.toSet(), {
        archiveCategory.id!,
        syncedCategory.id!,
      });
      expect(database.mangas.getSync(archive.id!)?.categories, [
        archiveCategory.id,
      ]);
      expect(
        database.chapters.getSync(archiveChapter.id!)?.archivePath,
        '/archive/book.cbz',
      );
      expect(
        database.historys.filter().mangaIdEqualTo(archive.id).countSync(),
        1,
      );
      expect(database.mangas.getSync(novel.id!)?.categories, [
        novelCategory.id,
      ]);
      expect(database.categorys.getSync(syncedCategory.id!)?.hide, isTrue);
      expect(
        database.categorys.getSync(syncedCategory.id!)?.shouldUpdate,
        isFalse,
      );

      final restoredProgress = database.epubBookProgress.getSync(
        novelProgress.id!,
      );
      expect(restoredProgress?.chapterIndex, 5);
      expect(restoredProgress?.progress, 0.8);
      expect(restoredProgress?.lang, 'en');
    },
  );

  test(
    'unions matched EPUB categories onto the novel parent without clearing',
    () async {
      late Category localOnlyCategory;
      late Manga parent;
      late Manga unmatchedParent;
      late EpubBookProgress firstBook;
      late EpubBookProgress secondBook;

      database.writeTxnSync(() {
        localOnlyCategory = Category(
          name: 'On this computer',
          forItemType: ItemType.novel,
          pos: 8,
          shouldUpdate: false,
        );
        database.categorys.putSync(localOnlyCategory);
        parent = _manga(
          name: 'Collected novels',
          sourceTitle: 'Collected novels',
          link: '/collected',
          sourceId: null,
          categories: [localOnlyCategory.id!],
          itemType: ItemType.novel,
          isLocalArchive: true,
        );
        unmatchedParent = _manga(
          name: 'Unmatched novels',
          sourceTitle: 'Unmatched novels',
          link: '/unmatched',
          sourceId: null,
          categories: [localOnlyCategory.id!],
          itemType: ItemType.novel,
          isLocalArchive: true,
        );
        database.mangas.putAllSync([parent, unmatchedParent]);
        firstBook = EpubBookProgress(
          mangaId: parent.id!,
          archivePath: '/books/first.epub',
          title: 'First volume',
          author: 'Writer',
        );
        secondBook = EpubBookProgress(
          mangaId: parent.id!,
          archivePath: r'C:\Books\second.epub',
          title: 'Second volume',
          author: 'Writer',
        );
        database.epubBookProgress.putAllSync([
          firstBook,
          secondBook,
          EpubBookProgress(
            mangaId: unmatchedParent.id!,
            archivePath: '/books/local-only.epub',
            title: 'Local-only volume',
          ),
        ]);
      });

      const ChimahonSyncImporter().apply(
        database: database,
        backup: BackupMihon(
          backupNovelCategories: [
            BackupNovelCategory(
              id: 'default',
              name: 'Default',
              order: Int64(-1),
            ),
            BackupNovelCategory(
              id: 'remote-reading',
              name: 'Reading',
              order: Int64(4),
              flags: Int64(9),
            ),
            BackupNovelCategory(
              id: 'remote-study',
              name: 'Study',
              order: Int64(2),
            ),
            BackupNovelCategory(
              id: 'remote-unused',
              name: 'Remote unused',
              order: Int64(6),
            ),
          ],
          backupNovels: [
            BackupNovel(
              title: firstBook.title,
              author: firstBook.author,
              categoryIds: const ['default', 'remote-reading'],
            ),
            BackupNovel(
              title: secondBook.title,
              author: secondBook.author,
              categoryIds: const ['remote-study', 'missing-definition'],
            ),
          ],
        ),
      );

      final novelCategories = database.categorys
          .filter()
          .forItemTypeEqualTo(ItemType.novel)
          .findAllSync();
      final categoriesByName = {
        for (final category in novelCategories) category.name: category,
      };
      expect(categoriesByName, containsPair('Reading', isA<Category>()));
      expect(categoriesByName, containsPair('Study', isA<Category>()));
      expect(categoriesByName, containsPair('Remote unused', isA<Category>()));
      expect(categoriesByName, isNot(contains('Default')));
      expect(categoriesByName['Reading']?.pos, 4);
      expect(categoriesByName['Study']?.pos, 2);
      expect(categoriesByName['Reading']?.shouldUpdate, isNull);
      expect(
        database.mangas.getSync(parent.id!)?.categories,
        unorderedEquals([
          localOnlyCategory.id!,
          categoriesByName['Reading']!.id!,
          categoriesByName['Study']!.id!,
        ]),
      );
      expect(database.mangas.getSync(unmatchedParent.id!)?.categories, [
        localOnlyCategory.id,
      ]);

      // A later payload with only the implicit default category is not a
      // request to discard either local-only or previously imported shelves.
      const ChimahonSyncImporter().apply(
        database: database,
        backup: BackupMihon(
          backupNovels: [
            BackupNovel(
              title: 'First volume',
              author: 'Writer',
              cover: 'a-cover',
              lang: 'ja',
              categoryIds: const ['default'],
            ),
          ],
        ),
      );
      expect(
        database.mangas.getSync(parent.id!)?.categories,
        unorderedEquals([
          localOnlyCategory.id!,
          categoriesByName['Reading']!.id!,
          categoriesByName['Study']!.id!,
        ]),
      );
    },
  );

  test(
    'remote absence preserves a local custom title and category membership',
    () {
      late Category localCategory;
      late Manga manga;
      database.writeTxnSync(() {
        database.sources.putSync(_source());
        localCategory = Category(
          name: 'Local shelf',
          forItemType: ItemType.manga,
          pos: 7,
        );
        database.categorys.putSync(localCategory);
        manga = _manga(
          name: 'My display title',
          sourceTitle: 'Source title',
          link: '/customized',
          sourceId: 42,
          categories: [localCategory.id!],
        );
        database.mangas.putSync(manga);
      });

      const ChimahonSyncImporter().apply(
        database: database,
        backup: BackupMihon(
          // A non-empty category table makes membership authoritative only
          // when this title actually maps at least one category.
          backupCategories: [
            BackupCategory(name: 'Remote shelf', order: Int64.ZERO),
          ],
          backupSources: [
            BackupSource(sourceId: Int64(9001), name: 'Remote source'),
          ],
          backupManga: [
            BackupManga(
              source: Int64(9001),
              url: '/customized',
              title: 'Source title',
              favorite: true,
              categories: [Int64(99)],
            ),
          ],
        ),
      );

      final restored = database.mangas.getSync(manga.id!)!;
      expect(restored.sourceTitle, 'Source title');
      expect(restored.name, 'My display title');
      expect(restored.categories, [localCategory.id]);
    },
  );

  test(
    'non-favorite tombstone keeps a matching local overlay accessible',
    () async {
      late Manga local;
      late Chapter chapter;
      late Chapter manualChapter;
      database.writeTxnSync(() {
        database.sources.putSync(_source());
        local = _manga(
          name: 'Keep metadata',
          sourceTitle: 'Keep metadata',
          link: '/portable',
          sourceId: 42,
        );
        database.mangas.putSync(local);
        chapter = _chapter(
          local,
          name: 'Keep chapter',
          url: '/chapter',
          isRead: true,
        );
        database.chapters.putSync(chapter);
        chapter.manga.saveSync();
        manualChapter = _chapter(
          local,
          name: 'Device-only chapter',
          url: '',
          archivePath: r'C:\Books\device-only.cbz',
          isRead: true,
        );
        database.chapters.putSync(manualChapter);
        manualChapter.manga.saveSync();
        database.tracks.putAllSync([
          Track(
            id: 80,
            mangaId: local.id,
            syncId: 2,
            status: TrackStatus.reading,
          ),
          Track(
            id: 81,
            mangaId: local.id,
            syncId: 4,
            status: TrackStatus.reading,
          ),
        ]);
      });

      const ChimahonSyncImporter().apply(
        database: database,
        backup: BackupMihon(
          backupSources: [
            BackupSource(sourceId: Int64(9001), name: 'Remote source'),
          ],
          backupManga: [
            BackupManga(
              source: Int64(9001),
              url: '/portable',
              title: 'Remote metadata must not replace tombstone target',
              favorite: false,
              favoriteModifiedAt: Int64(800),
            ),
            BackupManga(
              source: Int64(9001),
              url: '/not-local',
              title: 'Do not create cached tombstones',
              favorite: false,
            ),
          ],
        ),
      );

      final restored = database.mangas.getSync(local.id!);
      expect(restored?.favorite, isFalse);
      expect(restored?.hasLocalChapterOverlay, isTrue);
      expect(restored?.favoriteModifiedAt, 800);
      expect(restored?.name, 'Keep metadata');
      expect(database.chapters.getSync(chapter.id!)?.isRead, isTrue);
      expect(database.chapters.getSync(manualChapter.id!)?.isRead, isTrue);
      final visibleLibraryRows = database.mangas
          .filter()
          .group(
            (query) => query
                .favoriteEqualTo(true)
                .or()
                .hasLocalChapterOverlayEqualTo(true),
          )
          .findAllSync();
      expect(visibleLibraryRows.map((manga) => manga.id), contains(local.id));
      expect(database.tracks.getSync(80), isNotNull);
      expect(database.tracks.getSync(81), isNotNull);
      expect(database.mangas.countSync(), 1);
    },
  );

  test(
    'remote tombstone import does not activate stale cached metadata on the next sync',
    () {
      late Manga cached;
      database.writeTxnSync(() {
        database.sources.putSync(_source());
        cached = _manga(
          name: 'Cached metadata',
          sourceTitle: 'Cached metadata',
          link: '/cached-tombstone',
          sourceId: 42,
          favorite: false,
        )..updatedAt = 900;
        database.mangas.putSync(cached);
      });

      final uploaded = BackupMihon(
        backupSources: [
          BackupSource(sourceId: Int64(9001), name: 'Remote source'),
        ],
        backupManga: [
          BackupManga(
            source: Int64(9001),
            url: '/cached-tombstone',
            title: 'Cached metadata',
            artist: 'Local artist',
            author: 'Local author',
            description: 'Local description',
            genre: const ['Local genre'],
            status: 1,
            thumbnailUrl: 'local-cover',
            dateAdded: Int64.ZERO,
            favorite: false,
            lastModifiedAt: Int64(800),
            favoriteModifiedAt: Int64(800),
            version: Int64(7),
            initialized: true,
          ),
        ],
      );

      // Before the remote tombstone is imported, this cache row has no local
      // favorite clock and is correctly absent from the sync projection.
      expect(_exportProjection(database).backupManga, isEmpty);

      const ChimahonSyncImporter().apply(database: database, backup: uploaded);
      final imported = database.mangas.getSync(cached.id!)!;
      expect(imported.favorite, isFalse);
      expect(imported.favoriteModifiedAt, 800);
      expect(imported.updatedAt, 900);

      // Merely importing the just-uploaded tombstone makes the cached row
      // exportable. Its pre-existing metadata clock must not manufacture a
      // newer record/version when no local edit occurred after the upload.
      final nextProposal = const ChimahonSyncMerger().merge(
        local: _exportProjection(database),
        remote: uploaded,
      );
      final uploadedManga = uploaded.backupManga.single;
      final proposedManga = nextProposal.backupManga.single;
      final changedFields = _semanticFieldDiffSummary(
        uploadedManga,
        proposedManga,
      );
      final changedValues = <String, String>{
        'lastModifiedAt':
            '${uploadedManga.lastModifiedAt} -> '
            '${proposedManga.lastModifiedAt}',
        'version': '${uploadedManga.version} -> ${proposedManga.version}',
        'viewer':
            '${uploadedManga.hasViewer()}/${uploadedManga.viewer} -> '
            '${proposedManga.hasViewer()}/${proposedManga.viewer}',
        'chapterFlags':
            '${uploadedManga.hasChapterFlags()}/${uploadedManga.chapterFlags} '
            '-> ${proposedManga.hasChapterFlags()}/'
            '${proposedManga.chapterFlags}',
        'updateStrategy':
            '${uploadedManga.hasUpdateStrategy()}/'
            '${uploadedManga.updateStrategy} -> '
            '${proposedManga.hasUpdateStrategy()}/'
            '${proposedManga.updateStrategy}',
        'notes':
            '${uploadedManga.hasNotes()}/${uploadedManga.notes.length} -> '
            '${proposedManga.hasNotes()}/${proposedManga.notes.length}',
      };
      expect(
        changedFields,
        isEmpty,
        reason:
            'A no-edit post-import projection changed these protobuf fields: '
            '$changedFields; values: $changedValues (encoded bytes: '
            '${uploadedManga.writeToBuffer().length} -> '
            '${proposedManga.writeToBuffer().length})',
      );
      expect(proposedManga, uploadedManga);
    },
  );

  test('same-title tombstone with a different URL cannot unfavorite', () {
    database.writeTxnSync(() {
      database.sources.putSync(_source());
    });

    const ChimahonSyncImporter().apply(
      database: database,
      backup: BackupMihon(
        backupSources: [
          BackupSource(sourceId: Int64(9001), name: 'Remote source'),
        ],
        backupManga: [
          BackupManga(
            source: Int64(9001),
            url: '/current-entry',
            title: 'Reused source title',
            favorite: true,
            favoriteModifiedAt: Int64(200),
          ),
          BackupManga(
            source: Int64(9001),
            url: '/older-entry',
            title: 'Reused source title',
            favorite: false,
            favoriteModifiedAt: Int64(100),
          ),
        ],
      ),
    );

    final titles = database.mangas.where().findAllSync();
    expect(titles, hasLength(1));
    expect(titles.single.link, '/current-entry');
    expect(titles.single.favorite, isTrue);
    expect(titles.single.favoriteModifiedAt, 200);
  });

  test('imports distinct Chimahon manga and chapters which share URLs', () {
    database.writeTxnSync(() {
      database.sources.putSync(_source());
    });

    final result = const ChimahonSyncImporter().apply(
      database: database,
      backup: BackupMihon(
        backupSources: [
          BackupSource(sourceId: Int64(9001), name: 'Remote source'),
        ],
        backupManga: [
          BackupManga(
            source: Int64(9001),
            url: '/shared-title-url',
            title: 'First edition',
            author: 'Author',
            favorite: true,
            chapters: [
              BackupChapter(
                url: '/shared-chapter-url',
                name: 'Chapter one',
                chapterNumber: 1,
              ),
              BackupChapter(
                url: '/shared-chapter-url',
                name: 'Chapter one revised',
                chapterNumber: 1.5,
              ),
            ],
          ),
          BackupManga(
            source: Int64(9001),
            url: '/shared-title-url',
            title: 'Second edition',
            author: 'Author',
            favorite: true,
          ),
        ],
      ),
    );

    expect(result.titlesCreated, 2);
    expect(result.chaptersCreated, 2);
    final titles = database.mangas.where().findAllSync();
    expect(titles, hasLength(2));
    final first = titles.singleWhere(
      (manga) => manga.sourceTitle == 'First edition',
    );
    expect(
      database.chapters
          .filter()
          .mangaIdEqualTo(first.id)
          .urlEqualTo('/shared-chapter-url')
          .countSync(),
      2,
    );
  });

  test(
    'tracking import upserts present rows without deleting absent services',
    () {
      late Manga manga;
      database.writeTxnSync(() {
        database.sources.putSync(_source());
        manga = _manga(
          name: 'Tracked title',
          sourceTitle: 'Tracked title',
          link: '/tracked',
          sourceId: 42,
        );
        database.mangas.putSync(manga);
        database.tracks.putAllSync([
          Track(
            id: 77,
            mangaId: manga.id,
            syncId: 2,
            title: 'Old AniList title',
            mediaId: 1,
            status: TrackStatus.planToRead,
            updatedAt: 1234,
          ),
          Track(
            id: 78,
            mangaId: manga.id,
            syncId: 4,
            title: 'Mangatan Simkl row',
            mediaId: 444,
            status: TrackStatus.reading,
          ),
          Track(
            id: 79,
            mangaId: manga.id,
            syncId: 3,
            title: 'Deleted remote Kitsu row',
            mediaId: 555,
            status: TrackStatus.reading,
          ),
        ]);
      });

      const ChimahonSyncImporter().apply(
        database: database,
        backup: BackupMihon(
          backupSources: [
            BackupSource(sourceId: Int64(9001), name: 'Remote source'),
          ],
          backupManga: [
            BackupManga(
              source: Int64(9001),
              url: '/tracked',
              title: 'Tracked title',
              favorite: true,
              tracking: [
                BackupTracking(
                  syncId: 2,
                  libraryId: Int64(987),
                  mediaId: Int64(654),
                  trackingUrl: 'https://anilist.co/manga/654',
                  title: 'Remote AniList title',
                  lastChapterRead: 12,
                  totalChapters: 20,
                  score: 85,
                  status: 6,
                  startedReadingDate: Int64(1000),
                  finishedReadingDate: Int64(2000),
                  private: true,
                ),
                // Chimahon ID 4 is Shikimori, but the same local ID is Simkl.
                BackupTracking(
                  syncId: 4,
                  mediaId: Int64(999),
                  title: 'Remote Shikimori row',
                  status: 1,
                ),
              ],
            ),
          ],
        ),
      );

      final aniList = database.tracks.getSync(77)!;
      expect(aniList.id, 77);
      expect(aniList.mangaId, manga.id);
      expect(aniList.libraryId, 987);
      expect(aniList.mediaId, 654);
      expect(aniList.title, 'Remote AniList title');
      expect(aniList.lastChapterRead, 12);
      expect(aniList.totalChapter, 20);
      expect(aniList.score, 85);
      expect(aniList.status, TrackStatus.reReading);
      expect(aniList.startedReadingDate, 1000);
      expect(aniList.finishedReadingDate, 2000);
      expect(aniList.trackingUrl, 'https://anilist.co/manga/654');
      expect(aniList.updatedAt, 1234);

      final simkl = database.tracks.getSync(78)!;
      expect(simkl.title, 'Mangatan Simkl row');
      expect(simkl.mediaId, 444);
      final kitsu = database.tracks.getSync(79)!;
      expect(kitsu.title, 'Deleted remote Kitsu row');
      expect(kitsu.mediaId, 555);
      expect(database.tracks.countSync(), 3);
    },
  );

  test(
    'persists and imports empty novel metadata only by retained wire ID',
    () {
      final matchedParent = _manga(
        name: 'Matched empty metadata',
        sourceTitle: '',
        link: '/books/matched-empty.epub',
        sourceId: null,
        itemType: ItemType.novel,
        isLocalArchive: true,
      );
      final legacyParent = _manga(
        name: 'Legacy empty metadata',
        sourceTitle: '',
        link: '/books/legacy-empty.epub',
        sourceId: null,
        itemType: ItemType.novel,
        isLocalArchive: true,
      );
      final matched = EpubBookProgress.forImportedEpub(
        mangaId: 0,
        archivePath: '/books/matched-empty.epub',
        title: '',
      );
      final legacy = EpubBookProgress(
        mangaId: 0,
        archivePath: '/books/legacy-empty.epub',
        title: '',
      );
      final matchedWireId = matched.chimahonId!;
      database.writeTxnSync(() {
        database.mangas.putAllSync([matchedParent, legacyParent]);
        matched.mangaId = matchedParent.id!;
        legacy.mangaId = legacyParent.id!;
        database.epubBookProgress.putAllSync([matched, legacy]);
      });

      final result = const ChimahonSyncImporter().apply(
        database: database,
        backup: BackupMihon(
          backupNovels: [
            BackupNovel(
              id: matchedWireId,
              title: '',
              chapterIndex: 7,
              progress: 0.5,
              characterCount: 321,
              lastModified: Int64(200),
            ),
            BackupNovel(
              id: 'different-empty-book',
              title: '',
              chapterIndex: 9,
              lastModified: Int64(300),
            ),
          ],
        ),
      );

      expect(result.novelsUpdated, 2);
      final persistedMatched = database.epubBookProgress.getSync(matched.id!);
      expect(persistedMatched, isNotNull);
      expect(persistedMatched!.chimahonId, matchedWireId);
      expect(persistedMatched.chapterIndex, 7);
      expect(persistedMatched.progress, 0.5);
      expect(persistedMatched.characterCount, 321);
      final persistedLegacy = database.epubBookProgress.getSync(legacy.id!);
      expect(persistedLegacy, isNotNull);
      expect(persistedLegacy!.chimahonId, isNull);
      expect(persistedLegacy.chapterIndex, 0);

      final cloudParent = database.mangas
          .filter()
          .sourceEqualTo(chimahonCloudNovelSource)
          .findFirstSync();
      expect(cloudParent, isNotNull);
      expect(cloudParent!.favorite, isTrue);
      expect(cloudParent.isLocalArchive, isTrue);
      final cloudProgress = database.epubBookProgress
          .filter()
          .mangaIdEqualTo(cloudParent.id!)
          .findFirstSync();
      expect(cloudProgress, isNotNull);
      expect(cloudProgress!.archivePath, isEmpty);
      expect(cloudProgress.chimahonId, 'different-empty-book');
      expect(cloudProgress.chapterIndex, 9);
      expect(
        database.chapters.filter().mangaIdEqualTo(cloudParent.id).countSync(),
        0,
      );
    },
  );

  test(
    'materializes remote novels idempotently and keeps wire-only statistics',
    () {
      final remote = BackupMihon(
        backupNovelCategories: [
          BackupNovelCategory(id: 'reading', name: 'Reading', order: Int64(3)),
        ],
        backupNovels: [
          BackupNovel(
            title: 'Remote only',
            author: 'Writer',
            categoryIds: const ['reading'],
            chapterIndex: 2,
            progress: 0.25,
            characterCount: 88,
            lastModified: Int64(100),
            stats: [
              BackupNovelStat(
                dateKey: '2026-07-18',
                charactersRead: 500,
                lastStatisticModified: Int64(101),
              ),
            ],
          ),
        ],
      );

      final first = const ChimahonSyncImporter().apply(
        database: database,
        backup: remote,
      );
      final second = const ChimahonSyncImporter().apply(
        database: database,
        backup: remote,
      );

      expect(first.titlesCreated, 1);
      expect(first.novelsUpdated, 1);
      expect(second.titlesCreated, 0);
      expect(second.novelsUpdated, 0);
      final parent = database.mangas
          .filter()
          .sourceEqualTo(chimahonCloudNovelSource)
          .findFirstSync()!;
      final category = database.categorys
          .filter()
          .forItemTypeEqualTo(ItemType.novel)
          .nameEqualTo('Reading')
          .findFirstSync()!;
      expect(parent.categories, [category.id]);
      expect(
        database.chapters.filter().mangaIdEqualTo(parent.id).countSync(),
        0,
      );
      final progress = database.epubBookProgress
          .filter()
          .mangaIdEqualTo(parent.id!)
          .findFirstSync()!;
      expect(progress.archivePath, isEmpty);

      // Mangatan has no local novel-statistics model. The local projection is
      // merged with the authoritative raw/deferred row, preserving statistics
      // and categories instead of inventing lossy local state.
      final projected = _exportProjection(database);
      final merged = const ChimahonSyncMerger().merge(
        local: projected,
        remote: remote,
        remoteWinsProjectionTies: true,
      );
      expect(merged.backupNovels.single.stats.single.charactersRead, 500);
      expect(merged.backupNovels.single.categoryIds, ['reading']);
    },
  );

  test(
    'same-ID cloud cache follows the current account even when it is older',
    () {
      const importer = ChimahonSyncImporter();
      importer.apply(
        database: database,
        backup: BackupMihon(
          backupNovelCategories: [
            BackupNovelCategory(
              id: 'account-a',
              name: 'Account A',
              order: Int64(0),
            ),
          ],
          backupNovels: [
            BackupNovel(
              title: 'Shared Book',
              author: 'Writer',
              categoryIds: const ['account-a'],
              chapterIndex: 9,
              progress: 0.9,
              characterCount: 900,
              lastModified: Int64(900),
            ),
          ],
        ),
      );
      final originalParent = database.mangas
          .filter()
          .sourceEqualTo(chimahonCloudNovelSource)
          .findFirstSync()!;
      final originalProgress = database.epubBookProgress
          .filter()
          .mangaIdEqualTo(originalParent.id!)
          .findFirstSync()!;
      final accountACategory = database.categorys
          .filter()
          .forItemTypeEqualTo(ItemType.novel)
          .nameEqualTo('Account A')
          .findFirstSync()!;

      final accountB = BackupMihon(
        backupNovelCategories: [
          BackupNovelCategory(
            id: 'account-b',
            name: 'Account B',
            order: Int64(0),
          ),
        ],
        backupNovels: [
          BackupNovel(
            title: ' shared book ',
            author: 'WRITER',
            cover: 'b-cover',
            lang: 'en',
            categoryIds: const ['account-b'],
            chapterIndex: 1,
            progress: 0.1,
            characterCount: 100,
            lastModified: Int64(100),
          ),
        ],
      );
      final changed = importer.apply(database: database, backup: accountB);

      final persistedParent = database.mangas.getSync(originalParent.id!)!;
      final persistedProgress = database.epubBookProgress.getSync(
        originalProgress.id!,
      )!;
      final accountBCategory = database.categorys
          .filter()
          .forItemTypeEqualTo(ItemType.novel)
          .nameEqualTo('Account B')
          .findFirstSync()!;
      expect(changed.titlesCreated, 0);
      expect(changed.novelsUpdated, 1);
      expect(persistedProgress.mangaId, originalParent.id);
      expect(persistedProgress.archivePath, isEmpty);
      expect(persistedProgress.chapterIndex, 1);
      expect(persistedProgress.progress, 0.1);
      expect(persistedProgress.characterCount, 100);
      expect(persistedProgress.lastModified, 100);
      expect(persistedProgress.title, ' shared book ');
      expect(persistedProgress.author, 'WRITER');
      expect(persistedProgress.lang, 'en');
      expect(persistedParent.name, ' shared book ');
      expect(persistedParent.sourceTitle, ' shared book ');
      expect(persistedParent.author, 'WRITER');
      expect(persistedParent.imageUrl, 'b-cover');
      expect(persistedParent.lang, 'en');
      expect(persistedParent.updatedAt, 100);
      expect(persistedParent.categories, [accountBCategory.id]);
      expect(persistedParent.categories, isNot(contains(accountACategory.id)));

      final noOp = importer.apply(database: database, backup: accountB);
      expect(noOp.titlesCreated, 0);
      expect(noOp.novelsUpdated, 0);
    },
  );

  test('prunes only stale exact synthetic cloud-only parents', () {
    const importer = ChimahonSyncImporter();
    importer.apply(
      database: database,
      backup: BackupMihon(
        backupNovels: [
          BackupNovel(title: 'Account A book', lastModified: Int64(10)),
        ],
      ),
    );
    final staleParent = database.mangas
        .filter()
        .sourceEqualTo(chimahonCloudNovelSource)
        .findFirstSync()!;

    late Manga mixedParent;
    late Manga chapterParent;
    database.writeTxnSync(() {
      mixedParent = _manga(
        name: 'Mixed recovery state',
        sourceTitle: 'Mixed recovery state',
        link: '${chimahonCloudNovelLinkPrefix}mixed',
        sourceId: null,
        itemType: ItemType.novel,
        isLocalArchive: true,
      )..source = chimahonCloudNovelSource;
      chapterParent = _manga(
        name: 'Unexpected chapter state',
        sourceTitle: 'Unexpected chapter state',
        link: '${chimahonCloudNovelLinkPrefix}chapter',
        sourceId: null,
        itemType: ItemType.novel,
        isLocalArchive: true,
      )..source = chimahonCloudNovelSource;
      database.mangas.putAllSync([mixedParent, chapterParent]);
      database.epubBookProgress.putAllSync([
        EpubBookProgress(
          mangaId: mixedParent.id!,
          archivePath: '',
          title: 'Mixed ghost',
        ),
        EpubBookProgress(
          mangaId: mixedParent.id!,
          archivePath: '/books/real.epub',
          title: 'Real EPUB',
        ),
        EpubBookProgress(
          mangaId: chapterParent.id!,
          archivePath: '',
          title: 'Unexpected chapter',
        ),
      ]);
      final chapter = Chapter(
        mangaId: chapterParent.id!,
        name: 'Unexpected persisted chapter',
      )..manga.value = chapterParent;
      database.chapters.putSync(chapter);
      chapter.manga.saveSync();
    });

    importer.apply(database: database, backup: BackupMihon());

    expect(database.mangas.getSync(staleParent.id!), isNull);
    expect(
      database.epubBookProgress
          .filter()
          .mangaIdEqualTo(staleParent.id!)
          .countSync(),
      0,
    );
    expect(database.mangas.getSync(mixedParent.id!), isNotNull);
    expect(
      database.epubBookProgress
          .filter()
          .mangaIdEqualTo(mixedParent.id!)
          .countSync(),
      2,
    );
    expect(database.mangas.getSync(chapterParent.id!), isNotNull);
  });
}

BackupMihon _exportProjection(Isar database) =>
    const MihonBackupExporter().export(
      mangas: database.mangas.where().findAllSync(),
      categories: database.categorys.where().findAllSync(),
      chapters: database.chapters.where().findAllSync(),
      histories: database.historys.where().findAllSync(),
      sources: database.sources.where().findAllSync(),
      epubBookProgress: database.epubBookProgress.where().findAllSync(),
      tracks: database.tracks.where().findAllSync(),
    );

Map<String, int> _semanticFieldDiffSummary(
  GeneratedMessage before,
  GeneratedMessage after,
) {
  final result = <String, int>{};

  void record(String path) {
    result.update(path, (count) => count + 1, ifAbsent: () => 1);
  }

  bool scalarEquals(Object? left, Object? right) {
    if (left is List<int> && right is List<int>) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (left[index] != right[index]) return false;
      }
      return true;
    }
    return left == right;
  }

  void compare(GeneratedMessage left, GeneratedMessage right, String path) {
    if (left.info_.qualifiedMessageName != right.info_.qualifiedMessageName) {
      record('$path.<messageType>');
      return;
    }
    final fields = left.info_.fieldInfo.values.toList()
      ..sort((a, b) => a.tagNumber.compareTo(b.tagNumber));
    for (final field in fields) {
      final fieldPath = '$path.${field.name}';
      final leftValue = left.getField(field.tagNumber);
      final rightValue = right.getField(field.tagNumber);
      if (field.isRepeated) {
        final leftList = leftValue as List;
        final rightList = rightValue as List;
        if (leftList.length != rightList.length) {
          record('$fieldPath.length');
        }
        final sharedLength = leftList.length < rightList.length
            ? leftList.length
            : rightList.length;
        for (var index = 0; index < sharedLength; index++) {
          final leftElement = leftList[index];
          final rightElement = rightList[index];
          if (leftElement is GeneratedMessage &&
              rightElement is GeneratedMessage) {
            compare(leftElement, rightElement, '$fieldPath[*]');
          } else if (!scalarEquals(leftElement, rightElement)) {
            record('$fieldPath[*]');
          }
        }
        continue;
      }

      final leftPresent = left.hasField(field.tagNumber);
      final rightPresent = right.hasField(field.tagNumber);
      if (leftPresent != rightPresent) record('$fieldPath.<presence>');
      if (!leftPresent || !rightPresent) continue;
      if (leftValue is GeneratedMessage && rightValue is GeneratedMessage) {
        compare(leftValue, rightValue, fieldPath);
      } else if (!scalarEquals(leftValue, rightValue)) {
        record(fieldPath);
      }
    }
  }

  compare(before, after, before.info_.qualifiedMessageName);
  return Map.fromEntries(
    result.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key)),
  );
}

Source _source() => Source(
  id: 42,
  name: 'Remote source',
  lang: 'ja',
  sourceCode: 'installed',
  isAdded: true,
  additionalParams: encodeMihonSourceMetadata(
    sourceId: 9001,
    packageName: 'test.extension',
  ),
);

Manga _manga({
  required String name,
  required String sourceTitle,
  required String link,
  required int? sourceId,
  bool favorite = true,
  List<int>? categories,
  ItemType itemType = ItemType.manga,
  bool isLocalArchive = false,
  int? smartUpdateDays,
  List<int>? customCoverImage,
}) => Manga(
  source: sourceId == null ? 'Local' : 'Remote source',
  sourceId: sourceId,
  author: 'Local author',
  artist: 'Local artist',
  genre: const ['Local genre'],
  imageUrl: 'local-cover',
  lang: 'ja',
  link: link,
  name: name,
  sourceTitle: sourceTitle,
  status: Status.ongoing,
  description: 'Local description',
  favorite: favorite,
  categories: categories,
  itemType: itemType,
  isLocalArchive: isLocalArchive,
  smartUpdateDays: smartUpdateDays,
  customCoverImage: customCoverImage,
);

Chapter _chapter(
  Manga manga, {
  required String name,
  required String url,
  String archivePath = '',
  bool isRead = false,
}) => Chapter(
  mangaId: manga.id,
  name: name,
  url: url,
  archivePath: archivePath,
  isRead: isRead,
)..manga.value = manga;

Future<String> _isarLibraryPath() async {
  final packageConfig = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  final config = jsonDecode(await packageConfig.readAsString());
  final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
  final package = packages
      .where((entry) => entry['name'] == 'isar_community_flutter_libs')
      .firstOrNull;
  if (package == null) {
    throw StateError('Could not locate isar_community_flutter_libs');
  }
  final rootUri = Uri.parse(package['rootUri'] as String);
  final packageDirectory = Directory.fromUri(
    rootUri.isAbsolute ? rootUri : packageConfig.parent.uri.resolveUri(rootUri),
  );
  if (Platform.isMacOS) {
    return '${packageDirectory.path}/macos/libisar.dylib';
  }
  if (Platform.isLinux) {
    return '${packageDirectory.path}/linux/libisar.so';
  }
  if (Platform.isWindows) {
    return '${packageDirectory.path}/windows/libisar.dll';
  }
  throw UnsupportedError('Isar test is unsupported on this platform');
}
