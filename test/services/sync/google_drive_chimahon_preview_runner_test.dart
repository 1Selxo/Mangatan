import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/chimahon_sync_safety_audit.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';
import 'package:mangayomi/services/sync/google_drive_chimahon_preview_runner.dart';
import 'package:mangayomi/services/sync/google_drive_oauth.dart';
import 'package:mangayomi/services/sync/google_drive_refresh_token_store.dart';

void main() {
  const codec = ChimahonSyncCodec();

  test(
    'core uses exact account scope, stays write-free, and emits safe aggregates',
    () async {
      const permissionId = 'opaque-private-permission-id';
      const revision = 'opaque-private-drive-revision';
      final remote = BackupMihon();
      final storage = _CountingStorage(
        snapshot: RemoteSyncSnapshot(
          bytes: codec.encode(
            remote,
            format: ChimahonSyncWireFormat.gzipProtobuf,
          ),
          revision: revision,
          isCompleteRecovery: true,
        ),
      );
      final primary = _CountingPrimaryStore();
      final pending = _CountingPendingStore(
        BackupMihon(
          backupNovels: [
            BackupNovel(id: 'pending-empty-metadata-id', title: ''),
          ],
        ),
      );
      String? receivedScope;
      var projectionCalls = 0;
      var storageCloseCount = 0;
      bool? auditRemoteWinsTies;
      final projection = GoogleDriveChimahonLocalProjection(
        backup: BackupMihon(),
        unrepresentablePreferenceKeys: const {'private-preference-key'},
        trackingDeletionKeys: const {
          (source: 42, url: '/private/series', syncId: 1),
        },
      );
      final core = GoogleDriveChimahonReadOnlyPreviewCore(
        oauthClientId: ChimahonGoogleOAuthConfig.current.clientId,
        storage: storage,
        currentUserPermissionId: () async => permissionId,
        localProjection: () async {
          projectionCalls++;
          return projection;
        },
        sidecars: (scope) async {
          receivedScope = scope;
          return LayeredChimahonDeferredPayloadStore(
            primary: primary,
            pendingManualRestore: pending,
          );
        },
        audit:
            ({
              BackupMihon? reference,
              required BackupMihon remote,
              required BackupMihon local,
              required BackupMihon proposed,
              required preferenceSafetyPolicy,
              required localTrackingDeletions,
              required bool remoteWinsTies,
            }) {
              auditRemoteWinsTies = remoteWinsTies;
              return const ChimahonSyncSafetyAudit().audit(
                reference: reference,
                remote: remote,
                local: local,
                proposed: proposed,
                preferenceSafetyPolicy: preferenceSafetyPolicy,
                localTrackingDeletions: localTrackingDeletions,
                remoteWinsTies: remoteWinsTies,
              );
            },
        closeStorage: () => storageCloseCount++,
      );

      final referenceBytes = codec.encode(
        BackupMihon(),
        format: ChimahonSyncWireFormat.gzipProtobuf,
      );
      final report = await core.run(referenceBackupBytes: referenceBytes);
      core
        ..close()
        ..close();

      expect(
        receivedScope,
        'google-drive|${ChimahonGoogleOAuthConfig.current.clientId}|'
        '$permissionId',
      );
      expect(projectionCalls, 2);
      expect(storage.downloadCount, 1);
      expect(storage.uploadCount, 0);
      expect(storageCloseCount, 1);
      expect(primary.saveCount, 0);
      expect(primary.preferenceSaveCount, 0);
      expect(primary.sourcePreferenceSaveCount, 0);
      expect(pending.clearCount, 0);
      expect(auditRemoteWinsTies, isFalse);
      expect(report.referencePresent, isTrue);
      expect(report.remotePresent, isTrue);
      expect(report.remoteRecoveryComplete, isTrue);
      expect(report.pendingManualRestorePresent, isTrue);
      expect(report.localStability.stable, isTrue);
      expect(report.audit?.hardFailures, isEmpty);
      expect(report.audit?.counts['local.novelRecords'], 1);
      expect(report.audit?.counts['proposed.novelRecords'], 1);
      expect(
        report.audit?.observations.map((finding) => finding.code),
        contains('local_only_novel_records'),
      );
      expect(report.safeForFirstUpload, isTrue);
      expect(report.remoteToProposedDiff, isNotNull);
      expect(report.remoteToProposedDiff?.equivalent, isFalse);
      expect(
        report.remoteToProposedDiff?.fieldDifferences,
        contains('BackupMihon.backupNovels[]'),
      );
      expect(report.localFingerprint.counts['novels'], 1);
      expect(report.exportedLocalFingerprint.counts['novels'], 0);
      expect(report.localFingerprint.counts['mangaRecords'], 0);
      expect(
        report.localStability.hashes.values,
        everyElement(matches(RegExp(r'^[0-9a-f]{64}$'))),
      );
      expect(
        report
            .localStability
            .hashes['initialUnrepresentablePreferenceKeysSha256'],
        report
            .localStability
            .hashes['finalUnrepresentablePreferenceKeysSha256'],
      );
      expect(
        report.localStability.hashes['initialTrackingDeletionKeysSha256'],
        report.localStability.hashes['finalTrackingDeletionKeysSha256'],
      );

      final safeJson = jsonEncode(report.toSafeJson());
      for (final secret in [
        permissionId,
        revision,
        receivedScope!,
        'private-preference-key',
        '/private/series',
        'pending-empty-metadata-id',
      ]) {
        expect(safeJson, isNot(contains(secret)));
      }
    },
  );

  test(
    'missing remote returns a conservative report without auditing',
    () async {
      var auditCalls = 0;
      final core = GoogleDriveChimahonReadOnlyPreviewCore(
        oauthClientId: ChimahonGoogleOAuthConfig.current.clientId,
        storage: _CountingStorage(),
        currentUserPermissionId: () async => 'private-account',
        localProjection: () async =>
            GoogleDriveChimahonLocalProjection(backup: BackupMihon()),
        sidecars: (_) async => LayeredChimahonDeferredPayloadStore(
          primary: _CountingPrimaryStore(),
          pendingManualRestore: _CountingPendingStore(),
        ),
        audit:
            ({
              BackupMihon? reference,
              required BackupMihon remote,
              required BackupMihon local,
              required BackupMihon proposed,
              required preferenceSafetyPolicy,
              required localTrackingDeletions,
              required remoteWinsTies,
            }) {
              auditCalls++;
              throw StateError('Audit must not receive an absent remote.');
            },
      );

      final report = await core.run(
        referenceBackupBytes: _encodedBackup(codec, BackupMihon()),
      );
      core.close();

      expect(auditCalls, 0);
      expect(report.referencePresent, isTrue);
      expect(report.remotePresent, isFalse);
      expect(report.remoteRecoveryComplete, isFalse);
      expect(report.remoteFingerprint, isNull);
      expect(report.remoteToProposedDiff, isNull);
      expect(report.audit, isNull);
      expect(report.safeForFirstUpload, isFalse);
      expect(report.toSafeJson()['remoteToProposedDiff'], isNull);
      expect(report.toSafeJson()['audit'], isNull);
    },
  );

  test(
    'incomplete remote recovery cannot pass the first-upload gate',
    () async {
      bool? auditRemoteWinsTies;
      final core = GoogleDriveChimahonReadOnlyPreviewCore(
        oauthClientId: ChimahonGoogleOAuthConfig.current.clientId,
        storage: _CountingStorage(
          snapshot: RemoteSyncSnapshot(
            bytes: _encodedBackup(codec, BackupMihon()),
            revision: 'private-duplicate-set',
          ),
        ),
        currentUserPermissionId: () async => 'private-account',
        localProjection: () async =>
            GoogleDriveChimahonLocalProjection(backup: BackupMihon()),
        sidecars: (_) async => LayeredChimahonDeferredPayloadStore(
          primary: _CountingPrimaryStore(),
          pendingManualRestore: _CountingPendingStore(),
        ),
        audit:
            ({
              BackupMihon? reference,
              required BackupMihon remote,
              required BackupMihon local,
              required BackupMihon proposed,
              required preferenceSafetyPolicy,
              required localTrackingDeletions,
              required bool remoteWinsTies,
            }) {
              auditRemoteWinsTies = remoteWinsTies;
              return const ChimahonSyncSafetyAudit().audit(
                reference: reference,
                remote: remote,
                local: local,
                proposed: proposed,
                preferenceSafetyPolicy: preferenceSafetyPolicy,
                localTrackingDeletions: localTrackingDeletions,
                remoteWinsTies: remoteWinsTies,
              );
            },
      );

      final report = await core.run(
        referenceBackupBytes: _encodedBackup(codec, BackupMihon()),
      );
      core.close();

      expect(report.remotePresent, isTrue);
      expect(auditRemoteWinsTies, isTrue);
      expect(report.remoteRecoveryComplete, isFalse);
      expect(report.audit?.safeToUpload, isTrue);
      expect(report.safeForFirstUpload, isFalse);
      expect(report.toSafeJson()['remoteRecoveryComplete'], isFalse);
    },
  );

  test('all local projection components participate in stability', () async {
    var projectionCalls = 0;
    final scopeBefore = chimahonMediaSelectionScopeToken('scope-before');
    final scopeAfter = chimahonMediaSelectionScopeToken('scope-after');
    final initial = GoogleDriveChimahonLocalProjection(
      backup: BackupMihon(),
      unrepresentablePreferenceKeys: const {'private-key-before'},
      trackingDeletionKeys: const {
        (source: 42, url: '/private/before', syncId: 1),
      },
      persistedMediaSelectionState: ChimahonMediaSyncSelectionState(
        initialized: false,
        scopeToken: scopeBefore,
        generation: 1,
      ),
    );
    final changed = GoogleDriveChimahonLocalProjection(
      backup: BackupMihon(),
      unrepresentablePreferenceKeys: const {'private-key-after'},
      trackingDeletionKeys: const {
        (source: 42, url: '/private/after', syncId: 1),
      },
      persistedMediaSelectionState: ChimahonMediaSyncSelectionState(
        selection: const ChimahonMediaSyncSelection(anime: false),
        initialized: true,
        userSelected: true,
        scopeToken: scopeAfter,
        generation: 2,
      ),
    );
    final storage = _CountingStorage(
      snapshot: RemoteSyncSnapshot(
        bytes: _encodedBackup(codec, BackupMihon()),
        revision: 'secret-revision',
        isCompleteRecovery: true,
      ),
    );
    final core = GoogleDriveChimahonReadOnlyPreviewCore(
      oauthClientId: ChimahonGoogleOAuthConfig.current.clientId,
      storage: storage,
      currentUserPermissionId: () async => 'private-account',
      localProjection: () async => projectionCalls++ == 0 ? initial : changed,
      sidecars: (_) async => LayeredChimahonDeferredPayloadStore(
        primary: _CountingPrimaryStore(),
        pendingManualRestore: _CountingPendingStore(),
      ),
    );

    final report = await core.run(
      referenceBackupBytes: _encodedBackup(codec, BackupMihon()),
    );
    core.close();

    expect(report.localStability.backupUnchanged, isFalse);
    expect(
      report.localStability.unrepresentablePreferenceKeysUnchanged,
      isFalse,
    );
    expect(report.localStability.trackingDeletionKeysUnchanged, isFalse);
    expect(report.localStability.mediaSelectionUnchanged, isFalse);
    expect(
      report.localStability.mediaSelectionInitializationUnchanged,
      isFalse,
    );
    expect(report.localStability.mediaSelectionUserSelectedUnchanged, isFalse);
    expect(report.localStability.mediaSelectionScopeUnchanged, isFalse);
    expect(report.localStability.mediaSelectionGenerationUnchanged, isFalse);
    expect(report.localStability.previewUsedInitialBackup, isTrue);
    expect(report.localStability.stable, isFalse);
    expect(
      report
          .localStability
          .hashes['initialUnrepresentablePreferenceKeysSha256'],
      isNot(
        report
            .localStability
            .hashes['finalUnrepresentablePreferenceKeysSha256'],
      ),
    );
    expect(
      report.localStability.hashes['initialTrackingDeletionKeysSha256'],
      isNot(report.localStability.hashes['finalTrackingDeletionKeysSha256']),
    );
    expect(report.audit?.hardFailures, isEmpty);
    expect(report.safeForFirstUpload, isFalse);
    final safeJson = jsonEncode(report.toSafeJson());
    expect(safeJson, isNot(contains('private-key-before')));
    expect(safeJson, isNot(contains('/private/after')));
  });

  test('runner owns credential refresh and closes OAuth and storage', () async {
    const refreshToken = 'private-refresh-token';
    const accessToken = 'private-access-token';
    const permissionId = 'private-permission-id';
    final tokenStore = _FakeTokenStore(refreshToken);
    final oauth = _FakeOAuthSession(
      clientId: ChimahonGoogleOAuthConfig.current.clientId,
      accessToken: accessToken,
    );
    String? coreAccessToken;
    String? coreClientId;
    var storageCloseCount = 0;
    String? receivedScope;
    final runner = GoogleDriveChimahonPreviewRunner.withDependencies(
      tokenStore: tokenStore,
      oauthFactory: () => oauth,
      coreFactory:
          ({required String accessToken, required String oauthClientId}) {
            coreAccessToken = accessToken;
            coreClientId = oauthClientId;
            return GoogleDriveChimahonReadOnlyPreviewCore(
              oauthClientId: oauthClientId,
              storage: _CountingStorage(
                snapshot: RemoteSyncSnapshot(
                  bytes: _encodedBackup(codec, BackupMihon()),
                  revision: 'private-revision',
                  isCompleteRecovery: true,
                ),
              ),
              currentUserPermissionId: () async => permissionId,
              localProjection: () async =>
                  GoogleDriveChimahonLocalProjection(backup: BackupMihon()),
              sidecars: (scope) async {
                receivedScope = scope;
                return LayeredChimahonDeferredPayloadStore(
                  primary: _CountingPrimaryStore(),
                  pendingManualRestore: _CountingPendingStore(),
                );
              },
              closeStorage: () => storageCloseCount++,
            );
          },
    );

    final report = await runner.run(
      referenceBackupBytes: _encodedBackup(codec, BackupMihon()),
    );

    expect(tokenStore.readCount, 1);
    expect(tokenStore.writeCount, 0);
    expect(tokenStore.clearCount, 0);
    expect(oauth.receivedRefreshToken, refreshToken);
    expect(oauth.closed, isTrue);
    expect(coreAccessToken, accessToken);
    expect(coreClientId, ChimahonGoogleOAuthConfig.current.clientId);
    expect(storageCloseCount, 1);
    expect(report.safeForFirstUpload, isTrue);
    final safeJson = jsonEncode(report.toSafeJson());
    for (final secret in [
      refreshToken,
      accessToken,
      permissionId,
      receivedScope!,
    ]) {
      expect(safeJson, isNot(contains(secret)));
    }
  });

  test('runner reports missing credentials without creating OAuth', () async {
    final tokenStore = _FakeTokenStore(null);
    var oauthCreated = false;
    final runner = GoogleDriveChimahonPreviewRunner.withDependencies(
      tokenStore: tokenStore,
      oauthFactory: () {
        oauthCreated = true;
        return _FakeOAuthSession(clientId: 'unused', accessToken: 'unused');
      },
      coreFactory:
          ({required String accessToken, required String oauthClientId}) =>
              throw StateError('Core must not be created.'),
    );

    await expectLater(
      runner.run(),
      throwsA(
        isA<GoogleDriveChimahonPreviewException>().having(
          (error) => error.code,
          'code',
          'notConnected',
        ),
      ),
    );
    expect(oauthCreated, isFalse);
    expect(tokenStore.writeCount, 0);
    expect(tokenStore.clearCount, 0);
  });

  test('runner redacts authorization errors and still closes OAuth', () async {
    final oauth = _FakeOAuthSession(
      clientId: ChimahonGoogleOAuthConfig.current.clientId,
      accessToken: 'unused',
      refreshError: StateError('server included private-access-token'),
    );
    final runner = GoogleDriveChimahonPreviewRunner.withDependencies(
      tokenStore: _FakeTokenStore('private-refresh-token'),
      oauthFactory: () => oauth,
      coreFactory:
          ({required String accessToken, required String oauthClientId}) =>
              throw StateError('Core must not be created.'),
    );

    await expectLater(
      runner.run(),
      throwsA(
        isA<GoogleDriveChimahonPreviewException>()
            .having((error) => error.code, 'code', 'authorizationFailed')
            .having(
              (error) => error.toString(),
              'safe string',
              isNot(contains('private-access-token')),
            ),
      ),
    );
    expect(oauth.closed, isTrue);
  });

  test('default sidecar layering is read-only and creates no files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mangatan_chimahon_preview_sidecars_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final layered = await GoogleDriveChimahonReadOnlySidecars.open(
      scopeKey: 'google-drive|client|private-account',
      applicationSupportDirectory: directory,
    );

    expect(await layered.load(), isNull);
    expect(await layered.loadPendingLocalPayload(), isNull);
    await expectLater(layered.save(BackupMihon()), throwsUnsupportedError);
    await expectLater(
      layered.pendingManualRestore.clear(),
      throwsUnsupportedError,
    );
    expect(await directory.list(recursive: true).toList(), isEmpty);
  });

  test('invalid reference is rejected with a fixed safe code', () async {
    final core = GoogleDriveChimahonReadOnlyPreviewCore(
      oauthClientId: ChimahonGoogleOAuthConfig.current.clientId,
      storage: _CountingStorage(),
      currentUserPermissionId: () async => 'unused-private-account',
      localProjection: () async =>
          GoogleDriveChimahonLocalProjection(backup: BackupMihon()),
      sidecars: (_) async => LayeredChimahonDeferredPayloadStore(
        primary: _CountingPrimaryStore(),
        pendingManualRestore: _CountingPendingStore(),
      ),
    );

    await expectLater(
      core.run(referenceBackupBytes: Uint8List.fromList([0xff])),
      throwsA(
        isA<GoogleDriveChimahonPreviewException>().having(
          (error) => error.code,
          'code',
          'invalidReferenceBackup',
        ),
      ),
    );
    core.close();
  });
}

