import 'package:crypto/crypto.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_local_chapter_policy.dart';
import 'package:mangayomi/services/sync/chimahon_local_revision.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/chimahon_sync_importer.dart';

/// Immutable preflight for an explicit, authoritative Chimahon download.
class ChimahonDownloadPlan {
  ChimahonDownloadPlan({
    required BackupMihon backup,
    required this.selection,
    required BackupMihon localProjection,
    required Iterable<Manga> localMangas,
    required Iterable<Chapter> localChapters,
    Iterable<Source> localSources = const [],
    Set<int> downloadedChapterIds = const {},
    ChimahonLocalRevision? localRevision,
  }) : backup = backup.deepCopy()..freeze(),
       localFingerprint = _fingerprint(localProjection),
       localRevision =
           localRevision ??
           ChimahonLocalRevision(_fingerprint(localProjection)),
       remoteMangaFavorites = selection.manga
           ? backup.backupManga
                 .where((manga) => !manga.hasFavorite() || manga.favorite)
                 .length
           : 0,
       remoteAnimeFavorites = selection.anime
           ? backup.backupAnime
                 .where((anime) => !anime.hasFavorite() || anime.favorite)
                 .length
           : 0,
       remoteNovels = selection.novels ? backup.backupNovels.length : 0,
       estimatedMangaRemovals = _estimatedRemovals(
         selection: selection,
         backup: backup,
         localSources: localSources,
         localMangas: localMangas,
         localChapters: localChapters,
         downloadedChapterIds: downloadedChapterIds,
         itemType: ItemType.manga,
       ),
       estimatedAnimeRemovals = _estimatedRemovals(
         selection: selection,
         backup: backup,
         localSources: localSources,
         localMangas: localMangas,
         localChapters: localChapters,
         downloadedChapterIds: downloadedChapterIds,
         itemType: ItemType.anime,
       ),
       deviceLocalRowsRetained = _deviceLocalRows(
         selection: selection,
         localMangas: localMangas,
         localChapters: localChapters,
         downloadedChapterIds: downloadedChapterIds,
       );

  final BackupMihon backup;
  final ChimahonMediaSyncSelection selection;
  final String localFingerprint;
  final ChimahonLocalRevision localRevision;
  final int remoteMangaFavorites;
  final int remoteAnimeFavorites;
  final int remoteNovels;
  final int estimatedMangaRemovals;
  final int estimatedAnimeRemovals;
  final int deviceLocalRowsRetained;

  int get estimatedPortableRemovals =>
      estimatedMangaRemovals + estimatedAnimeRemovals;

  String get confirmationSummary {
    final scopes = <String>[
      if (selection.manga)
        'Manga: $remoteMangaFavorites remote, '
            '$estimatedMangaRemovals projected removal(s)',
      if (selection.anime)
        'Anime: $remoteAnimeFavorites remote, '
            '$estimatedAnimeRemovals projected removal(s)',
      if (selection.novels) 'Novels: $remoteNovels remote',
    ];
    return [
      'Download only will make the enabled Chimahon scopes authoritative.',
      ...scopes,
      '$deviceLocalRowsRetained device-local row(s) will be retained.',
      'An enabled scope with 0 remote entries will have its portable local '
          'entries removed.',
    ].join('\n');
  }

  bool matchesLocalProjection(BackupMihon projection) =>
      localFingerprint == _fingerprint(projection);

  bool matchesLocalRevision(ChimahonLocalRevision revision) =>
      localRevision.value == revision.value;

  ChimahonDownloadResult complete(ChimahonSyncImportResult imported) =>
      ChimahonDownloadResult(
        titlesCreated: imported.titlesCreated,
        titlesUpdated: imported.titlesUpdated,
        titlesRemoved: imported.titlesRemoved,
        duplicatesRepaired: imported.duplicatesRepaired,
        sourcesRebound: imported.sourcesRebound,
        sourcesUnavailable: imported.sourcesUnavailable,
        sourcesUnresolved: imported.sourcesUnresolved,
        ambiguousRowsRetained: imported.ambiguousRowsRetained,
      );

  static String _fingerprint(BackupMihon backup) =>
      sha256.convert(backup.writeToBuffer()).toString();

  static int _estimatedRemovals({
    required ChimahonMediaSyncSelection selection,
    required BackupMihon backup,
    required Iterable<Source> localSources,
    required Iterable<Manga> localMangas,
    required Iterable<Chapter> localChapters,
    required Set<int> downloadedChapterIds,
    required ItemType itemType,
  }) {
    return const ChimahonSyncImporter().estimateAuthoritativeRemovals(
      backup: backup,
      selection: selection,
      localSources: localSources,
      localMangas: localMangas,
      localChapters: localChapters,
      downloadedChapterIds: downloadedChapterIds,
      itemType: itemType,
    );
  }

  static int _deviceLocalRows({
    required ChimahonMediaSyncSelection selection,
    required Iterable<Manga> localMangas,
    required Iterable<Chapter> localChapters,
    required Set<int> downloadedChapterIds,
  }) {
    final selectedIds = localMangas
        .where(
          (manga) =>
              manga.id != null &&
              ((selection.manga && manga.itemType == ItemType.manga) ||
                  (selection.anime && manga.itemType == ItemType.anime)),
        )
        .map((manga) => manga.id!)
        .toSet();
    final chapterParentIds = localChapters
        .where(
          (chapter) =>
              selectedIds.contains(chapter.mangaId) &&
              (const ChimahonLocalChapterPolicy().isDeviceLocal(chapter) ||
                  (chapter.archivePath?.trim().isNotEmpty ?? false) ||
                  downloadedChapterIds.contains(chapter.id)),
        )
        .map((chapter) => chapter.mangaId)
        .nonNulls
        .toSet();
    return localMangas
        .where(
          (manga) =>
              selectedIds.contains(manga.id) &&
              (manga.isLocalArchive == true ||
                  manga.hasLocalChapterOverlay == true ||
                  chapterParentIds.contains(manga.id)),
        )
        .length;
  }
}

class ChimahonDownloadResult {
  const ChimahonDownloadResult({
    required this.titlesCreated,
    required this.titlesUpdated,
    required this.titlesRemoved,
    required this.duplicatesRepaired,
    required this.sourcesRebound,
    required this.sourcesUnavailable,
    required this.sourcesUnresolved,
    required this.ambiguousRowsRetained,
  });

  final int titlesCreated;
  final int titlesUpdated;
  final int titlesRemoved;
  final int duplicatesRepaired;
  final int sourcesRebound;
  final int sourcesUnavailable;
  final int sourcesUnresolved;
  final int ambiguousRowsRetained;

  String get summary => [
    'Downloaded: $titlesCreated new, $titlesUpdated updated, '
        '$titlesRemoved removed',
    if (duplicatesRepaired > 0) '$duplicatesRepaired duplicate(s) repaired',
    if (sourcesRebound > 0) '$sourcesRebound source binding(s) repaired',
    if (sourcesUnavailable > 0)
      '$sourcesUnavailable factory source(s) unavailable',
    if (sourcesUnresolved > 0)
      '$sourcesUnresolved factory group(s) require reconciliation retry',
    if (ambiguousRowsRetained > 0)
      '$ambiguousRowsRetained local-only row(s) retained',
  ].join('. ');
}
