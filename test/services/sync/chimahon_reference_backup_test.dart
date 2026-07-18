import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_backup_fingerprint.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:protobuf/protobuf.dart';

// Run this opt-in fixture with:
// CHIMAHON_REFERENCE_BACKUP=/path/to/backup.tachibk flutter test \
//   test/services/sync/chimahon_reference_backup_test.dart
void main() {
  const codec = ChimahonSyncCodec();
  final referencePath = Platform.environment['CHIMAHON_REFERENCE_BACKUP'];

  test(
    'losslessly decodes and semantically re-encodes a real Chimahon backup',
    () {
      final bytes = File(referencePath!).readAsBytesSync();
      final decoded = codec.decode(bytes);
      final backup = decoded.backup;

      expect(
        sha256.convert(bytes).toString(),
        '91da18b182bb99adfd10c7448a3be40f0dc2a89074fea18054e653b7632cc1ca',
      );
      expect(decoded.format, ChimahonSyncWireFormat.gzipProtobuf);
      final fingerprint = ChimahonBackupFingerprint.fromBytes(bytes);
      expect(
        fingerprint.rawSha256,
        '91da18b182bb99adfd10c7448a3be40f0dc2a89074fea18054e653b7632cc1ca',
      );
      expect(fingerprint.counts, containsPair('mangaRecords', 170));
      expect(fingerprint.counts, containsPair('mangaFavoriteFieldAbsent', 38));
      expect(fingerprint.counts, containsPair('mangaFavoriteTrue', 0));
      expect(fingerprint.counts, containsPair('mangaTombstones', 132));
      expect(fingerprint.counts, containsPair('animeRecords', 5));
      expect(fingerprint.counts, containsPair('novels', 3));
      expect(fingerprint.counts, containsPair('novelStatistics', 26));
      expect(fingerprint.counts, containsPair('novelCategories', 1));
      expect(backup.backupManga, hasLength(170));
      expect(backup.backupCategories, hasLength(3));
      expect(backup.backupSources, hasLength(45));
      expect(backup.backupPreferences, hasLength(182));
      expect(backup.backupSourcePreferences, hasLength(4));
      expect(backup.backupExtensionRepo, hasLength(1));
      expect(backup.backupAnime, hasLength(5));
      expect(backup.backupAnimeCategories, hasLength(2));
      expect(backup.backupAnimeSources, hasLength(3));
      expect(backup.backupAnimeExtensionRepo, hasLength(1));
      expect(backup.backupFeeds, hasLength(2));
      expect(backup.backupNovels, hasLength(3));
      expect(backup.backupNovelCategories, hasLength(1));
      expect(backup.backupMangaStats, hasLength(101));
      expect(backup.backupAnkiStats, hasLength(5));
      expect(
        backup.backupManga.where(
          (manga) => manga.hasFavorite() && !manga.favorite,
        ),
        hasLength(132),
      );
      expect(
        backup.backupManga.where((manga) => !manga.hasFavorite()),
        hasLength(38),
        reason: 'Legacy absence must not be conflated with a false tombstone.',
      );
      expect(
        backup.backupManga.where(
          (manga) => manga.hasFavorite() && manga.favorite,
        ),
        isEmpty,
      );

      final customizedTitles = backup.backupManga
          .where((manga) => manga.hasCustomTitle())
          .toList();
      expect(customizedTitles, hasLength(1));
      expect(
        customizedTitles.single.customTitle,
        isNot(customizedTitles.single.title),
      );
      final tracking = [
        ...backup.backupManga.expand((manga) => manga.tracking),
        ...backup.backupAnime.expand((anime) => anime.tracking),
      ];
      expect(tracking, hasLength(45));
      expect(tracking.map((row) => row.syncId).toSet(), {2});

      final titleDateAddedValues = [
        ...backup.backupManga.map((row) => row.dateAdded.toInt()),
        ...backup.backupAnime.map((row) => row.dateAdded.toInt()),
      ];
      expect(
        titleDateAddedValues.where((value) => value > 0),
        everyElement(greaterThanOrEqualTo(100000000000)),
      );
      final titleModifiedValues = [
        ...backup.backupManga.map((row) => row.lastModifiedAt.toInt()),
        ...backup.backupAnime.map((row) => row.lastModifiedAt.toInt()),
      ];
      expect(
        titleModifiedValues.where((value) => value > 0),
        everyElement(lessThan(100000000000)),
      );
      final childDateUploadValues = [
        ...backup.backupManga.expand(
          (manga) => manga.chapters.map((row) => row.dateUpload.toInt()),
        ),
        ...backup.backupAnime.expand(
          (anime) => anime.episodes.map((row) => row.dateUpload.toInt()),
        ),
      ];
      expect(
        childDateUploadValues.where((value) => value > 0),
        everyElement(greaterThanOrEqualTo(100000000000)),
      );
      final childModifiedValues = [
        ...backup.backupManga.expand(
          (manga) => manga.chapters.map((row) => row.lastModifiedAt.toInt()),
        ),
        ...backup.backupAnime.expand(
          (anime) => anime.episodes.map((row) => row.lastModifiedAt.toInt()),
        ),
      ];
      expect(
        childModifiedValues.where((value) => value > 0),
        everyElement(lessThan(100000000000)),
      );
      expect(
        backup.backupNovels.map((novel) => novel.lastModified.toInt()),
        everyElement(greaterThanOrEqualTo(100000000000)),
      );

      const preferenceCodec = ChimahonPreferenceCodec();
      final decodedPreferences = [
        ...backup.backupPreferences.map(preferenceCodec.decode),
        ...backup.backupSourcePreferences.expand(
          (group) => group.prefs.map(preferenceCodec.decode),
        ),
      ];
      expect(
        decodedPreferences,
        everyElement(
          isA<DecodedChimahonPreference>().having(
            (preference) => preference.kind,
            'known preference kind',
            isNot(ChimahonPreferenceKind.unknown),
          ),
        ),
      );
      final preferenceKinds = <ChimahonPreferenceKind, int>{};
      for (final preference in decodedPreferences) {
        preferenceKinds.update(
          preference.kind,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      expect(preferenceKinds, {
        ChimahonPreferenceKind.boolean: 94,
        ChimahonPreferenceKind.string: 37,
        ChimahonPreferenceKind.integer: 40,
        ChimahonPreferenceKind.longInteger: 6,
        ChimahonPreferenceKind.stringSet: 8,
        ChimahonPreferenceKind.floatingPoint: 3,
      });

      expect(backup.backupNovels.expand((novel) => novel.stats), hasLength(26));
      expect(
        backup.backupNovels.every(
          (novel) =>
              novel.chapterIndex > 0 &&
              novel.progress > 0 &&
              novel.characterCount > 0 &&
              novel.lastModified > Int64.ZERO,
        ),
        isTrue,
        reason: 'Every novel must contain bookmark progress and its clock.',
      );

      final rawRoundTrip = codec.decode(codec.encode(backup));
      final gzipRoundTrip = codec.decode(
        codec.encode(backup, format: ChimahonSyncWireFormat.gzipProtobuf),
      );

      // GeneratedMessage equality includes presence, nested values, and every
      // UnknownFieldSet recursively. This catches loss even for Chimahon fields
      // that Mangatan deliberately leaves opaque.
      expect(rawRoundTrip.backup, backup);
      expect(gzipRoundTrip.backup, backup);

      final firstContactMerge = const ChimahonSyncMerger().merge(
        local: BackupMihon(),
        remote: backup,
        remoteWinsRecordTies: true,
      );
      final canonicalMerge = _canonicalizeUnorderedCollections(
        firstContactMerge,
      );
      final canonicalBackup = _canonicalizeUnorderedCollections(backup);
      expect(
        _sameMessageBytes(canonicalMerge, canonicalBackup),
        isTrue,
        reason: 'First-contact merge must be an identity operation.',
      );

      final unknowns = _unknownFieldSummary(backup);
      expect(unknowns, {'BackupManga#601': 1, 'BackupManga#602': 1});

      final opaqueManga = backup.backupManga
          .where((manga) => manga.unknownFields.isNotEmpty)
          .toList();
      expect(opaqueManga, hasLength(2));
      for (final remote in opaqueManga) {
        final localProjection = remote.deepCopy()
          ..unknownFields.clear()
          ..lastModifiedAt = remote.lastModifiedAt + 1
          ..version = Int64.ZERO;
        final projectedMerge = const ChimahonSyncMerger().merge(
          local: BackupMihon(backupManga: [localProjection]),
          remote: BackupMihon(backupManga: [remote]),
        );
        expect(
          projectedMerge.backupManga.single.unknownFields,
          remote.unknownFields,
          reason: 'A newer local projection must retain opaque Chimahon data.',
        );
      }
    },
    skip: referencePath == null
        ? 'Set CHIMAHON_REFERENCE_BACKUP to run this integration fixture.'
        : false,
  );
}

BackupMihon _canonicalizeUnorderedCollections(BackupMihon source) {
  final result = source.deepCopy();
  result.backupPreferences.sort((left, right) => left.key.compareTo(right.key));
  result.backupSourcePreferences.sort(
    (left, right) => left.sourceKey.compareTo(right.sourceKey),
  );
  for (final sourcePreferences in result.backupSourcePreferences) {
    sourcePreferences.prefs.sort(
      (left, right) => left.key.compareTo(right.key),
    );
  }
  return result;
}

bool _sameMessageBytes(GeneratedMessage left, GeneratedMessage right) {
  final leftBytes = left.writeToBuffer();
  final rightBytes = right.writeToBuffer();
  if (leftBytes.length != rightBytes.length) return false;
  for (var index = 0; index < leftBytes.length; index++) {
    if (leftBytes[index] != rightBytes[index]) return false;
  }
  return true;
}

Map<String, int> _unknownFieldSummary(GeneratedMessage root) {
  final result = <String, int>{};

  void visit(GeneratedMessage message) {
    final type = message.info_.qualifiedMessageName;
    for (final entry in message.unknownFields.asMap().entries) {
      final key = '$type#${entry.key}';
      final field = entry.value;
      result[key] =
          (result[key] ?? 0) +
          field.varints.length +
          field.fixed32s.length +
          field.fixed64s.length +
          field.lengthDelimited.length +
          field.groups.length;
    }
    for (final field in message.info_.fieldInfo.values) {
      final value = message.getField(field.tagNumber);
      if (value is GeneratedMessage) {
        visit(value);
      } else if (value is Iterable) {
        for (final element in value) {
          if (element is GeneratedMessage) visit(element);
        }
      }
    }
  }

  visit(root);
  return Map.fromEntries(
    result.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key)),
  );
}
