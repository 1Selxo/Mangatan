import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/services/sync/chimahon_manga_title_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_local_chapter_policy.dart';
import 'package:mangayomi/services/sync/chimahon_novel_category_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_novel_progress_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_tracking_adapter.dart';

/// Pure mapper from Mangatan's persisted entities to the common Mihon backup
/// envelope. Database access and scheduling deliberately remain outside it.
class MihonBackupExporter {
  const MihonBackupExporter();

  BackupMihon export({
    required Iterable<Manga> mangas,
    required Iterable<Category> categories,
    required Iterable<Chapter> chapters,
    required Iterable<History> histories,
    required Iterable<Source> sources,
    required Iterable<EpubBookProgress> epubBookProgress,
    Iterable<Track> tracks = const [],
    Iterable<ChimahonTrackingDeletion> deletedTracks = const [],
    Iterable<BackupPreference> appPreferences = const [],
    Iterable<BackupSourcePreferences> sourcePreferences = const [],
  }) {
    final localMangas = mangas.toList(growable: false);
    final localCategories = categories.toList(growable: false);
    final novelCategoryProjection = const ChimahonNovelCategoryAdapter()
        .buildExportProjection(
          categories: localCategories,
          mangas: localMangas,
        );

    final mangaCategories = localCategories
        .where((category) => category.forItemType == ItemType.manga)
        .toList();
    final categoryOrderById = <int, int>{};
    for (final indexed in mangaCategories.indexed) {
      final category = indexed.$2;
      if (category.id != null) {
        categoryOrderById[category.id!] = category.pos ?? indexed.$1;
      }
    }

    final sourceByLocalId = {
      for (final source in sources)
        if (source.id != null) source.id!: source,
    };
    final chaptersByManga = <int, List<Chapter>>{};
    for (final chapter in chapters) {
      final mangaId = chapter.mangaId;
      if (mangaId != null) {
        chaptersByManga.putIfAbsent(mangaId, () => []).add(chapter);
      }
    }
    final historiesByManga = <int, List<History>>{};
    for (final history in histories) {
      final mangaId = history.mangaId;
      if (mangaId != null) {
        historiesByManga.putIfAbsent(mangaId, () => []).add(history);
      }
    }
    final tracksByManga = <int, List<Track>>{};
    for (final track in tracks) {
      final mangaId = track.mangaId;
      if (mangaId != null) {
        tracksByManga.putIfAbsent(mangaId, () => []).add(track);
      }
    }
    final deletedTracksByManga = <int, List<ChimahonTrackingDeletion>>{};
    for (final deletion in deletedTracks) {
      deletedTracksByManga
          .putIfAbsent(deletion.mangaId, () => [])
          .add(deletion);
    }

    final exportedManga = <BackupManga>[];
    final usedSources = <int, BackupSource>{};
    for (final manga in localMangas.where(
      (manga) =>
          manga.itemType == ItemType.manga &&
          ((manga.favorite ?? false) || manga.favoriteModifiedAt != null) &&
          !(manga.isLocalArchive ?? false),
    )) {
      final localSource = manga.sourceId == null
          ? null
          : sourceByLocalId[manga.sourceId!];
      final nativeId = _nativeSourceId(localSource);
      if (nativeId == null || manga.id == null) continue;
      usedSources[nativeId] = BackupSource(
        name: localSource?.name ?? manga.source ?? 'Unknown',
        sourceId: Int64(nativeId),
      );

      final mangaChapters = (chaptersByManga[manga.id!] ?? const [])
          .where(_isChimahonPortableChapter)
          .toList(growable: false);
      final chaptersById = {
        for (final chapter in mangaChapters)
          if (chapter.id != null) chapter.id!: chapter,
      };
      final backupHistory = _backupHistory(
        historiesByManga[manga.id!] ?? const [],
        chaptersById,
      );

      final titles = const ChimahonMangaTitleAdapter().fromManga(manga);
      final favoriteModifiedAt = _favoriteModifiedAt(manga);
      final mangaTracks = tracksByManga[manga.id!] ?? const [];
      final lastModifiedAt = _parentModifiedAt(
        manga: manga,
        favoriteModifiedAt: favoriteModifiedAt,
        tracks: mangaTracks,
        deletedTracks: deletedTracksByManga[manga.id!] ?? const [],
      );

      exportedManga.add(
        BackupManga(
          source: Int64(nativeId),
          url: manga.link ?? '',
          title: titles.sourceTitle,
          customTitle: titles.customTitle,
          artist: manga.artist,
          author: manga.author,
          description: manga.description,
          genre: manga.genre,
          status: _status(manga.status),
          thumbnailUrl: manga.imageUrl,
          dateAdded: Int64(manga.dateAdded ?? 0),
          chapters: [
            for (final indexed in mangaChapters.indexed)
              _backupChapter(indexed.$2, indexed.$1),
          ],
          categories: (manga.categories ?? const [])
              .map((id) => categoryOrderById[id])
              .nonNulls
              .map(Int64.new),
          favorite: manga.favorite ?? true,
          tracking: const ChimahonTrackingAdapter().exportAll(
            mangaTracks,
            itemType: ItemType.manga,
          ),
          history: backupHistory,
          lastModifiedAt: Int64(lastModifiedAt),
          favoriteModifiedAt: favoriteModifiedAt == null
              ? null
              : Int64(favoriteModifiedAt),
          // Mangatan's updatedAt is a wall-clock timestamp, not Chimahon's
          // monotonic version counter. Zero marks this projection as
          // unversioned; the merger promotes a newer projection above the
          // remote counter before it is uploaded.
          version: Int64.ZERO,
          initialized: true,
        ),
      );
    }

    final animeCategories = localCategories
        .where((category) => category.forItemType == ItemType.anime)
        .toList();
    final animeCategoryOrderById = <int, int>{};
    for (final indexed in animeCategories.indexed) {
      final category = indexed.$2;
      if (category.id != null) {
        animeCategoryOrderById[category.id!] = category.pos ?? indexed.$1;
      }
    }

    final exportedAnime = <BackupAnime>[];
    final usedAnimeSources = <int, BackupSource>{};
    for (final anime in localMangas.where(
      (manga) =>
          manga.itemType == ItemType.anime &&
          ((manga.favorite ?? false) || manga.favoriteModifiedAt != null) &&
          !(manga.isLocalArchive ?? false),
    )) {
      final localSource = anime.sourceId == null
          ? null
          : sourceByLocalId[anime.sourceId!];
      final nativeId = _nativeSourceId(localSource);
      if (nativeId == null || anime.id == null) continue;
      usedAnimeSources[nativeId] = BackupSource(
        name: localSource?.name ?? anime.source ?? 'Unknown',
        sourceId: Int64(nativeId),
      );

      final animeEpisodes = (chaptersByManga[anime.id!] ?? const [])
          .where(_isChimahonPortableChapter)
          .toList(growable: false);
      final episodesById = {
        for (final episode in animeEpisodes)
          if (episode.id != null) episode.id!: episode,
      };
      final backupHistory = _backupHistory(
        historiesByManga[anime.id!] ?? const [],
        episodesById,
      );

      final favoriteModifiedAt = _favoriteModifiedAt(anime);
      final animeTracks = tracksByManga[anime.id!] ?? const [];
      final lastModifiedAt = _parentModifiedAt(
        manga: anime,
        favoriteModifiedAt: favoriteModifiedAt,
        tracks: animeTracks,
        deletedTracks: deletedTracksByManga[anime.id!] ?? const [],
      );
      exportedAnime.add(
        BackupAnime(
          source: Int64(nativeId),
          url: anime.link ?? '',
          title: anime.name ?? '',
          artist: anime.artist,
          author: anime.author,
          description: anime.description,
          genre: anime.genre,
          status: _status(anime.status),
          thumbnailUrl: anime.imageUrl,
          dateAdded: Int64(anime.dateAdded ?? 0),
          episodes: [
            for (final indexed in animeEpisodes.indexed)
              _backupEpisode(indexed.$2, indexed.$1),
          ],
          categories: (anime.categories ?? const [])
              .map((id) => animeCategoryOrderById[id])
              .nonNulls
              .map(Int64.new),
          favorite: anime.favorite ?? true,
          tracking: const ChimahonTrackingAdapter().exportAll(
            animeTracks,
            itemType: ItemType.anime,
          ),
          history: backupHistory,
          lastModifiedAt: Int64(lastModifiedAt),
          favoriteModifiedAt: favoriteModifiedAt == null
              ? null
              : Int64(favoriteModifiedAt),
          version: Int64.ZERO,
        ),
      );
    }

    return BackupMihon(
      backupManga: exportedManga,
      backupCategories: [
        for (final indexed in mangaCategories.indexed)
          BackupCategory(
            name: indexed.$2.name ?? '',
            order: Int64(indexed.$2.pos ?? indexed.$1),
            id: Int64(indexed.$2.id ?? indexed.$1),
            hidden: indexed.$2.hide ?? false,
          ),
      ],
      backupSources: usedSources.values,
      backupAnime: exportedAnime,
      backupAnimeCategories: [
        for (final indexed in animeCategories.indexed)
          BackupCategory(
            name: indexed.$2.name ?? '',
            order: Int64(indexed.$2.pos ?? indexed.$1),
            id: Int64(indexed.$2.id ?? indexed.$1),
            hidden: indexed.$2.hide ?? false,
          ),
      ],
      backupAnimeSources: usedAnimeSources.values,
      backupPreferences: appPreferences,
      backupSourcePreferences: sourcePreferences,
      backupNovels: const ChimahonNovelProgressAdapter().exportAll(
        epubBookProgress,
        categoryIdsByMangaId: novelCategoryProjection.categoryIdsByMangaId,
      ),
      backupNovelCategories: novelCategoryProjection.categories,
    );
  }

