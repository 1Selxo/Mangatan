import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_download_plan.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';

void main() {
  test('plan owns a frozen copy of the remote payload', () {
    final backup = BackupMihon(
      backupManga: [BackupManga(title: 'Remote title', favorite: true)],
    );
    final plan = ChimahonDownloadPlan(
      backup: backup,
      selection: const ChimahonMediaSyncSelection(
        manga: true,
        anime: false,
        novels: false,
      ),
      localProjection: BackupMihon(),
      localMangas: const [],
      localChapters: const [],
    );

    backup.backupManga.single.title = 'Mutated by caller';

    expect(plan.backup.backupManga.single.title, 'Remote title');
    expect(
      () => plan.backup.backupManga.single.title = 'Cannot mutate plan',
      throwsA(anything),
    );
  });

  test('preview reports enabled empty scopes and retained device data', () {
    final localManga = _title(1, ItemType.manga)..favorite = true;
    final localAnime = _title(2, ItemType.anime)
      ..favorite = true
      ..mihonSourceId = '2';
    final staleManga = _title(3, ItemType.manga)..favorite = true;
    final downloadedChapter = Chapter(id: 20, mangaId: 1, name: 'Chapter 1');
    final plan = ChimahonDownloadPlan(
      backup: BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/2',
            title: 'Title 2',
            author: 'Author',
          ),
        ],
        backupNovels: [BackupNovel(id: 'novel', title: 'Novel')],
      ),
      selection: const ChimahonMediaSyncSelection(),
      localProjection: BackupMihon(),
      localMangas: [localManga, localAnime, staleManga],
      localChapters: [downloadedChapter],
      downloadedChapterIds: const {20},
    );

    expect(plan.remoteMangaFavorites, 0);
    expect(plan.remoteAnimeFavorites, 1);
    expect(plan.remoteNovels, 1);
    // Downloaded source chapters keep their files and cache row, but Chimahon
    // still removes their unfavorited parent from the visible library.
    expect(plan.estimatedMangaRemovals, 2);
    expect(plan.estimatedAnimeRemovals, 0);
    expect(plan.deviceLocalRowsRetained, 1);
    expect(plan.confirmationSummary, contains('Manga: 0 remote'));
    expect(plan.confirmationSummary, contains('enabled scope with 0'));
  });

  test('preview revision rejects a changed local projection', () {
    final plan = ChimahonDownloadPlan(
      backup: BackupMihon(),
      selection: const ChimahonMediaSyncSelection(),
      localProjection: BackupMihon(
        backupManga: [BackupManga(source: Int64(1), url: '/one', title: 'One')],
      ),
      localMangas: const [],
      localChapters: const [],
    );

    expect(
      plan.matchesLocalProjection(
        BackupMihon(
          backupManga: [
            BackupManga(source: Int64(1), url: '/two', title: 'Two'),
          ],
        ),
      ),
      isFalse,
    );
  });

  test('second preview does not recount non-favorite cache rows', () {
    final remoteFavorite = _title(1, ItemType.manga)
      ..favorite = true
      ..mihonSourceId = '1';
    final cachedManga = _title(2, ItemType.manga)..favorite = false;
    final tombstonedManga = _title(3, ItemType.manga)..favorite = false;
    final remoteAnime = _title(4, ItemType.anime)
      ..favorite = true
      ..mihonSourceId = '4';
    final cachedAnime = _title(5, ItemType.anime)..favorite = false;
    final plan = ChimahonDownloadPlan(
      backup: BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/1',
            title: 'Title 1',
            author: 'Author',
            favorite: true,
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(4),
            url: '/4',
            title: 'Title 4',
            author: 'Author',
            favorite: true,
          ),
        ],
      ),
      selection: const ChimahonMediaSyncSelection(),
      localProjection: BackupMihon(),
      localMangas: [
        remoteFavorite,
        cachedManga,
        tombstonedManga,
        remoteAnime,
        cachedAnime,
      ],
      localChapters: const [],
    );

    expect(plan.estimatedMangaRemovals, 0);
    expect(plan.estimatedAnimeRemovals, 0);
  });
}

Manga _title(int id, ItemType itemType) => Manga(
  id: id,
  source: 'Source',
  author: 'Author',
  artist: null,
  genre: const [],
  imageUrl: null,
  lang: 'en',
  link: '/$id',
  name: 'Title $id',
  status: Status.ongoing,
  description: null,
  sourceId: id,
  itemType: itemType,
);
