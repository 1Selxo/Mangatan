import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/changed.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';
import 'package:mangayomi/services/sync/chimahon_app_settings_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_mining_settings_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/chimahon_novel_materializer.dart';
import 'package:mangayomi/services/sync/chimahon_source_preferences_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/services/sync/chimahon_tracking_adapter.dart';
import 'package:mangayomi/services/sync/mihon_backup_exporter.dart';

typedef ChimahonMediaSyncSelectionProvider =
    ChimahonMediaSyncSelection Function();
typedef ChimahonMediaSelectionInitializedProvider = bool Function();
typedef ChimahonMediaSelectionUserSelectedProvider = bool Function();
typedef ChimahonMediaSelectionGenerationProvider = int Function();
typedef ChimahonMediaSelectionScopeTokenProvider = String? Function();
typedef ChimahonMediaSyncSelectionStateProvider =
    ChimahonMediaSyncSelectionState Function();

/// One complete, read-only projection of Mangatan's local state onto the
/// subset of the Chimahon backup format that Mangatan can represent.
///
/// The protobuf is recursively frozen and the collections are unmodifiable so
/// a preview or sync consumer cannot accidentally alter the state described by
/// this snapshot.
class ChimahonLocalSyncProjectionSnapshot {
  ChimahonLocalSyncProjectionSnapshot._({
    required BackupMihon backup,
    required Iterable<String> unrepresentablePreferenceKeys,
    required Iterable<ChimahonTrackingDeletionKey> trackingDeletionKeys,
    required Iterable<int> changedPartIds,
    required Map<ChimahonTrackingDeletionKey, List<int>>
    changedPartIdsByTrackingDeletionKey,
    required this.mediaSelection,
    required this.mediaSelectionInitialized,
    required this.mediaSelectionUserSelected,
    required this.mediaSelectionGeneration,
    required this.mediaSelectionScopeToken,
    required this.persistedMediaSelectionState,
  }) : backup = backup.deepCopy()..freeze(),
       unrepresentablePreferenceKeys = Set.unmodifiable(
         unrepresentablePreferenceKeys,
       ),
       trackingDeletionKeys = Set.unmodifiable(trackingDeletionKeys),
       changedPartIds = List.unmodifiable(changedPartIds),
       changedPartIdsByTrackingDeletionKey =
           Map<ChimahonTrackingDeletionKey, List<int>>.unmodifiable({
             for (final entry in changedPartIdsByTrackingDeletionKey.entries)
               entry.key: List<int>.unmodifiable(entry.value),
           });

  final BackupMihon backup;
  final Set<String> unrepresentablePreferenceKeys;
  final Set<ChimahonTrackingDeletionKey> trackingDeletionKeys;

  /// IDs of valid tracker-deletion markers represented by this snapshot.
  ///
  /// A caller may remove these only after the corresponding conditional
  /// upload succeeds. Invalid or currently unportable markers remain queued.
  final List<int> changedPartIds;

  /// Maps portable tracker deletion evidence back to its queued local marker
  /// so callers only clear markers that survived media filtering and upload.
  final Map<ChimahonTrackingDeletionKey, List<int>>
  changedPartIdsByTrackingDeletionKey;

  /// The persisted local selection used to encode this snapshot's three
  /// backed Chimahon preferences. The engine may replace it from the current
  /// remote once for an uninitialized account.
  final ChimahonMediaSyncSelection mediaSelection;
  final bool mediaSelectionInitialized;
  final bool mediaSelectionUserSelected;
  final int mediaSelectionGeneration;
  final String? mediaSelectionScopeToken;
  final ChimahonMediaSyncSelectionState persistedMediaSelectionState;
}

/// Builds the local Chimahon payload used by normal sync and dry-run preview.
///
/// Database reads and asynchronous mining-preference reads live here so normal
/// sync and preview share one projection pipeline. Read-only callers explicitly
/// suppress lazy store creation/migration and decode a detached snapshot when
/// the mining-preference box has not already been opened by the app.
class ChimahonLocalSyncProjectionService {
  const ChimahonLocalSyncProjectionService({
    required this.database,
    this.dictionaryStorage,
    this.readOnly = false,
    this.mediaSelection = const ChimahonMediaSyncSelection(),
    this.mediaSelectionInitialized = false,
    this.mediaSelectionUserSelected = false,
    this.mediaSelectionGeneration = 0,
    this.mediaSelectionScopeToken,
    this.activeMediaSelectionScopeToken,
    this.mediaSelectionStateProvider,
    this.mediaSelectionProvider,
    this.mediaSelectionInitializedProvider,
    this.mediaSelectionUserSelectedProvider,
    this.mediaSelectionGenerationProvider,
    this.mediaSelectionScopeTokenProvider,
  });

