import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/chimahon_pending_restore_authority.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';
import 'package:mangayomi/utils/chimahon_novel_identity.dart';

void main() {
  const codec = ChimahonSyncCodec();
  BackupMihon remoteWithoutKnownRecords() =>
      BackupMihon()..unknownFields.mergeVarintField(999, Int64(1));

  test(
    'downloads, merges, uploads, and imports through provider contracts',
    () async {
      final storage = _MemoryStorage(
        remote: codec.encode(
          BackupMihon(
            backupNovels: [
              BackupNovel(
                id: 'remote',
                title: 'Remote novel',
                lastModified: Int64(10),
              ),
            ],
          ),
        ),
      );
      BackupMihon? imported;
      final result = await CrossDeviceSyncEngine(
        storage: storage,
        exportLocal: () async => BackupMihon(
          backupNovels: [
            BackupNovel(
              id: 'local',
              title: 'Local novel',
              lastModified: Int64(20),
            ),
          ],
        ),
        importMerged: (backup) async => imported = backup,
      ).synchronize();

      expect(result.hadRemoteData, isTrue);
      expect(result.requiresRetry, isFalse);
      expect(storage.expectedRevision, 'revision-1');
      expect(storage.expectedAbsent, isFalse);
      expect(
        imported!.backupNovels.map((novel) => novel.title),
        containsAll(['Local novel', 'Remote novel']),
      );
      final uploaded = codec.decode(storage.uploaded!).backup;
      expect(uploaded.backupNovels, hasLength(2));
    },
  );

  test(
    'matching complete remote skips write but synchronize still finalizes',
    () async {
      final current = const ChimahonMediaSyncSelection().withBackedPreferences(
        BackupMihon(),
      );
      final sidecar = _MemoryPendingPayloadStore(
        baseline: current.deepCopy(),
        pending: current.deepCopy(),
      );
      final storage = _MemoryStorage(
        remote: codec.encode(current),
        isCompleteRecovery: true,
        wireFormat: ChimahonSyncWireFormat.gzipProtobuf,
      );
      BackupMihon? imported;
      var preUploadCount = 0;

      final result = await CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: sidecar,
        exportLocal: () async => current.deepCopy(),
        importMerged: (backup) async => imported = backup.deepCopy(),
        preUpload: (_) async => preUploadCount++,
      ).synchronize();

      expect(storage.downloadCount, 2);
      expect(storage.uploadCount, 0);
      expect(storage.uploaded, isNull);
      expect(preUploadCount, 0);
      expect(imported!.writeToBuffer(), orderedEquals(current.writeToBuffer()));
      expect(sidecar.pending, isNull);
      expect(
        sidecar.saved!.writeToBuffer(),
        orderedEquals(current.writeToBuffer()),
      );
      expect(sidecar.saveCount, 1);
      expect(sidecar.preferenceBaselineSaveCount, 1);
      expect(sidecar.sourceBaselineSaveCount, 1);
      expect(result.hadRemoteData, isTrue);
      expect(result.remoteRevision, 'revision-1');
      expect(result.requiresRetry, isFalse);
      expect(result.mediaSelectionInitializationCompleted, isTrue);
      expect(result.mediaSelectionNeedsPersistence, isTrue);
    },
  );

  test(
    'remote ghost omitted from local cache projection remains an exact no-op',
    () async {
      final current = const ChimahonMediaSyncSelection().withBackedPreferences(
        BackupMihon(
          backupNovels: [
            BackupNovel(
              id: ChimahonNovelIdentity.newBookId(
                title: 'Cloud-only book',
                author: 'Writer',
              ),
              title: 'Cloud-only book',
              author: 'Writer',
              categoryIds: const ['reading'],
              lastModified: Int64(100),
              stats: [
                BackupNovelStat(
                  dateKey: '2026-07-18',
                  charactersRead: 99,
                  lastStatisticModified: Int64(101),
                ),
              ],
            ),
          ],
        ),
      );
      final localWithoutRemoteCache = const ChimahonMediaSyncSelection()
          .withBackedPreferences(BackupMihon());
      final storage = _MemoryStorage(
        remote: codec.encode(current),
        isCompleteRecovery: true,
        wireFormat: ChimahonSyncWireFormat.gzipProtobuf,
      );
      BackupMihon? imported;

      await CrossDeviceSyncEngine(
        storage: storage,
        exportLocal: () async => localWithoutRemoteCache.deepCopy(),
        importMerged: (backup) async => imported = backup.deepCopy(),
      ).synchronize();

      expect(storage.uploadCount, 0);
      expect(imported!.writeToBuffer(), orderedEquals(current.writeToBuffer()));
      final novel = imported!.backupNovels.single;
      expect(novel.categoryIds, ['reading']);
      expect(novel.stats.single.charactersRead, 99);
    },
  );

  test(
    'matching complete remote makes upload-only a finalized no-op',
    () async {
      final current = remoteWithoutKnownRecords();
      final sidecar = _MemoryDeferredPayloadStore(current.deepCopy());
      final storage = _MemoryStorage(
        remote: codec.encode(current),
        isCompleteRecovery: true,
        wireFormat: ChimahonSyncWireFormat.gzipProtobuf,
      );
      var imported = false;
      var preUploadCount = 0;

      final result = await CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: sidecar,
        exportLocal: () async => current.deepCopy(),
        importMerged: (_) async => imported = true,
        preUpload: (_) async => preUploadCount++,
      ).uploadPreservingRemote();

      expect(storage.downloadCount, 2);
      expect(storage.uploadCount, 0);
      expect(preUploadCount, 0);
      expect(imported, isFalse);
      expect(sidecar.saveCount, 1);
      expect(result.remoteRevision, 'revision-1');
      expect(result.requiresRetry, isFalse);
    },
  );

  test('matching incomplete remote still runs consolidation upload', () async {
    final current = remoteWithoutKnownRecords();
    final storage = _MemoryStorage(remote: codec.encode(current));
    var preUploadCount = 0;

    await CrossDeviceSyncEngine(
      storage: storage,
      exportLocal: () async => current.deepCopy(),
      importMerged: (_) async {},
      preUpload: (_) async => preUploadCount++,
    ).uploadPreservingRemote();

    expect(storage.downloadCount, 1);
    expect(storage.uploadCount, 1);
    expect(preUploadCount, 1);
    expect(storage.uploaded, isNotNull);
  });

  test('matching complete remote without a revision still uploads', () async {
    final current = remoteWithoutKnownRecords();
    final storage = _MemoryStorage(
      remote: codec.encode(current),
      revision: null,
      isCompleteRecovery: true,
    );
    var preUploadCount = 0;

    await CrossDeviceSyncEngine(
      storage: storage,
      exportLocal: () async => current.deepCopy(),
      importMerged: (_) async {},
      preUpload: (_) async => preUploadCount++,
    ).uploadPreservingRemote();

    expect(storage.downloadCount, 1);
    expect(storage.uploadCount, 1);
    expect(preUploadCount, 1);
  });

  test('changed proposal still runs upload for a complete remote', () async {
    final remote = remoteWithoutKnownRecords();
    final local = BackupMihon(
      backupNovels: [BackupNovel(id: 'local', title: 'Local novel')],
    );
    final storage = _MemoryStorage(
      remote: codec.encode(remote),
      isCompleteRecovery: true,
    );
    var preUploadCount = 0;

    await CrossDeviceSyncEngine(
      storage: storage,
      exportLocal: () async => local.deepCopy(),
      importMerged: (_) async {},
      preUpload: (_) async => preUploadCount++,
    ).uploadPreservingRemote();

    expect(storage.downloadCount, 1);
    expect(storage.uploadCount, 1);
    expect(preUploadCount, 1);
    final uploaded = codec.decode(storage.uploaded!).backup;
    expect(uploaded.backupNovels.single.title, 'Local novel');
    expect(uploaded.unknownFields.hasField(999), isTrue);
  });

  test(
    'pending no-op confirmation conflict leaves all local state untouched',
    () async {
      final current = const ChimahonMediaSyncSelection().withBackedPreferences(
        BackupMihon(),
      );
      final bytes = codec.encode(current);
      final changed = remoteWithoutKnownRecords();
      final storage = _ConflictingMemoryStorage([
        RemoteSyncSnapshot(
          bytes: bytes,
          revision: 'revision-1',
          isCompleteRecovery: true,
        ),
        RemoteSyncSnapshot(
          bytes: codec.encode(changed),
          revision: 'revision-2',
          isCompleteRecovery: true,
        ),
      ]);
      final sidecar = _MemoryPendingPayloadStore(
        baseline: current.deepCopy(),
        pending: current.deepCopy(),
      );
      var imported = false;
      var preUploadCount = 0;

      await expectLater(
        CrossDeviceSyncEngine(
          storage: storage,
          deferredPayloadStore: sidecar,
          exportLocal: () async => current.deepCopy(),
          importMerged: (_) async => imported = true,
          preUpload: (_) async => preUploadCount++,
        ).synchronize(maxConflictRetries: 0),
        throwsA(isA<SyncConflictException>()),
      );

      expect(storage.uploadRevisions, isEmpty);
      expect(preUploadCount, 0);
      expect(imported, isFalse);
      expect(sidecar.saveCount, 0);
      expect(sidecar.saved, isNull);
      expect(
        sidecar.pending!.writeToBuffer(),
        orderedEquals(current.writeToBuffer()),
      );
      expect(sidecar.preferenceBaselineSaveCount, 0);
      expect(sidecar.sourceBaselineSaveCount, 0);
    },
  );

  test('no-op preserves the local generation retry check', () async {
    final current = remoteWithoutKnownRecords();
    var mediaSelectionGeneration = 4;
    final storage = _MemoryStorage(
      remote: codec.encode(current),
      isCompleteRecovery: true,
      onDownload: (count) {
        if (count == 2) mediaSelectionGeneration++;
      },
    );
    var imported = false;

    final result = await CrossDeviceSyncEngine(
      storage: storage,
      localMediaSelectionGenerationProvider: () => mediaSelectionGeneration,
      exportLocal: () async => current.deepCopy(),
      importMerged: (_) async => imported = true,
    ).synchronize();

    expect(storage.downloadCount, 2);
    expect(storage.uploadCount, 0);
    expect(result.requiresRetry, isTrue);
    expect(imported, isFalse);
  });

  test(
    'forced upload expects absence when the remote payload does not exist',
    () async {
      final storage = _MemoryStorage(remote: Uint8List(0), remoteExists: false);

      await CrossDeviceSyncEngine(
        storage: storage,
        exportLocal: () async => BackupMihon(),
        importMerged: (_) async {},
      ).uploadPreservingRemote();

      expect(storage.expectedRevision, isNull);
      expect(storage.expectedAbsent, isTrue);
    },
  );

  test('keeps a locally changed preference when remote is stale', () async {
    const preferenceCodec = ChimahonPreferenceCodec();
    final baseline = BackupMihon(
      backupPreferences: [preferenceCodec.encode('setting', 'baseline')],
      backupNovels: [
        BackupNovel(id: 'novel', title: 'Novel', lastModified: Int64(1)),
      ],
    );
    final storage = _MemoryStorage(remote: codec.encode(baseline.deepCopy()));

    await CrossDeviceSyncEngine(
      storage: storage,
      deferredPayloadStore: _MemoryDeferredPayloadStore(baseline),
      exportLocal: () async => BackupMihon(
        backupPreferences: [preferenceCodec.encode('setting', 'local change')],
      ),
      importMerged: (_) async {},
    ).synchronize();

    final uploaded = codec.decode(storage.uploaded!).backup;
    expect(
      preferenceCodec.decode(uploaded.backupPreferences.single).value,
      'local change',
    );
  });

  test(
    'upload keeps remote preference order and sorts only local additions',
    () async {
      const preferenceCodec = ChimahonPreferenceCodec();
      BackupSourcePreferences source(
        String sourceKey,
        Iterable<BackupPreference> preferences,
      ) => BackupSourcePreferences(sourceKey: sourceKey, prefs: preferences);

      final remote = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('z_remote', 'z'),
          preferenceCodec.encode('a_remote', 'a'),
        ],
        backupSourcePreferences: [
          source('source_z', [
            preferenceCodec.encode('z_remote', 'z'),
            preferenceCodec.encode('a_remote', 'a'),
          ]),
          source('source_a', [preferenceCodec.encode('only', 'remote')]),
        ],
      );
      final local = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('z_local', 'z'),
          preferenceCodec.encode('a_remote', 'a'),
          preferenceCodec.encode('a_local', 'a'),
          preferenceCodec.encode('z_remote', 'z'),
        ],
        backupSourcePreferences: [
          source('source_a', [preferenceCodec.encode('only', 'remote')]),
          source('source_z', [
            preferenceCodec.encode('z_local', 'z'),
            preferenceCodec.encode('a_remote', 'a'),
            preferenceCodec.encode('a_local', 'a'),
            preferenceCodec.encode('z_remote', 'z'),
          ]),
          source('source_y', [preferenceCodec.encode('only', 'local')]),
          source('source_b', [preferenceCodec.encode('only', 'local')]),
        ],
      );
      final storage = _MemoryStorage(remote: codec.encode(remote));

      await CrossDeviceSyncEngine(
        storage: storage,
        exportLocal: () async => local.deepCopy(),
        importMerged: (_) async {},
      ).uploadPreservingRemote();

      final uploaded = codec.decode(storage.uploaded!).backup;
      expect(uploaded.backupPreferences.map((preference) => preference.key), [
        'z_remote',
        'a_remote',
        'a_local',
        'z_local',
      ]);
      expect(uploaded.backupSourcePreferences.map((group) => group.sourceKey), [
        'source_z',
        'source_a',
        'source_b',
        'source_y',
      ]);
      expect(
        uploaded.backupSourcePreferences.first.prefs.map(
          (preference) => preference.key,
        ),
        ['z_remote', 'a_remote', 'a_local', 'z_local'],
      );
    },
  );

  test(
    'first contact preserves absent remote settings until a later local edit',
    () async {
      const preferenceCodec = ChimahonPreferenceCodec();
      BackupSourcePreferences sourceGroup({
        required String persisted,
        String? localDefault,
      }) => BackupSourcePreferences(
        sourceKey: 'source_1',
        prefs: [
          preferenceCodec.encode('persisted', persisted),
          if (localDefault != null)
            preferenceCodec.encode('descriptor-default', localDefault),
        ],
      );

      final firstLocal = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('persisted', 'Mangatan default'),
          preferenceCodec.encode('constructor-default', false),
        ],
        backupSourcePreferences: [
          sourceGroup(
            persisted: 'Mangatan descriptor default',
            localDefault: 'not persisted by Chimahon',
          ),
        ],
      );
      final remote = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('persisted', 'Chimahon value'),
        ],
        backupSourcePreferences: [
          sourceGroup(persisted: 'Chimahon source value'),
        ],
      );
      final store = _FirstContactPayloadStore();
      final firstStorage = _MemoryStorage(remote: codec.encode(remote));

      await CrossDeviceSyncEngine(
        storage: firstStorage,
        deferredPayloadStore: store,
        exportLocal: () async => firstLocal.deepCopy(),
        importMerged: (_) async {},
      ).uploadPreservingRemote();

      final firstUpload = codec.decode(firstStorage.uploaded!).backup;
      expect(
        {
          for (final preference in firstUpload.backupPreferences)
            preference.key: preferenceCodec.decode(preference).value,
        },
        {'persisted': 'Chimahon value'},
      );
      expect(
        {
          for (final preference
              in firstUpload.backupSourcePreferences.single.prefs)
            preference.key: preferenceCodec.decode(preference).value,
        },
        {'persisted': 'Chimahon source value'},
      );

      final editedLocal = firstLocal.deepCopy();
      editedLocal.backupPreferences
          .singleWhere((preference) => preference.key == 'constructor-default')
          .value = preferenceCodec
          .encode('ignored', true)
          .value;
      editedLocal.backupSourcePreferences.single.prefs
          .singleWhere((preference) => preference.key == 'descriptor-default')
          .value = preferenceCodec
          .encode('ignored', 'user edit')
          .value;
      final secondStorage = _MemoryStorage(remote: firstStorage.uploaded!);

      await CrossDeviceSyncEngine(
        storage: secondStorage,
        deferredPayloadStore: store,
        exportLocal: () async => editedLocal.deepCopy(),
        importMerged: (_) async {},
      ).uploadPreservingRemote();

      final secondUpload = codec.decode(secondStorage.uploaded!).backup;
      expect(
        {
          for (final preference in secondUpload.backupPreferences)
            preference.key: preferenceCodec.decode(preference).value,
        }['constructor-default'],
        isTrue,
      );
      expect(
        {
          for (final preference
              in secondUpload.backupSourcePreferences.single.prefs)
            preference.key: preferenceCodec.decode(preference).value,
        }['descriptor-default'],
        'user edit',
      );
    },
  );

  test(
    'does not let deferred state resurrect a local preference deletion',
    () async {
      const preferenceCodec = ChimahonPreferenceCodec();
      final baseline = BackupMihon(
        backupPreferences: [preferenceCodec.encode('setting', 'baseline')],
        backupNovels: [
          BackupNovel(id: 'novel', title: 'Novel', lastModified: Int64(1)),
        ],
      );
      final storage = _MemoryStorage(remote: codec.encode(baseline.deepCopy()));

      await CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: _MemoryDeferredPayloadStore(baseline),
        exportLocal: () async => BackupMihon(),
        importMerged: (_) async {},
      ).synchronize();

      final uploaded = codec.decode(storage.uploaded!).backup;
      expect(uploaded.backupPreferences, isEmpty);
    },
  );

  test(
    'a setting can return from unrepresentable state as a later local edit',
    () async {
      const preferenceCodec = ChimahonPreferenceCodec();
      const key = 'pref_default_reading_mode_key';
      final preference = preferenceCodec.encode(key, 3);
      final baseline = BackupMihon(backupPreferences: [preference]);
      final store = _MemoryDeferredPayloadStore(baseline);
      final firstStorage = _MemoryStorage(
        remote: codec.encode(baseline.deepCopy()),
      );
      int? localValue;

      await CrossDeviceSyncEngine(
        storage: firstStorage,
        deferredPayloadStore: store,
        exportLocal: () async => BackupMihon(
          backupPreferences: [
            if (localValue != null) preferenceCodec.encode(key, localValue),
          ],
        ),
        localUnrepresentablePreferenceKeys: () =>
            localValue == null ? const {key} : const {},
        importMerged: (_) async {},
      ).synchronize();

      final firstUpload = codec.decode(firstStorage.uploaded!).backup;
      expect(
        preferenceCodec.decode(firstUpload.backupPreferences.single).value,
        3,
      );
      expect(
        preferenceCodec
            .decode(
              store.localPreferenceBaseline!.singleWhere(
                (preference) => preference.key == key,
              ),
            )
            .value,
        3,
        reason: 'the raw value remains the comparison baseline for the gap',
      );

      localValue = 5;
      final secondStorage = _MemoryStorage(remote: firstStorage.uploaded!);
      await CrossDeviceSyncEngine(
        storage: secondStorage,
        deferredPayloadStore: store,
        exportLocal: () async => BackupMihon(
          backupPreferences: [preferenceCodec.encode(key, localValue!)],
        ),
        importMerged: (_) async {},
      ).synchronize();

      final secondUpload = codec.decode(secondStorage.uploaded!).backup;
      expect(
        preferenceCodec.decode(secondUpload.backupPreferences.single).value,
        5,
      );
    },
  );

  test(
    'preserves prior Chimahon OCR values while local OCR state is richer',
    () async {
      const preferenceCodec = ChimahonPreferenceCodec();
      final baseline = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('pref_ocr_engine', 'cloud'),
          preferenceCodec.encode('pref_ocr_box_scale', 1.0),
        ],
      );
      final storage = _MemoryStorage(remote: codec.encode(baseline.deepCopy()));

      await CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: _MemoryDeferredPayloadStore(baseline),
        exportLocal: () async => BackupMihon(),
        localUnrepresentablePreferenceKeys: () => const {
          'pref_ocr_engine',
          'pref_ocr_box_scale',
        },
        importMerged: (_) async {},
      ).synchronize();

      final uploaded = codec.decode(storage.uploaded!).backup;
      expect(
        {
          for (final preference in uploaded.backupPreferences)
            preference.key: preferenceCodec.decode(preference).value,
        },
        {'pref_ocr_box_scale': 1.0, 'pref_ocr_engine': 'cloud'},
      );
    },
  );

  test(
    'source preference baseline keeps local edits without reviving opaque deletions',
    () async {
      const preferenceCodec = ChimahonPreferenceCodec();
      BackupSourcePreferences group(String sourceKey, String value) =>
          BackupSourcePreferences(
            sourceKey: sourceKey,
            prefs: [preferenceCodec.encode('setting', value)],
          );

      final installedBaseline = group('source_1', 'baseline');
      final baseline = BackupMihon(
        backupSourcePreferences: [
          installedBaseline,
          group('source_999', 'deleted remotely'),
        ],
      );
      final deferredStore = _MemoryDeferredPayloadStore(baseline)
        ..localSourcePreferenceBaseline = [installedBaseline.deepCopy()];
      final storage = _MemoryStorage(
        remote: codec.encode(
          BackupMihon(backupSourcePreferences: [installedBaseline.deepCopy()]),
        ),
      );

      await CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: deferredStore,
        exportLocal: () async => BackupMihon(
          backupSourcePreferences: [group('source_1', 'local edit')],
        ),
        importMerged: (_) async {},
      ).uploadPreservingRemote();

      final uploaded = codec.decode(storage.uploaded!).backup;
      expect(uploaded.backupSourcePreferences, hasLength(1));
      expect(uploaded.backupSourcePreferences.single.sourceKey, 'source_1');
      expect(
        preferenceCodec
            .decode(uploaded.backupSourcePreferences.single.prefs.single)
            .value,
        'local edit',
      );
    },
  );

  test(
    'forced upload preserves current remote data without resurrecting baseline',
    () async {
      final remoteOnly = BackupManga(
        source: Int64(42),
        url: '/remote-only',
        title: 'Unavailable source title',
        author: 'Remote author',
        version: Int64(7),
      );
      final localOnly = BackupManga(
        source: Int64(1),
        url: '/local-only',
        title: 'Local title',
        author: 'Local author',
        version: Int64(3),
      );
      final baseline = BackupMihon(
        backupNovels: [
          BackupNovel(
            id: 'deferred',
            title: 'Deferred novel',
            lastModified: Int64(9),
          ),
        ],
      );
      final deferredStore = _MemoryDeferredPayloadStore(baseline);
      final storage = _MemoryStorage(
        remote: codec.encode(BackupMihon(backupManga: [remoteOnly])),
      );
      var imported = false;

      await CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: deferredStore,
        exportLocal: () async => BackupMihon(backupManga: [localOnly]),
        importMerged: (_) async => imported = true,
      ).uploadPreservingRemote();

      final uploaded = codec.decode(storage.uploaded!).backup;
      expect(
        uploaded.backupManga.map((manga) => manga.title),
        containsAll(['Unavailable source title', 'Local title']),
      );
      expect(uploaded.backupNovels, isEmpty);
      expect(storage.expectedRevision, 'revision-1');
      expect(storage.expectedAbsent, isFalse);
      expect(imported, isFalse);
      expect(
        deferredStore.saved!.writeToBuffer(),
        orderedEquals(uploaded.writeToBuffer()),
      );
    },
  );

  test('forced upload retries against the latest remote revision', () async {
    final storage = _ConflictingMemoryStorage([
      RemoteSyncSnapshot(
        bytes: codec.encode(
          BackupMihon(
            backupManga: [
              BackupManga(
                source: Int64(42),
                url: '/old-remote',
                title: 'Old remote title',
              ),
            ],
          ),
        ),
        revision: 'revision-1',
      ),
      RemoteSyncSnapshot(
        bytes: codec.encode(
          BackupMihon(
            backupManga: [
              BackupManga(
                source: Int64(42),
                url: '/latest-remote',
                title: 'Latest remote title',
              ),
            ],
          ),
        ),
        revision: 'revision-2',
      ),
    ]);
    var exportCount = 0;

    await CrossDeviceSyncEngine(
      storage: storage,
      exportLocal: () async {
        exportCount++;
        return BackupMihon(
          backupManga: [
            BackupManga(source: Int64(1), url: '/local', title: 'Local title'),
          ],
        );
      },
      importMerged: (_) async {},
    ).uploadPreservingRemote();

    final uploaded = codec.decode(storage.uploaded!).backup;
    expect(storage.uploadRevisions, ['revision-1', 'revision-2']);
    expect(exportCount, 3);
    expect(
      uploaded.backupManga.map((manga) => manga.title),
      containsAll(['Latest remote title', 'Local title']),
    );
  });

  test('remote deletion removes deferred-only opaque records', () async {
    final baseline = BackupMihon(
      backupNovels: [
        BackupNovel(id: 'a', title: 'Still local', lastModified: Int64(1)),
        BackupNovel(id: 'b', title: 'Deleted remotely', lastModified: Int64(1)),
      ],
    );
    final storage = _MemoryStorage(
      remote: codec.encode(remoteWithoutKnownRecords()),
    );

    await CrossDeviceSyncEngine(
      storage: storage,
      deferredPayloadStore: _MemoryDeferredPayloadStore(baseline),
      exportLocal: () async => BackupMihon(
        backupNovels: [
          BackupNovel(id: 'a', title: 'Still local', lastModified: Int64(2)),
        ],
      ),
      importMerged: (_) async {},
    ).uploadPreservingRemote();

    final uploaded = codec.decode(storage.uploaded!).backup;
    expect(uploaded.backupNovels.map((novel) => novel.title), ['Still local']);
  });

  test('an absent remote does not revive a stale account baseline', () async {
    final storage = _MemoryStorage(remote: Uint8List(0), remoteExists: false);

    await CrossDeviceSyncEngine(
      storage: storage,
      deferredPayloadStore: _MemoryDeferredPayloadStore(
        BackupMihon(
          backupNovels: [BackupNovel(id: 'stale', title: 'Stale baseline')],
        ),
      ),
      exportLocal: () async => BackupMihon(
        backupNovels: [BackupNovel(id: 'current', title: 'Current local')],
      ),
      importMerged: (_) async {},
    ).uploadPreservingRemote();

    final uploaded = codec.decode(storage.uploaded!).backup;
    expect(uploaded.backupNovels.map((novel) => novel.id), ['current']);
  });

  test('pending manual restore remains explicit local upload intent', () async {
    const preferenceCodec = ChimahonPreferenceCodec();
    BackupSourcePreferences sourceGroup(
      String value, {
      bool includePendingOnly = false,
    }) => BackupSourcePreferences(
      sourceKey: 'source_1',
      prefs: [
        preferenceCodec.encode('restored-source-setting', value),
        if (includePendingOnly)
          preferenceCodec.encode('pending-source-only', 'opaque source value'),
      ],
    );
    final deferredStore = _MemoryPendingPayloadStore(
      baseline: BackupMihon(
        backupNovels: [BackupNovel(id: 'stale', title: 'Old baseline')],
        backupPreferences: [
          preferenceCodec.encode('restored-setting', 'old baseline'),
        ],
        backupSourcePreferences: [sourceGroup('old baseline')],
      ),
      pending: BackupMihon(
        backupNovels: [BackupNovel(id: 'pending', title: 'Selected restore')],
        backupPreferences: [
          preferenceCodec.encode('restored-setting', 'selected restore'),
          preferenceCodec.encode('pending-only', 'opaque restore value'),
        ],
        backupSourcePreferences: [
          sourceGroup('selected restore', includePendingOnly: true),
        ],
      ),
    );
    final storage = _MemoryStorage(
      remote: codec.encode(
        BackupMihon(
          backupPreferences: [
            preferenceCodec.encode('restored-setting', 'remote current'),
          ],
          backupSourcePreferences: [sourceGroup('remote current')],
        ),
      ),
    );

    await CrossDeviceSyncEngine(
      storage: storage,
      deferredPayloadStore: deferredStore,
      exportLocal: () async => BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('restored-setting', 'selected restore'),
        ],
        backupSourcePreferences: [sourceGroup('selected restore')],
      ),
      importMerged: (_) async {},
    ).uploadPreservingRemote();

    final uploaded = codec.decode(storage.uploaded!).backup;
    expect(uploaded.backupNovels.map((novel) => novel.title), [
      'Selected restore',
    ]);
    expect(
      {
        for (final preference in uploaded.backupPreferences)
          preference.key: preferenceCodec.decode(preference).value,
      },
      {
        'pending-only': 'opaque restore value',
        'restored-setting': 'selected restore',
      },
    );
    expect(
      {
        for (final preference in uploaded.backupSourcePreferences.single.prefs)
          preference.key: preferenceCodec.decode(preference).value,
      },
      {
        'pending-source-only': 'opaque source value',
        'restored-source-setting': 'selected restore',
      },
    );
    expect(deferredStore.pending, isNull);
  });

  test(
    'pending restore beats a newer cloud record without dropping cloud-only data',
    () async {
      final selectedChapter = BackupChapter(
        url: '/selected/chapter-1',
        name: 'Chapter 1',
        read: false,
        bookmark: false,
        lastPageRead: Int64(2),
        lastModifiedAt: Int64(100),
        version: Int64(4),
      )..unknownFields.mergeVarintField(5003, Int64(11));
      final selectedNovelStat = BackupNovelStat(
        dateKey: '2026-07-17',
        charactersRead: 10,
        readingTime: 1.0,
        lastStatisticModified: Int64(100),
      )..unknownFields.mergeVarintField(5005, Int64(11));
      final selectedManga = BackupManga(
        source: Int64(1),
        url: '/selected',
        title: 'Selected title',
        author: 'Selected author',
        description: 'Selected backup description',
        favorite: true,
        favoriteModifiedAt: Int64(100),
        lastModifiedAt: Int64(100),
        version: Int64(5),
        categories: [Int64.ZERO],
        chapters: [selectedChapter],
        history: [
          BackupHistory(
            url: '/selected/chapter-1',
            lastRead: Int64(1000),
            readDuration: Int64(500),
          ),
        ],
      )..unknownFields.mergeVarintField(5001, Int64(11));
      final selectedNovel = BackupNovel(
        id: 'selected-novel',
        title: 'Selected novel',
        author: 'Selected novelist',
        chapterIndex: 1,
        progress: 0.2,
        characterCount: 20,
        lastModified: Int64(100),
        stats: [selectedNovelStat],
      )..unknownFields.mergeVarintField(5004, Int64(11));
      final pending = BackupMihon(
        backupManga: [selectedManga],
        backupCategories: [
          BackupCategory(
            name: 'Restored category',
            order: Int64.ZERO,
            id: Int64(1),
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/selected-anime',
            title: 'Selected anime',
            author: 'Selected anime author',
            description: 'Selected anime backup description',
            categories: [Int64.ZERO],
            lastModifiedAt: Int64(100),
            version: Int64(5),
          ),
        ],
        backupAnimeCategories: [
          BackupCategory(
            name: 'Restored anime category',
            order: Int64.ZERO,
            id: Int64(3),
          ),
        ],
        backupNovels: [selectedNovel],
        backupMangaStats: [
          BackupMangaStats(
            dateKey: '2026-07-17',
            mangaId: Int64(1),
            charactersRead: 10,
            readingTime: Int64(1000),
          ),
        ],
      )..unknownFields.mergeVarintField(5000, Int64(11));

      // This is the database projection after the selected backup was restored
      // and then edited locally, before its first successful cloud upload.
      final postRestoreLocal = BackupMihon(
        backupCategories: [
          BackupCategory(
            name: 'Restored category',
            order: Int64.ZERO,
            id: Int64(1),
          ),
        ],
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/selected',
            title: 'Selected title',
            author: 'Selected author',
            description: 'Post-restore local edit',
            favorite: true,
            favoriteModifiedAt: Int64(150),
            lastModifiedAt: Int64(150),
            categories: [Int64.ZERO],
            chapters: [
              BackupChapter(
                url: '/selected/chapter-1',
                name: 'Chapter 1',
                read: true,
                bookmark: true,
                lastPageRead: Int64(8),
                lastModifiedAt: Int64(150),
              ),
            ],
            history: [
              BackupHistory(
                url: '/selected/chapter-1',
                lastRead: Int64(1500),
                readDuration: Int64(700),
              ),
            ],
          ),
        ],
        backupAnimeCategories: [
          BackupCategory(
            name: 'Restored anime category',
            order: Int64.ZERO,
            id: Int64(3),
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/selected-anime',
            title: 'Selected anime',
            author: 'Selected anime author',
            description: 'Post-restore anime edit',
            categories: [Int64.ZERO],
            lastModifiedAt: Int64(150),
          ),
        ],
        backupNovels: [
          BackupNovel(
            id: 'selected-novel',
            title: 'Selected novel',
            author: 'Selected novelist',
            chapterIndex: 3,
            progress: 0.75,
            characterCount: 300,
            lastModified: Int64(150),
            stats: [
              BackupNovelStat(
                dateKey: '2026-07-17',
                charactersRead: 15,
                readingTime: 2.0,
                lastStatisticModified: Int64(150),
              ),
            ],
          ),
        ],
        backupMangaStats: [
          BackupMangaStats(
            dateKey: '2026-07-17',
            mangaId: Int64(1),
            charactersRead: 15,
            readingTime: Int64(1500),
          ),
        ],
      );

      final cloudChapter = BackupChapter(
        url: '/selected/chapter-1',
        name: 'Chapter 1',
        read: false,
        bookmark: false,
        lastPageRead: Int64(20),
        lastModifiedAt: Int64(200),
        version: Int64(8),
      )..unknownFields.mergeVarintField(5003, Int64(99));
      final cloudNovelStat = BackupNovelStat(
        dateKey: '2026-07-17',
        charactersRead: 99,
        readingTime: 9.0,
        lastStatisticModified: Int64(200),
      )..unknownFields.mergeVarintField(5005, Int64(99));
      final cloudManga = BackupManga(
        source: Int64(1),
        url: '/selected',
        title: 'Selected title',
        author: 'Selected author',
        description: 'Newer cloud edit',
        favorite: false,
        favoriteModifiedAt: Int64(200),
        lastModifiedAt: Int64(200),
        version: Int64(10),
        categories: [Int64(2)],
        chapters: [
          cloudChapter,
          BackupChapter(
            url: '/selected/cloud-only-chapter',
            name: 'Cloud-only chapter',
            version: Int64(3),
          ),
        ],
        history: [
          BackupHistory(
            url: '/selected/chapter-1',
            lastRead: Int64(2000),
            readDuration: Int64(900),
          ),
        ],
      )..unknownFields.mergeVarintField(5001, Int64(99));
      final cloudNovel = BackupNovel(
        id: 'cloud-selected-novel',
        title: 'Selected novel',
        author: 'Selected novelist',
        chapterIndex: 9,
        progress: 0.95,
        characterCount: 999,
        lastModified: Int64(200),
        stats: [
          cloudNovelStat,
          BackupNovelStat(
            dateKey: '2026-07-18',
            charactersRead: 20,
            readingTime: 3.0,
            lastStatisticModified: Int64(180),
          ),
        ],
      )..unknownFields.mergeVarintField(5004, Int64(99));
      final remote = BackupMihon(
        backupCategories: [
          BackupCategory(
            name: 'Restored category',
            order: Int64(2),
            id: Int64(1),
          ),
          BackupCategory(
            name: 'Cloud-only category',
            order: Int64.ZERO,
            id: Int64(2),
          ),
        ],
        backupManga: [
          cloudManga,
          BackupManga(
            source: Int64(42),
            url: '/cloud-only-title',
            title: 'Cloud-only title',
            version: Int64(7),
            categories: [Int64.ZERO],
          ),
        ],
        backupAnimeCategories: [
          BackupCategory(
            name: 'Restored anime category',
            order: Int64(2),
            id: Int64(3),
          ),
          BackupCategory(
            name: 'Cloud-only anime category',
            order: Int64.ZERO,
            id: Int64(4),
          ),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/selected-anime',
            title: 'Selected anime',
            author: 'Selected anime author',
            description: 'Newer cloud anime edit',
            categories: [Int64(2)],
            lastModifiedAt: Int64(200),
            version: Int64(10),
          ),
          BackupAnime(
            source: Int64(42),
            url: '/cloud-only-anime',
            title: 'Cloud-only anime',
            categories: [Int64.ZERO],
            version: Int64(7),
          ),
        ],
        backupNovels: [
          cloudNovel,
          BackupNovel(
            id: 'cloud-only-novel',
            title: 'Cloud-only novel',
            author: 'Cloud author',
            lastModified: Int64(180),
          ),
        ],
        backupMangaStats: [
          BackupMangaStats(
            dateKey: '2026-07-17',
            mangaId: Int64(1),
            charactersRead: 99,
            readingTime: Int64(9000),
          ),
          BackupMangaStats(
            dateKey: '2026-07-18',
            mangaId: Int64(42),
            charactersRead: 20,
            readingTime: Int64(2000),
          ),
        ],
      )..unknownFields.mergeVarintField(5000, Int64(99));

      final deferredStore = _MemoryPendingPayloadStore(
        baseline: BackupMihon(),
        pending: pending,
      );
      final authority = _ProofRecordingAuthority();
      final storage = _MemoryStorage(
        remote: codec.encode(remote),
        onUpload: () {
          expect(authority.proofRan, isTrue);
          expect(authority.proofResult, isTrue);
          expect(deferredStore.pending, isNotNull);
        },
      );

      await CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: deferredStore,
        pendingRestoreAuthority: authority,
        exportLocal: () async => postRestoreLocal.deepCopy(),
        importMerged: (_) async {},
      ).uploadPreservingRemote();

      final uploaded = codec.decode(storage.uploaded!).backup;
      final uploadedManga = uploaded.backupManga.singleWhere(
        (manga) => manga.url == '/selected',
      );
      final uploadedChapter = uploadedManga.chapters.singleWhere(
        (chapter) => chapter.url == '/selected/chapter-1',
      );
      final uploadedHistory = uploadedManga.history.singleWhere(
        (history) => history.url == '/selected/chapter-1',
      );
      expect(uploadedManga.description, 'Post-restore local edit');
      expect(uploadedManga.favorite, isTrue);
      expect(uploadedManga.favoriteModifiedAt, Int64(201));
      expect(uploadedManga.lastModifiedAt, Int64(201));
      expect(uploadedManga.version, Int64(11));
      expect(uploadedChapter.read, isTrue);
      expect(uploadedChapter.bookmark, isTrue);
      expect(uploadedChapter.lastPageRead, Int64(8));
      expect(uploadedChapter.version, Int64(9));
      expect(uploadedHistory.lastRead, Int64(2001));
      expect(uploadedHistory.readDuration, Int64(700));
      expect(
        uploadedManga.chapters.map((chapter) => chapter.url),
        contains('/selected/cloud-only-chapter'),
      );
      expect(
        uploaded.backupManga.map((manga) => manga.url),
        contains('/cloud-only-title'),
      );
      final categoryOrders = {
        for (final category in uploaded.backupCategories)
          category.name: category.order,
      };
      expect(categoryOrders.values.toSet(), hasLength(categoryOrders.length));
      expect(categoryOrders['Restored category'], Int64.ZERO);
      expect(uploadedManga.categories, [Int64.ZERO]);
      expect(
        uploaded.backupManga
            .singleWhere((manga) => manga.url == '/cloud-only-title')
            .categories,
        [categoryOrders['Cloud-only category']],
      );

      final uploadedAnime = uploaded.backupAnime.singleWhere(
        (anime) => anime.url == '/selected-anime',
      );
      final animeCategoryOrders = {
        for (final category in uploaded.backupAnimeCategories)
          category.name: category.order,
      };
      expect(
        animeCategoryOrders.values.toSet(),
        hasLength(animeCategoryOrders.length),
      );
      expect(animeCategoryOrders['Restored anime category'], Int64.ZERO);
      expect(uploadedAnime.description, 'Post-restore anime edit');
      expect(uploadedAnime.version, Int64(11));
      expect(uploadedAnime.categories, [Int64.ZERO]);
      expect(
        uploaded.backupAnime
            .singleWhere((anime) => anime.url == '/cloud-only-anime')
            .categories,
        [animeCategoryOrders['Cloud-only anime category']],
      );

      final uploadedNovel = uploaded.backupNovels.singleWhere(
        (novel) => novel.title == 'Selected novel',
      );
      final uploadedNovelStat = uploadedNovel.stats.singleWhere(
        (stat) => stat.dateKey == '2026-07-17',
      );
      expect(uploadedNovel.chapterIndex, 3);
      expect(uploadedNovel.progress, 0.75);
      expect(uploadedNovel.characterCount, 300);
      expect(uploadedNovel.lastModified, Int64(201));
      expect(uploadedNovelStat.charactersRead, 15);
      expect(uploadedNovelStat.readingTime, 2.0);
      expect(uploadedNovelStat.lastStatisticModified, Int64(201));
      expect(
        uploadedNovel.stats.map((stat) => stat.dateKey),
        contains('2026-07-18'),
      );
      expect(
        uploaded.backupNovels.map((novel) => novel.title),
        contains('Cloud-only novel'),
      );

      final selectedStat = uploaded.backupMangaStats.singleWhere(
        (stat) =>
            stat.dateKey == '2026-07-17' &&
            stat.mangaId == Int64(1) &&
            stat.charactersRead == 15 &&
            stat.readingTime == Int64(1500),
      );
      expect(selectedStat.charactersRead, 15);
      expect(selectedStat.readingTime, Int64(1500));
      expect(
        uploaded.backupMangaStats
            .where(
              (stat) =>
                  stat.dateKey == '2026-07-17' && stat.mangaId == Int64(1),
            )
            .map((stat) => (stat.charactersRead, stat.readingTime))
            .toSet(),
        {(10, Int64(1000)), (15, Int64(1500)), (99, Int64(9000))},
      );
      expect(
        uploaded.backupMangaStats.any(
          (stat) => stat.dateKey == '2026-07-18' && stat.mangaId == Int64(42),
        ),
        isTrue,
      );

      expect(uploaded.unknownFields.getField(5000)!.varints.last, Int64(11));
      expect(
        uploadedManga.unknownFields.getField(5001)!.varints.last,
        Int64(11),
      );
      expect(
        uploadedChapter.unknownFields.getField(5003)!.varints.last,
        Int64(11),
      );
      expect(
        uploadedNovel.unknownFields.getField(5004)!.varints.last,
        Int64(11),
      );
      expect(
        uploadedNovelStat.unknownFields.getField(5005)!.varints.last,
        Int64(11),
      );
      expect(authority.proofRan, isTrue);
      expect(authority.proofResult, isTrue);
      expect(deferredStore.pending, isNull);
    },
  );

  test(
    'a local edit during upload skips stale import and requests a retry',
    () async {
      BackupMihon local({required bool read, required int modified}) =>
          BackupMihon(
            backupManga: [
              BackupManga(
                source: Int64(1),
                url: '/title',
                title: 'Title',
                lastModifiedAt: Int64(modified),
                chapters: [
                  BackupChapter(
                    url: '/chapter',
                    name: 'Chapter',
                    read: read,
                    lastModifiedAt: Int64(modified),
                  ),
                ],
              ),
            ],
          );

      var localState = local(read: false, modified: 100);
      final deferredStore = _MemoryDeferredPayloadStore(BackupMihon());
      final storage = _MemoryStorage(
        remote: codec.encode(localState),
        onUpload: () => localState = local(read: true, modified: 200),
      );
      BackupMihon? imported;

      final result = await CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: deferredStore,
        exportLocal: () async => localState.deepCopy(),
        importMerged: (backup) async => imported = backup,
      ).synchronize();

      expect(result.requiresRetry, isTrue);
      expect(imported, isNull);
      expect(localState.backupManga.single.chapters.single.read, isTrue);
      expect(
        codec
            .decode(storage.uploaded!)
            .backup
            .backupManga
            .single
            .chapters
            .single
            .read,
        isFalse,
      );

      final retryStorage = _MemoryStorage(remote: storage.uploaded!);
      final retryResult = await CrossDeviceSyncEngine(
        storage: retryStorage,
        deferredPayloadStore: _MemoryDeferredPayloadStore(deferredStore.saved!),
        exportLocal: () async => localState.deepCopy(),
        importMerged: (backup) async => imported = backup,
      ).synchronize();

      expect(retryResult.requiresRetry, isFalse);
      expect(imported!.backupManga.single.chapters.single.read, isTrue);
      expect(
        codec
            .decode(retryStorage.uploaded!)
            .backup
            .backupManga
            .single
            .chapters
            .single
            .read,
        isTrue,
      );
    },
  );

  test('settings edited during upload remain local intent on retry', () async {
    const preferenceCodec = ChimahonPreferenceCodec();
    BackupSourcePreferences sourceGroup(String value) =>
        BackupSourcePreferences(
          sourceKey: 'source_1',
          prefs: [preferenceCodec.encode('source-setting', value)],
        );
    BackupMihon local(String value) => BackupMihon(
      backupPreferences: [preferenceCodec.encode('app-setting', value)],
      backupSourcePreferences: [sourceGroup(value)],
    );
    Object? appValue(BackupMihon backup) => preferenceCodec
        .decode(
          backup.backupPreferences.singleWhere(
            (preference) => preference.key == 'app-setting',
          ),
        )
        .value;
    Object? sourceValue(BackupMihon backup) => preferenceCodec
        .decode(backup.backupSourcePreferences.single.prefs.single)
        .value;

    var localState = local('before upload');
    final deferredStore = _MemoryDeferredPayloadStore(localState.deepCopy());
    final storage = _MemoryStorage(
      remote: codec.encode(localState),
      onUpload: () => localState = local('edited in flight'),
    );
    BackupMihon? imported;

    final first = await CrossDeviceSyncEngine(
      storage: storage,
      deferredPayloadStore: deferredStore,
      exportLocal: () async => localState.deepCopy(),
      importMerged: (backup) async => imported = backup,
    ).synchronize();

    expect(first.requiresRetry, isTrue);
    expect(imported, isNull);
    expect(
      preferenceCodec
          .decode(
            deferredStore.localPreferenceBaseline!.singleWhere(
              (preference) => preference.key == 'app-setting',
            ),
          )
          .value,
      'before upload',
    );
    expect(
      preferenceCodec
          .decode(
            deferredStore.localSourcePreferenceBaseline!.single.prefs.single,
          )
          .value,
      'before upload',
    );

    final retryStore = _MemoryDeferredPayloadStore(deferredStore.saved!)
      ..localPreferenceBaseline = [
        for (final preference in deferredStore.localPreferenceBaseline!)
          preference.deepCopy(),
      ]
      ..localSourcePreferenceBaseline = [
        for (final group in deferredStore.localSourcePreferenceBaseline!)
          group.deepCopy(),
      ];
    final retryStorage = _MemoryStorage(remote: storage.uploaded!);
    final retry = await CrossDeviceSyncEngine(
      storage: retryStorage,
      deferredPayloadStore: retryStore,
      exportLocal: () async => localState.deepCopy(),
      importMerged: (backup) async => imported = backup,
    ).synchronize();

    expect(retry.requiresRetry, isFalse);
    final uploaded = codec.decode(retryStorage.uploaded!).backup;
    expect(appValue(uploaded), 'edited in flight');
    expect(sourceValue(uploaded), 'edited in flight');
    expect(appValue(imported!), 'edited in flight');
    expect(sourceValue(imported!), 'edited in flight');
  });

  test(
    'in-flight retry baseline excludes opaque pending-restore preferences',
    () async {
      const preferenceCodec = ChimahonPreferenceCodec();
      BackupMihon local(String value) => BackupMihon(
        backupPreferences: [preferenceCodec.encode('known', value)],
      );
      var localState = local('before upload');
      final store = _MemoryPendingPayloadStore(
        baseline: localState.deepCopy(),
        pending: BackupMihon(
          backupPreferences: [
            preferenceCodec.encode('known', 'before upload'),
            preferenceCodec.encode('opaque-pending-only', 'preserve remotely'),
          ],
        ),
      );
      final storage = _MemoryStorage(
        remote: codec.encode(localState),
        onUpload: () => localState = local('edited in flight'),
      );

      final result = await CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: store,
        exportLocal: () async => localState.deepCopy(),
        importMerged: (_) async {},
      ).synchronize();

      expect(result.requiresRetry, isTrue);
      expect(store.pending, isNull);
      final baselineByKey = {
        for (final preference in store.localPreferenceBaseline!)
          preference.key: preference,
      };
      expect(baselineByKey, isNot(contains('opaque-pending-only')));
      expect(
        baselineByKey.keys,
        containsAll(<String>{
          'known',
          ...ChimahonMediaSyncSelection.preferenceKeys,
        }),
      );
      expect(
        preferenceCodec.decode(baselineByKey['known']!).value,
        'before upload',
      );
      expect(
        codec
            .decode(storage.uploaded!)
            .backup
            .backupPreferences
            .map((preference) => preference.key),
        contains('opaque-pending-only'),
      );
    },
  );
}

