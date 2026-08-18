import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/track_preference.dart';
import 'package:mangayomi/modules/more/statistics/immersion_stats_data.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/dictionary_profile_resolver.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/statistics/immersion_stats_models.dart';
import 'package:mangayomi/services/statistics/immersion_stats_storage.dart';
import 'package:mangayomi/services/sync/chimahon_novel_progress_adapter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'immersion_stats_provider.g.dart';

/// Aggregates immersion statistics for one filter combination.
///
/// This is the Dart counterpart of Chimahon's `StatsScreenModel`. Manga rows
/// hold milliseconds and novel rows hold seconds, so every novel value is
/// converted at the point of use rather than at load time — matching Chimahon
/// and keeping the persisted schema byte-compatible.
@riverpod
Future<ImmersionStatsOverview> immersionStats(
  Ref ref, {
  required ImmersionStatsQuery query,
}) async {
  // Rebuild whenever a reader or a mined card writes new statistics.
  _watchStatsRevision(ref);

  final profiles = await MiningPreferences.getDictionaryProfiles();
  final singleTitle = query.titleId != null;
  final type = singleTitle
      ? (query.isNovel ? ImmersionStatsType.novels : ImmersionStatsType.manga)
      : query.type;
  final range = immersionStatsDateRange(query.scale, query.offset);

  // ---------------------------------------------------------------- library
  final wantsManga =
      type == ImmersionStatsType.all || type == ImmersionStatsType.manga;
  final wantsNovels =
      type == ImmersionStatsType.all || type == ImmersionStatsType.novels;

  final mangaEntries = wantsManga
      ? await _mangaEntries(
          titleId: singleTitle && !query.isNovel ? query.titleId : null,
          includeNonLibrary: query.includeNonLibrary,
        )
      : const <Manga>[];
  final novelBooks = wantsNovels
      ? await _novelBooks(
          titleId: singleTitle && query.isNovel ? query.titleId : null,
        )
      : const <_NovelBook>[];

  final profileFilteredManga = await _filterMangaByProfile(
    mangaEntries,
    query.profileId,
  );
  final profileFilteredNovels = await _filterNovelsByProfile(
    novelBooks,
    query.profileId,
  );

  // ------------------------------------------------------------ manga stats
  var mangaStats = await ImmersionStatsStorage.loadMangaStats();
  if (singleTitle) {
    mangaStats = query.isNovel
        ? const []
        : mangaStats
              .where((entry) => entry.mangaId.toString() == query.titleId)
              .toList();
  }
  mangaStats = await _filterMangaStatsByProfile(mangaStats, query.profileId);
  if (!query.includeNonLibrary) {
    final libraryIds = {
      for (final manga in profileFilteredManga)
        if (manga.id != null) manga.id!,
    };
    // Chimahon keeps the id-0 bucket (reading with no library entry) even when
    // non-library titles are excluded, because it is not attributable.
    mangaStats = mangaStats
        .where((entry) => entry.mangaId == 0 || libraryIds.contains(entry.mangaId))
        .toList();
  }
  final unscopedMangaStats = mangaStats;
  final scopedMangaStats = mangaStats
      .where((entry) => range.containsKey(entry.dateKey))
      .toList();

  // ------------------------------------------------------------ novel stats
  final storedNovelStats = await ImmersionStatsStorage.loadAllNovelStats();
  final novelStatsByBook = <String, List<NovelStatsEntry>>{
    for (final book in profileFilteredNovels)
      if (storedNovelStats[book.chimahonId] != null)
        book.chimahonId: storedNovelStats[book.chimahonId]!,
  };
  final unscopedNovelStats = novelStatsByBook.values
      .expand((entries) => entries)
      .toList();
  final scopedNovelStats = unscopedNovelStats
      .where((entry) => range.containsKey(entry.dateKey))
      .toList();

  // -------------------------------------------------------------- totals
  final mangaChars = scopedMangaStats.fold(
    0,
    (sum, entry) => sum + entry.charactersRead,
  );
  final mangaTimeMs = scopedMangaStats.fold(
    0,
    (sum, entry) => sum + entry.readingTimeMs,
  );
  final novelChars = scopedNovelStats.fold(
    0,
    (sum, entry) => sum + entry.charactersRead,
  );
  final novelTimeMs = scopedNovelStats.fold(
    0,
    (sum, entry) => sum + entry.readingTimeMs,
  );

  final totalChars = switch (type) {
    ImmersionStatsType.all => mangaChars + novelChars,
    ImmersionStatsType.manga => mangaChars,
    ImmersionStatsType.novels => novelChars,
  };
  final totalTimeMs = switch (type) {
    ImmersionStatsType.all => mangaTimeMs + novelTimeMs,
    ImmersionStatsType.manga => mangaTimeMs,
    ImmersionStatsType.novels => novelTimeMs,
  };

  // --------------------------------------------------------------- anki
  var ankiStats = await ImmersionStatsStorage.loadAnkiStats();
  if (singleTitle) {
    ankiStats = ankiStats
        .where((entry) => entry.titleId == query.titleId)
        .toList();
  }
  final scopedAnki = ankiStats
      .where((entry) => range.containsKey(entry.dateKey))
      .toList();
  final profileFilteredAnki = _filterAnkiByProfile(
    scopedAnki,
    query.profileId,
    profiles,
  );
  final ankiCards = switch (type) {
    ImmersionStatsType.all => profileFilteredAnki.fold(
      0,
      (sum, entry) => sum + entry.totalCards,
    ),
    ImmersionStatsType.manga => profileFilteredAnki.fold(
      0,
      (sum, entry) => sum + entry.mangaCards,
    ),
    ImmersionStatsType.novels => profileFilteredAnki.fold(
      0,
      (sum, entry) => sum + entry.novelCards,
    ),
  };

  // ---------------------------------------------------------- chapters
  final chapterTotals = await _chapterTotals(
    profileFilteredManga,
    profileFilteredNovels,
    type,
  );

  // ---------------------------------------------------------- trackers
  final trackerTotals = singleTitle
      ? const _TrackerTotals(0, 0, 0)
      : await _trackerTotals(profileFilteredManga);

  // ------------------------------------------------------------- derived
  // The streak and chart deliberately use the *unscoped* rows: a streak is a
  // property of the whole history, and the chart shows periods outside the
  // selected window so it can be navigated.
  final streak = _readingStreak(unscopedMangaStats, unscopedNovelStats);
  final historyPoints = _historyPoints(
    mangaStats: unscopedMangaStats,
    novelStats: unscopedNovelStats,
    scale: query.scale,
    offset: query.offset,
  );

  final days = range.end.difference(range.start).inDays + 1;
  final avgPerDay =
      query.scale != ImmersionStatsDateScale.day &&
          query.scale != ImmersionStatsDateScale.allTime &&
          days > 0
      ? totalTimeMs ~/ days
      : null;

  return ImmersionStatsOverview(
    libraryTitleCount: switch (type) {
      ImmersionStatsType.all =>
        profileFilteredManga.length + profileFilteredNovels.length,
      ImmersionStatsType.manga => profileFilteredManga.length,
      ImmersionStatsType.novels => profileFilteredNovels.length,
    },
    completedTitleCount: _completedCount(profileFilteredManga, type),
    startedTitleCount: await _startedCount(
      profileFilteredManga,
      profileFilteredNovels,
      novelStatsByBook,
      type,
    ),
    localTitleCount: switch (type) {
      ImmersionStatsType.all =>
        profileFilteredManga
                .where((manga) => manga.isLocalArchive == true)
                .length +
            profileFilteredNovels.length,
      ImmersionStatsType.manga => profileFilteredManga
          .where((manga) => manga.isLocalArchive == true)
          .length,
      ImmersionStatsType.novels => profileFilteredNovels.length,
    },
    totalReadDurationMs: totalTimeMs,
    readingStreak: streak,
    historyPoints: historyPoints,
    avgDurationPerDayMs: avgPerDay,
    ankiCardsAdded: ankiCards,
    charactersRead: totalChars,
    charactersPerHour: totalTimeMs > 0
        ? (totalChars / (totalTimeMs / 3600000)).toInt()
        : null,
    totalChapterCount: chapterTotals.total,
    readChapterCount: chapterTotals.read,
    downloadedChapterCount: chapterTotals.downloaded,
    trackedTitleCount: trackerTotals.trackedTitles,
    meanScore: trackerTotals.meanScore,
    trackerCount: trackerTotals.trackerCount,
  );
}

