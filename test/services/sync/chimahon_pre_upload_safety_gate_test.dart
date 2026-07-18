import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_pre_upload_safety_gate.dart';
import 'package:mangayomi/services/sync/chimahon_remote_recovery_store.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/chimahon_sync_safety_audit.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

void main() {
  const codec = ChimahonSyncCodec();

  BackupMihon backup({
    required String title,
    required String url,
    bool favorite = true,
  }) => BackupMihon(
    backupManga: [
      BackupManga(
        source: Int64(42),
        url: url,
        title: title,
        favorite: favorite,
        version: Int64(1),
        lastModifiedAt: Int64(1),
      ),
    ],
    backupSources: [BackupSource(sourceId: Int64(42), name: 'Source')],
  );

  test('recovery is complete before the safe audit permits upload', () async {
    final remote = backup(title: 'Remote private title', url: '/private');
    final local = backup(title: 'Remote private title', url: '/private');
    final remoteBytes = codec.encode(remote);
    final storage = _GateStorage(
      RemoteSyncSnapshot(
        bytes: remoteBytes,
        revision: 'remote-revision',
        isCompleteRecovery: true,
      ),
    );
    final recovery = _RecordingRecoveryStore();
    final pending = BackupMihon(
      backupNovels: [
        BackupNovel(
          id: 'pending-empty-metadata-id',
          title: '',
          lastModified: Int64(2),
        ),
      ],
    );
    var auditCount = 0;
    final gate = ChimahonPreUploadSafetyGate(
      recoveryStore: recovery,
      audit:
          ({
            reference,
            required remote,
            required local,
            required proposed,
            required preferenceSafetyPolicy,
            required localTrackingDeletions,
            required remoteWinsTies,
          }) {
            expect(recovery.snapshots, hasLength(1));
            expect(remoteWinsTies, isFalse);
            expect(
              local.backupNovels.map((novel) => novel.id),
              contains('pending-empty-metadata-id'),
            );
            auditCount++;
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

    await CrossDeviceSyncEngine(
      storage: storage,
      exportLocal: () async => local,
      importMerged: (_) async {},
      deferredPayloadStore: _PendingSidecar(pending),
      preUpload: gate.check,
    ).uploadPreservingRemote();

    expect(auditCount, 1);
    expect(storage.uploadCount, 1);
    expect(recovery.snapshots.single.revision, 'remote-revision');
    expect(recovery.snapshots.single.bytes, orderedEquals(remoteBytes));
  });

  test(
    'hard audit findings refuse upload with codes and counts only',
    () async {
      const secretTitle = 'do not disclose this private title';
      const secretUrl = '/do/not/disclose/this/url';
      final remote = backup(
        title: secretTitle,
        url: secretUrl,
        favorite: false,
      );
      final remoteBytes = codec.encode(remote);
      final local = remote.deepCopy()
        ..unknownFields.mergeVarintField(700, Int64(1));
      final storage = _GateStorage(
        RemoteSyncSnapshot(
          bytes: remoteBytes,
          revision: 'secret-drive-id-and-revision',
          isCompleteRecovery: true,
        ),
      );
      final recovery = _RecordingRecoveryStore();
      final gate = ChimahonPreUploadSafetyGate(recoveryStore: recovery);
      var importCount = 0;

      Object? failure;
      try {
        await CrossDeviceSyncEngine(
          storage: storage,
          exportLocal: () async => local.deepCopy(),
          importMerged: (_) async => importCount++,
          preUpload: gate.check,
        ).synchronize();
      } catch (error) {
        failure = error;
      }

      expect(failure, isA<ChimahonPreUploadSafetyException>());
      final safeFailure = failure! as ChimahonPreUploadSafetyException;
      expect(safeFailure.code, 'unsafe_proposed_payload');
      expect(
        safeFailure.failureCounts,
        containsPair('remote_tombstone_deletion_clock_missing', 1),
      );
      expect(
        safeFailure.failureCounts,
        containsPair('remote_tombstone_not_preserved', 1),
      );
      expect(safeFailure.toString(), isNot(contains(secretTitle)));
      expect(safeFailure.toString(), isNot(contains(secretUrl)));
      expect(safeFailure.toString(), isNot(contains('secret-drive-id')));
      expect(recovery.snapshots, hasLength(1));
      expect(recovery.snapshots.single.bytes, orderedEquals(remoteBytes));
      expect(storage.uploadCount, 0);
      expect(importCount, 0);
    },
  );

  test('incomplete recovery refuses upload before running the audit', () async {
    final remote = backup(title: 'Remote', url: '/remote');
    final storage = _GateStorage(
      RemoteSyncSnapshot(bytes: codec.encode(remote), revision: 'revision-1'),
    );
    final recovery = _RecordingRecoveryStore(
      failure: const ChimahonRemoteRecoveryException(
        ChimahonRemoteRecoveryFailure.incompleteSnapshot,
      ),
    );
    var auditCount = 0;
    final gate = ChimahonPreUploadSafetyGate(
      recoveryStore: recovery,
      audit:
          ({
            reference,
            required remote,
            required local,
            required proposed,
            required preferenceSafetyPolicy,
            required localTrackingDeletions,
            required remoteWinsTies,
          }) {
            auditCount++;
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

    await expectLater(
      CrossDeviceSyncEngine(
        storage: storage,
        exportLocal: () async => remote.deepCopy(),
        importMerged: (_) async {},
        preUpload: gate.check,
      ).uploadPreservingRemote(),
      throwsA(
        isA<ChimahonPreUploadSafetyException>().having(
          (error) => error.code,
          'code',
          'incomplete_remote_snapshot',
        ),
      ),
    );

    expect(auditCount, 0);
    expect(storage.uploadCount, 0);
  });

  test(
    'blob-retaining upload skips local recovery but still runs the audit',
    () async {
      final remote = backup(title: 'Remote', url: '/remote');
      final storage = _GateStorage(
        RemoteSyncSnapshot(
          bytes: codec.encode(remote),
          revision: 'duplicate-set-revision',
          uploadRetainsAllRemoteByteBlobs: true,
        ),
      );
      final recovery = _RecordingRecoveryStore(
        failure: const ChimahonRemoteRecoveryException(
          ChimahonRemoteRecoveryFailure.incompleteSnapshot,
        ),
      );
      var auditCount = 0;
      final gate = ChimahonPreUploadSafetyGate(
        recoveryStore: recovery,
        audit:
            ({
              reference,
              required remote,
              required local,
              required proposed,
              required preferenceSafetyPolicy,
              required localTrackingDeletions,
              required remoteWinsTies,
            }) {
              auditCount++;
              expect(remoteWinsTies, isTrue);
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

      await CrossDeviceSyncEngine(
        storage: storage,
        exportLocal: () async => remote.deepCopy(),
        importMerged: (_) async {},
        preUpload: gate.check,
      ).uploadPreservingRemote();

      expect(recovery.snapshots, isEmpty);
      expect(auditCount, 1);
      expect(storage.uploadCount, 1);
    },
  );

  test('missing remote creation needs no recovery archive', () async {
    final storage = _GateStorage(null);
    final recovery = _RecordingRecoveryStore();
    var auditCount = 0;
    final gate = ChimahonPreUploadSafetyGate(
      recoveryStore: recovery,
      audit:
          ({
            reference,
            required remote,
            required local,
            required proposed,
            required preferenceSafetyPolicy,
            required localTrackingDeletions,
            required remoteWinsTies,
          }) {
            auditCount++;
            expect(remoteWinsTies, isTrue);
            expect(remote.writeToBuffer(), isEmpty);
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

    await CrossDeviceSyncEngine(
      storage: storage,
      exportLocal: () async => backup(title: 'Local', url: '/local'),
      importMerged: (_) async {},
      preUpload: gate.check,
    ).uploadPreservingRemote();

    expect(recovery.snapshots, isEmpty);
    expect(auditCount, 1);
    expect(storage.uploadCount, 1);
    expect(storage.expectedAbsent, isTrue);
  });
}

class _PendingSidecar
    implements ChimahonDeferredPayloadStore, ChimahonPendingLocalPayloadStore {
  _PendingSidecar(this.pending);

  final BackupMihon pending;

  @override
  Future<BackupMihon?> load() async => null;

  @override
  Future<BackupMihon?> loadPendingLocalPayload() async => pending.deepCopy();

  @override
  Future<void> save(BackupMihon backup) async {}
}

class _RecordingRecoveryStore implements ChimahonRemoteRecoveryStore {
  _RecordingRecoveryStore({this.failure});

  final Object? failure;
  final List<RemoteSyncSnapshot> snapshots = [];

  @override
  Future<ChimahonRemoteRecoveryRecord> preserve(
    RemoteSyncSnapshot snapshot,
  ) async {
    snapshots.add(
      RemoteSyncSnapshot(
        bytes: Uint8List.fromList(snapshot.bytes),
        revision: snapshot.revision,
        isCompleteRecovery: snapshot.isCompleteRecovery,
        uploadRetainsAllRemoteByteBlobs:
            snapshot.uploadRetainsAllRemoteByteBlobs,
      ),
    );
    if (failure != null) throw failure!;
    return const ChimahonRemoteRecoveryRecord(
      digest:
          '0000000000000000000000000000000000000000000000000000000000000000',
      alreadyPresent: false,
    );
  }
}

class _GateStorage implements CrossDeviceSyncStorage {
  _GateStorage(this.snapshot);

  final RemoteSyncSnapshot? snapshot;
  int uploadCount = 0;
  bool? expectedAbsent;

  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.protobuf;

  @override
  Future<RemoteSyncSnapshot?> download() async => snapshot;

  @override
  Future<String?> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    uploadCount++;
    this.expectedAbsent = expectedAbsent;
    return 'uploaded-revision';
  }
}
