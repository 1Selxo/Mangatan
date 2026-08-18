import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

void main() {
  const codec = ChimahonSyncCodec();
  const preferenceCodec = ChimahonPreferenceCodec();

  test(
    'first-contact remote selection filters effective local intent read-only',
    () async {
      final local = _localBackup(
        const ChimahonMediaSyncSelection(),
        includeManga: true,
        includeAnime: true,
      );
      final remote = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('before', 'unchanged'),
          ..._mediaPreferences(const ChimahonMediaSyncSelection(anime: false)),
          preferenceCodec.encode('after', 7),
        ],
      );
      final storage = _MemoryStorage(remote, codec);
      final sidecar = _MemorySidecar();
      final engine = CrossDeviceSyncEngine(
        storage: storage,
        exportLocal: () async => local.deepCopy(),
        importMerged: (_) async {},
        deferredPayloadStore: sidecar,
        localMediaSelection: const ChimahonMediaSyncSelection(),
        localMediaSelectionInitialized: false,
        localTrackingDeletions: const {
          (source: 1, url: '/manga', syncId: 2),
          (source: 2, url: '/anime', syncId: 2),
        },
      );

      final preview = await engine.preview();

      expect(preview.exportedLocal.backupAnime, hasLength(1));
      expect(preview.effectiveLocalIntent.backupManga, hasLength(1));
      expect(preview.effectiveLocalIntent.backupAnime, isEmpty);
      expect(preview.proposedMerged.backupAnime, isEmpty);
      expect(
        preview.mediaSelection,
        const ChimahonMediaSyncSelection(anime: false),
      );
      expect(preview.mediaSelectionResolvedFromRemote, isTrue);
      expect(preview.localTrackingDeletions, const {
        (source: 1, url: '/manga', syncId: 2),
      });
      expect(
        BackupMihon(
          backupPreferences: preview.proposedMerged.backupPreferences,
        ).writeToBuffer(),
        orderedEquals(
          BackupMihon(
            backupPreferences: remote.backupPreferences,
          ).writeToBuffer(),
        ),
        reason: 'remote order and exact messages must not churn',
      );
      expect(storage.uploadCount, 0);
      expect(sidecar.saveCount, 0);
      expect(sidecar.preferenceBaselineSaveCount, 0);
    },
  );

  test('explicit local first-contact choice beats a remote default', () async {
    const localSelection = ChimahonMediaSyncSelection(anime: true);
    final local = _localBackup(localSelection, includeAnime: true);
    final remote = BackupMihon(
      backupPreferences: _mediaPreferences(
        const ChimahonMediaSyncSelection(anime: false),
      ),
    );
    final preview = await CrossDeviceSyncEngine(
      storage: _MemoryStorage(remote, codec),
      exportLocal: () async => local.deepCopy(),
      importMerged: (_) async {},
      deferredPayloadStore: _MemorySidecar(),
      localMediaSelection: localSelection,
      localMediaSelectionInitialized: true,
      localMediaSelectionUserSelected: true,
    ).preview();

    expect(preview.mediaSelection.anime, isTrue);
    expect(preview.effectiveLocalIntent.backupAnime, hasLength(1));
    expect(preview.proposedMerged.backupAnime, hasLength(1));
    expect(
      _preferenceValue(
        preview.proposedMerged,
        ChimahonMediaSyncSelection.animePreferenceKey,
      ),
      isTrue,
    );
  });

  test(
    'a later remote selector edit drives both projection and final row',
    () async {
      const original = ChimahonMediaSyncSelection(anime: true);
      const changed = ChimahonMediaSyncSelection(anime: false);
      final baseline = BackupMihon(
        backupPreferences: _mediaPreferences(original),
      );
      final remote = BackupMihon(backupPreferences: _mediaPreferences(changed));
      final preview = await CrossDeviceSyncEngine(
        storage: _MemoryStorage(remote, codec),
        exportLocal: () async => _localBackup(original, includeAnime: true),
        importMerged: (_) async {},
        deferredPayloadStore: _MemorySidecar(
          baseline: baseline,
          localPreferenceBaseline: baseline.backupPreferences,
        ),
        localMediaSelection: original,
        localMediaSelectionInitialized: true,
      ).preview();

      expect(preview.mediaSelection, changed);
      expect(preview.effectiveLocalIntent.backupAnime, isEmpty);
      expect(preview.proposedMerged.backupAnime, isEmpty);
      expect(
        _preferenceValue(
          preview.proposedMerged,
          ChimahonMediaSyncSelection.animePreferenceKey,
        ),
        isFalse,
      );
    },
  );

  test(
    'a later local selector edit drives both projection and final row',
    () async {
      const original = ChimahonMediaSyncSelection(anime: true);
      const changed = ChimahonMediaSyncSelection(anime: false);
      final baseline = BackupMihon(
        backupPreferences: _mediaPreferences(original),
      );
      final remote = baseline.deepCopy();
      final preview = await CrossDeviceSyncEngine(
        storage: _MemoryStorage(remote, codec),
        exportLocal: () async => _localBackup(changed, includeAnime: true),
        importMerged: (_) async {},
        deferredPayloadStore: _MemorySidecar(
          baseline: baseline,
          localPreferenceBaseline: baseline.backupPreferences,
        ),
        localMediaSelection: changed,
        localMediaSelectionInitialized: true,
        localMediaSelectionUserSelected: true,
      ).preview();

      expect(preview.mediaSelection, changed);
      expect(preview.effectiveLocalIntent.backupAnime, isEmpty);
      expect(preview.proposedMerged.backupAnime, isEmpty);
      expect(
        _preferenceValue(
          preview.proposedMerged,
          ChimahonMediaSyncSelection.animePreferenceKey,
        ),
        isFalse,
      );
    },
  );

  test(
    'post-restore selector edit filters current media but retains pending',
    () async {
      const restored = ChimahonMediaSyncSelection(anime: true);
      const edited = ChimahonMediaSyncSelection(anime: false);
      final pending = _localBackup(restored, includeAnime: true);
      pending.backupAnime.single.title = 'Selected restore anime';
      final remote = BackupMihon(
        backupPreferences: _mediaPreferences(restored),
      );
      final sidecar = _MemorySidecar(
        baseline: remote,
        pending: pending,
        localPreferenceBaseline: remote.backupPreferences,
        pendingLocalPreferenceBaseline: _mediaPreferences(restored),
      );
      final preview = await CrossDeviceSyncEngine(
        storage: _MemoryStorage(remote, codec),
        exportLocal: () async => _localBackup(edited, includeAnime: true),
        importMerged: (_) async {},
        deferredPayloadStore: sidecar,
        localMediaSelection: edited,
        localMediaSelectionInitialized: true,
        localMediaSelectionUserSelected: true,
      ).preview();

      expect(preview.mediaSelection, edited);
      expect(
        preview.effectiveLocalIntent.backupAnime.single.title,
        'Selected restore anime',
        reason: 'the exact selected restore payload is an explicit override',
      );
      expect(preview.proposedMerged.backupAnime, hasLength(1));
      expect(
        _preferenceValue(
          preview.proposedMerged,
          ChimahonMediaSyncSelection.animePreferenceKey,
        ),
        isFalse,
      );
      expect(
        sidecar.pending,
        isNotNull,
        reason: 'preview never consumes pending',
      );
    },
  );

  test(
    'malformed remote control stays exact and cannot finish bootstrap',
    () async {
      final malformed = preferenceCodec.encode(
        ChimahonMediaSyncSelection.animePreferenceKey,
        'wrong type',
      );
      final remote = BackupMihon(
        backupPreferences: [
          ..._mediaPreferences(const ChimahonMediaSyncSelection()).where(
            (preference) =>
                preference.key != ChimahonMediaSyncSelection.animePreferenceKey,
          ),
          malformed,
        ],
      );
      final storage = _MemoryStorage(remote, codec);
      final result = await CrossDeviceSyncEngine(
        storage: storage,
        exportLocal: () async => _localBackup(
          const ChimahonMediaSyncSelection(),
          includeAnime: true,
        ),
        importMerged: (_) async {},
        deferredPayloadStore: _MemorySidecar(),
        localMediaSelectionInitialized: false,
      ).uploadPreservingRemote();

      expect(result.mediaSelection.anime, isTrue);
      expect(result.mediaSelectionInitializationCompleted, isFalse);
      expect(result.mediaSelectionNeedsPersistence, isFalse);
      final uploaded = codec.decode(storage.uploaded!).backup;
      final uploadedMalformed = uploaded.backupPreferences.singleWhere(
        (preference) =>
            preference.key == ChimahonMediaSyncSelection.animePreferenceKey,
      );
      expect(
        uploadedMalformed.writeToBuffer(),
        orderedEquals(malformed.writeToBuffer()),
      );
    },
  );

  test(
    'established malformed remote keeps a local false filtering fallback',
    () async {
      const current = ChimahonMediaSyncSelection(anime: false);
      final baseline = BackupMihon(
        backupPreferences: _mediaPreferences(current),
      );
      final malformed = preferenceCodec.encode(
        ChimahonMediaSyncSelection.animePreferenceKey,
        'wrong type',
      );
      final remote = baseline.deepCopy();
      remote.backupPreferences
        ..removeWhere(
          (preference) =>
              preference.key == ChimahonMediaSyncSelection.animePreferenceKey,
        )
        ..add(malformed);
      final preview = await CrossDeviceSyncEngine(
        storage: _MemoryStorage(remote, codec),
        exportLocal: () async => _localBackup(current, includeAnime: true),
        importMerged: (_) async {},
        deferredPayloadStore: _MemorySidecar(
          baseline: baseline,
          localPreferenceBaseline: baseline.backupPreferences,
        ),
        localMediaSelection: current,
        localMediaSelectionInitialized: true,
      ).preview();

      expect(preview.mediaSelection.anime, isFalse);
      expect(preview.effectiveLocalIntent.backupAnime, isEmpty);
      final proposedMalformed = preview.proposedMerged.backupPreferences
          .singleWhere(
            (preference) =>
                preference.key == ChimahonMediaSyncSelection.animePreferenceKey,
          );
      expect(
        proposedMalformed.writeToBuffer(),
        orderedEquals(malformed.writeToBuffer()),
      );
    },
  );

  test('selector generation detects a true-false-true upload ABA', () async {
    final local = _localBackup(
      const ChimahonMediaSyncSelection(),
      includeAnime: true,
    );
    var exportCount = 0;
    final result = await CrossDeviceSyncEngine(
      storage: _MemoryStorage(
        BackupMihon(
          backupPreferences: _mediaPreferences(
            const ChimahonMediaSyncSelection(),
          ),
        ),
        codec,
      ),
      exportLocal: () async {
        exportCount++;
        return local.deepCopy();
      },
      importMerged: (_) async {},
      deferredPayloadStore: _MemorySidecar(),
      localMediaSelectionGenerationProvider: () => exportCount <= 1 ? 4 : 6,
    ).uploadPreservingRemote();

    expect(result.initialMediaSelectionGeneration, 4);
    expect(result.requiresRetry, isTrue);
  });
}