/// The per-title list backing the "In library" card drill-down.
@riverpod
Future<List<ImmersionStatsTitle>> immersionStatsTitles(
  Ref ref, {
  required ImmersionStatsQuery query,
  required ImmersionStatsTitlesSort sort,
  String? search,
}) async {
  _watchStatsRevision(ref);

  final wantsManga =
      query.type == ImmersionStatsType.all ||
      query.type == ImmersionStatsType.manga;
  final wantsNovels =
      query.type == ImmersionStatsType.all ||
      query.type == ImmersionStatsType.novels;

  final mangaEntries = wantsManga
      ? await _filterMangaByProfile(
          await _mangaEntries(
            titleId: null,
            includeNonLibrary: query.includeNonLibrary,
          ),
          query.profileId,
        )
      : const <Manga>[];
  final novelBooks = wantsNovels
      ? await _filterNovelsByProfile(
          await _novelBooks(titleId: null),
          query.profileId,
        )
      : const <_NovelBook>[];

  final mangaStats = await ImmersionStatsStorage.loadMangaStats();
  final statsByManga = <int, List<MangaStatsEntry>>{};
  for (final entry in mangaStats) {
    statsByManga.putIfAbsent(entry.mangaId, () => []).add(entry);
  }
  final novelStats = await ImmersionStatsStorage.loadAllNovelStats();

  final items = <ImmersionStatsTitle>[];
  for (final manga in mangaEntries) {
    final id = manga.id;
    if (id == null) continue;
    final stats = statsByManga[id] ?? const <MangaStatsEntry>[];
    items.add(
      ImmersionStatsTitle(
        id: id.toString(),
        title: manga.name ?? '',
        author: manga.author,
        mangaId: id,
        lastReadDate: _latestDate(stats.map((entry) => entry.dateKey)),
        readDurationMs: stats.fold(
          0,
          (sum, entry) => sum + entry.readingTimeMs,
        ),
        charactersRead: stats.fold(
          0,
          (sum, entry) => sum + entry.charactersRead,
        ),
        dateAdded: manga.dateAdded ?? 0,
      ),
    );
  }
  for (final book in novelBooks) {
    final stats = novelStats[book.chimahonId] ?? const <NovelStatsEntry>[];
    items.add(
      ImmersionStatsTitle(
        id: book.chimahonId,
        title: book.title,
        author: book.author,
        isNovel: true,
        mangaId: book.mangaId,
        lastReadDate: _latestDate(stats.map((entry) => entry.dateKey)),
        readDurationMs: stats.fold(
          0,
          (sum, entry) => sum + entry.readingTimeMs,
        ),
        charactersRead: stats.fold(
          0,
          (sum, entry) => sum + entry.charactersRead,
        ),
        dateAdded: book.dateAdded,
      ),
    );
  }

  final query0 = search?.trim().toLowerCase();
  final filtered = query0 == null || query0.isEmpty
      ? items
      : items
            .where(
              (item) =>
                  item.title.toLowerCase().contains(query0) ||
                  (item.author?.toLowerCase().contains(query0) ?? false),
            )
            .toList();

  switch (sort) {
    case ImmersionStatsTitlesSort.alphabetical:
      filtered.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    case ImmersionStatsTitlesSort.lastRead:
      filtered.sort((a, b) {
        // Titles with any reading history sort above those without.
        final aHas = a.lastReadDate != null;
        final bHas = b.lastReadDate != null;
        if (aHas != bHas) return aHas ? -1 : 1;
        if (aHas && bHas) {
          final byDate = b.lastReadDate!.compareTo(a.lastReadDate!);
          if (byDate != 0) return byDate;
        }
        final byDuration = b.readDurationMs.compareTo(a.readDurationMs);
        if (byDuration != 0) return byDuration;
        return a.title.compareTo(b.title);
      });
    case ImmersionStatsTitlesSort.dateAdded:
      filtered.sort((a, b) {
        final byDate = b.dateAdded.compareTo(a.dateAdded);
        return byDate != 0 ? byDate : a.title.compareTo(b.title);
      });
  }
  return filtered;
}

