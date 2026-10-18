import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_local_intent_safety_audit.dart';
import 'package:mangayomi/services/sync/chimahon_novel_stat_safety.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/utils/chimahon_novel_identity.dart';

BackupNovelStat _stat({
  int chars = 100,
  double time = 10,
  int min = 80,
  int altMin = 90,
  int last = 100,
  int max = 120,
  int clock = 0,
}) => BackupNovelStat(
  dateKey: '2026-10-17',
  charactersRead: chars,
  readingTime: time,
  minReadingSpeed: min,
  altMinReadingSpeed: altMin,
  lastReadingSpeed: last,
  maxReadingSpeed: max,
  lastStatisticModified: Int64(clock),
);

BackupNovel _novel(BackupNovelStat stat) => BackupNovel(
  id: ChimahonNovelIdentity.stableIdOrNull(title: 'Novel', author: 'Author'),
  title: 'Novel',
  author: 'Author',
  lastModified: Int64(20),
  stats: [stat],
);

void main() {
  test('an unclocked day that absorbed more reading is not a regression', () {
    final local = _stat();
    final merged = _stat(chars: 250, time: 30, min: 60, last: 140, max: 150);
    expect(chimahonNovelStatRegressed(local, merged), isFalse);
  });

  test('an unclocked day that lost reading is a regression', () {
    final local = _stat();
    expect(chimahonNovelStatRegressed(local, _stat(chars: 99)), isTrue);
    expect(chimahonNovelStatRegressed(local, _stat(time: 9)), isTrue);
    expect(chimahonNovelStatRegressed(local, _stat(max: 119)), isTrue);
    expect(chimahonNovelStatRegressed(local, _stat(min: 81)), isTrue);
    expect(chimahonNovelStatRegressed(local, _stat(altMin: 0)), isTrue);
  });

  test('an unset minimum speed may be filled by the other device', () {
    expect(chimahonNovelStatRegressed(_stat(min: 0), _stat(min: 70)), isFalse);
  });

  test('clocks still decide when they differ', () {
    expect(
      chimahonNovelStatRegressed(_stat(clock: 5), _stat(chars: 1, clock: 6)),
      isFalse,
    );
    expect(
      chimahonNovelStatRegressed(_stat(clock: 5), _stat(chars: 999, clock: 4)),
      isTrue,
    );
  });

  test('a merge of two devices reading the same day passes the audit', () {
    // Chimahon's database-backed stats carry clock 0 on both sides.
    final local = BackupMihon(backupNovels: [_novel(_stat())]);
    final remote = BackupMihon(
      backupNovels: [
        _novel(_stat(chars: 300, time: 40, min: 50, last: 90, max: 200)),
      ],
    );
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
      remoteWinsProjectionTies: true,
    );
    final failures = <String>{};
    const ChimahonLocalIntentSafetyAudit().audit(
      local: local,
      remote: remote,
      proposed: proposed,
      remoteWinsTies: true,
      fail: (code, affected) {
        if (affected.isNotEmpty) failures.add(code);
      },
      observe: (_, _) {},
    );

    expect(proposed.backupNovels.single.stats.single.charactersRead, 300);
    expect(failures, isNot(contains('local_novel_stat_regressed_in_proposed')));
  });
}