Uint8List _encodedBackup(ChimahonSyncCodec codec, BackupMihon backup) =>
    codec.encode(backup, format: ChimahonSyncWireFormat.gzipProtobuf);

class _CountingStorage implements CrossDeviceSyncStorage {
  _CountingStorage({this.snapshot});

  final RemoteSyncSnapshot? snapshot;
  int downloadCount = 0;
  int uploadCount = 0;

  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.gzipProtobuf;

  @override
  Future<RemoteSyncSnapshot?> download() async {
    downloadCount++;
    return snapshot == null
        ? null
        : RemoteSyncSnapshot(
            bytes: Uint8List.fromList(snapshot!.bytes),
            revision: snapshot!.revision,
            isCompleteRecovery: snapshot!.isCompleteRecovery,
          );
  }

  @override
  Future<String?> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    uploadCount++;
    throw StateError('A preview must not call storage.upload.');
  }
}

class _CountingPrimaryStore
    implements
        ChimahonDeferredPayloadStore,
        ChimahonLocalPreferenceBaselineStore,
        ChimahonLocalSourcePreferenceBaselineStore {
  int saveCount = 0;
  int preferenceSaveCount = 0;
  int sourcePreferenceSaveCount = 0;

  @override
  Future<BackupMihon?> load() async => null;

  @override
  Future<List<BackupPreference>?> loadLocalPreferenceBaseline() async => null;

  @override
  Future<List<BackupSourcePreferences>?>
  loadLocalSourcePreferenceBaseline() async => null;

  @override
  Future<void> save(BackupMihon backup) async {
    saveCount++;
  }

  @override
  Future<void> saveLocalPreferenceBaseline(
    Iterable<BackupPreference> preferences,
  ) async {
    preferenceSaveCount++;
  }

  @override
  Future<void> saveLocalSourcePreferenceBaseline(
    Iterable<BackupSourcePreferences> preferences,
  ) async {
    sourcePreferenceSaveCount++;
  }
}

