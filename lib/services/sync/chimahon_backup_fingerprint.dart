import 'package:crypto/crypto.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';

/// Non-secret structural fingerprint of one Chimahon wire payload.
///
/// Both the original container hash and decompressed protobuf hash are kept:
/// equal protobuf data can have a different gzip representation, while an
/// equal raw hash proves byte-for-byte identity with a reference backup.
class ChimahonBackupFingerprint {
  ChimahonBackupFingerprint._({
    required this.format,
    required this.rawSha256,
    required this.protobufSha256,
    required this.rawByteLength,
    required this.protobufByteLength,
    required this.counts,
  });

  factory ChimahonBackupFingerprint.fromBytes(
    List<int> bytes, {
    ChimahonSyncCodec codec = const ChimahonSyncCodec(),
  }) {
    final decoded = codec.decode(bytes);
    return ChimahonBackupFingerprint._(
      format: decoded.format,
      rawSha256: sha256.convert(bytes).toString(),
      protobufSha256: sha256.convert(decoded.protobufBytes).toString(),
      rawByteLength: bytes.length,
      protobufByteLength: decoded.protobufBytes.length,
      counts: _backupCounts(decoded.backup),
    );
  }

  final ChimahonSyncWireFormat format;
  final String rawSha256;
  final String protobufSha256;
  final int rawByteLength;
  final int protobufByteLength;
  final Map<String, int> counts;

  ChimahonBackupComparison compareTo(ChimahonBackupFingerprint reference) {
    final countDifferences = <String, ChimahonCountDifference>{};
    final keys = {...counts.keys, ...reference.counts.keys}.toList()..sort();
    for (final key in keys) {
      final actual = counts[key] ?? 0;
      final expected = reference.counts[key] ?? 0;
      if (actual != expected) {
        countDifferences[key] = ChimahonCountDifference(
          actual: actual,
          reference: expected,
        );
      }
    }
    return ChimahonBackupComparison(
      rawBytesMatch: rawSha256 == reference.rawSha256,
      protobufBytesMatch: protobufSha256 == reference.protobufSha256,
      countDifferences: countDifferences,
    );
  }

  Map<String, Object> toSafeJson() => {
    'format': format.name,
    'rawSha256': rawSha256,
    'protobufSha256': protobufSha256,
    'rawByteLength': rawByteLength,
    'protobufByteLength': protobufByteLength,
    'counts': counts,
  };

  static Map<String, int> _backupCounts(BackupMihon backup) => {
    'mangaRecords': backup.backupManga.length,
    'mangaFavoriteTrue': backup.backupManga
        .where((manga) => manga.hasFavorite() && manga.favorite)
        .length,
    'mangaTombstones': backup.backupManga
        .where((manga) => manga.hasFavorite() && !manga.favorite)
        .length,
    'mangaFavoriteFieldAbsent': backup.backupManga
        .where((manga) => !manga.hasFavorite())
        .length,
    'mangaChapters': backup.backupManga.fold(
      0,
      (sum, manga) => sum + manga.chapters.length,
    ),
    'mangaHistory': backup.backupManga.fold(
      0,
      (sum, manga) => sum + manga.history.length,
    ),
    'mangaTracking': backup.backupManga.fold(
      0,
      (sum, manga) => sum + manga.tracking.length,
    ),
    'mangaCategories': backup.backupCategories.length,
    'mangaSources': backup.backupSources.length,
    'appPreferences': backup.backupPreferences.length,
    'sourcePreferenceGroups': backup.backupSourcePreferences.length,
    'extensionRepositories': backup.backupExtensionRepo.length,
    'animeRecords': backup.backupAnime.length,
    'animeEpisodes': backup.backupAnime.fold(
      0,
      (sum, anime) => sum + anime.episodes.length,
    ),
    'animeHistory': backup.backupAnime.fold(
      0,
      (sum, anime) => sum + anime.history.length,
    ),
    'animeTracking': backup.backupAnime.fold(
      0,
      (sum, anime) => sum + anime.tracking.length,
    ),
    'animeCategories': backup.backupAnimeCategories.length,
    'animeSources': backup.backupAnimeSources.length,
    'animeExtensionRepositories': backup.backupAnimeExtensionRepo.length,
    'savedSearches': backup.backupSavedSearches.length,
    'feeds': backup.backupFeeds.length,
    'novels': backup.backupNovels.length,
    'novelStatistics': backup.backupNovels.fold(
      0,
      (sum, novel) => sum + novel.stats.length,
    ),
    'novelCategories': backup.backupNovelCategories.length,
    'mangaStatistics': backup.backupMangaStats.length,
    'ankiStatistics': backup.backupAnkiStats.length,
  };
}

class ChimahonBackupComparison {
  const ChimahonBackupComparison({
    required this.rawBytesMatch,
    required this.protobufBytesMatch,
    required this.countDifferences,
  });

  final bool rawBytesMatch;
  final bool protobufBytesMatch;
  final Map<String, ChimahonCountDifference> countDifferences;

  Map<String, Object> toSafeJson() => {
    'rawBytesMatch': rawBytesMatch,
    'protobufBytesMatch': protobufBytesMatch,
    'countDifferences': {
      for (final entry in countDifferences.entries)
        entry.key: entry.value.toSafeJson(),
    },
  };
}

class ChimahonCountDifference {
  const ChimahonCountDifference({
    required this.actual,
    required this.reference,
  });

  final int actual;
  final int reference;

  Map<String, int> toSafeJson() => {'actual': actual, 'reference': reference};
}