  BackupChapter _backupChapter(Chapter chapter, int sourceOrder) {
    final modified = _epochSeconds(chapter.updatedAt);
    return BackupChapter(
      url: chapter.url ?? '',
      name: chapter.name ?? '',
      scanlator: chapter.scanlator,
      read: chapter.isRead ?? false,
      bookmark: chapter.isBookmarked ?? false,
      lastPageRead: Int64(_wireProgress(chapter.lastPageRead)),
      dateFetch: Int64(0),
      dateUpload: Int64(int.tryParse(chapter.dateUpload ?? '') ?? 0),
      chapterNumber: chapter.chapterNumber ?? _chapterNumber(chapter.name),
      sourceOrder: Int64(sourceOrder),
      lastModifiedAt: Int64(modified),
      version: Int64.ZERO,
    );
  }

  BackupEpisode _backupEpisode(Chapter episode, int sourceOrder) {
    final modified = _epochSeconds(episode.updatedAt);
    return BackupEpisode(
      url: episode.url ?? '',
      name: episode.name ?? '',
      scanlator: episode.scanlator,
      seen: episode.isRead ?? false,
      bookmark: episode.isBookmarked ?? false,
      lastSecondSeen: Int64(_wireProgress(episode.lastPageRead)),
      dateFetch: Int64(0),
      dateUpload: Int64(int.tryParse(episode.dateUpload ?? '') ?? 0),
      episodeNumber: episode.chapterNumber ?? _chapterNumber(episode.name),
      sourceOrder: Int64(sourceOrder),
      lastModifiedAt: Int64(modified),
      version: Int64.ZERO,
      totalSeconds: Int64(int.tryParse(episode.duration ?? '') ?? 0),
      fillermark: episode.isFiller ?? false,
      summary: episode.description,
      previewUrl: episode.thumbnailUrl,
    );
  }