/// Dictionary profiles available as a filter.
@riverpod
Future<List<DictionaryProfile>> immersionStatsProfiles(Ref ref) =>
    MiningPreferences.getDictionaryProfiles();

/// Rebuilds the provider whenever statistics are written.
void _watchStatsRevision(Ref ref) {
  void onChanged() => ref.invalidateSelf();
  ImmersionStatsStorage.revision.addListener(onChanged);
  ref.onDispose(
    () => ImmersionStatsStorage.revision.removeListener(onChanged),
  );
}

// --------------------------------------------------------------- library IO

Future<List<Manga>> _mangaEntries({
  required String? titleId,
  required bool includeNonLibrary,
}) async {
  if (titleId != null) {
    final id = int.tryParse(titleId);
    if (id == null) return const [];
    final manga = await isar.mangas.get(id);
    return manga == null ? const [] : [manga];
  }
  // Chimahon's "include all read entries" adds titles that were read but are
  // not (or no longer) favourites; those still have a Manga row locally.
  final query = isar.mangas.filter().itemTypeEqualTo(ItemType.manga);
  return includeNonLibrary
      ? query.findAll()
      : query.favoriteEqualTo(true).findAll();
}

/// One EPUB with a Chimahon-representable identity.
class _NovelBook {
  const _NovelBook({
    required this.chimahonId,
    required this.title,
    this.author,
    this.mangaId,
    this.dateAdded = 0,
  });