class _MemoryDeferredPayloadStore
    implements
        ChimahonDeferredPayloadStore,
        ChimahonLocalPreferenceBaselineStore,
        ChimahonLocalSourcePreferenceBaselineStore {
  _MemoryDeferredPayloadStore(this.baseline)
    : localPreferenceBaseline = baseline.backupPreferences.toList(),
      localSourcePreferenceBaseline = baseline.backupSourcePreferences.toList();

  final BackupMihon baseline;
  BackupMihon? saved;
  List<BackupPreference>? localPreferenceBaseline;
  List<BackupSourcePreferences>? localSourcePreferenceBaseline;
  int saveCount = 0;
  int preferenceBaselineSaveCount = 0;
  int sourceBaselineSaveCount = 0;

  @override
  Future<BackupMihon?> load() async => baseline.deepCopy();

  @override
  Future<void> save(BackupMihon backup) async {
    saveCount++;
    saved = backup.deepCopy();
  }

  @override
  Future<List<BackupPreference>?> loadLocalPreferenceBaseline() async =>
      localPreferenceBaseline;

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
  Future<List<BackupSourcePreferences>?>
  loadLocalSourcePreferenceBaseline() async => localSourcePreferenceBaseline;

  @override
  Future<void> saveLocalSourcePreferenceBaseline(
    Iterable<BackupSourcePreferences> preferences,
  ) async {
    sourceBaselineSaveCount++;
    localSourcePreferenceBaseline = [
      for (final preference in preferences) preference.deepCopy(),
    ];
  }
}