  final Isar database;

  /// Optional only to make the asynchronous dictionary-order dependency
  /// explicit and independently testable. Production uses the shared store.
  final DictionaryStorage? dictionaryStorage;

  /// Prevents lazy preference migration and application-support directory
  /// creation while constructing a diagnostic/dry-run projection.
  final bool readOnly;
  final ChimahonMediaSyncSelection mediaSelection;
  final bool mediaSelectionInitialized;
  final bool mediaSelectionUserSelected;
  final int mediaSelectionGeneration;
  final String? mediaSelectionScopeToken;
  final String? activeMediaSelectionScopeToken;
  final ChimahonMediaSyncSelectionProvider? mediaSelectionProvider;
  final ChimahonMediaSelectionInitializedProvider?
  mediaSelectionInitializedProvider;
  final ChimahonMediaSelectionUserSelectedProvider?
  mediaSelectionUserSelectedProvider;
  final ChimahonMediaSelectionGenerationProvider?
  mediaSelectionGenerationProvider;
  final ChimahonMediaSelectionScopeTokenProvider?
  mediaSelectionScopeTokenProvider;
  final ChimahonMediaSyncSelectionStateProvider? mediaSelectionStateProvider;

  Future<ChimahonLocalSyncProjectionSnapshot> createSnapshot() async {
    final persistedMediaSelectionState =
        mediaSelectionStateProvider?.call() ??
        ChimahonMediaSyncSelectionState(
          selection: mediaSelectionProvider?.call() ?? mediaSelection,
          initialized:
              mediaSelectionInitializedProvider?.call() ??
              mediaSelectionInitialized,
          userSelected:
              mediaSelectionUserSelectedProvider?.call() ??
              mediaSelectionUserSelected,
          generation:
              mediaSelectionGenerationProvider?.call() ??
              mediaSelectionGeneration,
          scopeToken:
              mediaSelectionScopeTokenProvider?.call() ??
              mediaSelectionScopeToken,
        );
    final activeScopeToken = activeMediaSelectionScopeToken;
    final currentMediaSelection = activeScopeToken == null
        ? persistedMediaSelectionState.selection
        : persistedMediaSelectionState.selectionForScope(activeScopeToken);
    final currentMediaSelectionInitialized = activeScopeToken == null
        ? persistedMediaSelectionState.initialized ||
              persistedMediaSelectionState.userSelected
        : persistedMediaSelectionState.isInitializedForScope(activeScopeToken);
    final trackingDeletions = _trackingDeletionState();
    final settings = database.settings.getSync(227);
    final settingsProjection = settings == null
        ? null
        : const ChimahonAppSettingsAdapter().project(settings);
    final sources = database.sources.filter().idIsNotNull().findAllSync();
    final miningProjection = await const ChimahonMiningSettingsAdapter()
        .project(
          dictionaryStorage: dictionaryStorage,
          portableSourceIds: chimahonPortableSourceOverrideIds(sources),
          readOnly: readOnly,
        );
    final appPreferences = [
      if (settingsProjection != null) ...settingsProjection.preferences,
      ...miningProjection.preferences,
    ];
    final sourcePreferences = const ChimahonSourcePreferencesAdapter().export(
      sources: sources,
      storedPreferences: database.sourcePreferences.where().findAllSync(),
    );
    final localMangas = database.mangas.filter().idIsNotNull().findAllSync();
    final localCategories = database.categorys
        .filter()
        .idIsNotNull()
        .findAllSync();
    final localChapters = database.chapters
        .filter()
        .idIsNotNull()
        .findAllSync();
    final localNovelProgress = database.epubBookProgress.where().findAllSync();
    final cloudCacheParentIds = const ChimahonNovelMaterializer()
        .exactCloudNovelParentIds(
          localMangas: localMangas,
          localProgress: localNovelProgress,
          localChapters: localChapters,
        );
    final syncMangas = localMangas
        .where((manga) => !cloudCacheParentIds.contains(manga.id))
        .toList(growable: false);
    final realNovelParentIds = localNovelProgress
        .where((progress) => progress.archivePath.trim().isNotEmpty)
        .map((progress) => progress.mangaId)
        .toSet();
    final liveNovelCategoryIds = localMangas
        .where(
          (manga) =>
              manga.itemType == ItemType.novel &&
              realNovelParentIds.contains(manga.id),
        )
        .expand((manga) => manga.categories ?? const <int>[])
        .toSet();
    final syncCategories = localCategories.where(
      (category) =>
          category.forItemType != ItemType.novel ||
          (category.updatedAt ?? 0) > 0 ||
          (category.id != null && liveNovelCategoryIds.contains(category.id)),
    );
    final exported = const MihonBackupExporter().export(
      // Exact empty-path Chimahon parents are a remote cache. Excluding both
      // those parents and zero-clock categories used only by remote cache
      // prevents Drive account A's imported definitions from becoming local
      // intent in B. Categories created/edited locally carry a nonzero clock.
      mangas: syncMangas,
      categories: syncCategories,
      chapters: localChapters,
      histories: database.historys.filter().idIsNotNull().findAllSync(),
      sources: sources,
      // Empty-path rows are remote cache projections for visible missing-EPUB
      // placeholders, not local novel intent. The downloaded/deferred payload
      // supplies them during merge; exporting them before account scope is
      // resolved could otherwise leak account A's ghost into account B.
      epubBookProgress: localNovelProgress.where(
        (progress) => progress.archivePath.trim().isNotEmpty,
      ),
      tracks: database.tracks.filter().idIsNotNull().findAllSync(),
      deletedTracks: trackingDeletions.deletions,
      appPreferences: appPreferences,
      sourcePreferences: sourcePreferences,
    );
    // Keep every local media record until the engine has read the current
    // remote and can safely resolve a first-contact selection. Only the exact
    // preference rows are part of this raw snapshot.
    final backup = currentMediaSelection.withBackedPreferences(exported);
    return ChimahonLocalSyncProjectionSnapshot._(
      backup: backup,
      unrepresentablePreferenceKeys: {
        ...?settingsProjection?.unrepresentableKeys,
        ...miningProjection.unrepresentableKeys,
      },
      trackingDeletionKeys: trackingDeletions.keys,
      changedPartIds: trackingDeletions.changedPartIds,
      changedPartIdsByTrackingDeletionKey:
          trackingDeletions.changedPartIdsByTrackingDeletionKey,
      mediaSelection: currentMediaSelection,
      mediaSelectionInitialized: currentMediaSelectionInitialized,
      mediaSelectionUserSelected: persistedMediaSelectionState.userSelected,
      mediaSelectionGeneration: persistedMediaSelectionState.generation,
      mediaSelectionScopeToken: persistedMediaSelectionState.scopeToken,
      persistedMediaSelectionState: persistedMediaSelectionState,
    );
  }