  final String chimahonId;
  final String title;
  final String? author;
  final int? mangaId;
  final int dateAdded;
}

Future<List<_NovelBook>> _novelBooks({required String? titleId}) async {
  const adapter = ChimahonNovelProgressAdapter();
  final progresses = await isar.epubBookProgress.where().findAll();
  final parentDates = <int, int>{};
  final books = <String, _NovelBook>{};
  for (final progress in progresses) {
    final id = adapter.stableLocalIdOrNull(progress);
    if (id == null) continue;
    if (titleId != null && id != titleId) continue;
    parentDates[progress.mangaId] ??=
        (await isar.mangas.get(progress.mangaId))?.dateAdded ?? 0;
    // A duplicate identity means the same book imported twice; the first row
    // wins so a title is never double counted.
    books.putIfAbsent(
      id,
      () => _NovelBook(
        chimahonId: id,
        title: progress.title,
        author: progress.author,
        mangaId: progress.mangaId,
        dateAdded: parentDates[progress.mangaId] ?? 0,
      ),
    );
  }
  return books.values.toList();
}

// ------------------------------------------------------------ profile filters

Future<List<Manga>> _filterMangaByProfile(
  List<Manga> entries,
  String? profileId,
) async {
  if (profileId == null || entries.isEmpty) return entries;
  final kept = <Manga>[];
  for (final manga in entries) {
    if (await _mangaProfileId(manga) == profileId) kept.add(manga);
  }
  return kept;
}

Future<String?> _mangaProfileId(Manga manga) async {
  final source = manga.sourceId == null
      ? null
      : await isar.sources.get(manga.sourceId!);
  final resolved = await DictionaryProfileResolver.resolve(
    mangaId: manga.id,
    sourceId: DictionaryProfileResolver.overrideIdForSource(source),
    sourceLanguage: DictionaryProfileResolver.sourceLanguageForSource(
      source,
      fallback: manga.lang ?? '',
    ),
  );
  return resolved.id;
}