class _CountingPendingStore implements ClearableChimahonDeferredPayloadStore {
  _CountingPendingStore([this.pending]);

  final BackupMihon? pending;
  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<BackupMihon?> load() async => pending?.deepCopy();

  @override
  Future<void> save(BackupMihon backup) async {
    saveCount++;
  }

  @override
  Future<void> clear() async {
    clearCount++;
  }
}

class _FakeTokenStore implements GoogleDriveRefreshTokenStore {
  _FakeTokenStore(this.refreshToken);

  final String? refreshToken;
  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<String?> readRefreshToken() async {
    readCount++;
    return refreshToken;
  }

  @override
  Future<void> writeRefreshToken(String refreshToken) async {
    writeCount++;
  }

  @override
  Future<void> clearRefreshToken() async {
    clearCount++;
  }
}

class _FakeOAuthSession implements GoogleDriveChimahonPreviewOAuthSession {
  _FakeOAuthSession({
    required this.clientId,
    required this.accessToken,
    this.refreshError,
  });

  @override
  final String clientId;
  final String accessToken;
  final Object? refreshError;
  String? receivedRefreshToken;
  bool closed = false;

  @override
  Future<String> refreshAccessToken(String refreshToken) async {
    receivedRefreshToken = refreshToken;
    if (refreshError != null) throw refreshError!;
    return accessToken;
  }

  @override
  void close() {
    closed = true;
  }
}
