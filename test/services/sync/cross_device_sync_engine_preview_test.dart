import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/chimahon_preference_safety_policy.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

void main() {
  const codec = ChimahonSyncCodec();
  const preferenceCodec = ChimahonPreferenceCodec();

  BackupSourcePreferences sourcePreferences(
    String persisted, {
    String? descriptorDefault,
  }) => BackupSourcePreferences(
    sourceKey: 'source_1',
    prefs: [
      preferenceCodec.encode('persisted', persisted),
      if (descriptorDefault != null)
        preferenceCodec.encode('descriptor-default', descriptorDefault),
    ],
  );

  test(
    'routine preview preserves exact equal-clock remote projection and order',
    () async {
      BackupManga manga(String url) => BackupManga(
        source: Int64(1),
        url: url,
        title: 'Title $url',
        lastModifiedAt: Int64(10),
        version: Int64.ZERO,
        chapters: [
          BackupChapter(
            url: '$url/chapter',
            name: 'Chapter',
            lastModifiedAt: Int64(10),
            version: Int64.ZERO,
          ),
        ],
        history: [BackupHistory(url: '$url/chapter', lastRead: Int64(20))],
        tracking: [BackupTracking(syncId: 2, status: 1)],
      );

      final remote = BackupMihon(
        backupCategories: [
          BackupCategory(name: 'First', order: Int64.ZERO, id: Int64(10)),
          BackupCategory(name: 'Second', order: Int64(1), id: Int64(11)),
        ],
        backupManga: [
          manga('/first')..categories.add(Int64.ZERO),
          manga('/second')..categories.add(Int64(1)),
        ],
        backupAnime: [
          BackupAnime(
            source: Int64(2),
            url: '/anime',
            title: 'Anime',
            lastModifiedAt: Int64(30),
            version: Int64.ZERO,
            episodes: [
              BackupEpisode(
                url: '/episode',
                name: 'Episode',
                lastModifiedAt: Int64(30),
                version: Int64.ZERO,
              ),
            ],
          ),
        ],
      );
      final local = remote.deepCopy();
      final reordered = local.backupManga.reversed
          .map((manga) => manga.deepCopy())
          .toList();
      local.backupManga
        ..clear()
        ..addAll(reordered);
      final reorderedCategories = local.backupCategories.reversed
          .map((category) => category.deepCopy())
          .toList();
      local.backupCategories
        ..clear()
        ..addAll(reorderedCategories);
      // Model defaults/presence that a lossy database projection can
      // synthesize after import. Equal clocks retain the exact remote wire
      // representation instead of these defaults or a promoted version.
      local.backupManga.first
        ..viewer = 0
        ..chapterFlags = 0
        ..updateStrategy = 0
        ..notes = '';
      local.backupManga.first.history.single.readDuration = Int64.ZERO;
      local.backupManga.first.tracking.single
        ..libraryId = Int64.ZERO
        ..title = '';
      local.backupAnime.single
        ..episodeFlags = 0
        ..updateStrategy = 0
        ..seasonFlags = Int64.ZERO
        ..seasonNumber = 0
        ..seasonSourceOrder = Int64.ZERO
        ..fetchType = 0;
      local.backupAnime.single.episodes.single
        ..dateFetch = Int64.ZERO
        ..sourceOrder = Int64.ZERO
        ..totalSeconds = Int64.ZERO;

      final preview = await CrossDeviceSyncEngine(
        storage: _CountingStorage(codec.encode(remote)),
        exportLocal: () async => local.deepCopy(),
        importMerged: (_) async {},
      ).preview();

      expect(
        preview.proposedMerged.writeToBuffer(),
        orderedEquals(remote.writeToBuffer()),
      );
    },
  );

  test(
    'routine preview preserves exact remote app and source preference order',
    () async {
      final remote = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('z_app', 'remote z'),
          preferenceCodec.encode('a_app', 'remote a'),
          preferenceCodec.encode('m_app', 'remote m'),
        ],
        backupSourcePreferences: [
          BackupSourcePreferences(
            sourceKey: 'source_z',
            prefs: [
              preferenceCodec.encode('z_nested', 'remote z'),
              preferenceCodec.encode('a_nested', 'remote a'),
              preferenceCodec.encode('m_nested', 'remote m'),
            ],
          ),
          BackupSourcePreferences(
            sourceKey: 'source_a',
            prefs: [preferenceCodec.encode('only', 'remote')],
          ),
        ],
      );
      final local = remote.deepCopy();
      local.backupPreferences
        ..clear()
        ..addAll(
          remote.backupPreferences.reversed.map((value) => value.deepCopy()),
        );
      local.backupSourcePreferences
        ..clear()
        ..addAll(
          remote.backupSourcePreferences.reversed.map((value) {
            final copy = value.deepCopy();
            final reversed = copy.prefs.reversed
                .map((preference) => preference.deepCopy())
                .toList();
            copy.prefs
              ..clear()
              ..addAll(reversed);
            return copy;
          }),
        );

      final preview = await CrossDeviceSyncEngine(
        storage: _CountingStorage(codec.encode(remote)),
        exportLocal: () async => local.deepCopy(),
        importMerged: (_) async {},
      ).preview();

      expect(
        preview.proposedMerged.writeToBuffer(),
        orderedEquals(remote.writeToBuffer()),
      );
      expect(preview.proposedBytes, orderedEquals(codec.encode(remote)));
    },
  );

  test(
    'preview is write-free and matches a stable first-contact upload byte for byte',
    () async {
      final local = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('persisted', 'Mangatan default'),
          preferenceCodec.encode('constructor-default', false),
          preferenceCodec.encode('unrepresentable', 'local projection'),
        ],
        backupSourcePreferences: [
          sourcePreferences(
            'Mangatan descriptor default',
            descriptorDefault: 'not persisted by Chimahon',
          ),
        ],
        backupNovels: [
          BackupNovel(
            id: 'local-novel',
            title: 'Local novel',
            lastModified: Int64(20),
          ),
        ],
      );
      final remote = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('persisted', 'Chimahon value'),
        ],
        backupSourcePreferences: [sourcePreferences('Chimahon source value')],
        backupNovels: [
          BackupNovel(
            id: 'remote-novel',
            title: 'Remote novel',
            lastModified: Int64(10),
          ),
        ],
      );
      final storage = _CountingStorage(codec.encode(remote));
      final sidecar = _CountingSidecarStore();
      var importCount = 0;
      final engine = CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: sidecar,
        exportLocal: () async => local.deepCopy(),
        importMerged: (_) async => importCount++,
        localTrackingDeletions: const {(source: 1, url: '/manga', syncId: 2)},
        localUnrepresentablePreferenceKeys: () => {'unrepresentable'},
      );

      final preview = await engine.preview();
      final proposedBytes = preview.proposedBytes;

      expect(storage.downloadCount, 1);
      expect(storage.uploadCount, 0);
      expect(importCount, 0);
      expect(sidecar.deferredSaveCount, 0);
      expect(sidecar.preferenceBaselineSaveCount, 0);
      expect(sidecar.sourcePreferenceBaselineSaveCount, 0);
      expect(preview.pendingManualRestorePresent, isFalse);
      expect(preview.preferenceSafetyPolicy.remoteAuthoritativeAppKeys, {
        'constructor-default',
        'persisted',
        'unrepresentable',
      });
      expect(
        preview.preferenceSafetyPolicy.remoteAuthoritativeSourceKeys,
        const {
          (sourceKey: 'source_1', preferenceKey: 'descriptor-default'),
          (sourceKey: 'source_1', preferenceKey: 'persisted'),
        },
      );
      expect(preview.unrepresentablePreferenceKeys, {'unrepresentable'});
      expect(preview.localTrackingDeletions, const {
        (source: 1, url: '/manga', syncId: 2),
      });
      expect(
        () => preview.unrepresentablePreferenceKeys.add('mutation'),
        throwsUnsupportedError,
      );
      expect(
        () => preview.localTrackingDeletions.add((
          source: 2,
          url: '/mutation',
          syncId: 3,
        )),
        throwsUnsupportedError,
      );
      expect(
        preview.exportedLocal.writeToBuffer(),
        orderedEquals(local.writeToBuffer()),
      );
      final effectiveLocalIntent = preview.effectiveLocalIntent;
      expect(
        {
          for (final preference in effectiveLocalIntent.backupPreferences)
            preference.key: preferenceCodec.decode(preference).value,
        },
        {'persisted': 'Chimahon value'},
        reason: 'the effective merger input contains reconciled app settings',
      );
      expect(
        BackupMihon(
          backupSourcePreferences: effectiveLocalIntent.backupSourcePreferences,
          backupNovels: effectiveLocalIntent.backupNovels,
        ).writeToBuffer(),
        orderedEquals(
          BackupMihon(
            backupSourcePreferences: local.backupSourcePreferences,
            backupNovels: local.backupNovels,
          ).writeToBuffer(),
        ),
        reason: 'unrelated local intent remains unchanged',
      );
      expect(preview.remoteSnapshot!.revision, 'revision-1');
      expect(
        preview.remoteSnapshot!.bytes,
        orderedEquals(codec.encode(remote)),
      );
      expect(
        preview.decodedRemote!.writeToBuffer(),
        orderedEquals(remote.writeToBuffer()),
      );
      expect(
        codec.decode(proposedBytes).backup.writeToBuffer(),
        orderedEquals(preview.proposedMerged.writeToBuffer()),
      );

      final appValues = {
        for (final preference in preview.proposedMerged.backupPreferences)
          preference.key: preferenceCodec.decode(preference).value,
      };
      expect(appValues, {'persisted': 'Chimahon value'});
      final sourceValues = {
        for (final preference
            in preview.proposedMerged.backupSourcePreferences.single.prefs)
          preference.key: preferenceCodec.decode(preference).value,
      };
      expect(sourceValues, {'persisted': 'Chimahon source value'});

      // The result is defensive even though protobuf messages and byte buffers
      // are mutable.
      preview.exportedLocal.backupNovels.clear();
      preview.effectiveLocalIntent.backupNovels.clear();
      final mutatedBytes = preview.proposedBytes;
      mutatedBytes[0] = (mutatedBytes[0] + 1) & 0xff;
      expect(preview.exportedLocal.backupNovels, hasLength(1));
      expect(preview.effectiveLocalIntent.backupNovels, hasLength(1));
      expect(mutatedBytes, isNot(orderedEquals(preview.proposedBytes)));

      await engine.uploadPreservingRemote();

      expect(storage.downloadCount, 2);
      expect(storage.uploadCount, 1);
      expect(importCount, 0);
      expect(storage.uploaded, orderedEquals(proposedBytes));
      expect(sidecar.deferredSaveCount, 1);
      expect(sidecar.preferenceBaselineSaveCount, 1);
      expect(sidecar.sourcePreferenceBaselineSaveCount, 1);
    },
  );

  test(
    'existing selector-less sidecar keeps absent remote controls exact',
    () async {
      const localSelection = ChimahonMediaSyncSelection(
        manga: false,
        anime: false,
        novels: false,
      );
      final remote = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('before', 'remote'),
          preferenceCodec.encode('after', 7),
        ],
      );
      remote.backupPreferences.first.unknownFields.mergeVarintField(
        701,
        Int64(9),
      );
      final local = localSelection.withBackedPreferences(remote);
      final storage = _CountingStorage(codec.encode(remote));
      final sidecar = _CountingSidecarStore(
        baseline: remote,
        localPreferenceBaseline: remote.backupPreferences,
      );
      final engine = CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: sidecar,
        exportLocal: () async => local.deepCopy(),
        importMerged: (_) async {},
        localMediaSelection: localSelection,
        localMediaSelectionInitialized: true,
        localMediaSelectionUserSelected: false,
      );

      final preview = await engine.preview();
      final previewBytes = preview.proposedBytes;

      expect(preview.mediaSelection, const ChimahonMediaSyncSelection());
      expect(
        preview.proposedMerged.writeToBuffer(),
        orderedEquals(remote.writeToBuffer()),
        reason: 'remote absence is the authoritative Chimahon true default',
      );
      expect(previewBytes, orderedEquals(codec.encode(remote)));

      await engine.uploadPreservingRemote();

      expect(storage.uploaded, orderedEquals(previewBytes));
    },
  );

  test(
    'existing sidecar keeps malformed remote control exact without persistence',
    () async {
      const localSelection = ChimahonMediaSyncSelection(anime: false);
      final malformed = preferenceCodec.encode(
        ChimahonMediaSyncSelection.animePreferenceKey,
        'future representation',
      )..unknownFields.mergeVarintField(702, Int64(11));
      final remote = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('before', true),
          malformed,
          preferenceCodec.encode('after', 'remote'),
        ],
      );
      final local = localSelection.withBackedPreferences(remote);
      final storage = _CountingStorage(codec.encode(remote));
      final sidecar = _CountingSidecarStore(
        baseline: remote,
        localPreferenceBaseline: remote.backupPreferences,
      );
      final engine = CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: sidecar,
        exportLocal: () async => local.deepCopy(),
        importMerged: (_) async {},
        localMediaSelection: localSelection,
        localMediaSelectionInitialized: true,
        localMediaSelectionUserSelected: false,
      );

      final preview = await engine.preview();
      final previewBytes = preview.proposedBytes;

      expect(preview.mediaSelection, localSelection);
      expect(
        preview.proposedMerged.writeToBuffer(),
        orderedEquals(remote.writeToBuffer()),
      );
      expect(previewBytes, orderedEquals(codec.encode(remote)));

      final result = await engine.uploadPreservingRemote();

      expect(storage.uploaded, orderedEquals(previewBytes));
      expect(result.mediaSelectionInitializationCompleted, isFalse);
      expect(result.mediaSelectionNeedsPersistence, isFalse);
    },
  );

  test(
    'preview retains pending restore intent without consuming it and matches upload',
    () async {
      final baseline = BackupMihon(
        backupPreferences: [preferenceCodec.encode('known', 'old baseline')],
        backupSourcePreferences: [sourcePreferences('old baseline')],
      );
      final pending = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('known', 'restored value'),
          preferenceCodec.encode('pending-only', 'preserve me'),
        ],
        backupSourcePreferences: [
          BackupSourcePreferences(
            sourceKey: 'source_1',
            prefs: [
              preferenceCodec.encode('persisted', 'restored source value'),
              preferenceCodec.encode('pending-only', 'preserve source value'),
            ],
          ),
        ],
        backupNovels: [
          BackupNovel(
            id: 'selected-novel',
            title: 'Selected novel',
            chapterIndex: 4,
            progress: 0.75,
            lastModified: Int64(100),
          ),
        ],
      );
      final local = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('known', 'post-restore local value'),
        ],
        backupSourcePreferences: [
          sourcePreferences('post-restore source value'),
        ],
        backupNovels: [
          BackupNovel(
            id: 'selected-novel',
            title: 'Selected novel',
            chapterIndex: 5,
            progress: 0.8,
            lastModified: Int64(110),
          ),
        ],
      );
      final remote = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('known', 'newer remote value'),
        ],
        backupSourcePreferences: [sourcePreferences('newer remote value')],
        backupNovels: [
          BackupNovel(
            id: 'cloud-only',
            title: 'Cloud-only novel',
            lastModified: Int64(200),
          ),
        ],
      );
      final storage = _CountingStorage(codec.encode(remote));
      final pendingProjectedBaseline = BackupMihon(
        backupPreferences: [preferenceCodec.encode('known', 'restored value')],
        backupSourcePreferences: [sourcePreferences('restored source value')],
      );
      final sidecar = _CountingSidecarStore(
        baseline: baseline,
        pending: pending,
        localPreferenceBaseline: baseline.backupPreferences,
        localSourcePreferenceBaseline: baseline.backupSourcePreferences,
        pendingLocalPreferenceBaseline:
            pendingProjectedBaseline.backupPreferences,
        pendingLocalSourcePreferenceBaseline:
            pendingProjectedBaseline.backupSourcePreferences,
      );
      var importCount = 0;
      final engine = CrossDeviceSyncEngine(
        storage: storage,
        deferredPayloadStore: sidecar,
        exportLocal: () async => local.deepCopy(),
        importMerged: (_) async => importCount++,
      );

      final preview = await engine.preview();
      final proposedBytes = preview.proposedBytes;

      expect(storage.downloadCount, 1);
      expect(storage.uploadCount, 0);
      expect(importCount, 0);
      expect(preview.pendingManualRestorePresent, isTrue);
      expect(
        preview.preferenceSafetyPolicy.remoteAuthoritativeAppKeys,
        isEmpty,
      );
      expect(
        preview.preferenceSafetyPolicy.remoteAuthoritativeSourceKeys,
        isEmpty,
      );
      expect(sidecar.pending, isNotNull);
      expect(sidecar.deferredSaveCount, 0);
      expect(sidecar.preferenceBaselineSaveCount, 0);
      expect(sidecar.sourcePreferenceBaselineSaveCount, 0);
      final effectiveLocalIntent = preview.effectiveLocalIntent;
      expect(
        effectiveLocalIntent.backupPreferences.map(
          (preference) => preference.key,
        ),
        containsAll(['known', 'pending-only']),
      );
      expect(
        preferenceCodec
            .decode(
              effectiveLocalIntent.backupPreferences.singleWhere(
                (preference) => preference.key == 'known',
              ),
            )
            .value,
        'post-restore local value',
      );
      final effectiveSelectedNovel = effectiveLocalIntent.backupNovels.single;
      expect(effectiveSelectedNovel.title, 'Selected novel');
      expect(effectiveSelectedNovel.chapterIndex, 5);
      expect(effectiveSelectedNovel.progress, 0.8);
      expect(
        effectiveLocalIntent.backupNovels.map((novel) => novel.title),
        isNot(contains('Cloud-only novel')),
      );
      effectiveLocalIntent.backupNovels.clear();
      expect(preview.effectiveLocalIntent.backupNovels, hasLength(1));
      final proposed = codec.decode(proposedBytes).backup;
      expect(
        proposed.backupPreferences.map((preference) => preference.key),
        contains('pending-only'),
      );
      final selectedNovel = proposed.backupNovels.singleWhere(
        (novel) => novel.title == 'Selected novel',
      );
      expect(selectedNovel.chapterIndex, 5);
      expect(selectedNovel.progress, 0.8);
      expect(
        proposed.backupNovels.map((novel) => novel.title),
        contains('Cloud-only novel'),
      );

      await engine.uploadPreservingRemote();

      expect(storage.downloadCount, 2);
      expect(storage.uploadCount, 1);
      expect(importCount, 0);
      expect(storage.uploaded, orderedEquals(proposedBytes));
      expect(sidecar.pending, isNull);
      expect(sidecar.deferredSaveCount, 1);
      expect(sidecar.preferenceBaselineSaveCount, 1);
      expect(sidecar.sourcePreferenceBaselineSaveCount, 1);
    },
  );

  test(
    'pending tracker deletion survives the promoted local parent overlay',
    () async {
      final pending = BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/tracked',
            title: 'Tracked',
            lastModifiedAt: Int64(100),
            version: Int64(4),
            tracking: [
              BackupTracking(syncId: 2, status: 1),
              BackupTracking(syncId: 3, status: 1),
              BackupTracking(syncId: 4, status: 1),
            ],
          ),
        ],
      );
      final local = BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/tracked',
            title: 'Tracked',
            lastModifiedAt: Int64(200),
            version: Int64.ZERO,
            tracking: [BackupTracking(syncId: 3, status: 1)],
          ),
        ],
      );
      final remote = BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(1),
            url: '/tracked',
            title: 'Tracked',
            lastModifiedAt: Int64(50),
            version: Int64(1),
            tracking: [
              BackupTracking(syncId: 2, status: 1),
              BackupTracking(syncId: 3, status: 1),
              BackupTracking(syncId: 4, status: 1),
            ],
          ),
        ],
      );
      final engine = CrossDeviceSyncEngine(
        storage: _CountingStorage(codec.encode(remote)),
        exportLocal: () async => local.deepCopy(),
        importMerged: (_) async {},
        deferredPayloadStore: _CountingSidecarStore(pending: pending),
        localTrackingDeletions: const {
          (source: 1, url: '/tracked', syncId: 2),
          // A tracker re-added before sync wins over its older deletion marker.
          (source: 1, url: '/tracked', syncId: 3),
        },
      );

      final preview = await engine.preview();

      expect(
        preview.effectiveLocalIntent.backupManga.single.tracking.map(
          (row) => row.syncId,
        ),
        [3, 4],
      );
      expect(
        preview.proposedMerged.backupManga.single.tracking.map(
          (row) => row.syncId,
        ),
        [3, 4],
      );
      expect(preview.proposedMerged.backupManga.single.version, Int64(5));
    },
  );

  test(
    'pending tracker deletion beats a higher-version cloud parent',
    () async {
      BackupManga tracked({required Int64 modified, required Int64 version}) =>
          BackupManga(
            source: Int64(1),
            url: '/tracked',
            title: 'Tracked',
            lastModifiedAt: modified,
            version: version,
            tracking: [
              BackupTracking(syncId: 2, status: 1),
              BackupTracking(syncId: 4, status: 1),
            ],
          );

      final engine = CrossDeviceSyncEngine(
        storage: _CountingStorage(
          codec.encode(
            BackupMihon(
              backupManga: [tracked(modified: Int64(300), version: Int64(50))],
            ),
          ),
        ),
        exportLocal: () async => BackupMihon(
          backupManga: [
            BackupManga(
              source: Int64(1),
              url: '/tracked',
              title: 'Tracked',
              lastModifiedAt: Int64(200),
              version: Int64.ZERO,
            ),
          ],
        ),
        importMerged: (_) async {},
        deferredPayloadStore: _CountingSidecarStore(
          pending: BackupMihon(
            backupManga: [tracked(modified: Int64(100), version: Int64(4))],
          ),
        ),
        localTrackingDeletions: const {(source: 1, url: '/tracked', syncId: 2)},
      );

      final preview = await engine.preview();

      expect(
        preview.effectiveLocalIntent.backupManga.single.tracking.map(
          (row) => row.syncId,
        ),
        [4],
      );
      final proposed = preview.proposedMerged.backupManga.single;
      expect(proposed.version, Int64(51));
      expect(proposed.tracking.map((row) => row.syncId), [4]);
    },
  );

  test('first-file creation classifies every local preference path', () async {
    final localGroup = BackupSourcePreferences(
      sourceKey: 'source_1',
      prefs: [preferenceCodec.encode('source-setting', 'local')],
    )..unknownFields.mergeVarintField(700, Int64(1));
    final local = BackupMihon(
      backupPreferences: [preferenceCodec.encode('app-setting', 'local')],
      backupSourcePreferences: [localGroup],
    );

    final preview = await CrossDeviceSyncEngine(
      storage: _CountingStorage(null),
      exportLocal: () async => local.deepCopy(),
      importMerged: (_) async {},
    ).preview();

    expect(preview.remoteSnapshot, isNull);
    expect(preview.preferenceSafetyPolicy.appSelections, {
      'app-setting': ChimahonPreferenceSelectionOrigin.local,
    });
    expect(preview.preferenceSafetyPolicy.sourceSelections, const {
      (sourceKey: 'source_1', preferenceKey: 'source-setting'):
          ChimahonPreferenceSelectionOrigin.local,
    });
    expect(preview.preferenceSafetyPolicy.sourceGroupEnvelopeSelections, {
      'source_1': ChimahonPreferenceSelectionOrigin.local,
    });
  });

  test(
    'pending projection evidence preserves incompatible values, app deletion, source gaps, and both group envelopes',
    () async {
      final futurePending = preferenceCodec.encode(
        'future-setting',
        'selected future value',
      )..unknownFields.mergeVarintField(701, Int64(2));
      final pendingGroup = BackupSourcePreferences(
        sourceKey: 'source_1',
        prefs: [preferenceCodec.encode('preserve-source-setting', true)],
      )..unknownFields.mergeVarintField(702, Int64(3));
      final pending = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('delete-app-setting', true),
          futurePending,
        ],
        backupSourcePreferences: [pendingGroup],
      );
      final projectedBaseline = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('delete-app-setting', true),
          preferenceCodec.encode('future-setting', 'fallback projection'),
        ],
        backupSourcePreferences: [
          BackupSourcePreferences(
            sourceKey: 'source_1',
            prefs: [preferenceCodec.encode('preserve-source-setting', true)],
          ),
        ],
      );
      final remoteGroup = BackupSourcePreferences(
        sourceKey: 'source_1',
        prefs: [
          preferenceCodec.encode('preserve-source-setting', true),
          preferenceCodec.encode('remote-only', 'keep'),
        ],
      )..unknownFields.mergeVarintField(703, Int64(4));
      final remote = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('delete-app-setting', true),
          preferenceCodec.encode('future-setting', 'cloud value'),
        ],
        backupSourcePreferences: [remoteGroup],
      );
      final current = BackupMihon(
        backupPreferences: [
          preferenceCodec.encode('future-setting', 'fallback projection'),
        ],
      );
      final sidecar = _CountingSidecarStore(
        baseline: remote,
        pending: pending,
        localPreferenceBaseline: projectedBaseline.backupPreferences,
        localSourcePreferenceBaseline:
            projectedBaseline.backupSourcePreferences,
        pendingLocalPreferenceBaseline: projectedBaseline.backupPreferences,
        pendingLocalSourcePreferenceBaseline:
            projectedBaseline.backupSourcePreferences,
      );

      final preview = await CrossDeviceSyncEngine(
        storage: _CountingStorage(codec.encode(remote)),
        deferredPayloadStore: sidecar,
        exportLocal: () async => current.deepCopy(),
        importMerged: (_) async {},
      ).preview();
      final proposed = preview.proposedMerged;
      final appByKey = {
        for (final preference in proposed.backupPreferences)
          preference.key: preference,
      };
      final proposedGroup = proposed.backupSourcePreferences.single;
      final sourceByKey = {
        for (final preference in proposedGroup.prefs)
          preference.key: preference,
      };

      expect(appByKey, isNot(contains('delete-app-setting')));
      expect(
        preferenceCodec.decode(appByKey['future-setting']!).value,
        'selected future value',
      );
      expect(appByKey['future-setting']!.unknownFields.hasField(701), isTrue);
      expect(
        preferenceCodec.decode(sourceByKey['preserve-source-setting']!).value,
        isTrue,
      );
      expect(preferenceCodec.decode(sourceByKey['remote-only']!).value, 'keep');
      expect(proposedGroup.unknownFields.hasField(702), isTrue);
      expect(proposedGroup.unknownFields.hasField(703), isTrue);
      expect(
        preview.preferenceSafetyPolicy.appSelections['delete-app-setting'],
        ChimahonPreferenceSelectionOrigin.deleted,
      );
      expect(
        preview.preferenceSafetyPolicy.sourceSelections[const (
          sourceKey: 'source_1',
          preferenceKey: 'preserve-source-setting',
        )],
        ChimahonPreferenceSelectionOrigin.local,
      );
      expect(
        preview
            .preferenceSafetyPolicy
            .sourceGroupEnvelopeSelections['source_1'],
        ChimahonPreferenceSelectionOrigin.local,
      );
    },
  );
}