class _MemoryPendingPayloadStore extends _MemoryDeferredPayloadStore
    implements ChimahonPendingLocalPayloadStore {
  _MemoryPendingPayloadStore({
    required BackupMihon baseline,
    required this.pending,
  }) : super(baseline);

  BackupMihon? pending;

  @override
  Future<BackupMihon?> loadPendingLocalPayload() async => pending?.deepCopy();

  @override
  Future<void> save(BackupMihon backup) async {
    await super.save(backup);
    pending = null;
  }
}

class _ProofRecordingAuthority extends ChimahonPendingRestoreAuthority {
  bool proofRan = false;
  bool proofResult = false;

  @override
  bool containsSelectedIntent({
    required BackupMihon uploaded,
    required BackupMihon pending,
    required BackupMihon localIntent,
  }) {
    proofRan = true;
    proofResult = super.containsSelectedIntent(
      uploaded: uploaded,
      pending: pending,
      localIntent: localIntent,
    );
    return proofResult;
  }
}

class _FirstContactPayloadStore
    implements
        ChimahonDeferredPayloadStore,
        ChimahonLocalPreferenceBaselineStore,
        ChimahonLocalSourcePreferenceBaselineStore {
  BackupMihon? saved;
  List<BackupPreference>? localPreferenceBaseline;
  List<BackupSourcePreferences>? localSourcePreferenceBaseline;

  @override
  Future<BackupMihon?> load() async => saved?.deepCopy();

  @override
  Future<void> save(BackupMihon backup) async => saved = backup.deepCopy();

  @override
  Future<List<BackupPreference>?> loadLocalPreferenceBaseline() async =>
      localPreferenceBaseline;

  @override
  Future<void> saveLocalPreferenceBaseline(
    Iterable<BackupPreference> preferences,
  ) async {
    localPreferenceBaseline = [
      for (final preference in preferences) preference.deepCopy(),
    ];
  }

  @override
  Future<List<BackupSourcePreferences>?>
  loadLocalSourcePreferenceBaseline() async => localSourcePreferenceBaseline;

  @override
  Future<void> saveLocalSourcePreferenceBaseline(
    Iterable<BackupSourcePreferences> preferences,
  ) async {
    localSourcePreferenceBaseline = [
      for (final preference in preferences) preference.deepCopy(),
    ];
  }
}

