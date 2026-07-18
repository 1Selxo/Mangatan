import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_backup_semantic_diff.dart';

void main() {
  test('identical payloads have no changed field paths', () {
    final remote = BackupMihon(
      backupManga: [
        BackupManga(
          url: '/private/title',
          title: 'Private title',
          chapters: [BackupChapter(url: '/private/chapter', read: true)],
        ),
      ],
    );

    final diff = ChimahonBackupSemanticDiff.compare(
      remote: remote,
      proposed: remote.deepCopy(),
    );

    expect(diff.equivalent, isTrue);
    expect(diff.fieldDifferences, isEmpty);
    expect(diff.toSafeJson(), {
      'equivalent': true,
      'changedFieldPathCount': 0,
      'changedFieldPaths': <String, Object>{},
    });
  });

  test('reports nested schema paths and aggregates without field values', () {
    const remoteTitle = 'Remote private title';
    const proposedTitle = 'Proposed private title';
    const privateUrl = '/private/chapter/url';
    final remote = BackupMihon(
      backupManga: [
        BackupManga(
          url: '/private/manga/url',
          title: remoteTitle,
          chapters: [
            BackupChapter(
              url: privateUrl,
              name: 'Private chapter name',
              version: Int64(1),
            ),
          ],
        ),
      ],
    );
    final proposed = remote.deepCopy()
      ..backupManga.single.title = proposedTitle
      ..backupManga.single.chapters.single.version = Int64(2);

    final diff = ChimahonBackupSemanticDiff.compare(
      remote: remote,
      proposed: proposed,
    );

    expect(diff.equivalent, isFalse);
    expect(
      diff.fieldDifferences.keys,
      containsAll([
        'BackupMihon.backupManga[]',
        'BackupMihon.backupManga[].title',
        'BackupMihon.backupManga[].chapters[]',
        'BackupMihon.backupManga[].chapters[].version',
      ]),
    );
    expect(
      diff.fieldDifferences,
      isNot(contains('BackupMihon.backupManga[].chapters[].url')),
    );
    final version =
        diff.fieldDifferences['BackupMihon.backupManga[].chapters[].version']!;
    expect(version.remoteOccurrences, 1);
    expect(version.proposedOccurrences, 1);
    expect(version.matchingOccurrences, 0);
    expect(version.remoteOnlyOccurrences, 1);
    expect(version.proposedOnlyOccurrences, 1);
    expect(version.orderOnly, isFalse);
    for (final hash in [
      version.remoteOrderedSha256,
      version.proposedOrderedSha256,
      version.remoteUnorderedSha256,
      version.proposedUnorderedSha256,
    ]) {
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    }

    final safeJson = jsonEncode(diff.toSafeJson());
    for (final privateValue in [
      remoteTitle,
      proposedTitle,
      privateUrl,
      '/private/manga/url',
      'Private chapter name',
    ]) {
      expect(safeJson, isNot(contains(privateValue)));
    }
  });

  test('separates order-only changes from changed occurrence multisets', () {
    final first = BackupManga(url: '/private/first', title: 'Private first');
    final second = BackupManga(url: '/private/second', title: 'Private second');
    final remote = BackupMihon(backupManga: [first, second]);
    final proposed = BackupMihon(
      backupManga: [second.deepCopy(), first.deepCopy()],
    );

    final diff = ChimahonBackupSemanticDiff.compare(
      remote: remote,
      proposed: proposed,
    );

    final manga = diff.fieldDifferences['BackupMihon.backupManga[]']!;
    expect(manga.orderOnly, isTrue);
    expect(manga.matchingOccurrences, 2);
    expect(manga.remoteOnlyOccurrences, 0);
    expect(manga.proposedOnlyOccurrences, 0);
    expect(manga.remoteOrderedSha256, isNot(manga.proposedOrderedSha256));
    expect(manga.remoteUnorderedSha256, manga.proposedUnorderedSha256);
    expect(
      diff.fieldDifferences['BackupMihon.backupManga[].title']?.orderOnly,
      isTrue,
    );
  });

  test('preserves absent-versus-explicit-default protobuf presence', () {
    final diff = ChimahonBackupSemanticDiff.compare(
      remote: BackupMihon(backupManga: [BackupManga(title: 'Private title')]),
      proposed: BackupMihon(
        backupManga: [BackupManga(title: 'Private title', favorite: false)],
      ),
    );

    final favorite =
        diff.fieldDifferences['BackupMihon.backupManga[].favorite']!;
    expect(favorite.remoteOccurrences, 0);
    expect(favorite.proposedOccurrences, 1);
    expect(favorite.remoteOnlyOccurrences, 0);
    expect(favorite.proposedOnlyOccurrences, 1);
    expect(jsonEncode(diff.toSafeJson()), isNot(contains('Private title')));
  });

  test('summarizes unknown fields by tag without retaining their values', () {
    const privateUnknownValue = 987654321;
    final remoteManga = BackupManga(title: 'Private title')
      ..unknownFields.mergeVarintField(600, Int64(privateUnknownValue));
    final proposedManga = BackupManga(title: 'Private title')
      ..unknownFields.mergeVarintField(600, Int64(privateUnknownValue + 1));

    final diff = ChimahonBackupSemanticDiff.compare(
      remote: BackupMihon(backupManga: [remoteManga]),
      proposed: BackupMihon(backupManga: [proposedManga]),
    );

    expect(
      diff.fieldDifferences,
      contains('BackupMihon.backupManga[].unknownFields[600]'),
    );
    final safeJson = jsonEncode(diff.toSafeJson());
    expect(safeJson, contains('unknownFields[600]'));
    expect(safeJson, isNot(contains('$privateUnknownValue')));
    expect(safeJson, isNot(contains('${privateUnknownValue + 1}')));
    expect(safeJson, isNot(contains('Private title')));
  });
}