Future<List<_NovelBook>> _filterNovelsByProfile(
  List<_NovelBook> books,
  String? profileId,
) async {
  if (profileId == null || books.isEmpty) return books;
  final kept = <_NovelBook>[];
  for (final book in books) {
    final resolved = await DictionaryProfileResolver.resolve(
      novelId: book.chimahonId,
    );
    if (resolved.id == profileId) kept.add(book);
  }
  return kept;
}

Future<List<MangaStatsEntry>> _filterMangaStatsByProfile(
  List<MangaStatsEntry> stats,
  String? profileId,
) async {
  if (profileId == null || stats.isEmpty) return stats;
  final byMangaId = <int, String?>{};
  final kept = <MangaStatsEntry>[];
  for (final entry in stats) {
    // Reading with no library entry cannot be attributed to a profile, so it
    // is excluded from a profile-scoped view rather than counted everywhere.
    if (entry.mangaId == 0) continue;
    final resolved = byMangaId.putIfAbsent(entry.mangaId, () => null);
    final profile =
        resolved ??
        await () async {
          final manga = await isar.mangas.get(entry.mangaId);
          final id = manga == null ? null : await _mangaProfileId(manga);
          byMangaId[entry.mangaId] = id;
          return id;
        }();
    if (profile == profileId) kept.add(entry);
  }
  return kept;
}

/// Chimahon treats an empty `profileId` as belonging to the first profile,
/// because early builds wrote cards before profiles were introduced.
List<AnkiStatsEntry> _filterAnkiByProfile(
  List<AnkiStatsEntry> stats,
  String? profileId,
  List<DictionaryProfile> profiles,
) {
  if (profileId == null) return stats;
  final firstProfileId = profiles.isEmpty ? null : profiles.first.id;
  return stats
      .where(
        (entry) =>
            entry.profileId == profileId ||
            (entry.profileId.isEmpty && profileId == firstProfileId),
      )
      .toList();
}

// -------------------------------------------------------------- aggregations

class _ChapterTotals {
  const _ChapterTotals(this.total, this.read, this.downloaded);

  final int total;
  final int read;
  final int downloaded;
}

Future<_ChapterTotals> _chapterTotals(
  List<Manga> manga,
  List<_NovelBook> novels,
  ImmersionStatsType type,
) async {
  var total = 0;
  var read = 0;
  var downloaded = 0;
  if (type != ImmersionStatsType.novels) {
    for (final entry in manga) {
      final id = entry.id;
      if (id == null) continue;
      total += await isar.chapters.filter().mangaIdEqualTo(id).count();
      read += await isar.chapters
          .filter()
          .mangaIdEqualTo(id)
          .isReadEqualTo(true)
          .count();
      downloaded += await isar.downloads
          .filter()
          .chapter((q) => q.mangaIdEqualTo(id))
          .isDownloadEqualTo(true)
          .count();
    }
  }
  if (type != ImmersionStatsType.manga) {
    // A novel's "chapters" are its EPUB spine entries; the parent library
    // entry already holds one chapter row per spine item.
    for (final book in novels) {
      final parentId = book.mangaId;
      if (parentId == null) continue;
      total += await isar.chapters.filter().mangaIdEqualTo(parentId).count();
      read += await isar.chapters
          .filter()
          .mangaIdEqualTo(parentId)
          .isReadEqualTo(true)
          .count();
    }
  }
  return _ChapterTotals(total, read, downloaded);
}

int _completedCount(List<Manga> manga, ImmersionStatsType type) {
  if (type == ImmersionStatsType.novels) return 0;
  // Chimahon counts a title completed only when the source says it is finished
  // and nothing is left unread.
  return manga
      .where(
        (entry) =>
            entry.status == Status.completed &&
            entry.id != null &&
            isar.chapters
                    .filter()
                    .mangaIdEqualTo(entry.id!)
                    .isReadEqualTo(false)
                    .countSync() ==
                0 &&
            isar.chapters.filter().mangaIdEqualTo(entry.id!).countSync() > 0,
      )
      .length;
}

