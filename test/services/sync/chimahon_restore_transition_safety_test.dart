import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';
import 'package:mangayomi/services/sync/chimahon_pending_restore_authority.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';

const _authority = ChimahonPendingRestoreAuthority();
const _merger = ChimahonSyncMerger();

void main() {
  for (final tag in [500, 502, 503, 504, 505, 506, 507]) {
    test('legacy restore cannot silently erase retained season field $tag', () {
      final legacy = BackupAnime(
        source: Int64(7),
        url: '/season',
        title: 'Season',
      );
      final pending = BackupMihon(backupAnime: [legacy]);
      final remote = BackupMihon(
        backupAnime: [
          BackupAnime(
            source: Int64(7),
            url: '/series',
            title: 'Series',
            id: Int64(20),
            fetchType: 0,
          ),
          legacy.deepCopy()
            ..id = Int64(21)
            ..parentId = Int64(20)
            ..fetchType = 1
            ..backgroundUrl = '/background'
            ..seasonFlags = Int64(16)
            ..seasonNumber = 2
            ..seasonSourceOrder = Int64(3),
        ],
      );
      final fixture = _Restore(pending, remote);
      fixture.uploaded.backupAnime.last.clearField(tag);
      expect(fixture.failure, isNotNull);
    });
  }

  test(
    'category handle collisions are rejected before comparison rebasing',
    () {
      final pending = BackupMihon(
        backupCategories: [BackupCategory(name: 'Selected', order: Int64(1))],
        backupManga: [
          BackupManga(
            source: Int64(7),
            url: '/book',
            title: 'Book',
            categories: [Int64(1)],
          ),
        ],
      );
      final remote = BackupMihon(
        backupCategories: [BackupCategory(name: 'Cloud', order: Int64(2))],
      );
      final fixture = _Restore(pending, remote);
      fixture.uploaded.backupCategories.last.order =
          fixture.uploaded.backupCategories.first.order;
      fixture.uploaded.backupManga.single.categories
        ..clear()
        ..add(fixture.uploaded.backupCategories.first.order);
      expect(fixture.failure, isNotNull);
    },
  );

  test('selected novel categories retain remote unknown data', () {
    final pending = BackupMihon(
      backupNovelCategories: [
        BackupNovelCategory(id: 'category', name: 'Reading'),
      ],
    );
    final remote = pending.deepCopy();
    remote.backupNovelCategories.single.unknownFields.mergeVarintField(
      9999,
      Int64(42),
    );
    final fixture = _Restore(pending, remote);
    fixture.uploaded.backupNovelCategories.single.unknownFields.clear();
    expect(fixture.failure, isNotNull);
  });

  test('invented or duplicated novel categories do not pass restore proof', () {
    for (final duplicate in [false, true]) {
      final fixture = _Restore(
        BackupMihon(
          backupNovelCategories: [
            BackupNovelCategory(id: 'selected', name: 'Selected'),
          ],
        ),
        BackupMihon(
          backupNovelCategories: [
            BackupNovelCategory(id: 'cloud', name: 'Cloud'),
          ],
        ),
      );
      fixture.uploaded.backupNovelCategories.add(
        duplicate
            ? fixture.uploaded.backupNovelCategories.last.deepCopy()
            : BackupNovelCategory(id: 'invented', name: 'Invented'),
      );
      expect(fixture.failure, isNotNull);
    }
  });

  for (final tamper in <String, void Function(BackupMihon)>{
    'invented manga statistics': (backup) =>
        backup.backupMangaStats.add(BackupMangaStats(dateKey: 'invented')),
    'duplicate manga statistics': (backup) =>
        backup.backupMangaStats.add(backup.backupMangaStats.first.deepCopy()),
    'inflated manga characters': (backup) =>
        backup.backupMangaStats.first.charactersRead = 999,
    'inflated manga time': (backup) =>
        backup.backupMangaStats.first.readingTime = Int64(999),
    'invented Anki statistics': (backup) =>
        backup.backupAnkiStats.add(BackupAnkiStats(dateKey: 'invented')),
    'inflated Anki manga cards': (backup) =>
        backup.backupAnkiStats.first.mangaCards = 999,
    'inflated Anki novel cards': (backup) =>
        backup.backupAnkiStats.first.novelCards = 999,
  }.entries) {
    test('restore proof rejects ${tamper.key}', () {
      final pending = BackupMihon(
        backupMangaStats: [
          BackupMangaStats(
            dateKey: '2026-09-01',
            charactersRead: 10,
            readingTime: Int64(20),
          ),
        ],
        backupAnkiStats: [
          BackupAnkiStats(dateKey: '2026-09-01', mangaCards: 3, novelCards: 4),
        ],
      );
      final fixture = _Restore(pending, pending.deepCopy());
      tamper.value(fixture.uploaded);
      expect(fixture.failure, isNotNull);
    });
  }
}

class _Restore {
  _Restore(this.pending, this.remote) {
    ordinary = _merger.merge(local: pending, remote: remote);
    uploaded = _authority.apply(
      pending: pending,
      localIntent: pending,
      remote: remote,
      merged: ordinary,
    );
    expect(
      failure,
      isNull,
      reason: 'The unmodified restore must pass both proofs.',
    );
  }
  final BackupMihon pending;
  final BackupMihon remote;
  late final BackupMihon ordinary;
  late final BackupMihon uploaded;

  String? get failure =>
      _authority.selectedIntentFailure(
        uploaded: uploaded,
        pending: pending,
        localIntent: pending,
      ) ??
      _authority.transitionFailure(
        uploaded: uploaded,
        pending: pending,
        localIntent: pending,
        ordinaryMerged: ordinary,
        remote: remote,
      );
}
