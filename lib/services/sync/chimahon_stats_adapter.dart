import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';
import 'package:mangayomi/services/statistics/immersion_stats_models.dart';

/// Lossless mapping between immersion statistics and Chimahon's backup rows.
///
/// The three collections travel differently in Chimahon's envelope: manga and
/// Anki statistics are top-level repeated fields (710 and 711), while a novel's
/// statistics are nested inside its own `BackupNovel`. That shape is preserved
/// so a Mangatan backup restores in Chimahon and vice versa.
class ChimahonStatsAdapter {
  const ChimahonStatsAdapter();

  // ---------------------------------------------------------------- manga

  BackupMangaStats exportMangaStats(MangaStatsEntry entry) => BackupMangaStats(
    dateKey: entry.dateKey,
    charactersRead: entry.charactersRead,
    readingTime: Int64(entry.readingTimeMs),
    mangaId: Int64(entry.mangaId),
  );

  List<BackupMangaStats> exportAllMangaStats(
    Iterable<MangaStatsEntry> entries,
  ) => [
    for (final entry in entries)
      // A row without a date key cannot be attributed to a day, so it would be
      // unmergeable on the other side.
      if (entry.dateKey.isNotEmpty) exportMangaStats(entry),
  ];

  MangaStatsEntry importMangaStats(BackupMangaStats stats) => MangaStatsEntry(
    dateKey: stats.dateKey,
    charactersRead: stats.charactersRead,
    readingTimeMs: stats.readingTime.toInt(),
    mangaId: stats.mangaId.toInt(),
  );

  List<MangaStatsEntry> importAllMangaStats(
    Iterable<BackupMangaStats> stats,
  ) => [
    for (final entry in stats)
      if (entry.dateKey.isNotEmpty) importMangaStats(entry),
  ];

  // ----------------------------------------------------------------- anki

  BackupAnkiStats exportAnkiStats(AnkiStatsEntry entry) {
    final stats = BackupAnkiStats(
      dateKey: entry.dateKey,
      mangaCards: entry.mangaCards,
      novelCards: entry.novelCards,
      profileId: entry.profileId,
    );
    // `titleId` is an optional proto field: leaving it absent is what marks a
    // card mined outside any title, and is distinct from an empty string.
    if (entry.titleId != null) stats.titleId = entry.titleId!;
    return stats;
  }

  List<BackupAnkiStats> exportAllAnkiStats(Iterable<AnkiStatsEntry> entries) => [
    for (final entry in entries)
      if (entry.dateKey.isNotEmpty) exportAnkiStats(entry),
  ];

  AnkiStatsEntry importAnkiStats(BackupAnkiStats stats) => AnkiStatsEntry(
    dateKey: stats.dateKey,
    mangaCards: stats.mangaCards,
    novelCards: stats.novelCards,
    profileId: stats.profileId,
    titleId: stats.hasTitleId() ? stats.titleId : null,
  );

  List<AnkiStatsEntry> importAllAnkiStats(Iterable<BackupAnkiStats> stats) => [
    for (final entry in stats)
      if (entry.dateKey.isNotEmpty) importAnkiStats(entry),
  ];

  // ---------------------------------------------------------------- novel

  BackupNovelStat exportNovelStats(NovelStatsEntry entry) => BackupNovelStat(
    dateKey: entry.dateKey,
    charactersRead: entry.charactersRead,
    readingTime: entry.readingTimeSeconds,
    minReadingSpeed: entry.minReadingSpeed,
    altMinReadingSpeed: entry.altMinReadingSpeed,
    lastReadingSpeed: entry.lastReadingSpeed,
    maxReadingSpeed: entry.maxReadingSpeed,
    lastStatisticModified: Int64(entry.lastStatisticModified),
  );

  List<BackupNovelStat> exportAllNovelStats(
    Iterable<NovelStatsEntry> entries,
  ) => [
    for (final entry in entries)
      if (entry.dateKey.isNotEmpty) exportNovelStats(entry),
  ];

  NovelStatsEntry importNovelStats(BackupNovelStat stats) => NovelStatsEntry(
    dateKey: stats.dateKey,
    charactersRead: stats.charactersRead,
    readingTimeSeconds: stats.readingTime,
    minReadingSpeed: stats.minReadingSpeed,
    altMinReadingSpeed: stats.altMinReadingSpeed,
    lastReadingSpeed: stats.lastReadingSpeed,
    maxReadingSpeed: stats.maxReadingSpeed,
    lastStatisticModified: stats.lastStatisticModified.toInt(),
  );

  List<NovelStatsEntry> importAllNovelStats(
    Iterable<BackupNovelStat> stats,
  ) => [
    for (final entry in stats)
      if (entry.dateKey.isNotEmpty) importNovelStats(entry),
  ];
}