Future<int> _startedCount(
  List<Manga> manga,
  List<_NovelBook> novels,
  Map<String, List<NovelStatsEntry>> novelStats,
  ImmersionStatsType type,
) async {
  var started = 0;
  if (type != ImmersionStatsType.novels) {
    for (final entry in manga) {
      final id = entry.id;
      if (id == null) continue;
      final hasRead = await isar.chapters
          .filter()
          .mangaIdEqualTo(id)
          .isReadEqualTo(true)
          .count();
      if (hasRead > 0) started++;
    }
  }
  if (type != ImmersionStatsType.manga) {
    // A novel counts as started once it has any recorded reading.
    started += novels
        .where((book) => (novelStats[book.chimahonId] ?? const []).isNotEmpty)
        .length;
  }
  return started;
}

class _TrackerTotals {
  const _TrackerTotals(this.trackedTitles, this.meanScore, this.trackerCount);

  final int trackedTitles;
  final double meanScore;
  final int trackerCount;
}

Future<_TrackerTotals> _trackerTotals(List<Manga> manga) async {
  final loggedIn = await isar.trackPreferences
      .filter()
      .syncIdIsNotNull()
      .findAll();
  final loggedInIds = {
    for (final preference in loggedIn)
      if (preference.syncId != null) preference.syncId!,
  };
  if (loggedInIds.isEmpty) return const _TrackerTotals(0, 0, 0);

  final scoreScales = {
    for (final preference in loggedIn)
      if (preference.syncId != null)
        preference.syncId!: _scoreScale(preference.syncId!),
  };

  var trackedTitles = 0;
  final titleAverages = <double>[];
  for (final entry in manga) {
    final id = entry.id;
    if (id == null) continue;
    final tracks = (await isar.tracks.filter().mangaIdEqualTo(id).findAll())
        .where((track) => loggedInIds.contains(track.syncId))
        .toList();
    if (tracks.isEmpty) continue;
    trackedTitles++;
    final scored = <double>[];
    for (final track in tracks) {
      final score = track.score ?? 0;
      if (score <= 0) continue;
      scored.add(_tenPointScore(score, scoreScales[track.syncId] ?? 10));
    }
    if (scored.isNotEmpty) {
      titleAverages.add(scored.reduce((a, b) => a + b) / scored.length);
    }
  }

  final meanScore = titleAverages.isEmpty
      ? 0.0
      : titleAverages.reduce((a, b) => a + b) / titleAverages.length;
  return _TrackerTotals(trackedTitles, meanScore, loggedInIds.length);
}

/// The maximum raw score a tracker reports, used to normalize to 10 points.
///
/// AniList (syncId 2) always stores its score internally out of 100 regardless
/// of the display format the account uses; every other tracker reports out of
/// 10.
int _scoreScale(int syncId) => syncId == 2 ? 100 : 10;

double _tenPointScore(int score, int scale) =>
    scale <= 0 ? 0 : score * 10 / scale;