  ({
    List<ChimahonTrackingDeletion> deletions,
    Set<ChimahonTrackingDeletionKey> keys,
    List<int> changedPartIds,
    Map<ChimahonTrackingDeletionKey, List<int>>
    changedPartIdsByTrackingDeletionKey,
  })
  _trackingDeletionState() {
    const adapter = ChimahonTrackingAdapter();
    final deletions = <ChimahonTrackingDeletion>[];
    final keys = <ChimahonTrackingDeletionKey>{};
    final changedPartIds = <int>[];
    final changedPartIdsByTrackingDeletionKey =
        <ChimahonTrackingDeletionKey, List<int>>{};
    final sourcesById = {
      for (final source
          in database.sources.filter().idIsNotNull().findAllSync())
        source.id!: source,
    };
    for (final marker
        in database.changedParts
            .filter()
            .actionTypeEqualTo(ActionType.removeTrack)
            .findAllSync()) {
      final decoded = ChimahonTrackingDeletionMarker.tryDecode(marker.data);
      if (decoded == null) continue;
      final mangaId = decoded.mangaId;
      final trackerId = decoded.syncId;
      if (mangaId is! int ||
          trackerId is! int ||
          !adapter.isSupportedTracker(trackerId)) {
        continue;
      }
      final manga = database.mangas.getSync(mangaId);
      final source = manga?.sourceId == null
          ? null
          : sourcesById[manga!.sourceId!];
      final nativeSource = source == null
          ? null
          : int.tryParse(mihonSourceMetadata(source)?.sourceId ?? '');
      final portableUrl = manga?.link?.trim() ?? '';
      if (manga == null ||
          manga.isLocalArchive == true ||
          nativeSource == null ||
          portableUrl.isEmpty ||
          marker.id == null) {
        continue;
      }
      final deletion = ChimahonTrackingDeletion(
        mangaId: mangaId,
        syncId: trackerId,
        modifiedAt: decoded.modifiedAt,
      );
      deletions.add(deletion);
      keys.add((source: nativeSource, url: portableUrl, syncId: trackerId));
      changedPartIds.add(marker.id!);
      changedPartIdsByTrackingDeletionKey
          .putIfAbsent((
            source: nativeSource,
            url: portableUrl,
            syncId: trackerId,
          ), () => [])
          .add(marker.id!);
    }
    return (
      deletions: deletions,
      keys: keys,
      changedPartIds: changedPartIds,
      changedPartIdsByTrackingDeletionKey: changedPartIdsByTrackingDeletionKey,
    );
  }
}
