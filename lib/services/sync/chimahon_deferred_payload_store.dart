import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:path_provider/path_provider.dart';

const _deferredPayloadFileName = 'chimahon_deferred.tachibk';
const _localPreferenceBaselineFileName =
    'chimahon_local_preference_baseline.tachibk';
const _localSourcePreferenceBaselineFileName =
    'chimahon_local_source_preference_baseline.tachibk';
const _pendingManualRestoreFileName = 'chimahon_pending_restore.tachibk';
const _pendingManualRestoreStateFileName = 'chimahon_pending_restore.state';

Future<FileChimahonDeferredPayloadStore> defaultChimahonDeferredPayloadStore({
  required String scopeKey,
  Directory? applicationSupportDirectory,
  bool readOnly = false,
}) async {
  if (scopeKey.isEmpty) {
    throw ArgumentError.value(scopeKey, 'scopeKey', 'Must not be empty');
  }
  final support =
      applicationSupportDirectory ?? await getApplicationSupportDirectory();
  final scopeDigest = sha256.convert(utf8.encode(scopeKey)).toString();
  return FileChimahonDeferredPayloadStore(
    File(
      '${support.path}${Platform.pathSeparator}sync'
      '${Platform.pathSeparator}chimahon'
      '${Platform.pathSeparator}$scopeDigest'
      '${Platform.pathSeparator}$_deferredPayloadFileName',
    ),
    readOnly: readOnly,
  );
}

/// Stores the complete protobuf selected by an explicit backup restore until
/// it has been incorporated into a successful Chimahon upload. Unlike the
/// account-scoped deferred cache, this must retain media rows and their future
/// unknown fields/version counters: some of them cannot be represented by the
/// current Mangatan database yet.
Future<FileChimahonPendingManualRestoreStore>
defaultChimahonPendingManualRestoreStore({
  Directory? applicationSupportDirectory,
  bool readOnly = false,
}) async {
  final support =
      applicationSupportDirectory ?? await getApplicationSupportDirectory();
  final payloadFile = File(
    '${support.path}${Platform.pathSeparator}sync'
    '${Platform.pathSeparator}chimahon'
    '${Platform.pathSeparator}manual_restore'
    '${Platform.pathSeparator}$_pendingManualRestoreFileName',
  );
  return FileChimahonPendingManualRestoreStore(
    payloadFile,
    stateFile: File(
      '${payloadFile.parent.path}${Platform.pathSeparator}'
      '$_pendingManualRestoreStateFileName',
    ),
    readOnly: readOnly,
  );
}

/// A pending manual restore is the only copy of fields Mangatan cannot project
/// into its database. Corruption must therefore stop synchronization instead
/// of being treated like a recoverable account cache miss.
class ChimahonDeferredPayloadCorruptionException implements Exception {
  const ChimahonDeferredPayloadCorruptionException(this.corruptPaths);

  final List<String> corruptPaths;

  @override
  String toString() =>
      'Stored Chimahon manual-restore data is corrupt. Restore the original '
      'backup again before syncing. Corrupt file: ${corruptPaths.join(', ')}';
}

enum ChimahonPendingManualRestorePhase { absent, preparing, ready }

/// Indicates that a selected backup did not reach the durable `ready` phase.
/// Sync must remain blocked because its pending protobuf may be the only copy
/// of fields that Mangatan cannot represent locally.
class ChimahonPendingManualRestoreIncompleteException implements Exception {
  const ChimahonPendingManualRestoreIncompleteException(this.phase);

  final ChimahonPendingManualRestorePhase phase;

  @override
  String toString() =>
      'The pending Chimahon manual restore is ${phase.name}. Restore the '
      'original backup again and let it finish before syncing.';
}

abstract interface class ChimahonDeferredPayloadStore {
  Future<BackupMihon?> load();

  Future<void> save(BackupMihon backup);
}

/// Optional one-shot local intent layered above an account's last successful
/// remote baseline.
///
/// A normal deferred payload is evidence of what the remote used to contain;
/// treating it as current local data would resurrect records another client
/// deleted. An explicitly selected manual restore is different: its complete
/// payload must participate in the next upload even when Mangatan cannot
/// project all of its fields into the local database.
abstract interface class ChimahonPendingLocalPayloadStore {
  Future<BackupMihon?> loadPendingLocalPayload();
}