class _MemoryStorage implements CrossDeviceSyncStorage {
  _MemoryStorage({
    required this.remote,
    this.remoteExists = true,
    this.revision = 'revision-1',
    this.isCompleteRecovery = false,
    this.wireFormat = ChimahonSyncWireFormat.protobuf,
    this.onDownload,
    this.onUpload,
  });

  final Uint8List remote;
  final bool remoteExists;
  final String? revision;
  final bool isCompleteRecovery;
  @override
  final ChimahonSyncWireFormat wireFormat;
  final void Function(int count)? onDownload;
  final void Function()? onUpload;
  Uint8List? uploaded;
  String? expectedRevision;
  bool expectedAbsent = false;
  int downloadCount = 0;
  int uploadCount = 0;

  @override
  Future<RemoteSyncSnapshot?> download() async {
    downloadCount++;
    onDownload?.call(downloadCount);
    return remoteExists
        ? RemoteSyncSnapshot(
            bytes: remote,
            revision: revision,
            isCompleteRecovery: isCompleteRecovery,
          )
        : null;
  }

  @override
  Future<String?> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    uploadCount++;
    uploaded = bytes;
    this.expectedRevision = expectedRevision;
    this.expectedAbsent = expectedAbsent;
    onUpload?.call();
    return 'revision-2';
  }
}

class _ConflictingMemoryStorage implements CrossDeviceSyncStorage {
  _ConflictingMemoryStorage(this.snapshots);

  final List<RemoteSyncSnapshot> snapshots;
  final List<String?> uploadRevisions = [];
  var _downloadIndex = 0;
  Uint8List? uploaded;

  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.protobuf;

  @override
  Future<RemoteSyncSnapshot?> download() async => snapshots[_downloadIndex++];

  @override
  Future<String?> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    uploadRevisions.add(expectedRevision);
    if (uploadRevisions.length == 1) {
      throw const SyncConflictException();
    }
    uploaded = bytes;
    return 'revision-3';
  }
}
