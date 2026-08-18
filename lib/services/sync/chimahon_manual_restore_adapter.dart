import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';
import 'package:mangayomi/services/sync/chimahon_tracking_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_local_chapter_policy.dart';
import 'package:mangayomi/services/sync/mihon_backup_source_resolver.dart';

/// Projects the Chimahon fields needed by an explicit, destructive restore.
///
/// Routine sync has its own incremental importer. A manual restore rebuilds
/// title rows and therefore needs to attach portable tracking rows to the new
/// local IDs after those IDs have been assigned.
class ChimahonManualRestoreAdapter {
  const ChimahonManualRestoreAdapter({
    this.trackingAdapter = const ChimahonTrackingAdapter(),
  });

  final ChimahonTrackingAdapter trackingAdapter;

  /// A source URL is Chimahon's chapter identity. File-backed rows without one,
  /// including legacy rows that repeated the archive path in the URL field,
  /// are retained around an explicit restore and never put on the wire.
  bool isDeviceLocalChapter(Chapter chapter) =>
      const ChimahonLocalChapterPolicy().isDeviceLocal(chapter);

  /// Finds the retained manual-overlay parent that an explicit restore may
  /// safely rebuild in place. A non-empty source URL is the portable identity;
  /// title fallback is only safe for URL-less legacy records.
  Manga? retainedTitle({
    required Iterable<Manga> retained,
    required ItemType itemType,
    required ResolvedMihonBackupSource source,
    required String url,
    required String sourceTitle,
  }) {
    bool sourceMatches(Manga manga) {
      if (source.localId != null) {
        return manga.sourceId == source.localId ||
            (manga.sourceId == null && manga.source == source.name);
      }
      return manga.source == source.name;
    }

    final candidates = retained.where(
      (manga) =>
          manga.itemType == itemType &&
          manga.isLocalArchive != true &&
          sourceMatches(manga),
    );
    if (url.trim().isNotEmpty) {
      for (final manga in candidates) {
        if (manga.link == url) return manga;
      }
      return null;
    }
    for (final manga in candidates) {
      if (manga.sourceTitle == sourceTitle || manga.name == sourceTitle) {
        return manga;
      }
    }
    return null;
  }

  /// Retains tracker rows for every title that survives a destructive restore.
  /// This includes source-backed titles kept solely because they own a
  /// device-local chapter overlay, not just titles marked as local archives.
  List<Track> trackingRowsForRetainedParents({
    required Iterable<Track> tracks,
    required Set<int> retainedParentIds,
  }) => tracks
      .where((track) => retainedParentIds.contains(track.mangaId))
      .toList(growable: false);

  /// A retained manual chapter keeps its History row. Carry that history's
  /// latest clock back onto the rebuilt parent as well so recent-reading order
  /// and resume behavior do not silently regress.
  int retainedLastRead({
    int? parentLastRead,
    Iterable<History> histories = const [],
  }) {
    var latest = parentLastRead ?? 0;
    for (final history in histories) {
      final readAt = int.tryParse(history.date ?? '') ?? 0;
      if (readAt > latest) latest = readAt;
    }
    return latest;
  }

  Chapter mangaChapterRow({
    required BackupChapter remote,
    required int mangaId,
    required int dateUpload,
  }) => Chapter(
    mangaId: mangaId,
    name: remote.name,
    dateUpload: '$dateUpload',
    isBookmarked: remote.bookmark,
    isRead: remote.read,
    lastPageRead: remote.lastPageRead == 0 ? '1' : '${remote.lastPageRead}',
    scanlator: remote.hasScanlator() ? remote.scanlator : '',
    url: remote.url,
    chapterNumber: remote.chapterNumber,
    updatedAt: updatedAtFromLastModified(remote.lastModifiedAt.toInt()),
  );

  Chapter animeEpisodeRow({
    required BackupEpisode remote,
    required int mangaId,
    required int dateUpload,
  }) => Chapter(
    mangaId: mangaId,
    name: remote.name,
    dateUpload: '$dateUpload',
    isBookmarked: remote.bookmark,
    isRead: remote.seen,
    lastPageRead: remote.lastSecondSeen == 0 ? '1' : '${remote.lastSecondSeen}',
    scanlator: remote.hasScanlator() ? remote.scanlator : '',
    url: remote.url,
    chapterNumber: remote.episodeNumber,
    isFiller: remote.fillermark,
    thumbnailUrl: remote.hasPreviewUrl() ? remote.previewUrl : null,
    description: remote.hasSummary() ? remote.summary : null,
    duration: remote.totalSeconds == 0 ? null : '${remote.totalSeconds}',
    updatedAt: updatedAtFromLastModified(remote.lastModifiedAt.toInt()),
  );

  /// Returns one valid row per tracker shared by Mangatan and Chimahon.
  ///
  /// Chimahon IDs 4 and 5 have different meanings in Mangatan, so the shared
  /// tracking adapter deliberately filters them. If a malformed duplicate is
  /// present, the last valid row wins without discarding an earlier valid row.
  List<Track> trackingRows({
    required Iterable<BackupTracking> remote,
    required int mangaId,
    required ItemType itemType,
    required int parentModifiedAt,
    Iterable<Track> existing = const [],
  }) {
    final rowsByTracker = <int, Track>{};
    final existingByTracker = <int, Track>{
      for (final track in existing)
        if (trackingAdapter.isSupportedTracker(track.syncId))
          track.syncId!: track,
    };
    final updatedAt = updatedAtFromLastModified(parentModifiedAt);
    for (final backup in remote) {
      final imported = trackingAdapter.fromBackup(
        backup,
        mangaId: mangaId,
        itemType: itemType,
        existing: existingByTracker[backup.syncId],
      );
      if (imported == null || imported.syncId == null) continue;
      imported.updatedAt = updatedAt;
      rowsByTracker[imported.syncId!] = imported;
    }
    return [
      for (final syncId in [
        ChimahonTrackingAdapter.myAnimeList,
        ChimahonTrackingAdapter.aniList,
        ChimahonTrackingAdapter.kitsu,
      ])
        ?rowsByTracker[syncId],
    ];
  }

  /// The favorite clock is a Chimahon epoch-seconds value, unlike most Mihon
  /// backup timestamps. Preserve it exactly so false favorites remain
  /// exportable tombstones after the manual restore.
  int? mangaFavoriteModifiedAt(BackupManga backup) =>
      backup.hasFavoriteModifiedAt() ? backup.favoriteModifiedAt.toInt() : null;

  int? animeFavoriteModifiedAt(BackupAnime backup) =>
      backup.hasFavoriteModifiedAt() ? backup.favoriteModifiedAt.toInt() : null;

  int updatedAtFromLastModified(int value) {
    if (value <= 0) return value;
    return value < 100000000000 ? value * 1000 : value;
  }
}
