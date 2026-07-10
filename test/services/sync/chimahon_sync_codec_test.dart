import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';

void main() {
  const codec = ChimahonSyncCodec();

  test('round-trips Chimahon novel data as raw SyncYomi protobuf', () {
    final backup = BackupMihon(
      backupNovels: [
        BackupNovel(
          id: 'novel-id',
          title: 'Novel',
          chapterIndex: 4,
          progress: 0.75,
          characterCount: 1200,
          lastModified: Int64(1700000000000),
          stats: [
            BackupNovelStat(
              dateKey: '2026-07-10',
              charactersRead: 500,
              readingTime: 12.5,
              lastStatisticModified: Int64(1700000000001),
            ),
          ],
          categoryIds: ['reading'],
          lang: 'ja',
        ),
      ],
    );

    final encoded = codec.encode(backup);
    final decoded = codec.decode(encoded);

    expect(decoded.format, ChimahonSyncWireFormat.protobuf);
    expect(decoded.backup.backupNovels.single.title, 'Novel');
    expect(decoded.backup.backupNovels.single.progress, 0.75);
    expect(decoded.backup.backupNovels.single.stats.single.charactersRead, 500);
  });

  test('round-trips the Google Drive and tachibk gzip representation', () {
    final encoded = codec.encode(
      BackupMihon(
        backupNovelCategories: [
          BackupNovelCategory(id: 'reading', name: 'Reading'),
        ],
      ),
      format: ChimahonSyncWireFormat.gzipProtobuf,
    );

    expect(encoded.take(2), [0x1f, 0x8b]);
    final decoded = codec.decode(encoded);
    expect(decoded.format, ChimahonSyncWireFormat.gzipProtobuf);
    expect(decoded.backup.backupNovelCategories.single.id, 'reading');
  });

  test('decodes Chimahon novel and statistics extension fixture', () {
    const fixture =
        '4itkCghub3ZlbC1pZBIFTm92ZWwaBkF1dGhvcigEMQAAAAAAAOg/OLAJQIDQlf+8MUonCgoyMDI2LTA3LTEwEPQDGQAAAAAAAClAIAEoAjADOARAgdCV/7wxUgdyZWFkaW5nWgJqYeorFgoHcmVhZGluZxIHUmVhZGluZxgCIAOyLBQKCjIwMjYtMDctMTAQ2AQYvAUgCLosIwoKMjAyNi0wNy0xMBAJGAoiB3Byb2ZpbGUqCG5vdmVsLWlk';
    final backup = codec.decode(base64Decode(fixture)).backup;

    expect(backup.backupNovels.single.title, 'Novel');
    expect(backup.backupNovels.single.progress, 0.75);
    expect(backup.backupNovelCategories.single.flags, Int64(3));
    expect(backup.backupMangaStats.single.charactersRead, 600);
    expect(backup.backupAnkiStats.single.titleId, 'novel-id');
  });

  test('rejects empty payloads without affecting callers', () {
    expect(
      () => codec.decode(const []),
      throwsA(isA<ChimahonSyncFormatException>()),
    );
  });
}
