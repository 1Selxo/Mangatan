import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';
import 'package:mangayomi/services/sync/chimahon_manual_restore_adapter.dart';
import 'package:mangayomi/services/sync/mihon_backup_source_resolver.dart';

void main() {
  const adapter = ChimahonManualRestoreAdapter();

  test('identifies current and legacy file-backed chapter identities', () {
    Chapter chapter({String? url, String? archivePath}) =>
        Chapter(mangaId: 1, name: 'Manual', url: url, archivePath: archivePath);

    expect(
      adapter.isDeviceLocalChapter(
        chapter(url: '', archivePath: r'C:\Books\manual.cbz'),
      ),
      isTrue,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(
          url: r'c:/books/MANUAL.cbz',
          archivePath: r'C:\Books\manual.cbz',
        ),
      ),
      isTrue,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(url: r'D:\Books\orphaned.cbz', archivePath: ''),
      ),
      isTrue,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(url: r'\\server\Books\orphaned.cbz', archivePath: ''),
      ),
      isTrue,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(url: 'file:///Users/reader/orphaned.cbz', archivePath: ''),
      ),
      isTrue,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(
          url: 'file:///C:/Books/My%20Chapter.cbz',
          archivePath: r'c:\books\my chapter.cbz',
        ),
      ),
      isTrue,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(
          url: r'file://server/Books/Chapter.cbz',
          archivePath: r'\\SERVER\books\chapter.cbz',
        ),
      ),
      isTrue,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(
          url: '/Users/reader/Books/chapter.cbz',
          archivePath: '/Users/reader/Books/chapter.cbz',
        ),
      ),
      isTrue,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(
          url: '/Users/reader/Books/orphaned-url-only.cbz',
          archivePath: '',
        ),
      ),
      isTrue,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(url: '/chapter', archivePath: r'C:\Books\cached.cbz'),
      ),
      isFalse,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(url: '/chapter', archivePath: '/chapter-cache/chapter.cbz'),
      ),
      isFalse,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(url: '/source/chapter', archivePath: ''),
      ),
      isFalse,
    );
    expect(
      adapter.isDeviceLocalChapter(
        chapter(url: '//cdn.example.test/chapter', archivePath: ''),
      ),
      isFalse,
    );
    expect(
      adapter.isDeviceLocalChapter(chapter(url: '', archivePath: '')),
      isFalse,
    );
  });

  test('retained overlay parent requires exact portable URL identity', () {
    final retained = Manga(
      id: 7,
      source: 'Installed source',
      sourceId: 42,
      author: null,
      artist: null,
      genre: const [],
      imageUrl: null,
      lang: 'ja',
      link: '/current-entry',
      name: 'Reused title',
      sourceTitle: 'Reused title',
      status: Status.ongoing,
      description: null,
      itemType: ItemType.manga,
      isLocalArchive: false,
    );
    const source = ResolvedMihonBackupSource(
      nativeId: 9001,
      name: 'Installed source',
      language: 'ja',
      localId: 42,
      installed: true,
    );

    expect(
      adapter.retainedTitle(
        retained: [retained],
        itemType: ItemType.manga,
        source: source,
        url: '/older-entry',
        sourceTitle: 'Reused title',
      ),
      isNull,
      reason: 'A stale same-title row must not capture the manual overlay.',
    );
    expect(
      adapter.retainedTitle(
        retained: [retained],
        itemType: ItemType.manga,
        source: source,
        url: '/current-entry',
        sourceTitle: 'Different title does not matter after an exact URL',
      ),
      same(retained),
    );
    expect(
      adapter.retainedTitle(
        retained: [retained],
        itemType: ItemType.manga,
        source: source,
        url: '',
        sourceTitle: 'Reused title',
      ),
      same(retained),
      reason: 'URL-less legacy rows may still use title fallback.',
    );
  });

  test('retains tracks for local archives and manual-overlay parents', () {
    final archiveTrack = Track(
      id: 10,
      mangaId: 1,
      syncId: 2,
      status: TrackStatus.reading,
    );
    final overlayTrack = Track(
      id: 11,
      mangaId: 2,
      syncId: 4,
      status: TrackStatus.reading,
    );
    final removedParentTrack = Track(
      id: 12,
      mangaId: 3,
      syncId: 1,
      status: TrackStatus.reading,
    );

    final retained = adapter.trackingRowsForRetainedParents(
      tracks: [archiveTrack, overlayTrack, removedParentTrack],
      retainedParentIds: {1, 2},
    );

    expect(retained.map((track) => track.id), [10, 11]);
  });

  test('carries retained manual history onto the rebuilt parent clock', () {
    final histories = [
      History(
        mangaId: 7,
        itemType: ItemType.manga,
        chapterId: 70,
        date: '1700000002000',
      ),
      History(
        mangaId: 7,
        itemType: ItemType.manga,
        chapterId: 71,
        date: 'not-a-clock',
      ),
    ];

    expect(
      adapter.retainedLastRead(
        parentLastRead: 1700000001000,
        histories: histories,
      ),
      1700000002000,
    );
    expect(
      adapter.retainedLastRead(parentLastRead: 1700000003000),
      1700000003000,
    );
  });

  test('restores only portable manga tracker rows onto the rebuilt title', () {
    final rows = adapter.trackingRows(
      remote: [
        BackupTracking(
          syncId: 1,
          mediaId: Int64(101),
          status: 1,
          lastChapterRead: 12,
        ),
        // Chimahon ID 4 is Shikimori, while Mangatan ID 4 is Simkl.
        BackupTracking(syncId: 4, mediaId: Int64(404), status: 1),
        BackupTracking(syncId: 2, mediaId: Int64(202), status: 6, score: 8),
        BackupTracking(syncId: 3, mediaId: Int64(303), status: 5),
      ],
      mangaId: 71,
      itemType: ItemType.manga,
      parentModifiedAt: 1700000000,
    );

    expect(rows.map((row) => row.syncId), [1, 2, 3]);
    expect(rows.map((row) => row.mangaId).toSet(), {71});
    expect(rows.map((row) => row.itemType).toSet(), {ItemType.manga});
    expect(rows.map((row) => row.updatedAt).toSet(), {1700000000000});
    expect(rows[0].status, TrackStatus.reading);
    expect(rows[1].status, TrackStatus.reReading);
    expect(rows[2].status, TrackStatus.planToRead);
    expect(rows[1].mediaId, 202);
    expect(rows[1].score, 8);
  });

  test('uses the last valid duplicate without accepting an invalid status', () {
    final rows = adapter.trackingRows(
      remote: [
        BackupTracking(syncId: 2, mediaId: Int64(10), status: 11),
        BackupTracking(syncId: 2, mediaId: Int64(30), status: 16),
        BackupTracking(syncId: 2, mediaId: Int64(20), status: 999),
      ],
      mangaId: 72,
      itemType: ItemType.anime,
      parentModifiedAt: 1700000000000,
    );

    expect(rows, hasLength(1));
    expect(rows.single.mediaId, 30);
    expect(rows.single.status, TrackStatus.reWatching);
    expect(rows.single.isManga, isFalse);
    expect(rows.single.updatedAt, 1700000000000);
  });

  test('portable restore updates a retained track without changing its ID', () {
    final existing = Track(
      id: 81,
      mangaId: 72,
      syncId: 2,
      mediaId: 10,
      status: TrackStatus.dropped,
      updatedAt: 99,
    );
    final rows = adapter.trackingRows(
      remote: [BackupTracking(syncId: 2, mediaId: Int64(20), status: 1)],
      mangaId: 72,
      itemType: ItemType.manga,
      parentModifiedAt: 1700000000,
      existing: [existing],
    );

    expect(rows, hasLength(1));
    expect(rows.single.id, 81);
    expect(rows.single.mediaId, 20);
    expect(rows.single.status, TrackStatus.reading);
    expect(rows.single.updatedAt, 1700000000000);
  });

  test('preserves favorite tombstone clocks as exact epoch seconds', () {
    final manga = BackupManga(
      favorite: false,
      favoriteModifiedAt: Int64(1800000001),
    );
    final anime = BackupAnime(
      favorite: false,
      favoriteModifiedAt: Int64(1800000002),
    );

    expect(adapter.mangaFavoriteModifiedAt(manga), 1800000001);
    expect(adapter.animeFavoriteModifiedAt(anime), 1800000002);
    expect(adapter.mangaFavoriteModifiedAt(BackupManga()), isNull);
    expect(adapter.animeFavoriteModifiedAt(BackupAnime()), isNull);
  });

  test('maps explicit-restore chapter and episode fields losslessly', () {
    final chapter = adapter.mangaChapterRow(
      remote: BackupChapter(
        name: 'Chapter',
        url: '/chapter',
        scanlator: 'Group',
        chapterNumber: 12.5,
        read: true,
        bookmark: true,
        lastPageRead: Int64(7),
        lastModifiedAt: Int64(1700000001),
        version: Int64(91),
      ),
      mangaId: 40,
      dateUpload: 1700000002000,
    );
    expect(chapter.mangaId, 40);
    expect(chapter.chapterNumber, 12.5);
    expect(chapter.lastPageRead, '7');
    expect(chapter.updatedAt, 1700000001000);

    final episode = adapter.animeEpisodeRow(
      remote: BackupEpisode(
        name: 'Episode',
        url: '/episode',
        episodeNumber: 3.5,
        seen: true,
        bookmark: true,
        lastSecondSeen: Int64(44),
        fillermark: true,
        totalSeconds: Int64(1500),
        summary: 'Summary',
        previewUrl: 'https://example.test/preview.jpg',
        lastModifiedAt: Int64(1700000003),
        version: Int64(92),
      ),
      mangaId: 41,
      dateUpload: 1700000004000,
    );
    expect(episode.mangaId, 41);
    expect(episode.chapterNumber, 3.5);
    expect(episode.isFiller, isTrue);
    expect(episode.duration, '1500');
    expect(episode.description, 'Summary');
    expect(episode.thumbnailUrl, 'https://example.test/preview.jpg');
    expect(episode.updatedAt, 1700000003000);
  });
}
