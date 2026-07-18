import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_backup_fingerprint.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';

void main() {
  const codec = ChimahonSyncCodec();

  test('distinguishes container identity from protobuf identity', () {
    final backup = BackupMihon(
      backupNovels: [
        BackupNovel(
          title: List.filled(100, 'Repeated title').join(),
          stats: [BackupNovelStat(dateKey: '2026-07-17')],
        ),
      ],
    );
    final lightlyCompressed = ChimahonBackupFingerprint.fromBytes(
      codec.encode(
        backup,
        format: ChimahonSyncWireFormat.gzipProtobuf,
        compressionLevel: 1,
      ),
    );
    final heavilyCompressed = ChimahonBackupFingerprint.fromBytes(
      codec.encode(
        backup,
        format: ChimahonSyncWireFormat.gzipProtobuf,
        compressionLevel: 9,
      ),
    );

    final comparison = lightlyCompressed.compareTo(heavilyCompressed);
    expect(comparison.rawBytesMatch, isFalse);
    expect(comparison.protobufBytesMatch, isTrue);
    expect(comparison.countDifferences, isEmpty);
    expect(lightlyCompressed.counts['novels'], 1);
    expect(lightlyCompressed.counts['novelStatistics'], 1);
  });

  test('reports only structural count differences', () {
    final actual = ChimahonBackupFingerprint.fromBytes(
      codec.encode(BackupMihon(backupNovels: [BackupNovel(title: 'Novel')])),
    );
    final reference = ChimahonBackupFingerprint.fromBytes(
      codec.encode(
        BackupMihon(
          backupNovels: [
            BackupNovel(title: 'Novel'),
            BackupNovel(title: 'Another novel'),
          ],
        ),
      ),
    );

    final comparison = actual.compareTo(reference);

    expect(comparison.rawBytesMatch, isFalse);
    expect(comparison.protobufBytesMatch, isFalse);
    expect(comparison.countDifferences.keys, ['novels']);
    expect(comparison.countDifferences['novels']?.actual, 1);
    expect(comparison.countDifferences['novels']?.reference, 2);
  });

  test('does not conflate an absent favorite field with either bool value', () {
    final fingerprint = ChimahonBackupFingerprint.fromBytes(
      codec.encode(
        BackupMihon(
          backupManga: [
            BackupManga(title: 'Absent'),
            BackupManga(title: 'Favorite', favorite: true),
            BackupManga(title: 'Tombstone', favorite: false),
          ],
        ),
      ),
    );

    expect(fingerprint.counts['mangaFavoriteFieldAbsent'], 1);
    expect(fingerprint.counts['mangaFavoriteTrue'], 1);
    expect(fingerprint.counts['mangaTombstones'], 1);
  });
}
