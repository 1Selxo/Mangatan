import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

typedef SyncBackupExporter = Future<BackupMihon> Function();
typedef SyncBackupImporter = Future<void> Function(BackupMihon backup);

class CrossDeviceSyncResult {
  const CrossDeviceSyncResult({
    required this.hadRemoteData,
    required this.remoteRevision,
  });

  final bool hadRemoteData;
  final String? remoteRevision;
}

/// Provider-neutral orchestration. UI scheduling and authentication are kept
/// outside this class so the same backend works for Google Drive, SyncYomi,
/// WebDAV, or a filesystem-backed provider.
class CrossDeviceSyncEngine {
  CrossDeviceSyncEngine({
    required this.storage,
    required this.exportLocal,
    required this.importMerged,
    this.deferredPayloadStore,
    this.codec = const ChimahonSyncCodec(),
    this.merger = const ChimahonSyncMerger(),
  });

  final CrossDeviceSyncStorage storage;
  final SyncBackupExporter exportLocal;
  final SyncBackupImporter importMerged;
  final ChimahonDeferredPayloadStore? deferredPayloadStore;
  final ChimahonSyncCodec codec;
  final ChimahonSyncMerger merger;

  Future<CrossDeviceSyncResult> synchronize() async {
    final exported = await exportLocal();
    final deferred = await deferredPayloadStore?.load();
    final local = deferred == null
        ? exported
        : merger.merge(local: deferred, remote: exported);
    final remoteSnapshot = await storage.download();
    final merged = remoteSnapshot == null
        ? local
        : merger.merge(
            local: local,
            remote: codec.decode(remoteSnapshot.bytes).backup,
          );
    final bytes = codec.encode(merged, format: storage.wireFormat);
    final revision = await storage.upload(
      bytes,
      expectedRevision: remoteSnapshot?.revision,
    );
    await importMerged(merged);
    await deferredPayloadStore?.save(merged);
    return CrossDeviceSyncResult(
      hadRemoteData: remoteSnapshot != null,
      remoteRevision: revision,
    );
  }
}