  /// Chimahon identifies history by its parent and chapter URL, while older
  /// Mangatan databases can contain more than one History row for a chapter.
  /// Project those rows onto one wire record and retain the greatest known
  /// values for both monotonic fields. Taking the maximum duration instead of
  /// summing avoids double-counting duplicate database rows. Local History has
  /// no protobuf unknown-field representation, so no opaque data is discarded
  /// by this projection.
  List<BackupHistory> _backupHistory(
    Iterable<History> histories,
    Map<int, Chapter> chaptersById,
  ) {
    final byUrl = <String, BackupHistory>{};
    for (final history in histories) {
      final chapter = history.chapterId == null
          ? null
          : chaptersById[history.chapterId!];
      final url = chapter?.url;
      if (url == null || url.isEmpty) continue;

      final lastRead = Int64(int.tryParse(history.date ?? '') ?? 0);
      final readDuration = Int64((history.readingTimeSeconds ?? 0) * 1000);
      final existing = byUrl[url];
      if (existing == null) {
        byUrl[url] = BackupHistory(
          url: url,
          lastRead: lastRead,
          readDuration: readDuration,
        );
        continue;
      }
      if (lastRead > existing.lastRead) existing.lastRead = lastRead;
      if (readDuration > existing.readDuration) {
        existing.readDuration = readDuration;
      }
    }
    final projected = byUrl.values.toList()
      ..sort((left, right) => left.url.compareTo(right.url));
    return List.unmodifiable(projected);
  }

  int? _nativeSourceId(Source? source) {
    if (source == null) return null;
    final metadata = mihonSourceMetadata(source);
    if (metadata != null) return int.tryParse(metadata.sourceId);
    // Mangatan's local Mihon ID is a hash and is not portable. A source with
    // missing native metadata cannot be represented compatibly.
    return null;
  }

