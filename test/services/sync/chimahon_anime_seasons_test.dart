import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_anime_seasons.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/services/sync/chimahon_media_safety_audit.dart';

BackupAnime anime(String url, int id, {int? parent, int fetchType = 0}) =>
    BackupAnime(
      source: Int64(7),
      url: url,
      title: url,
      id: Int64(id),
      parentId: parent == null ? null : Int64(parent),
      fetchType: fetchType,
      favorite: parent == null,
      seasonNumber: parent == null ? -1 : 1,
    );

void main() {
  test('old backups without IDs cannot link unrelated anime', () {
    final first = BackupAnime(source: Int64(7), url: '/first');
    final second = BackupAnime(
      source: Int64(7),
      url: '/second',
      parentId: Int64.ZERO,
    );
    expect(chimahonSeasonParents([first, second]), isEmpty);
  });

  test('all edges entering a cycle are rejected, regardless of order', () {
    final first = anime('/first', 1, parent: 2);
    final second = anime('/second', 2, parent: 1);
    final descendant = anime('/child', 3, parent: 1, fetchType: 1);
    expect(chimahonSeasonParents([first, second, descendant]), isEmpty);
    expect(chimahonSeasonParents([descendant, second, first]), isEmpty);
  });

  test('duplicate IDs and cross-source parents are rejected', () {
    final parent = anime('/series', 1);
    final child = anime('/season', 2, parent: 1, fetchType: 1);
    expect(chimahonSeasonParents([parent, child])[child], parent);
    expect(chimahonSeasonParents([parent, anime('/other', 1), child]), isEmpty);
    child.source = Int64(8);
    expect(chimahonSeasonParents([parent, child]), isEmpty);
  });

  test('independent device IDs do not attach seasons to another series', () {
    final remote = BackupMihon(
      backupAnime: [anime('/other', 1), anime('/series', 20)],
    );
    final local = BackupMihon(
      backupAnime: [
        anime('/series', 1),
        anime('/season', 2, parent: 1, fetchType: 1),
      ],
    );
    final result = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );
    final parent = result.backupAnime.singleWhere((a) => a.url == '/series');
    final child = result.backupAnime.singleWhere((a) => a.url == '/season');
    expect(parent.id, Int64(20));
    expect(child.parentId, parent.id);
    expect(result.backupAnime.map((a) => a.id).toSet().length, 3);
    final failures = <String>[];
    const ChimahonMediaSafetyAudit().audit(
      local: local,
      remote: remote,
      proposed: result,
      fail: (name, rows) {
        if (rows.isNotEmpty) failures.add(name);
      },
      observe: (_, _) {},
    );
    expect(failures, isEmpty);
  });

  test(
    'an older client cannot clear local season structure or remote flags',
    () {
      final parent = anime('/series', 1)..lastModifiedAt = Int64(10);
      final old = BackupAnime(
        source: Int64(7),
        url: '/series',
        title: '/series',
        favorite: true,
        lastModifiedAt: Int64(20),
        seasonFlags: Int64(16),
      );
      final result = const ChimahonSyncMerger().merge(
        local: BackupMihon(backupAnime: [parent]),
        remote: BackupMihon(backupAnime: [old]),
      );
      expect(result.backupAnime.single.hasFetchType(), true);
      expect(result.backupAnime.single.fetchType, 0);
      expect(result.backupAnime.single.seasonFlags, Int64(16));
    },
  );

  test('season-only edits are not mistaken for clock-only refreshes', () {
    final remote = anime('/series', 90)..lastModifiedAt = Int64(10);
    final local = anime('/series', 1)
      ..lastModifiedAt = Int64(20)
      ..seasonFlags = Int64(32);
    final result = const ChimahonSyncMerger().merge(
      local: BackupMihon(backupAnime: [local]),
      remote: BackupMihon(backupAnime: [remote]),
      remoteWinsProjectionTies: true,
    );
    expect(result.backupAnime.single.seasonFlags, Int64(32));
  });

  test('new season metadata survives a local metadata edit', () {
    final remote = BackupMihon(backupAnime: [anime('/series', 90)]);
    final localAnime = anime('/series', 1)
      ..seasonFlags = Int64(12)
      ..lastModifiedAt = Int64(5);
    final result = const ChimahonSyncMerger().merge(
      local: BackupMihon(backupAnime: [localAnime]),
      remote: remote,
    );
    expect(result.backupAnime.single.seasonFlags, Int64(12));
    expect(result.backupAnime.single.id, Int64(90));
  });

  test('an older remote parent gains the ID needed by a new local season', () {
    final parent = anime('/series', 1);
    final remoteParent = parent.deepCopy()..clearId();
    final local = BackupMihon(
      backupAnime: [parent, anime('/season', 2, parent: 1, fetchType: 1)],
    );
    final remote = BackupMihon(backupAnime: [anime('/other', 1), remoteParent]);
    final merged = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );
    final parents = chimahonSeasonParents(merged.backupAnime);
    final child = merged.backupAnime.singleWhere((row) => row.url == '/season');
    expect(parents[child]?.url, '/series');
    final failures = <String>[];
    const ChimahonMediaSafetyAudit().audit(
      local: local,
      remote: remote,
      proposed: merged,
      fail: (code, rows) {
        if (rows.isNotEmpty) failures.add(code);
      },
      observe: (_, _) {},
    );
    expect(failures, isEmpty);
  });

  test(
    'opaque orphan and duplicate remote handles never attach to new local rows',
    () {
      for (final duplicates in [false, true]) {
        final remote = BackupMihon(
          backupAnime: [
            if (duplicates) ...[anime('/first', 1), anime('/second', 1)],
            anime('/orphan', 2, parent: 1, fetchType: 1),
          ],
        );
        final local = BackupMihon(backupAnime: [anime('/local', 1)]);
        final merged = const ChimahonSyncMerger().merge(
          local: local,
          remote: remote,
        );
        expect(
          merged.backupAnime.map((row) => row.id).toSet(),
          hasLength(merged.backupAnime.length),
        );
        final orphan = merged.backupAnime.singleWhere(
          (row) => row.url == '/orphan',
        );
        expect(orphan.parentId, Int64.ONE);
        expect(chimahonSeasonParents(merged.backupAnime)[orphan], isNull);
        expect(
          merged.backupAnime.singleWhere((row) => row.url == '/local').id,
          isNot(Int64.ONE),
        );
      }
    },
  );

  test(
    'explicit detach and default resets survive in either merge direction',
    () {
      final parent = anime('/series', 1);
      final attached = anime('/season', 2, parent: 1, fetchType: 1)
        ..version = Int64(1)
        ..seasonFlags = Int64(32);
      final detached = attached.deepCopy()
        ..clearParentId()
        ..clearSeasonFlags()
        ..clearFetchType()
        ..version = Int64(2);
      for (final localWins in [false, true]) {
        final result = const ChimahonSyncMerger()
            .merge(
              local: BackupMihon(
                backupAnime: [parent, localWins ? detached : attached],
              ),
              remote: BackupMihon(
                backupAnime: [parent, localWins ? attached : detached],
              ),
            )
            .backupAnime
            .last;
        expect(result.hasParentId(), isFalse);
        expect(result.seasonFlags, Int64.ZERO);
        expect(chimahonAnimeFetchType(result), 1);
      }
    },
  );

  test('independent device ID permutations converge without changing parent meaning', () {
    const merger = ChimahonSyncMerger();
    for (var offset = 1; offset <= 12; offset++) {
      final local = BackupMihon(
        backupAnime: [
          for (var index = 0; index < 4; index++) ...[
            anime('/series-$index', 2 * index + 1),
            anime(
              '/season-$index',
              2 * index + 2,
              parent: 2 * index + 1,
              fetchType: 1,
            ),
          ],
        ],
      );
      final remote = BackupMihon(
        backupAnime: [
          for (var index = 3; index >= 0; index--) ...[
            anime('/series-$index', offset + 2 * index),
            anime(
              '/season-$index',
              offset + 2 * index + 1,
              parent: offset + 2 * index,
              fetchType: 1,
            ),
          ],
        ],
      );
      final merged = merger.merge(
        local: local,
        remote: remote,
        remoteWinsProjectionTies: true,
      );
      final parents = chimahonSeasonParents(merged.backupAnime);
      expect(parents, hasLength(4));
      for (var index = 0; index < 4; index++) {
        final child = merged.backupAnime.singleWhere(
          (row) => row.url == '/season-$index',
        );
        expect(parents[child]!.url, '/series-$index');
      }
      expect(
        merger
            .merge(local: local, remote: merged, remoteWinsProjectionTies: true)
            .writeToBuffer(),
        merged.writeToBuffer(),
      );
    }
  });
}