/// Post-import projection captured alongside a pending manual restore.
///
/// It lets the next upload distinguish a real edit made after restore from a
/// lossy or unsupported value which never entered Mangatan's local model.
abstract interface class ChimahonPendingLocalProjectionBaselineStore {
  Future<List<BackupPreference>?> loadPendingLocalPreferenceBaseline();

  Future<List<BackupSourcePreferences>?>
  loadPendingLocalSourcePreferenceBaseline();
}

abstract interface class ClearableChimahonDeferredPayloadStore
    implements ChimahonDeferredPayloadStore {
  Future<void> clear();
}

/// Optional companion state used to distinguish an actual local settings edit
/// from a lossy Chimahon -> Mangatan representation.
abstract interface class ChimahonLocalPreferenceBaselineStore {
  Future<List<BackupPreference>?> loadLocalPreferenceBaseline();

  Future<void> saveLocalPreferenceBaseline(
    Iterable<BackupPreference> preferences,
  );
}

/// Optional companion state used to distinguish edits to an installed
/// source's projected preferences from opaque or uninstalled source stores.
abstract interface class ChimahonLocalSourcePreferenceBaselineStore {
  Future<List<BackupSourcePreferences>?> loadLocalSourcePreferenceBaseline();

  Future<void> saveLocalSourcePreferenceBaseline(
    Iterable<BackupSourcePreferences> preferences,
  );
}

/// Durable two-phase lifecycle for an explicitly selected manual restore.
abstract interface class ChimahonPendingManualRestoreLifecycleStore
    implements
        ClearableChimahonDeferredPayloadStore,
        ChimahonLocalPreferenceBaselineStore,
        ChimahonLocalSourcePreferenceBaselineStore {
  Future<void> beginPreparing(BackupMihon backup);

  Future<void> markReady();

  Future<ChimahonPendingManualRestorePhase> loadRestorePhase();

  Future<void> ensureReadyForSync();
}

