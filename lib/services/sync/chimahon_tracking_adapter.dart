import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';

class ChimahonTrackingDeletion {
  const ChimahonTrackingDeletion({
    required this.mangaId,
    required this.syncId,
    required this.modifiedAt,
  });

  final int mangaId;
  final int syncId;
  final int modifiedAt;
}

/// JSON payload kept in [ChangedPart] while a portable tracker deletion is
/// waiting to be included in the next Chimahon sync.
class ChimahonTrackingDeletionMarker {
  const ChimahonTrackingDeletionMarker({
    required this.mangaId,
    required this.syncId,
    required this.modifiedAt,
  });

  final int? mangaId;
  final int? syncId;
  final int modifiedAt;

  Map<String, Object?> toJson() => {
    'mangaId': mangaId,
    'syncId': syncId,
    'modifiedAt': modifiedAt,
  };

  /// Also accepts the briefly shipped double-encoded form so queued deletion
  /// markers created by a development build are not stranded forever.
  static ChimahonTrackingDeletionMarker? tryDecode(String payload) {
    Object? decoded;
    try {
      decoded = jsonDecode(payload);
      if (decoded is String) decoded = jsonDecode(decoded);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final mangaId = decoded['mangaId'];
    final syncId = decoded['syncId'];
    final modifiedAt = decoded['modifiedAt'];
    if (mangaId is! int || syncId is! int || modifiedAt is! int) return null;
    return ChimahonTrackingDeletionMarker(
      mangaId: mangaId,
      syncId: syncId,
      modifiedAt: modifiedAt,
    );
  }
}

/// Converts tracker rows between Mangatan and Chimahon's Mihon backup wire
/// format.
///
/// Only the tracker IDs shared by both applications are portable. Mangatan's
/// IDs 4 and 5 mean Simkl and Trakt, while Chimahon uses those IDs for
/// Shikimori and Bangumi, so sending either would silently attach progress to
/// the wrong service.
class ChimahonTrackingAdapter {
  const ChimahonTrackingAdapter();

  static const myAnimeList = 1;
  static const aniList = 2;
  static const kitsu = 3;

  bool isSupportedTracker(int? syncId) =>
      syncId == myAnimeList || syncId == aniList || syncId == kitsu;

  /// Exports at most one row for each portable tracker service.
  List<BackupTracking> exportAll(
    Iterable<Track> tracks, {
    required ItemType itemType,
  }) {
    final lastByTracker = <int, Track>{};
    for (final track in tracks) {
      final syncId = track.syncId;
      if (isSupportedTracker(syncId)) lastByTracker[syncId!] = track;
    }
    return [
      for (final syncId in [myAnimeList, aniList, kitsu])
        if (lastByTracker[syncId] case final track?)
          toBackup(track, itemType: itemType),
    ];
  }

  BackupTracking toBackup(Track track, {required ItemType itemType}) {
    final syncId = track.syncId;
    if (!isSupportedTracker(syncId)) {
      throw ArgumentError.value(
        syncId,
        'track.syncId',
        'Tracker is not portable to Chimahon',
      );
    }
    final isManga = itemType == ItemType.manga;
    final backup = BackupTracking(
      syncId: syncId,
      // mediaIdInt is deliberately omitted. It is a deprecated legacy copy of
      // mediaId and the merger retains an existing remote value as fallback.
      status: statusToWire(syncId!, track.status, isManga: isManga),
      // Mangatan has no private-tracking field. Leaving it absent lets the
      // Chimahon merger carry a remote value forward instead of forcing false.
    );
    // A null local value means Mangatan has no projection for that field, not
    // that the user cleared it. Leave it absent so the merger can retain a
    // complete Chimahon record. Non-null zero/empty values remain explicit.
    if (track.libraryId case final value?) backup.libraryId = Int64(value);
    if (track.mediaId case final value?) backup.mediaId = Int64(value);
    if (track.trackingUrl case final value?) backup.trackingUrl = value;
    if (track.title case final value?) backup.title = value;
    if (track.lastChapterRead case final value?) {
      backup.lastChapterRead = value.toDouble();
    }
    if (track.totalChapter case final value?) backup.totalChapters = value;
    if (track.score case final value?) backup.score = value.toDouble();
    if (track.startedReadingDate case final value?) {
      backup.startedReadingDate = Int64(value);
    }
    if (track.finishedReadingDate case final value?) {
      backup.finishedReadingDate = Int64(value);
    }
    return backup;
  }

