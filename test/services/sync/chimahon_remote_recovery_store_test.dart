import 'dart:io';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_remote_recovery_store.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  const codec = ChimahonSyncCodec();
  late Directory temporarySupport;

  setUp(() async {
    temporarySupport = await Directory.systemTemp.createTemp(
      'mangatan_remote_recovery_test_',
    );
  });

  tearDown(() async {
    if (await temporarySupport.exists()) {
      await temporarySupport.delete(recursive: true);
    }
  });

  Uint8List payload(
    String id, {
    ChimahonSyncWireFormat format = ChimahonSyncWireFormat.gzipProtobuf,
  }) => codec.encode(
    BackupMihon(
      backupNovels: [BackupNovel(id: id, title: id, lastModified: Int64(1))],
    ),
    format: format,
  );

  Future<List<File>> recoveryFiles(
    FileChimahonRemoteRecoveryStore store,
  ) async => store.directory
      .list()
      .where((entry) => entry is File && entry.path.endsWith('.tachibk'))
      .cast<File>()
      .toList();

  test(
    'scope and entry names are hashes and exact bytes stay importable',
    () async {
      const scope =
          'google-drive|oauth-client-secret-looking|opaque-account-identifier';
      final bytes = payload('private novel');
      final store = await defaultChimahonRemoteRecoveryStore(
        scopeKey: scope,
        applicationSupportDirectory: temporarySupport,
      );

      final record = await store.preserve(
        RemoteSyncSnapshot(
          bytes: bytes,
          revision: 'private-drive-file:514:opaque-etag',
          isCompleteRecovery: true,
        ),
      );

      expect(record.digest, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(record.alreadyPresent, isFalse);
      expect(store.directory.path, isNot(contains('oauth-client')));
      expect(store.directory.path, isNot(contains('opaque-account')));
      final files = await recoveryFiles(store);
      expect(files, hasLength(1));
      expect(p.basename(files.single.path), '${record.digest}.tachibk');
      expect(files.single.path, isNot(contains('private-drive-file')));
      expect(await files.single.readAsBytes(), orderedEquals(bytes));
      expect(
        codec
            .decode(await files.single.readAsBytes())
            .backup
            .backupNovels
            .single
            .id,
        'private novel',
      );
    },
  );

  test(
    'raw protobuf bytes remain exact and are accepted by backup restore codec',
    () async {
      final bytes = payload(
        'raw protobuf',
        format: ChimahonSyncWireFormat.protobuf,
      );
      final store = FileChimahonRemoteRecoveryStore(
        Directory(p.join(temporarySupport.path, 'archive')),
      );

      await store.preserve(
        RemoteSyncSnapshot(
          bytes: bytes,
          revision: 'revision-1',
          isCompleteRecovery: true,
        ),
      );

      final file = (await recoveryFiles(store)).single;
      expect(await file.readAsBytes(), orderedEquals(bytes));
      expect(
        codec.decode(await file.readAsBytes()).format,
        ChimahonSyncWireFormat.protobuf,
      );
    },
  );

  test('same content is idempotent and never rewritten', () async {
    final store = FileChimahonRemoteRecoveryStore(
      Directory(p.join(temporarySupport.path, 'archive')),
    );
    final snapshot = RemoteSyncSnapshot(
      bytes: payload('same'),
      revision: 'revision-1',
      isCompleteRecovery: true,
    );
    final first = await store.preserve(snapshot);
    final file = (await recoveryFiles(store)).single;
    final firstModified = await file.lastModified();

    final second = await store.preserve(snapshot);

    expect(second.digest, first.digest);
    expect(second.alreadyPresent, isTrue);
    expect(await file.lastModified(), firstModified);
    expect(await recoveryFiles(store), hasLength(1));
  });

  test('identical bytes across revisions share one recovery entry', () async {
    final store = FileChimahonRemoteRecoveryStore(
      Directory(p.join(temporarySupport.path, 'archive')),
    );
    final bytes = payload('same bytes');

    final first = await store.preserve(
      RemoteSyncSnapshot(
        bytes: bytes,
        revision: 'revision-1',
        isCompleteRecovery: true,
      ),
    );
    final file = (await recoveryFiles(store)).single;
    final firstModified = await file.lastModified();
    final second = await store.preserve(
      RemoteSyncSnapshot(
        bytes: bytes,
        revision: 'revision-2',
        isCompleteRecovery: true,
      ),
    );

    expect(first.alreadyPresent, isFalse);
    expect(second.digest, first.digest);
    expect(second.alreadyPresent, isTrue);
    expect(await file.lastModified(), firstModified);
    expect(await file.readAsBytes(), orderedEquals(bytes));
    expect(await recoveryFiles(store), hasLength(1));
  });

  test('an externally changed completed entry is never overwritten', () async {
    final store = FileChimahonRemoteRecoveryStore(
      Directory(p.join(temporarySupport.path, 'archive')),
    );
    final snapshot = RemoteSyncSnapshot(
      bytes: payload('original'),
      revision: 'revision-1',
      isCompleteRecovery: true,
    );
    await store.preserve(snapshot);
    final file = (await recoveryFiles(store)).single;
    final differentBytes = payload('different');
    await file.writeAsBytes(differentBytes, flush: true);

    await expectLater(
      store.preserve(snapshot),
      throwsA(
        isA<ChimahonRemoteRecoveryException>().having(
          (error) => error.failure,
          'failure',
          ChimahonRemoteRecoveryFailure.existingEntryMismatch,
        ),
      ),
    );

    expect(await file.readAsBytes(), orderedEquals(differentBytes));
  });

  test(
    'incomplete and invalid snapshots fail before creating an entry',
    () async {
      final store = FileChimahonRemoteRecoveryStore(
        Directory(p.join(temporarySupport.path, 'archive')),
      );

      await expectLater(
        store.preserve(
          RemoteSyncSnapshot(
            bytes: payload('incomplete'),
            revision: 'revision-1',
          ),
        ),
        throwsA(
          isA<ChimahonRemoteRecoveryException>().having(
            (error) => error.failure,
            'failure',
            ChimahonRemoteRecoveryFailure.incompleteSnapshot,
          ),
        ),
      );
      await expectLater(
        store.preserve(
          RemoteSyncSnapshot(
            bytes: Uint8List.fromList([1, 2, 3]),
            revision: 'revision-2',
            isCompleteRecovery: true,
          ),
        ),
        throwsA(
          isA<ChimahonRemoteRecoveryException>().having(
            (error) => error.failure,
            'failure',
            ChimahonRemoteRecoveryFailure.invalidPayload,
          ),
        ),
      );

      expect(await store.directory.exists(), isFalse);
    },
  );

  test(
    'failed atomic publish cleans its temp and exposes no sensitive path',
    () async {
      const secret = 'secret-account-and-drive-id';
      final store = await defaultChimahonRemoteRecoveryStore(
        scopeKey: secret,
        applicationSupportDirectory: temporarySupport,
      );
      final snapshot = RemoteSyncSnapshot(
        bytes: payload('blocked'),
        revision: 'secret-drive-revision',
        isCompleteRecovery: true,
      );
      final first = await store.preserve(snapshot);
      final completed = (await recoveryFiles(store)).single;
      await completed.delete();
      await Directory(completed.path).create();

      Object? failure;
      try {
        await store.preserve(snapshot);
      } catch (error) {
        failure = error;
      }

      expect(failure, isA<ChimahonRemoteRecoveryException>());
      expect(failure.toString(), isNot(contains(secret)));
      expect(failure.toString(), isNot(contains('secret-drive-revision')));
      expect(failure.toString(), isNot(contains(temporarySupport.path)));
      expect(
        await store.directory
            .list()
            .where((entry) => p.basename(entry.path).startsWith('.tmp_'))
            .toList(),
        isEmpty,
      );
      expect(p.basename(completed.path), '${first.digest}.tachibk');
    },
  );
}