BackupMihon _localBackup(
  ChimahonMediaSyncSelection selection, {
  bool includeManga = false,
  bool includeAnime = false,
}) => selection.withBackedPreferences(
  BackupMihon(
    backupManga: includeManga
        ? [BackupManga(source: Int64(1), url: '/manga', title: 'Manga')]
        : const [],
    backupSources: includeManga
        ? [BackupSource(sourceId: Int64(1), name: 'Manga source')]
        : const [],
    backupAnime: includeAnime
        ? [BackupAnime(source: Int64(2), url: '/anime', title: 'Anime')]
        : const [],
    backupAnimeSources: includeAnime
        ? [BackupSource(sourceId: Int64(2), name: 'Anime source')]
        : const [],
  ),
);

List<BackupPreference> _mediaPreferences(
  ChimahonMediaSyncSelection selection,
) => selection
    .withBackedPreferences(BackupMihon())
    .backupPreferences
    .toList(growable: false);

Object? _preferenceValue(BackupMihon backup, String key) =>
    const ChimahonPreferenceCodec()
        .decode(
          backup.backupPreferences.singleWhere(
            (preference) => preference.key == key,
          ),
        )
        .value;

class _MemoryStorage implements CrossDeviceSyncStorage {
  _MemoryStorage(BackupMihon remote, this.codec)
    : remoteBytes = codec.encode(remote);

