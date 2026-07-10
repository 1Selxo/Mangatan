import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

void main() {
  const codec = ChimahonSyncCodec();

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
      expect(storage.expectedRevision, 'revision-1');
      expect(
        imported!.backupNovels.map((novel) => novel.title),
        containsAll(['Local novel', 'Remote novel']),
      );
      final uploaded = codec.decode(storage.uploaded!).backup;
      expect(uploaded.backupNovels, hasLength(2));
    },
  );
}

class _MemoryStorage implements CrossDeviceSyncStorage {
  _MemoryStorage({required this.remote});

  final Uint8List remote;
  Uint8List? uploaded;
  String? expectedRevision;

  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.protobuf;

  @override
  Future<RemoteSyncSnapshot?> download() async =>
      RemoteSyncSnapshot(bytes: remote, revision: 'revision-1');

  @override
  Future<String?> upload(Uint8List bytes, {String? expectedRevision}) async {
    uploaded = bytes;
    this.expectedRevision = expectedRevision;
    return 'revision-2';
  }
}
