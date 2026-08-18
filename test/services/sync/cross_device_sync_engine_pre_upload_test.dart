import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

void main() {
  const codec = ChimahonSyncCodec();

  BackupMihon backup(String id, int modified) => BackupMihon(
    backupNovels: [
      BackupNovel(id: id, title: id, lastModified: Int64(modified)),
    ],
  );

  test(
    'hook failure receives exact immutable attempt and prevents every write',
    () async {
      final remoteBytes = codec.encode(backup('remote', 1));
      final storage = _HookStorage([
        RemoteSyncSnapshot(
          bytes: remoteBytes,
          revision: 'exact-revision',
          isCompleteRecovery: true,
          uploadRetainsAllRemoteByteBlobs: true,
        ),
      ]);
      final sidecar = _CountingSidecar();
      var importCount = 0;
      CrossDeviceSyncPreview? captured;
      final engine = CrossDeviceSyncEngine(
        storage: storage,
        exportLocal: () async => backup('local', 2),
        importMerged: (_) async => importCount++,
        deferredPayloadStore: sidecar,
        preUpload: (preview) async {
          captured = preview;
          final mutableRemote = preview.remoteSnapshot!;
          mutableRemote.bytes[0] = (mutableRemote.bytes[0] + 1) & 0xff;
          preview.exportedLocal.backupNovels.clear();
          preview.effectiveLocalIntent.backupNovels.clear();
          preview.proposedMerged.backupNovels.clear();
          preview.proposedBytes[0] = (preview.proposedBytes[0] + 1) & 0xff;
          throw StateError('refuse');
        },
      );

      await expectLater(engine.synchronize(), throwsStateError);

      expect(storage.downloadCount, 1);
      expect(storage.uploadCount, 0);
      expect(importCount, 0);
      expect(sidecar.deferredSaves, 0);
      expect(sidecar.preferenceSaves, 0);
      expect(sidecar.sourcePreferenceSaves, 0);
      expect(captured!.remoteSnapshot!.revision, 'exact-revision');
      expect(captured!.remoteSnapshot!.isCompleteRecovery, isTrue);
      expect(captured!.remoteSnapshot!.uploadRetainsAllRemoteByteBlobs, isTrue);
      expect(captured!.remoteSnapshot!.bytes, orderedEquals(remoteBytes));
      expect(captured!.exportedLocal.backupNovels, hasLength(1));
      expect(captured!.effectiveLocalIntent.backupNovels, hasLength(1));
      expect(captured!.proposedMerged.backupNovels, hasLength(2));
      expect(
        codec.decode(captured!.proposedBytes).backup.backupNovels,
        hasLength(2),
      );
    },
  );

  test('hook runs against each newly prepared conflict retry', () async {
    final firstBytes = codec.encode(backup('first-remote', 1));
    final secondBytes = codec.encode(backup('second-remote', 2));
    final storage = _HookStorage([
      RemoteSyncSnapshot(
        bytes: firstBytes,
        revision: 'revision-1',
        isCompleteRecovery: true,
      ),
      RemoteSyncSnapshot(
        bytes: secondBytes,
        revision: 'revision-2',
        isCompleteRecovery: true,
      ),
    ], conflictUploads: 1);
    final hookRevisions = <String?>[];
    final hookRemoteBytes = <Uint8List>[];

    await CrossDeviceSyncEngine(
      storage: storage,
      exportLocal: () async => backup('local', 3),
      importMerged: (_) async {},
      preUpload: (preview) async {
        hookRevisions.add(preview.remoteSnapshot?.revision);
        hookRemoteBytes.add(preview.remoteSnapshot!.bytes);
      },
    ).uploadPreservingRemote();

    expect(hookRevisions, ['revision-1', 'revision-2']);
    expect(hookRemoteBytes[0], orderedEquals(firstBytes));
    expect(hookRemoteBytes[1], orderedEquals(secondBytes));
    expect(storage.uploadRevisions, ['revision-1', 'revision-2']);
    expect(storage.uploadCount, 2);
    expect(
      codec
          .decode(storage.uploads.last)
          .backup
          .backupNovels
          .map((novel) => novel.title),
      containsAll(['local', 'second-remote']),
    );
  });

  test('read-only preview never invokes the pre-upload hook', () async {
    final storage = _HookStorage([
      RemoteSyncSnapshot(
        bytes: codec.encode(backup('remote', 1)),
        revision: 'revision-1',
        isCompleteRecovery: true,
      ),
    ]);
    var hookCount = 0;
    final engine = CrossDeviceSyncEngine(
      storage: storage,
      exportLocal: () async => backup('local', 2),
      importMerged: (_) async {},
      preUpload: (_) async => hookCount++,
    );

    final preview = await engine.preview();

    expect(preview.remoteSnapshot, isNotNull);
    expect(hookCount, 0);
    expect(storage.uploadCount, 0);
  });

  test('remote creation still passes through a null-remote hook', () async {
    final storage = _HookStorage([null]);
    var hookCount = 0;
    await CrossDeviceSyncEngine(
      storage: storage,
      exportLocal: () async => backup('local', 2),
      importMerged: (_) async {},
      preUpload: (preview) async {
        hookCount++;
        expect(preview.remoteSnapshot, isNull);
        expect(preview.decodedRemote, isNull);
      },
    ).uploadPreservingRemote();

    expect(hookCount, 1);
    expect(storage.expectedAbsent, isTrue);
    expect(storage.uploadCount, 1);
  });
}

class _HookStorage implements CrossDeviceSyncStorage {
  _HookStorage(this.snapshots, {this.conflictUploads = 0});

  final List<RemoteSyncSnapshot?> snapshots;
  final int conflictUploads;
  int downloadCount = 0;
  int uploadCount = 0;
  bool? expectedAbsent;
  final List<String?> uploadRevisions = [];
  final List<Uint8List> uploads = [];

  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.protobuf;

  @override
  Future<RemoteSyncSnapshot?> download() async => snapshots[downloadCount++];

  @override
  Future<String?> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    uploadCount++;
    uploadRevisions.add(expectedRevision);
    uploads.add(Uint8List.fromList(bytes));
    this.expectedAbsent = expectedAbsent;
    if (uploadCount <= conflictUploads) {
      throw const SyncConflictException();
    }
    return 'uploaded-$uploadCount';
  }
}

class _CountingSidecar
    implements
        ChimahonDeferredPayloadStore,
        ChimahonLocalPreferenceBaselineStore,
        ChimahonLocalSourcePreferenceBaselineStore {
  int deferredSaves = 0;
  int preferenceSaves = 0;
  int sourcePreferenceSaves = 0;

  @override
  Future<BackupMihon?> load() async => null;

  @override
  Future<void> save(BackupMihon backup) async => deferredSaves++;

  @override
  Future<List<BackupPreference>?> loadLocalPreferenceBaseline() async => null;

  @override
  Future<void> saveLocalPreferenceBaseline(
    Iterable<BackupPreference> preferences,
  ) async => preferenceSaves++;

  @override
  Future<List<BackupSourcePreferences>?>
  loadLocalSourcePreferenceBaseline() async => null;

  @override
  Future<void> saveLocalSourcePreferenceBaseline(
    Iterable<BackupSourcePreferences> preferences,
  ) async => sourcePreferenceSaves++;
}