class _CountingStorage implements CrossDeviceSyncStorage {
  _CountingStorage(this.remote);

  final Uint8List? remote;
  int downloadCount = 0;
  int uploadCount = 0;
  Uint8List? uploaded;

  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.protobuf;

  @override
  Future<RemoteSyncSnapshot?> download() async {
    downloadCount++;
    final current = remote;
    if (current == null) return null;
    return RemoteSyncSnapshot(
      bytes: Uint8List.fromList(current),
      revision: 'revision-1',
    );
  }

  @override
  Future<String?> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    uploadCount++;
    uploaded = Uint8List.fromList(bytes);
    return 'revision-2';
  }
}

class _CountingSidecarStore
    implements
        ChimahonDeferredPayloadStore,
        ChimahonPendingLocalPayloadStore,
        ChimahonPendingLocalProjectionBaselineStore,
        ChimahonLocalPreferenceBaselineStore,
        ChimahonLocalSourcePreferenceBaselineStore {
  _CountingSidecarStore({
    BackupMihon? baseline,
    BackupMihon? pending,
    Iterable<BackupPreference>? localPreferenceBaseline,
    Iterable<BackupSourcePreferences>? localSourcePreferenceBaseline,
    Iterable<BackupPreference>? pendingLocalPreferenceBaseline,
    Iterable<BackupSourcePreferences>? pendingLocalSourcePreferenceBaseline,
  }) : _baseline = baseline?.deepCopy(),
       pending = pending?.deepCopy(),
       _localPreferenceBaseline = localPreferenceBaseline == null
           ? null
           : [
               for (final preference in localPreferenceBaseline)
                 preference.deepCopy(),
             ],
       _localSourcePreferenceBaseline = localSourcePreferenceBaseline == null
           ? null
           : [
               for (final group in localSourcePreferenceBaseline)
                 group.deepCopy(),
             ],
       _pendingLocalPreferenceBaseline = pendingLocalPreferenceBaseline == null
           ? null
           : [
               for (final preference in pendingLocalPreferenceBaseline)
                 preference.deepCopy(),
             ],
       _pendingLocalSourcePreferenceBaseline =
           pendingLocalSourcePreferenceBaseline == null
           ? null
           : [
               for (final group in pendingLocalSourcePreferenceBaseline)
                 group.deepCopy(),
             ];

  BackupMihon? _baseline;
  BackupMihon? pending;
  List<BackupPreference>? _localPreferenceBaseline;
  List<BackupSourcePreferences>? _localSourcePreferenceBaseline;
  final List<BackupPreference>? _pendingLocalPreferenceBaseline;
  final List<BackupSourcePreferences>? _pendingLocalSourcePreferenceBaseline;
  int deferredSaveCount = 0;
  int preferenceBaselineSaveCount = 0;
  int sourcePreferenceBaselineSaveCount = 0;

  @override
  Future<BackupMihon?> load() async => _baseline?.deepCopy();

  @override
  Future<BackupMihon?> loadPendingLocalPayload() async => pending?.deepCopy();

  @override
  Future<List<BackupPreference>?> loadPendingLocalPreferenceBaseline() async =>
      _pendingLocalPreferenceBaseline == null
      ? null
      : [
          for (final preference in _pendingLocalPreferenceBaseline)
            preference.deepCopy(),
        ];

  @override
  Future<List<BackupSourcePreferences>?>
  loadPendingLocalSourcePreferenceBaseline() async =>
      _pendingLocalSourcePreferenceBaseline == null
      ? null
      : [
          for (final group in _pendingLocalSourcePreferenceBaseline)
            group.deepCopy(),
        ];

  @override
  Future<List<BackupPreference>?> loadLocalPreferenceBaseline() async =>
      _localPreferenceBaseline == null
      ? null
      : [
          for (final preference in _localPreferenceBaseline!)
            preference.deepCopy(),
        ];

  @override
  Future<List<BackupSourcePreferences>?>
  loadLocalSourcePreferenceBaseline() async =>
      _localSourcePreferenceBaseline == null
      ? null
      : [for (final group in _localSourcePreferenceBaseline!) group.deepCopy()];

  @override
  Future<void> save(BackupMihon backup) async {
    deferredSaveCount++;
    _baseline = backup.deepCopy();
    pending = null;
  }

  @override
  Future<void> saveLocalPreferenceBaseline(
    Iterable<BackupPreference> preferences,
  ) async {
    preferenceBaselineSaveCount++;
    _localPreferenceBaseline = [
      for (final preference in preferences) preference.deepCopy(),
    ];
  }

  @override
  Future<void> saveLocalSourcePreferenceBaseline(
    Iterable<BackupSourcePreferences> preferences,
  ) async {
    sourcePreferenceBaselineSaveCount++;
    _localSourcePreferenceBaseline = [
      for (final group in preferences) group.deepCopy(),
    ];
  }
}
