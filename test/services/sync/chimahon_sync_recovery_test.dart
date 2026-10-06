import 'dart:io';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_pre_upload_safety_gate.dart';
import 'package:mangayomi/services/sync/chimahon_remote_recovery_store.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

enum _Failure {
  uploadRejected,
  uploadAcknowledgement,
  import,
  baseline,
  preferences,
  sourcePreferences,
}

void main() {
  for (final format in ChimahonSyncWireFormat.values) {
    for (final failure in _Failure.values) {
      test('${format.name} restore resumes after ${failure.name}', () async {
        final scratch = await Directory.systemTemp.createTemp(
          'chimahon-recovery-',
        );
        addTearDown(() => scratch.delete(recursive: true));
        final pending = await defaultChimahonPendingManualRestoreStore(
          applicationSupportDirectory: scratch,
        );
        final selected = _backup(read: false, version: 1);
        final remote = _backup(read: true, version: 10);
        remote.backupManga.add(
          BackupManga(
            source: Int64(7),
            url: '/cloud-only',
            title: 'Cloud only',
          ),
        );
        await pending.beginPreparing(selected);
        await pending.saveLocalPreferenceBaseline([]);
        await pending.saveLocalSourcePreferenceBaseline([]);
        await pending.markReady();
        final storage = _Storage(remote, format)..failure = failure;
        var local = selected.deepCopy();
        var shouldFail = true;
        final cacheFile = File('${scratch.path}/account/remote.tachibk');
        final primary = _FailingBaseline(
          cacheFile,
          () => shouldFail ? failure : null,
        );
        final gate = ChimahonPreUploadSafetyGate(
          recoveryStore: FileChimahonRemoteRecoveryStore(
            Directory('${scratch.path}/recovery'),
          ),
        );
        CrossDeviceSyncEngine engine(
          ClearableChimahonDeferredPayloadStore pendingStore,
        ) => CrossDeviceSyncEngine(
          storage: storage,
          deferredPayloadStore: LayeredChimahonDeferredPayloadStore(
            primary: primary,
            pendingManualRestore: pendingStore,
          ),
          exportLocal: () async => local.deepCopy(),
          importMerged: (backup) async {
            if (shouldFail && failure == _Failure.import) {
              throw StateError('injected import failure');
            }
            local = backup.deepCopy();
          },
          preUpload: gate.check,
        );

        await expectLater(engine(pending).synchronize(), throwsA(anything));
        // Reopen the files, not just the same in-memory store, as after restart.
        final reopened = await defaultChimahonPendingManualRestoreStore(
          applicationSupportDirectory: scratch,
        );
        expect(
          await reopened.loadRestorePhase(),
          ChimahonPendingManualRestorePhase.ready,
        );
        expect(await reopened.load(), isNotNull);
        shouldFail = false;
        storage.failure = null;
        await engine(reopened).synchronize();
        expect(
          await reopened.loadRestorePhase(),
          ChimahonPendingManualRestorePhase.absent,
        );
        expect(await primary.loadLocalPreferenceBaseline(), isNotNull);
        expect(await primary.loadLocalSourcePreferenceBaseline(), isNotNull);
        final committed = storage.bytes;
        final decoded = const ChimahonSyncCodec().decode(committed).backup;
        expect(decoded.backupManga.first.chapters.single.read, isFalse);
        expect(
          decoded.backupManga.map((row) => row.url),
          contains('/cloud-only'),
        );
        final uploadCount = storage.uploads;
        await engine(reopened).synchronize();
        expect(storage.bytes, committed);
        expect(
          storage.uploads,
          uploadCount,
          reason: 'A recovered no-edit sync must not upload again.',
        );
      });
    }
  }
}

BackupMihon _backup({required bool read, required int version}) => BackupMihon(
  backupManga: [
    BackupManga(
      source: Int64(7),
      url: '/selected',
      title: 'Selected',
      version: Int64(version),
      chapters: [
        BackupChapter(
          url: '/chapter',
          name: 'Chapter 1.1',
          chapterNumber: 1.1,
          read: read,
          version: Int64(version),
        ),
      ],
    ),
  ],
);

class _FailingBaseline extends FileChimahonDeferredPayloadStore {
  _FailingBaseline(super.file, this.failure);
  final _Failure? Function() failure;
  @override
  Future<void> save(BackupMihon backup) async {
    if (failure() == _Failure.baseline) {
      throw StateError('injected baseline failure');
    }
    await super.save(backup);
  }

  @override
  Future<void> saveLocalPreferenceBaseline(
    Iterable<BackupPreference> preferences,
  ) async {
    if (failure() == _Failure.preferences) {
      throw StateError('injected preference failure');
    }
    await super.saveLocalPreferenceBaseline(preferences);
  }

  @override
  Future<void> saveLocalSourcePreferenceBaseline(
    Iterable<BackupSourcePreferences> preferences,
  ) async {
    if (failure() == _Failure.sourcePreferences) {
      throw StateError('injected source preference failure');
    }
    await super.saveLocalSourcePreferenceBaseline(preferences);
  }
}

class _Storage implements CrossDeviceSyncStorage {
  _Storage(BackupMihon remote, this.wireFormat)
    : bytes = const ChimahonSyncCodec().encode(remote, format: wireFormat);
  Uint8List bytes;
  _Failure? failure;
  int uploads = 0;
  @override
  final ChimahonSyncWireFormat wireFormat;
  @override
  Future<RemoteSyncSnapshot?> download() async => RemoteSyncSnapshot(
    bytes: bytes,
    revision: '$uploads',
    isCompleteRecovery: true,
  );
  @override
  Future<String?> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    expect(expectedRevision, '$uploads');
    if (failure == _Failure.uploadRejected) {
      throw StateError('injected upload failure');
    }
    this.bytes = bytes;
    uploads++;
    if (failure == _Failure.uploadAcknowledgement) {
      throw StateError('server accepted but response was lost');
    }
    return '$uploads';
  }
}