  /// File-picker and drag-and-drop chapters are a device-local overlay. Source
  /// chapters downloaded for offline use remain portable because their source
  /// URL differs from their archive path.
  bool _isChimahonPortableChapter(Chapter chapter) =>
      const ChimahonLocalChapterPolicy().hasPortableIdentity(chapter);

  /// Mangatan stores `1` as its no-resume sentinel. Mihon and Chimahon use
  /// zero, so sending the local sentinel verbatim would mark every untouched
  /// chapter or episode as partially consumed.
  int _wireProgress(String? progress) {
    final parsed = int.tryParse(progress ?? '');
    return parsed != null && parsed > 1 ? parsed : 0;
  }

  double _chapterNumber(String? name) {
    final matches = RegExp(r'\d+(?:\.\d+)?').allMatches(name ?? '').toList();
    return matches.isEmpty
        ? 0
        : double.tryParse(matches.last.group(0) ?? '') ?? 0;
  }

  /// Mangatan normally stores timestamps in milliseconds, while Chimahon's
  /// sync columns are SQLite `strftime('%s', 'now')` epoch seconds. Imported
  /// Chimahon rows can already contain seconds, so normalize both forms.
  int _epochSeconds(int? value) {
    final timestamp = value ?? 0;
    if (timestamp.abs() < 100000000000) return timestamp;
    // Imported Chimahon clocks are exact-second millisecond values. A local
    // edit later in that same second has a remainder; round it up so it does
    // not tie the imported versioned record and get discarded.
    return timestamp % 1000 == 0
        ? timestamp ~/ 1000
        : (timestamp + 999) ~/ 1000;
  }

  int _epochSecondsFloor(int? value) {
    final timestamp = value ?? 0;
    return timestamp.abs() >= 100000000000 ? timestamp ~/ 1000 : timestamp;
  }

  /// Rows created before favorite tombstones were added have no explicit
  /// favorite clock. A favorite's date-added value is the closest semantic
  /// equivalent because Mangatan updates it whenever the title enters the
  /// library. If that semantic timestamp is absent, leave the field absent
  /// instead of guessing from an unrelated metadata refresh.
  int? _favoriteModifiedAt(Manga manga) {
    if (manga.favoriteModifiedAt case final timestamp?) return timestamp;
    if (!(manga.favorite ?? false)) return null;
    final dateAdded = _epochSecondsFloor(manga.dateAdded);
    if (dateAdded > 0) return dateAdded;
    return null;
  }

  /// A non-favorite row is a portable deletion marker, not an authoritative
  /// projection of Mangatan's source cache. Its pre-existing metadata clock
  /// can be newer than the remote tombstone that first made the cache row
  /// exportable. Use the independent favorite clock for that parent so merely
  /// importing a tombstone cannot promote stale cached metadata on the next
  /// sync. A genuine local unfavorite advances this clock, and a later
  /// re-favorite resumes normal record/tracking clock handling below.
  int _parentModifiedAt({
    required Manga manga,
    required int? favoriteModifiedAt,
    required Iterable<Track> tracks,
    required Iterable<ChimahonTrackingDeletion> deletedTracks,
  }) {
    if (manga.favorite == false && favoriteModifiedAt != null) {
      return favoriteModifiedAt;
    }
    return _latestPortableModifiedAt(
      manga.updatedAt ?? manga.lastUpdate,
      tracks,
      deletedTracks,
    );
  }

  int _latestPortableModifiedAt(
    int? recordModifiedAt,
    Iterable<Track> tracks,
    Iterable<ChimahonTrackingDeletion> deletedTracks,
  ) {
    var latest = _epochSeconds(recordModifiedAt);
    const adapter = ChimahonTrackingAdapter();
    for (final track in tracks) {
      if (adapter.isSupportedTracker(track.syncId)) {
        final modified = _epochSeconds(track.updatedAt);
        if (modified > latest) latest = modified;
      }
    }
    for (final deletion in deletedTracks) {
      if (adapter.isSupportedTracker(deletion.syncId)) {
        final modified = _epochSeconds(deletion.modifiedAt);
        if (modified > latest) latest = modified;
      }
    }
    return latest;
  }

  int _status(Status status) => switch (status) {
    Status.ongoing => 1,
    Status.completed => 2,
    Status.publishingFinished => 4,
    Status.canceled => 5,
    Status.onHiatus => 6,
    Status.unknown => 0,
  };
}