/// Retains fields whose app features are not wired yet (notably novels,
/// language profiles, and statistics). This makes a Chimahon -> Mangatan ->
/// Chimahon round-trip non-destructive while those screens/models evolve.
class FileChimahonDeferredPayloadStore
    implements
        ClearableChimahonDeferredPayloadStore,
        ChimahonLocalPreferenceBaselineStore,
        ChimahonLocalSourcePreferenceBaselineStore {
  FileChimahonDeferredPayloadStore(
    this.file, {
    File? localPreferenceBaselineFile,
    File? localSourcePreferenceBaselineFile,
    this.retainMediaRecords = false,
    this.failOnCorruption = false,
    this.readOnly = false,
    this.codec = const ChimahonSyncCodec(),
  }) : localPreferenceBaselineFile =
           localPreferenceBaselineFile ??
           File(
             '${file.parent.path}${Platform.pathSeparator}'
             '$_localPreferenceBaselineFileName',
           ),
       localSourcePreferenceBaselineFile =
           localSourcePreferenceBaselineFile ??
           File(
             '${file.parent.path}${Platform.pathSeparator}'
             '$_localSourcePreferenceBaselineFileName',
           );

  final File file;
  final File localPreferenceBaselineFile;
  final File localSourcePreferenceBaselineFile;
  final bool retainMediaRecords;
  final bool failOnCorruption;
  final bool readOnly;
  final ChimahonSyncCodec codec;

  @override
  Future<BackupMihon?> load() async {
    return _loadBackup(file);
  }

  @override
  Future<void> save(BackupMihon backup) async {
    _ensureWritable();
    if (retainMediaRecords) {
      // Invalidate evidence before replacing the exact payload. If either the
      // deletion or later atomic write fails, the remaining state has no stale
      // baseline and therefore falls back to preserving the selected bytes.
      await _deleteFileAndPrevious(localPreferenceBaselineFile);
      await _deleteFileAndPrevious(localSourcePreferenceBaselineFile);
    }
    final deferred = retainMediaRecords
        ? backup.deepCopy()
        : (BackupMihon(
            backupPreferences: backup.backupPreferences,
            backupSourcePreferences: backup.backupSourcePreferences,
            backupExtensionRepo: backup.backupExtensionRepo,
            backupAnimeExtensionRepo: backup.backupAnimeExtensionRepo,
            backupSavedSearches: backup.backupSavedSearches,
            backupFeeds: backup.backupFeeds,
            backupNovels: backup.backupNovels,
            backupNovelCategories: backup.backupNovelCategories,
            backupMangaStats: backup.backupMangaStats,
            backupAnkiStats: backup.backupAnkiStats,
          )..mergeUnknownFields(backup.unknownFields));
    await _atomicWrite(
      file,
      codec.encode(deferred, format: ChimahonSyncWireFormat.gzipProtobuf),
    );
  }

  @override
  Future<void> clear() async {
    _ensureWritable();
    await _deleteFileAndPrevious(file);
    await _deleteFileAndPrevious(localPreferenceBaselineFile);
    await _deleteFileAndPrevious(localSourcePreferenceBaselineFile);
  }

  @override
  Future<List<BackupPreference>?> loadLocalPreferenceBaseline() async {
    final backup = await _loadBackup(localPreferenceBaselineFile);
    if (backup == null) return null;
    return [for (final preference in backup.backupPreferences) preference];
  }

  @override
  Future<void> saveLocalPreferenceBaseline(
    Iterable<BackupPreference> preferences,
  ) async {
    _ensureWritable();
    await _atomicWrite(
      localPreferenceBaselineFile,
      codec.encode(
        BackupMihon(backupPreferences: preferences),
        format: ChimahonSyncWireFormat.gzipProtobuf,
      ),
    );
  }

  @override
  Future<List<BackupSourcePreferences>?>
  loadLocalSourcePreferenceBaseline() async {
    final backup = await _loadBackup(localSourcePreferenceBaselineFile);
    if (backup == null) return null;
    return [
      for (final preferences in backup.backupSourcePreferences) preferences,
    ];
  }

  @override
  Future<void> saveLocalSourcePreferenceBaseline(
    Iterable<BackupSourcePreferences> preferences,
  ) async {
    _ensureWritable();
    await _atomicWrite(
      localSourcePreferenceBaselineFile,
      codec.encode(
        BackupMihon(backupSourcePreferences: preferences),
        format: ChimahonSyncWireFormat.gzipProtobuf,
      ),
    );
  }

  Future<BackupMihon?> _loadBackup(File target) async {
    // Windows cannot atomically replace an existing file. `_atomicWrite`
    // briefly moves the current file to `.previous` before installing its
    // replacement, so only a missing current file is evidence that this
    // interrupted-rename recovery path should be used. A present but corrupt
    // current file must never be masked by an older, valid `.previous` file.
    final currentExists = await target.exists();
    final candidates = <File>[
      currentExists ? target : _previousFile(target),
      // Account caches are recoverable hints, so a corrupt current cache may
      // fall back to the valid Windows recovery copy. The strict pending
      // manual-restore store deliberately never takes this branch.
      if (currentExists && !failOnCorruption) _previousFile(target),
    ];
    for (final candidate in candidates) {
      if (!await candidate.exists()) continue;
      try {
        return codec.decode(await candidate.readAsBytes()).backup;
      } on ChimahonSyncFormatException {
        if (failOnCorruption) {
          // Do not move the only authoritative copy of pending local intent.
          // It must keep blocking every retry until the user restores it.
          throw ChimahonDeferredPayloadCorruptionException([candidate.path]);
        }
        if (!readOnly) await _quarantine(candidate);
      }
    }
    return null;
  }

  void _ensureWritable() {
    if (readOnly) {
      throw UnsupportedError(
        'Cannot modify a read-only Chimahon deferred payload store.',
      );
    }
  }

  Future<void> _atomicWrite(File target, List<int> bytes) async {
    await target.parent.create(recursive: true);
    final suffix = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
    final temporary = File('${target.path}.tmp_$suffix');
    final previous = _previousFile(target);
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (Platform.isWindows && await target.exists()) {
        if (await previous.exists()) await previous.delete();
        await target.rename(previous.path);
        try {
          await temporary.rename(target.path);
        } catch (_) {
          if (!await target.exists() && await previous.exists()) {
            await previous.rename(target.path);
          }
          rethrow;
        }
        if (await previous.exists()) await previous.delete();
      } else {
        await temporary.rename(target.path);
      }
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  File _previousFile(File target) => File('${target.path}.previous');

  Future<void> _deleteFileAndPrevious(File target) async {
    // Remove the recovery copy first. If deleting the current file then fails,
    // a later load cannot mistake stale `.previous` data for an interrupted
    // Windows rename and resurrect older local intent.
    for (final candidate in [_previousFile(target), target]) {
      await _deleteFileIfPresent(candidate);
    }
  }

  Future<void> _deleteFileIfPresent(File candidate) async {
    try {
      await candidate.delete();
    } on FileSystemException {
      final type = await FileSystemEntity.type(
        candidate.path,
        followLinks: false,
      );
      if (type != FileSystemEntityType.notFound) rethrow;
    }
  }

  Future<void> _quarantine(File corrupt) async {
    final quarantine = File(
      '${corrupt.path}.corrupt_${DateTime.now().millisecondsSinceEpoch}',
    );
    try {
      await corrupt.rename(quarantine.path);
    } on FileSystemException {
      // Recovery must still be able to continue from the remote payload when
      // a local cache cannot be moved (for example, due to antivirus locking).
    }
  }
}

/// File-backed pending restore with a crash-safe preparing/ready marker.
///
/// A marker-less payload predating this lifecycle is treated as ready. New
/// restores write `preparing` before replacing either payload or baselines and
/// only transition to `ready` once both projection baselines are durable.
class FileChimahonPendingManualRestoreStore
    extends FileChimahonDeferredPayloadStore
    implements ChimahonPendingManualRestoreLifecycleStore {
  FileChimahonPendingManualRestoreStore(
    super.file, {
    required this.stateFile,
    super.readOnly,
    super.codec,
  }) : super(retainMediaRecords: true, failOnCorruption: true);

  static const _preparingMarker = 'v1:preparing\n';
  static const _readyMarker = 'v1:ready\n';

  final File stateFile;

  @override
  Future<void> beginPreparing(BackupMihon backup) async {
    _ensureWritable();
    await _writeMarker(_preparingMarker);
    await super.save(backup);
  }

  /// Retains the behavior of callers from before the two-phase API existed.
  /// The temporary preparing marker still makes an interrupted legacy save
  /// fail closed; successful legacy saves remain marker-less and thus ready.
  @override
  Future<void> save(BackupMihon backup) async {
    _ensureWritable();
    await _writeMarker(_preparingMarker);
    await super.save(backup);
    await _deleteFileAndPrevious(stateFile);
  }

  @override
  Future<void> markReady() async {
    _ensureWritable();
    final marker = await _readMarker();
    if (marker != _preparingMarker) {
      throw const ChimahonPendingManualRestoreIncompleteException(
        ChimahonPendingManualRestorePhase.absent,
      );
    }
    await _requireCompletePreparingState();
    await _writeMarker(_readyMarker);
  }

  @override
  Future<BackupMihon?> load() async {
    final backup = await super.load();
    final phase = await _resolvePhase(backup);
    if (phase == ChimahonPendingManualRestorePhase.preparing) {
      throw ChimahonPendingManualRestoreIncompleteException(phase);
    }
    return backup;
  }

  @override
  Future<ChimahonPendingManualRestorePhase> loadRestorePhase() async =>
      _resolvePhase(await super.load());

  @override
  Future<void> ensureReadyForSync() async {
    final phase = await loadRestorePhase();
    if (phase == ChimahonPendingManualRestorePhase.preparing) {
      throw ChimahonPendingManualRestoreIncompleteException(phase);
    }
  }

  @override
  Future<void> clear() async {
    await super.clear();
    // Delete the marker last. An interrupted clear therefore fails closed
    // instead of silently forgetting that pending local intent existed.
    await _deleteFileAndPrevious(stateFile);
  }

  Future<ChimahonPendingManualRestorePhase> _resolvePhase(
    BackupMihon? backup,
  ) async {
    final marker = await _readMarker();
    if (marker == _preparingMarker) {
      return ChimahonPendingManualRestorePhase.preparing;
    }
    if (marker == _readyMarker) {
      if (backup == null) {
        throw ChimahonDeferredPayloadCorruptionException([stateFile.path]);
      }
      final preferences = await super.loadLocalPreferenceBaseline();
      final sourcePreferences = await super.loadLocalSourcePreferenceBaseline();
      if (preferences == null || sourcePreferences == null) {
        throw const ChimahonPendingManualRestoreIncompleteException(
          ChimahonPendingManualRestorePhase.preparing,
        );
      }
      return ChimahonPendingManualRestorePhase.ready;
    }
    // Existing installs can have a complete pending payload but no phase
    // marker. Preserve that pre-upgrade contract as ready.
    return backup == null
        ? ChimahonPendingManualRestorePhase.absent
        : ChimahonPendingManualRestorePhase.ready;
  }

  Future<void> _requireCompletePreparingState() async {
    final backup = await super.load();
    final preferences = await super.loadLocalPreferenceBaseline();
    final sourcePreferences = await super.loadLocalSourcePreferenceBaseline();
    if (backup == null || preferences == null || sourcePreferences == null) {
      throw const ChimahonPendingManualRestoreIncompleteException(
        ChimahonPendingManualRestorePhase.preparing,
      );
    }
  }

  Future<String?> _readMarker() async {
    final candidate = await stateFile.exists()
        ? stateFile
        : _previousFile(stateFile);
    if (!await candidate.exists()) return null;
    late final String marker;
    try {
      marker = await candidate.readAsString();
    } on FormatException {
      throw ChimahonDeferredPayloadCorruptionException([candidate.path]);
    }
    if (marker == _preparingMarker || marker == _readyMarker) return marker;
    throw ChimahonDeferredPayloadCorruptionException([candidate.path]);
  }

  Future<void> _writeMarker(String marker) =>
      _atomicWrite(stateFile, utf8.encode(marker));
}

/// Presents an account-scoped remote baseline alongside a one-shot manual
/// restore. The two payloads deliberately remain separate: only the manual
/// restore is local upload intent. It is consumed by [save], which the sync
/// engine calls after its conditional remote upload succeeds.
class LayeredChimahonDeferredPayloadStore
    implements
        ChimahonDeferredPayloadStore,
        ChimahonPendingLocalPayloadStore,
        ChimahonPendingLocalProjectionBaselineStore,
        ChimahonLocalPreferenceBaselineStore,
        ChimahonLocalSourcePreferenceBaselineStore {
  const LayeredChimahonDeferredPayloadStore({
    required this.primary,
    required this.pendingManualRestore,
  });

  final ChimahonDeferredPayloadStore primary;
  final ClearableChimahonDeferredPayloadStore pendingManualRestore;

  @override
  Future<BackupMihon?> load() => primary.load();

  @override
  Future<BackupMihon?> loadPendingLocalPayload() => pendingManualRestore.load();

  ChimahonLocalPreferenceBaselineStore? get _pendingPreferenceStore =>
      pendingManualRestore is ChimahonLocalPreferenceBaselineStore
      ? pendingManualRestore as ChimahonLocalPreferenceBaselineStore
      : null;

  ChimahonLocalSourcePreferenceBaselineStore?
  get _pendingSourcePreferenceStore =>
      pendingManualRestore is ChimahonLocalSourcePreferenceBaselineStore
      ? pendingManualRestore as ChimahonLocalSourcePreferenceBaselineStore
      : null;

  @override
  Future<List<BackupPreference>?> loadPendingLocalPreferenceBaseline() =>
      _pendingPreferenceStore?.loadLocalPreferenceBaseline() ??
      Future.value(null);

  @override
  Future<List<BackupSourcePreferences>?>
  loadPendingLocalSourcePreferenceBaseline() =>
      _pendingSourcePreferenceStore?.loadLocalSourcePreferenceBaseline() ??
      Future.value(null);

  @override
  Future<void> save(BackupMihon backup) async {
    await primary.save(backup);
    await pendingManualRestore.clear();
  }

  ChimahonLocalPreferenceBaselineStore? get _primaryPreferenceStore =>
      primary is ChimahonLocalPreferenceBaselineStore
      ? primary as ChimahonLocalPreferenceBaselineStore
      : null;

  ChimahonLocalSourcePreferenceBaselineStore?
  get _primarySourcePreferenceStore =>
      primary is ChimahonLocalSourcePreferenceBaselineStore
      ? primary as ChimahonLocalSourcePreferenceBaselineStore
      : null;

  @override
  Future<List<BackupPreference>?> loadLocalPreferenceBaseline() =>
      _primaryPreferenceStore?.loadLocalPreferenceBaseline() ??
      Future.value(null);

  @override
  Future<void> saveLocalPreferenceBaseline(
    Iterable<BackupPreference> preferences,
  ) =>
      _primaryPreferenceStore?.saveLocalPreferenceBaseline(preferences) ??
      Future.value();

  @override
  Future<List<BackupSourcePreferences>?> loadLocalSourcePreferenceBaseline() =>
      _primarySourcePreferenceStore?.loadLocalSourcePreferenceBaseline() ??
      Future.value(null);

  @override
  Future<void> saveLocalSourcePreferenceBaseline(
    Iterable<BackupSourcePreferences> preferences,
  ) =>
      _primarySourcePreferenceStore?.saveLocalSourcePreferenceBaseline(
        preferences,
      ) ??
      Future.value();
}