  final ChimahonSyncCodec codec;
  Uint8List remoteBytes;
  Uint8List? uploaded;
  int uploadCount = 0;

  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.gzipProtobuf;

  @override
  Future<RemoteSyncSnapshot?> download() async => RemoteSyncSnapshot(
    bytes: Uint8List.fromList(remoteBytes),
    revision: 'revision',
    isCompleteRecovery: true,
  );

  @override
  Future<String?> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    uploadCount++;
    uploaded = Uint8List.fromList(bytes);
    remoteBytes = Uint8List.fromList(bytes);
    return 'next-revision';
  }
}

class _MemorySidecar
    implements
        ChimahonDeferredPayloadStore,
        ChimahonLocalPreferenceBaselineStore,
        ChimahonLocalSourcePreferenceBaselineStore,
        ChimahonPendingLocalPayloadStore,
        ChimahonPendingLocalProjectionBaselineStore {
  _MemorySidecar({
    this.baseline,
    this.pending,
    this.localPreferenceBaseline,
    this.pendingLocalPreferenceBaseline,
  });

  BackupMihon? baseline;
  BackupMihon? pending;
  List<BackupPreference>? localPreferenceBaseline;
  List<BackupPreference>? pendingLocalPreferenceBaseline;
  int saveCount = 0;
  int preferenceBaselineSaveCount = 0;

  @override
  Future<BackupMihon?> load() async => baseline?.deepCopy();

  @override
  Future<BackupMihon?> loadPendingLocalPayload() async => pending?.deepCopy();

  @override
  Future<List<BackupPreference>?> loadLocalPreferenceBaseline() async =>
      localPreferenceBaseline == null
      ? null
      : [
          for (final preference in localPreferenceBaseline!)
            preference.deepCopy(),
        ];

  @override
  Future<List<BackupPreference>?> loadPendingLocalPreferenceBaseline() async =>
      pendingLocalPreferenceBaseline == null
      ? null
      : [
          for (final preference in pendingLocalPreferenceBaseline!)
            preference.deepCopy(),
        ];

  @override
  Future<List<BackupSourcePreferences>?>
  loadLocalSourcePreferenceBaseline() async => const [];

  @override
  Future<List<BackupSourcePreferences>?>
  loadPendingLocalSourcePreferenceBaseline() async => const [];

  @override
  Future<void> save(BackupMihon backup) async {
    saveCount++;
    baseline = backup.deepCopy();
    pending = null;
  }

  @override
  Future<void> saveLocalPreferenceBaseline(
    Iterable<BackupPreference> preferences,
  ) async {
    preferenceBaselineSaveCount++;
    localPreferenceBaseline = [
      for (final preference in preferences) preference.deepCopy(),
    ];
  }

  @override
  Future<void> saveLocalSourcePreferenceBaseline(
    Iterable<BackupSourcePreferences> preferences,
  ) async {}
}
