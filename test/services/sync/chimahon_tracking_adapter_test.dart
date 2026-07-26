import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';
import 'package:mangayomi/services/sync/chimahon_tracking_adapter.dart';

void main() {
  const adapter = ChimahonTrackingAdapter();

  test('uses Chimahon service-specific manga and anime status codes', () {
    const expected = {
      1: {
        TrackStatus.reading: 1,
        TrackStatus.completed: 2,
        TrackStatus.onHold: 3,
        TrackStatus.dropped: 4,
        TrackStatus.planToRead: 6,
        TrackStatus.reReading: 7,
      },
      2: {
        TrackStatus.reading: 1,
        TrackStatus.completed: 2,
        TrackStatus.onHold: 3,
        TrackStatus.dropped: 4,
        TrackStatus.planToRead: 5,
        TrackStatus.reReading: 6,
      },
      3: {
        TrackStatus.reading: 1,
        TrackStatus.completed: 2,
        TrackStatus.onHold: 3,
        TrackStatus.dropped: 4,
        TrackStatus.planToRead: 5,
        TrackStatus.reReading: 1,
      },
    };

    for (final tracker in expected.entries) {
      for (final status in tracker.value.entries) {
        expect(
          adapter.statusToWire(tracker.key, status.key, isManga: true),
          status.value,
        );
      }
    }

    expect(
      adapter.statusToWire(1, TrackStatus.planToWatch, isManga: false),
      16,
    );
    expect(adapter.statusToWire(1, TrackStatus.reWatching, isManga: false), 17);
    expect(
      adapter.statusToWire(2, TrackStatus.planToWatch, isManga: false),
      15,
    );
    expect(adapter.statusToWire(2, TrackStatus.reWatching, isManga: false), 16);
    expect(adapter.statusToWire(3, TrackStatus.reWatching, isManga: false), 11);
  });

  test('maps an AniList row from the reference Chimahon backup', () {
    final backup = BackupTracking(
      syncId: 2,
      libraryId: Int64(519251976),
      trackingUrl: 'https://anilist.co/manga/189080',
      title: 'Oneurui Hanyoireun Yeojada',
      lastChapterRead: 70,
      status: 1,
      startedReadingDate: Int64(1764543600000),
      mediaId: Int64(189080),
    );

    final local = adapter.fromBackup(
      backup,
      mangaId: 42,
      itemType: ItemType.manga,
    )!;

    expect(local.syncId, 2);
    expect(local.libraryId, 519251976);
    expect(local.mediaId, 189080);
    expect(local.mangaId, 42);
    expect(local.title, 'Oneurui Hanyoireun Yeojada');
    expect(local.lastChapterRead, 70);
    expect(local.status, TrackStatus.reading);
    expect(local.startedReadingDate, 1764543600000);

    final roundTrip = adapter.toBackup(local, itemType: ItemType.manga);
    expect(roundTrip.syncId, 2);
    expect(roundTrip.libraryId, Int64(519251976));
    expect(roundTrip.mediaId, Int64(189080));
    expect(roundTrip.status, 1);
    expect(roundTrip.hasPrivate(), isFalse);
    expect(roundTrip.hasMediaIdInt(), isFalse);
  });

  test('never exports Mangatan tracker IDs that conflict with Chimahon', () {
    Track track(int syncId) =>
        Track(mangaId: 1, syncId: syncId, status: TrackStatus.reading);

    final exported = adapter.exportAll([
      track(1),
      track(4),
      track(5),
    ], itemType: ItemType.manga);

    expect(exported.map((track) => track.syncId), [1]);
    expect(
      () => adapter.toBackup(track(4), itemType: ItemType.manga),
      throwsArgumentError,
    );
  });

  test('omits unavailable values but keeps explicit local zeroes', () {
    final incomplete = adapter.toBackup(
      Track(syncId: 2, status: TrackStatus.reading),
      itemType: ItemType.manga,
    );
    expect(incomplete.hasLibraryId(), isFalse);
    expect(incomplete.hasMediaId(), isFalse);
    expect(incomplete.hasTitle(), isFalse);
    expect(incomplete.hasScore(), isFalse);

    final explicitZero = adapter.toBackup(
      Track(
        syncId: 2,
        libraryId: 0,
        mediaId: 0,
        title: '',
        score: 0,
        status: TrackStatus.reading,
      ),
      itemType: ItemType.manga,
    );
    expect(explicitZero.hasLibraryId(), isTrue);
    expect(explicitZero.hasMediaId(), isTrue);
    expect(explicitZero.hasTitle(), isTrue);
    expect(explicitZero.hasScore(), isTrue);
  });

  test('does not materialize absent remote tracking fields as defaults', () {
    final sparse = BackupTracking(syncId: 2, status: 1);
    final imported = adapter.fromBackup(
      sparse,
      mangaId: 42,
      itemType: ItemType.manga,
    )!;

    expect(imported.libraryId, isNull);
    expect(imported.mediaId, isNull);
    expect(imported.trackingUrl, isNull);
    expect(imported.title, isNull);
    expect(imported.lastChapterRead, isNull);
    expect(imported.totalChapter, isNull);
    expect(imported.score, isNull);
    expect(imported.startedReadingDate, isNull);
    expect(imported.finishedReadingDate, isNull);

    final projected = adapter.toBackup(imported, itemType: ItemType.manga);
    expect(projected.hasLibraryId(), isFalse);
    expect(projected.hasMediaId(), isFalse);
    expect(projected.hasTrackingUrl(), isFalse);
    expect(projected.hasTitle(), isFalse);
    expect(projected.hasLastChapterRead(), isFalse);
    expect(projected.hasTotalChapters(), isFalse);
    expect(projected.hasScore(), isFalse);
    expect(projected.hasStartedReadingDate(), isFalse);
    expect(projected.hasFinishedReadingDate(), isFalse);
  });

  test('absent remote tracking fields preserve an existing local value', () {
    final existing = Track(
      libraryId: 10,
      mediaId: 20,
      mangaId: 42,
      syncId: 2,
      title: 'Existing',
      lastChapterRead: 3,
      totalChapter: 4,
      score: 5,
      status: TrackStatus.reading,
      startedReadingDate: 6,
      finishedReadingDate: 7,
      trackingUrl: 'existing-url',
    );
    final imported = adapter.fromBackup(
      BackupTracking(syncId: 2, status: 1),
      mangaId: 42,
      itemType: ItemType.manga,
      existing: existing,
    )!;

    expect(imported.libraryId, 10);
    expect(imported.mediaId, 20);
    expect(imported.title, 'Existing');
    expect(imported.lastChapterRead, 3);
    expect(imported.totalChapter, 4);
    expect(imported.score, 5);
    expect(imported.startedReadingDate, 6);
    expect(imported.finishedReadingDate, 7);
    expect(imported.trackingUrl, 'existing-url');
  });

  test('round-trips tracker deletion markers and reads legacy encoding', () {
    const marker = ChimahonTrackingDeletionMarker(
      mangaId: 42,
      syncId: ChimahonTrackingAdapter.aniList,
      modifiedAt: 123456,
    );
    final encoded = jsonEncode(marker.toJson());

    final decoded = ChimahonTrackingDeletionMarker.tryDecode(encoded)!;
    expect(decoded.mangaId, 42);
    expect(decoded.syncId, ChimahonTrackingAdapter.aniList);
    expect(decoded.modifiedAt, 123456);

    final legacy = ChimahonTrackingDeletionMarker.tryDecode(
      jsonEncode(encoded),
    )!;
    expect(legacy.mangaId, 42);
    expect(legacy.syncId, ChimahonTrackingAdapter.aniList);
    expect(legacy.modifiedAt, 123456);
    expect(ChimahonTrackingDeletionMarker.tryDecode('not json'), isNull);
  });
}