  /// Builds a detached local row. The caller decides whether to persist it.
  /// Unsupported tracker IDs and unknown service status codes are ignored.
  Track? fromBackup(
    BackupTracking backup, {
    required int mangaId,
    required ItemType itemType,
    Track? existing,
  }) {
    if (!isSupportedTracker(backup.syncId)) return null;
    final isManga = itemType == ItemType.manga;
    final status = statusFromWire(
      backup.syncId,
      backup.status,
      isManga: isManga,
    );
    if (status == null) return null;

    final imported = Track(
      libraryId: backup.hasLibraryId()
          ? backup.libraryId.toInt()
          : existing?.libraryId,
      mediaId: backup.hasMediaIdInt() && backup.mediaIdInt != 0
          ? backup.mediaIdInt
          : backup.hasMediaId()
          ? backup.mediaId.toInt()
          : backup.hasMediaIdInt()
          ? backup.mediaIdInt
          : existing?.mediaId,
      mangaId: mangaId,
      syncId: backup.syncId,
      title: backup.hasTitle() ? backup.title : existing?.title,
      lastChapterRead: backup.hasLastChapterRead()
          ? backup.lastChapterRead.toInt()
          : existing?.lastChapterRead,
      totalChapter: backup.hasTotalChapters()
          ? backup.totalChapters
          : existing?.totalChapter,
      score: backup.hasScore() ? backup.score.toInt() : existing?.score,
      status: status,
      startedReadingDate: backup.hasStartedReadingDate()
          ? backup.startedReadingDate.toInt()
          : existing?.startedReadingDate,
      finishedReadingDate: backup.hasFinishedReadingDate()
          ? backup.finishedReadingDate.toInt()
          : existing?.finishedReadingDate,
      trackingUrl: backup.hasTrackingUrl()
          ? backup.trackingUrl
          : existing?.trackingUrl,
      isManga: isManga,
      itemType: itemType,
      updatedAt: existing?.updatedAt ?? 0,
    );
    if (existing != null) imported.id = existing.id;
    return imported;
  }

  int statusToWire(int syncId, TrackStatus status, {required bool isManga}) {
    if (!isSupportedTracker(syncId)) {
      throw ArgumentError.value(syncId, 'syncId', 'Unsupported tracker');
    }
    return switch (status) {
      TrackStatus.completed => 2,
      TrackStatus.onHold => 3,
      TrackStatus.dropped => 4,
      TrackStatus.planToRead || TrackStatus.planToWatch => switch (syncId) {
        myAnimeList => isManga ? 6 : 16,
        aniList || kitsu => isManga ? 5 : 15,
        _ => throw StateError('unreachable'),
      },
      TrackStatus.reReading || TrackStatus.reWatching => switch (syncId) {
        myAnimeList => isManga ? 7 : 17,
        aniList => isManga ? 6 : 16,
        // Kitsu has no repeating state; Chimahon itself falls back to the
        // service's active state when progress changes.
        kitsu => isManga ? 1 : 11,
        _ => throw StateError('unreachable'),
      },
      TrackStatus.reading || TrackStatus.watching => isManga ? 1 : 11,
    };
  }

  TrackStatus? statusFromWire(int syncId, int status, {required bool isManga}) {
    if (!isSupportedTracker(syncId)) return null;
    if (status == 2) return TrackStatus.completed;
    if (status == 3) return TrackStatus.onHold;
    if (status == 4) return TrackStatus.dropped;

    if (isManga) {
      if (status == 1) return TrackStatus.reading;
      if (status == (syncId == myAnimeList ? 6 : 5)) {
        return TrackStatus.planToRead;
      }
      if (syncId == myAnimeList && status == 7) {
        return TrackStatus.reReading;
      }
      if (syncId == aniList && status == 6) return TrackStatus.reReading;
    } else {
      if (status == 11) return TrackStatus.watching;
      if (status == (syncId == myAnimeList ? 16 : 15)) {
        return TrackStatus.planToWatch;
      }
      if (syncId == myAnimeList && status == 17) {
        return TrackStatus.reWatching;
      }
      if (syncId == aniList && status == 16) return TrackStatus.reWatching;
    }
    return null;
  }
}