/// Consecutive days ending today (or yesterday) with any recorded reading.
int _readingStreak(
  List<MangaStatsEntry> mangaStats,
  List<NovelStatsEntry> novelStats,
) {
  final days = <DateTime>{};
  for (final entry in mangaStats) {
    final date = parseStatsDateKey(entry.dateKey);
    if (date != null) days.add(date);
  }
  for (final entry in novelStats) {
    final date = parseStatsDateKey(entry.dateKey);
    if (date != null) days.add(date);
  }
  if (days.isEmpty) return 0;

  final now = DateTime.now();
  var current = DateTime(now.year, now.month, now.day);
  // Not having read yet today does not break a streak; it resumes from
  // yesterday.
  if (!days.contains(current)) {
    current = current.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (days.contains(current)) {
    streak++;
    current = current.subtract(const Duration(days: 1));
  }
  return streak;
}

/// The bars for the hero chart: a week of days, a month of weeks, a year of
/// months, or the last five years.
List<ImmersionHistoryPoint> _historyPoints({
  required List<MangaStatsEntry> mangaStats,
  required List<NovelStatsEntry> novelStats,
  required ImmersionStatsDateScale scale,
  required int offset,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final range = immersionStatsDateRange(scale, offset, now: now);

  int durationFor(DateTime start, DateTime end) {
    final window = ImmersionStatsDateRange(start, end);
    var total = 0;
    for (final entry in mangaStats) {
      if (window.containsKey(entry.dateKey)) total += entry.readingTimeMs;
    }
    for (final entry in novelStats) {
      if (window.containsKey(entry.dateKey)) total += entry.readingTimeMs;
    }
    return total;
  }

  switch (scale) {
    case ImmersionStatsDateScale.day:
      final weekStart = range.start.subtract(
        Duration(days: range.start.weekday - DateTime.monday),
      );
      return [
        for (var i = 0; i < 7; i++)
          () {
            final date = weekStart.add(Duration(days: i));
            return ImmersionHistoryPoint(
              label: _weekdayLabels[date.weekday - 1],
              durationMs: durationFor(date, date),
              dateOffset: date.difference(today).inDays,
            );
          }(),
      ];
    case ImmersionStatsDateScale.week:
      // Bars cover the weeks of the month the selected week falls in; the
      // Thursday of an ISO week always lies inside its owning month.
      final anchor = range.start.add(const Duration(days: 3));
      final monthStart = DateTime(anchor.year, anchor.month);
      final monthEnd = DateTime(anchor.year, anchor.month + 1, 0);
      final firstMonday = monthStart.subtract(
        Duration(days: monthStart.weekday - DateTime.monday),
      );
      final lastMonday = monthEnd.subtract(
        Duration(days: monthEnd.weekday - DateTime.monday),
      );
      final weeks = (lastMonday.difference(firstMonday).inDays ~/ 7) + 1;
      final currentMonday = today.subtract(
        Duration(days: today.weekday - DateTime.monday),
      );
      return [
        for (var i = 0; i < (weeks < 4 ? 4 : weeks); i++)
          () {
            final weekStart = firstMonday.add(Duration(days: i * 7));
            final weekEnd = weekStart.add(const Duration(days: 6));
            return ImmersionHistoryPoint(
              label: 'W${_isoWeekNumber(weekStart)}',
              durationMs: durationFor(weekStart, weekEnd),
              dateOffset: weekStart.difference(currentMonday).inDays ~/ 7,
            );
          }(),
      ];
    case ImmersionStatsDateScale.month:
      return [
        for (var month = 1; month <= 12; month++)
          () {
            final start = DateTime(range.start.year, month);
            final end = DateTime(range.start.year, month + 1, 0);
            return ImmersionHistoryPoint(
              label: _monthLabels[month - 1],
              durationMs: durationFor(start, end),
              dateOffset:
                  (start.year - today.year) * 12 + (start.month - today.month),
            );
          }(),
      ];
    case ImmersionStatsDateScale.year:
    case ImmersionStatsDateScale.allTime:
      return [
        for (var yearsAgo = 4; yearsAgo >= 0; yearsAgo--)
          () {
            final year = today.year - yearsAgo;
            return ImmersionHistoryPoint(
              label: year.toString(),
              durationMs: durationFor(DateTime(year), DateTime(year, 12, 31)),
              dateOffset: -yearsAgo,
            );
          }(),
      ];
  }
}

/// ISO-8601 week number, matching Chimahon's `WEEK_OF_WEEK_BASED_YEAR`.
int _isoWeekNumber(DateTime date) {
  final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstThursdayOfYear = firstThursday.add(
    Duration(days: DateTime.thursday - firstThursday.weekday),
  );
  return 1 + thursday.difference(firstThursdayOfYear).inDays ~/ 7;
}

DateTime? _latestDate(Iterable<String> dateKeys) {
  DateTime? latest;
  for (final key in dateKeys) {
    final date = parseStatsDateKey(key);
    if (date == null) continue;
    if (latest == null || date.isAfter(latest)) latest = date;
  }
  return latest;
}

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
