import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';
import 'package:mangayomi/services/sync/google_drive_sync_storage.dart';

void main() {
  const codec = ChimahonSyncCodec();

  test('uses Drive account identity without a profile scope', () async {
    final requests = <http.Request>[];
    final storage = GoogleDriveSyncStorage(
      accessToken: 'access',
      deviceId: 'device-123',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'user': {'permissionId': 'opaque-drive-user'},
          }),
          200,
        );
      }),
    );

    expect(await storage.currentUserPermissionId(), 'opaque-drive-user');
    expect(requests.single.url.path, '/drive/v3/about');
    expect(requests.single.url.queryParameters, {
      'fields': 'user(permissionId)',
    });
  });

  test('rejects a Drive account response without an identity', () async {
    final storage = GoogleDriveSyncStorage(
      accessToken: 'access',
      deviceId: 'device-123',
      client: MockClient((_) async => http.Response('{"user":{}}', 200)),
    );

    await expectLater(
      storage.currentUserPermissionId(),
      throwsA(
        isA<SyncStorageException>().having(
          (error) => error.message,
          'message',
          contains('identify'),
        ),
      ),
    );
  });

  test(
    'merges every valid exact-name candidate regardless of MIME type',
    () async {
      final drive = _FakeDrive([
        _FakeDriveFile(
          id: 'older-octet-stream',
          version: 3,
          modifiedTime: DateTime.utc(2026, 7, 17, 20),
          mimeType: 'application/octet-stream',
          bytes: _payload([
            _novel('older-only', 'Older only', 10),
            _novel('shared', 'Shared', 10),
          ]),
          etag: '"etag-older"',
        ),
        _FakeDriveFile(
          id: 'corrupt-newest',
          version: 9,
          modifiedTime: DateTime.utc(2026, 7, 17, 22),
          mimeType: 'application/x-gzip',
          bytes: const [1, 2, 3],
          etag: '"etag-corrupt"',
        ),
        _FakeDriveFile(
          id: 'newer-valid',
          version: 4,
          modifiedTime: DateTime.utc(2026, 7, 17, 21),
          mimeType: 'application/x-gzip',
          bytes: _payload([
            _novel('shared', 'Shared', 20),
            _novel('newer-only', 'Newer only', 20),
          ]),
          etag: '"etag-newer"',
        ),
      ]);
      final storage = _storage(drive);

      final snapshot = await storage.download();

      final novels = codec.decode(snapshot!.bytes).backup.backupNovels;
      expect(novels.map((novel) => novel.title), {
        'Older only',
        'Shared',
        'Newer only',
      });
      expect(
        novels.singleWhere((novel) => novel.title == 'Shared').lastModified,
        Int64(20),
      );
      expect(snapshot.revision, startsWith('newer-valid:4:'));
      expect(snapshot.isCompleteRecovery, isFalse);
      expect(snapshot.uploadRetainsAllRemoteByteBlobs, isTrue);
      expect(
        drive.requests.where(
          (request) => request.url.queryParameters['alt'] == 'media',
        ),
        hasLength(3),
      );
      for (final id in [
        'older-octet-stream',
        'corrupt-newest',
        'newer-valid',
      ]) {
        final reads = drive.requests
            .where((request) => request.url.path.endsWith('/$id'))
            .toList();
        expect(reads, hasLength(3));
        expect(reads[0].url.queryParameters['fields'], contains('etag'));
        expect(reads[1].url.queryParameters['alt'], 'media');
        expect(reads[2].url.queryParameters['fields'], contains('etag'));
      }
      final listRequest = drive.requests.first;
      expect(listRequest.url.queryParameters['spaces'], 'appDataFolder');
      expect(listRequest.url.queryParameters['pageSize'], '1000');
      expect(
        listRequest.url.queryParameters['q'],
        "name = 'Chimahon_sync.proto.gz' and trashed = false",
      );
      expect(listRequest.url.queryParameters['q'], isNot(contains('mimeType')));
    },
  );

  test('newest Drive file wins equal record and chapter counters', () async {
    final drive = _FakeDrive([
      _FakeDriveFile(
        id: 'older',
        version: 7,
        modifiedTime: DateTime.utc(2026, 7, 17, 20),
        bytes: _mangaPayload('older metadata', 'Older scanlator'),
        etag: '"etag-older"',
      ),
      _FakeDriveFile(
        id: 'newer',
        version: 8,
        modifiedTime: DateTime.utc(2026, 7, 17, 21),
        bytes: _mangaPayload('newer metadata', 'Newer scanlator'),
        etag: '"etag-newer"',
      ),
    ]);

    final snapshot = await _storage(drive).download();
    final manga = codec.decode(snapshot!.bytes).backup.backupManga.single;

    expect(manga.description, 'newer metadata');
    expect(manga.chapters.single.name, 'Same chapter');
    expect(manga.chapters.single.scanlator, 'Newer scanlator');
    expect(snapshot.revision, startsWith('newer:8:'));
  });

  test(
    'creates a new canonical file and archives every old copy unchanged',
    () async {
      final drive = _FakeDrive([
        _FakeDriveFile(
          id: 'older-valid',
          version: 3,
          modifiedTime: DateTime.utc(2026, 7, 17, 20),
          mimeType: 'application/octet-stream',
          bytes: _payload([_novel('older', 'Older', 10)]),
          etag: '"etag-older"',
        ),
        _FakeDriveFile(
          id: 'newer-valid',
          version: 4,
          modifiedTime: DateTime.utc(2026, 7, 17, 21),
          mimeType: 'application/octet-stream',
          bytes: _payload([_novel('newer', 'Newer', 20)]),
          etag: '"etag-newer"',
        ),
        _FakeDriveFile(
          id: 'corrupt-copy',
          version: 2,
          modifiedTime: DateTime.utc(2026, 7, 17, 19),
          mimeType: 'application/octet-stream',
          bytes: const [9, 8, 7],
          etag: '"etag-corrupt"',
        ),
      ]);
      final originalBytes = {
        for (final file in drive.files) file.id: Uint8List.fromList(file.bytes),
      };
      final storage = _storage(drive);
      final snapshot = await storage.download();

      final revision = await storage.upload(
        snapshot!.bytes,
        expectedRevision: snapshot.revision,
      );

      expect(revision, 'created:1');
      final contentCreate = drive.requests.singleWhere(
        (request) => request.url.path == '/upload/drive/v3/files',
      );
      expect(contentCreate.method, 'POST');
      expect(contentCreate.headers.containsKey('If-Match'), isFalse);
      final contentMultipart = latin1.decode(contentCreate.bodyBytes);
      expect(contentMultipart, contains('device-123'));
      expect(contentMultipart, contains('application/x-gzip'));
      expect(contentMultipart, contains('"name":"Chimahon_sync.proto.gz"'));
      expect(contentMultipart, contains('"appProperties"'));
      expect(
        drive.requests.where(
          (request) =>
              request.headers.containsKey('If-Match') &&
              request.url.path.contains('/drive/v3/'),
        ),
        isEmpty,
      );

      final olderArchive = drive.requests.singleWhere(
        (request) =>
            request.url.path == '/drive/v2/files/older-valid' &&
            request.method == 'PATCH',
      );
      expect(olderArchive.headers['If-Match'], '"etag-older"');
      expect(
        jsonDecode(olderArchive.body) as Map,
        containsPair(
          'title',
          '${GoogleDriveSyncStorage.chimahonRemoteFileName}'
              '.mangatan-duplicate-older-valid',
        ),
      );
      final newerArchive = drive.requests.singleWhere(
        (request) =>
            request.url.path == '/drive/v2/files/newer-valid' &&
            request.method == 'PATCH',
      );
      expect(newerArchive.headers['If-Match'], '"etag-newer"');
      expect(
        jsonDecode(newerArchive.body) as Map,
        containsPair(
          'title',
          '${GoogleDriveSyncStorage.chimahonRemoteFileName}'
              '.mangatan-duplicate-newer-valid',
        ),
      );
      final corruptArchive = drive.requests.singleWhere(
        (request) =>
            request.url.path == '/drive/v2/files/corrupt-copy' &&
            request.method == 'PATCH',
      );
      expect(corruptArchive.headers['If-Match'], '"etag-corrupt"');
      expect(
        jsonDecode(corruptArchive.body) as Map,
        containsPair(
          'title',
          '${GoogleDriveSyncStorage.chimahonRemoteFileName}'
              '.mangatan-corrupt-corrupt-copy',
        ),
      );

      expect(
        drive.files
            .where(
              (file) =>
                  file.name == GoogleDriveSyncStorage.chimahonRemoteFileName,
            )
            .map((file) => file.id),
        ['created'],
      );
      for (final entry in originalBytes.entries) {
        expect(
          drive.file(entry.key).bytes,
          orderedEquals(entry.value),
          reason: '${entry.key} must remain byte-for-byte recoverable',
        );
      }
      expect(
        codec
            .decode(drive.file('created').bytes)
            .backup
            .backupNovels
            .map((novel) => novel.title),
        {'Older', 'Newer'},
      );
    },
  );

  test(
    'rejects a missing canonical v2 resource ETag during download',
    () async {
      final drive = _FakeDrive([
        _FakeDriveFile(
          id: 'canonical',
          version: 1,
          modifiedTime: DateTime.utc(2026, 7, 17, 20),
          bytes: _payload([_novel('novel', 'Novel', 10)]),
          etag: null,
        ),
      ]);
      final storage = _storage(drive);
      await expectLater(
        storage.download(),
        throwsA(
          isA<SyncStorageException>().having(
            (error) => error.message,
            'message',
            contains('strong ETag'),
          ),
        ),
      );
      expect(drive.mutationRequests, isEmpty);
    },
  );

  for (final invalidEtag in <String>[
    'W/"weak"',
    'unquoted',
    '"unterminated',
    '"embedded"quote"',
    '"control\u0001"',
    '"contains space"',
    ' "outer-space"',
  ]) {
    test(
      'rejects weak or malformed v2 ETag ${jsonEncode(invalidEtag)}',
      () async {
        final drive = _FakeDrive([
          _FakeDriveFile(
            id: 'canonical',
            version: 1,
            modifiedTime: DateTime.utc(2026, 7, 17, 20),
            bytes: _payload([_novel('novel', 'Novel', 10)]),
            etag: invalidEtag,
          ),
        ]);

        await expectLater(
          _storage(drive).download(),
          throwsA(isA<SyncStorageException>()),
        );
        expect(drive.mutationRequests, isEmpty);
      },
    );
  }

  test('detects a v2 resource ETag change across the media read', () async {
    final drive = _FakeDrive([
      _FakeDriveFile(
        id: 'canonical',
        version: 1,
        modifiedTime: DateTime.utc(2026, 7, 17, 20),
        bytes: _payload([_novel('novel', 'Novel', 10)]),
        etag: '"etag-before"',
      ),
    ]);
    drive.beforeV2MetadataRead = (_, file, readCount) {
      if (readCount == 2) file.etag = '"etag-after"';
    };

    await expectLater(
      _storage(drive).download(),
      throwsA(isA<SyncConflictException>()),
    );
    expect(drive.mutationRequests, isEmpty);
  });

  group('rejects mismatched v2 metadata', () {
    final mutations = <String, void Function(_FakeDriveFile)>{
      'id': (file) => file.metadataIdOverride = 'different-id',
      'title': (file) => file.metadataTitleOverride = 'different-title',
      'version': (file) => file.metadataVersionOverride = '999',
      'appDataContents': (file) => file.appDataContents = false,
      'trashed': (file) => file.trashed = true,
    };

    for (final entry in mutations.entries) {
      test(entry.key, () async {
        final file = _FakeDriveFile(
          id: 'canonical',
          version: 1,
          modifiedTime: DateTime.utc(2026, 7, 17, 20),
          bytes: _payload([_novel('novel', 'Novel', 10)]),
          etag: '"etag-canonical"',
        );
        entry.value(file);
        final drive = _FakeDrive([file]);

        await expectLater(
          _storage(drive).download(),
          throwsA(isA<SyncConflictException>()),
        );
        expect(drive.mutationRequests, isEmpty);
      });
    }
  });

  test('returns the exact raw gzip bytes for one valid candidate', () async {
    final exactBytes = _payload([_novel('novel', 'Novel', 10)]);
    // The gzip OS marker is ignored by decoders but is not reproduced by a
    // fresh encoding, which makes this a byte-identity assertion.
    exactBytes[9] = exactBytes[9] == 3 ? 255 : 3;
    final drive = _FakeDrive([
      _FakeDriveFile(
        id: 'canonical',
        version: 1,
        modifiedTime: DateTime.utc(2026, 7, 17, 20),
        bytes: exactBytes,
        etag: '"etag-canonical"',
      ),
    ]);

    final snapshot = await _storage(drive).download();

    expect(snapshot!.bytes, orderedEquals(exactBytes));
    expect(snapshot.isCompleteRecovery, isTrue);
    expect(snapshot.uploadRetainsAllRemoteByteBlobs, isFalse);
  });

  test(
    'returns exact valid bytes when another exact-name candidate is corrupt',
    () async {
      final exactBytes = _payload([_novel('novel', 'Novel', 10)]);
      exactBytes[9] = exactBytes[9] == 3 ? 255 : 3;
      final drive = _FakeDrive([
        _FakeDriveFile(
          id: 'valid',
          version: 1,
          modifiedTime: DateTime.utc(2026, 7, 17, 20),
          bytes: exactBytes,
          etag: '"etag-valid"',
        ),
        _FakeDriveFile(
          id: 'corrupt',
          version: 2,
          modifiedTime: DateTime.utc(2026, 7, 17, 21),
          bytes: const [1, 2, 3],
          etag: '"etag-corrupt"',
        ),
      ]);

      final snapshot = await _storage(drive).download();

      expect(snapshot!.bytes, orderedEquals(exactBytes));
      expect(
        snapshot.isCompleteRecovery,
        isFalse,
        reason: 'the corrupt duplicate would also be changed by cleanup',
      );
      expect(snapshot.uploadRetainsAllRemoteByteBlobs, isTrue);
    },
  );

  test('rejects a missing duplicate ETag before any mutation', () async {
    final drive = _FakeDrive([
      _FakeDriveFile(
        id: 'canonical',
        version: 2,
        modifiedTime: DateTime.utc(2026, 7, 17, 21),
        bytes: _payload([_novel('new', 'New', 20)]),
        etag: '"etag-canonical"',
      ),
      _FakeDriveFile(
        id: 'duplicate',
        version: 1,
        modifiedTime: DateTime.utc(2026, 7, 17, 20),
        bytes: _payload([_novel('old', 'Old', 10)]),
        etag: null,
      ),
    ]);
    final storage = _storage(drive);
    await expectLater(storage.download(), throwsA(isA<SyncStorageException>()));
    expect(drive.mutationRequests, isEmpty);
  });

  test('detects a candidate version race before updating anything', () async {
    final drive = _FakeDrive([
      _FakeDriveFile(
        id: 'canonical',
        version: 2,
        modifiedTime: DateTime.utc(2026, 7, 17, 21),
        bytes: _payload([_novel('new', 'New', 20)]),
        etag: '"etag-canonical"',
      ),
      _FakeDriveFile(
        id: 'duplicate',
        version: 1,
        modifiedTime: DateTime.utc(2026, 7, 17, 20),
        bytes: _payload([_novel('old', 'Old', 10)]),
        etag: '"etag-duplicate"',
      ),
    ]);
    drive.beforeList = (drive, listCount) {
      if (listCount == 2) drive.file('duplicate').version = 2;
    };
    final storage = _storage(drive);
    final snapshot = await storage.download();

    await expectLater(
      storage.upload(snapshot!.bytes, expectedRevision: snapshot.revision),
      throwsA(isA<SyncConflictException>()),
    );
    expect(drive.mutationRequests, isEmpty);
  });

  test('maps a conditional canonical update failure to a conflict', () async {
    final drive = _FakeDrive([
      _FakeDriveFile(
        id: 'canonical',
        version: 1,
        modifiedTime: DateTime.utc(2026, 7, 17, 20),
        bytes: _payload([_novel('novel', 'Novel', 10)]),
        etag: '"etag-canonical"',
      ),
    ])..failContentUpdate = true;
    final storage = _storage(drive);
    final snapshot = await storage.download();

    await expectLater(
      storage.upload(snapshot!.bytes, expectedRevision: snapshot.revision),
      throwsA(isA<SyncConflictException>()),
    );
    expect(
      drive.requests
          .singleWhere(
            (request) => request.url.path.contains('/upload/drive/v2/files/'),
          )
          .headers['If-Match'],
      '"etag-canonical"',
    );
  });

  test('requires Drive to confirm the private deviceId after update', () async {
    final drive = _FakeDrive([
      _FakeDriveFile(
        id: 'canonical',
        version: 1,
        modifiedTime: DateTime.utc(2026, 7, 17, 20),
        bytes: _payload([_novel('novel', 'Novel', 10)]),
        etag: '"etag-canonical"',
      ),
    ])..omitDeviceIdAfterContentUpdate = true;
    final storage = _storage(drive);
    final snapshot = await storage.download();

    await expectLater(
      storage.upload(snapshot!.bytes, expectedRevision: snapshot.revision),
      throwsA(
        isA<SyncStorageException>().having(
          (error) => error.message,
          'message',
          contains('device identity'),
        ),
      ),
    );
  });

  test('detects a same-file overwrite after the canonical update', () async {
    final drive = _FakeDrive([
      _FakeDriveFile(
        id: 'canonical',
        version: 1,
        modifiedTime: DateTime.utc(2026, 7, 17, 20),
        bytes: _payload([_novel('novel', 'Novel', 10)]),
        etag: '"etag-canonical"',
      ),
    ]);
    drive.beforeList = (drive, listCount) {
      if (listCount == 3) {
        final canonical = drive.file('canonical');
        canonical
          ..version = canonical.version + 1
          ..etag = '"etag-external-${canonical.version}"'
          ..bytes = _payload([_novel('external', 'External', 20)]);
      }
    };
    final storage = _storage(drive);
    final snapshot = await storage.download();

    await expectLater(
      storage.upload(snapshot!.bytes, expectedRevision: snapshot.revision),
      throwsA(isA<SyncConflictException>()),
    );
    expect(drive.file('canonical').version, 3);
    expect(
      codec
          .decode(drive.file('canonical').bytes)
          .backup
          .backupNovels
          .single
          .title,
      'External',
    );
  });

  test(
    'a conditional rename race preserves the duplicate and retries',
    () async {
      final drive = _FakeDrive([
        _FakeDriveFile(
          id: 'canonical',
          version: 2,
          modifiedTime: DateTime.utc(2026, 7, 17, 21),
          bytes: _payload([_novel('new', 'New', 20)]),
          etag: '"etag-canonical"',
        ),
        _FakeDriveFile(
          id: 'duplicate',
          version: 1,
          modifiedTime: DateTime.utc(2026, 7, 17, 20),
          bytes: _payload([_novel('old', 'Old', 10)]),
          etag: '"etag-duplicate"',
        ),
      ])..failArchiveIds.add('duplicate');
      final originalCanonical = Uint8List.fromList(
        drive.file('canonical').bytes,
      );
      final originalDuplicate = Uint8List.fromList(
        drive.file('duplicate').bytes,
      );
      final storage = _storage(drive);
      final snapshot = await storage.download();

      await expectLater(
        storage.upload(snapshot!.bytes, expectedRevision: snapshot.revision),
        throwsA(isA<SyncConflictException>()),
      );
      expect(
        drive.file('duplicate').name,
        GoogleDriveSyncStorage.chimahonRemoteFileName,
      );
      expect(drive.file('duplicate').bytes, orderedEquals(originalDuplicate));
      expect(drive.file('canonical').bytes, orderedEquals(originalCanonical));
      expect(
        drive.requests.where(
          (request) => request.url.path.startsWith('/upload/drive/v2/files/'),
        ),
        isEmpty,
      );
    },
  );

  test('partial duplicate cleanup retains every original byte blob', () async {
    final drive = _FakeDrive([
      _FakeDriveFile(
        id: 'canonical',
        version: 2,
        modifiedTime: DateTime.utc(2026, 7, 17, 21),
        bytes: _payload([_novel('new', 'New', 20)]),
        etag: '"etag-canonical"',
      ),
      _FakeDriveFile(
        id: 'duplicate',
        version: 1,
        modifiedTime: DateTime.utc(2026, 7, 17, 20),
        bytes: _payload([_novel('old', 'Old', 10)]),
        etag: '"etag-duplicate"',
      ),
    ])..failArchiveIds.add('canonical');
    final originals = {
      for (final file in drive.files) file.id: Uint8List.fromList(file.bytes),
    };
    final storage = _storage(drive);
    final snapshot = await storage.download();

    await expectLater(
      storage.upload(snapshot!.bytes, expectedRevision: snapshot.revision),
      throwsA(isA<SyncConflictException>()),
    );

    expect(drive.file('duplicate').name, contains('.mangatan-duplicate-'));
    expect(
      drive.file('canonical').name,
      GoogleDriveSyncStorage.chimahonRemoteFileName,
    );
    expect(
      drive.file('created').name,
      GoogleDriveSyncStorage.chimahonRemoteFileName,
    );
    for (final entry in originals.entries) {
      expect(
        drive.file(entry.key).bytes,
        orderedEquals(entry.value),
        reason: '${entry.key} must survive partial cleanup exactly',
      );
    }
  });

  test('detects a new writer before duplicate cleanup', () async {
    final drive = _FakeDrive([
      _FakeDriveFile(
        id: 'canonical',
        version: 2,
        modifiedTime: DateTime.utc(2026, 7, 17, 21),
        bytes: _payload([_novel('new', 'New', 20)]),
        etag: '"etag-canonical"',
      ),
      _FakeDriveFile(
        id: 'duplicate',
        version: 1,
        modifiedTime: DateTime.utc(2026, 7, 17, 20),
        bytes: _payload([_novel('old', 'Old', 10)]),
        etag: '"etag-duplicate"',
      ),
    ]);
    drive.beforeList = (drive, listCount) {
      if (listCount == 3) {
        drive.files.add(
          _FakeDriveFile(
            id: 'concurrent-writer',
            version: 1,
            modifiedTime: DateTime.utc(2026, 7, 17, 22),
            bytes: _payload([_novel('race', 'Race', 30)]),
            etag: '"etag-race"',
          ),
        );
      }
    };
    final storage = _storage(drive);
    final snapshot = await storage.download();

    await expectLater(
      storage.upload(snapshot!.bytes, expectedRevision: snapshot.revision),
      throwsA(isA<SyncConflictException>()),
    );
    expect(
      drive.file('duplicate').name,
      GoogleDriveSyncStorage.chimahonRemoteFileName,
    );
    expect(
      drive.file('canonical').name,
      GoogleDriveSyncStorage.chimahonRemoteFileName,
    );
    expect(
      drive.file('concurrent-writer').name,
      GoogleDriveSyncStorage.chimahonRemoteFileName,
    );
  });

  test(
    'a writer during duplicate cleanup leaves every original recoverable',
    () async {
      final concurrentBytes = _payload([_novel('race', 'Race', 30)]);
      final drive = _FakeDrive([
        _FakeDriveFile(
          id: 'canonical',
          version: 2,
          modifiedTime: DateTime.utc(2026, 7, 17, 21),
          bytes: _payload([_novel('new', 'New', 20)]),
          etag: '"etag-canonical"',
        ),
        _FakeDriveFile(
          id: 'duplicate',
          version: 1,
          modifiedTime: DateTime.utc(2026, 7, 17, 20),
          bytes: _payload([_novel('old', 'Old', 10)]),
          etag: '"etag-duplicate"',
        ),
      ]);
      final originals = {
        for (final file in drive.files) file.id: Uint8List.fromList(file.bytes),
      };
      drive.afterArchive = (drive, archiveCount) {
        if (archiveCount != 1) return;
        drive.files.add(
          _FakeDriveFile(
            id: 'concurrent-writer',
            version: 1,
            modifiedTime: DateTime.utc(2026, 7, 17, 22),
            bytes: concurrentBytes,
            etag: '"etag-race"',
          ),
        );
      };
      final storage = _storage(drive);
      final snapshot = await storage.download();

      await expectLater(
        storage.upload(snapshot!.bytes, expectedRevision: snapshot.revision),
        throwsA(isA<SyncConflictException>()),
      );

      for (final entry in originals.entries) {
        expect(
          drive.file(entry.key).bytes,
          orderedEquals(entry.value),
          reason: '${entry.key} must survive concurrent cleanup exactly',
        );
      }
      expect(
        drive.file('concurrent-writer').bytes,
        orderedEquals(concurrentBytes),
      );
      expect(drive.archiveCount, 2);
    },
  );

  test('creates a gzip Chimahon file in appDataFolder when absent', () async {
    final drive = _FakeDrive([]);
    final storage = _storage(drive);

    final revision = await storage.upload(
      _payload([_novel('novel', 'Novel', 10)]),
      expectedAbsent: true,
    );

    expect(revision, 'created:1');
    final request = drive.requests.singleWhere(
      (request) => request.url.path == '/upload/drive/v3/files',
    );
    expect(request.method, 'POST');
    final multipart = latin1.decode(request.bodyBytes);
    expect(multipart, contains('"parents":["appDataFolder"]'));
    expect(multipart, contains('"mimeType":"application/x-gzip"'));
    expect(multipart, contains('"deviceId":"device-123"'));
  });

  test(
    'detects a same-file overwrite after creating the canonical file',
    () async {
      final drive = _FakeDrive([]);
      drive.beforeList = (drive, listCount) {
        if (listCount == 2) {
          final created = drive.file('created');
          created
            ..version = created.version + 1
            ..etag = '"etag-external-${created.version}"'
            ..bytes = _payload([_novel('external', 'External', 20)]);
        }
      };
      final storage = _storage(drive);

      await expectLater(
        storage.upload(
          _payload([_novel('local', 'Local', 10)]),
          expectedAbsent: true,
        ),
        throwsA(isA<SyncConflictException>()),
      );
      expect(drive.file('created').version, 2);
      expect(
        codec
            .decode(drive.file('created').bytes)
            .backup
            .backupNovels
            .single
            .title,
        'External',
      );
    },
  );

  test('detects concurrent duplicate creation after POST', () async {
    final drive = _FakeDrive([]);
    drive.afterCreate = (drive) {
      drive.files.add(
        _FakeDriveFile(
          id: 'created-elsewhere',
          version: 1,
          modifiedTime: DateTime.utc(2026, 7, 17, 22),
          bytes: _payload([_novel('other', 'Other', 20)]),
          etag: '"etag-other"',
        ),
      );
    };
    final storage = _storage(drive);

    await expectLater(
      storage.upload(
        _payload([_novel('local', 'Local', 10)]),
        expectedAbsent: true,
      ),
      throwsA(isA<SyncConflictException>()),
    );
    expect(
      drive.files.where(
        (file) => file.name == GoogleDriveSyncStorage.chimahonRemoteFileName,
      ),
      hasLength(2),
    );
  });

  test(
    'engine retry after concurrent first creation canonicalizes safely',
    () async {
      final local = BackupMihon(backupNovels: [_novel('local', 'Local', 10)]);
      final otherBytes = _payload([_novel('other', 'Other', 20)]);
      final drive = _FakeDrive([]);
      drive.afterCreate = (drive) {
        drive.afterCreate = null;
        drive.files.add(
          _FakeDriveFile(
            id: 'created-elsewhere',
            version: 1,
            modifiedTime: DateTime.utc(2026, 7, 17, 22),
            bytes: otherBytes,
            etag: '"etag-other"',
          ),
        );
      };
      final storage = _storage(drive);

      final result = await CrossDeviceSyncEngine(
        storage: storage,
        exportLocal: () async => local.deepCopy(),
        importMerged: (_) async {},
      ).uploadPreservingRemote();

      expect(result.remoteRevision, 'created-2:1');
      expect(result.hadRemoteData, isTrue);
      expect(drive.createCount, 2);
      expect(
        drive.files
            .where(
              (file) =>
                  file.name == GoogleDriveSyncStorage.chimahonRemoteFileName,
            )
            .map((file) => file.id),
        ['created-2'],
      );
      expect(
        drive.file('created').bytes,
        orderedEquals(drive.bytesAtCreation['created']!),
      );
      expect(drive.file('created-elsewhere').bytes, orderedEquals(otherBytes));
      expect(
        codec
            .decode(drive.file('created-2').bytes)
            .backup
            .backupNovels
            .map((novel) => novel.title),
        {'Local', 'Other'},
      );
    },
  );

  test('refuses to overwrite an existing file without a download', () async {
    final drive = _FakeDrive([
      _FakeDriveFile(
        id: 'existing',
        version: 1,
        modifiedTime: DateTime.utc(2026, 7, 17, 20),
        bytes: _payload([_novel('remote', 'Remote', 10)]),
        etag: '"etag-existing"',
      ),
    ]);
    final storage = _storage(drive);

    await expectLater(
      storage.upload(_payload([_novel('local', 'Local', 20)])),
      throwsA(isA<SyncStorageException>()),
    );
    expect(drive.mutationRequests, isEmpty);
  });

  test('paginates exact-name discovery before building a snapshot', () async {
    final first = _payload([_novel('first', 'First', 10)]);
    final second = _payload([_novel('second', 'Second', 20)]);
    final requests = <http.Request>[];
    final storage = GoogleDriveSyncStorage(
      accessToken: 'access',
      deviceId: 'device-123',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/drive/v3/files' &&
            !request.url.queryParameters.containsKey('pageToken')) {
          return http.Response(
            jsonEncode({
              'nextPageToken': 'next-page',
              'files': [_metadata('first', 1, DateTime.utc(2026, 7, 17, 20))],
            }),
            200,
          );
        }
        if (request.url.path == '/drive/v3/files') {
          expect(request.url.queryParameters['pageToken'], 'next-page');
          return http.Response(
            jsonEncode({
              'files': [_metadata('second', 2, DateTime.utc(2026, 7, 17, 21))],
            }),
            200,
          );
        }
        final id = request.url.pathSegments.last;
        if (request.url.path.startsWith('/drive/v2/files/') &&
            request.url.queryParameters['alt'] != 'media') {
          final version = id == 'first' ? 1 : 2;
          final modified = id == 'first'
              ? DateTime.utc(2026, 7, 17, 20)
              : DateTime.utc(2026, 7, 17, 21);
          return http.Response(
            jsonEncode(_v2Metadata(id, version, modified, '"$version"')),
            200,
          );
        }
        if (id == 'first') {
          return http.Response.bytes(first, 200);
        }
        return http.Response.bytes(second, 200);
      }),
    );

    final snapshot = await storage.download();

    expect(
      codec
          .decode(snapshot!.bytes)
          .backup
          .backupNovels
          .map((novel) => novel.title),
      {'First', 'Second'},
    );
    expect(
      requests.where((request) => request.url.path == '/drive/v3/files'),
      hasLength(2),
    );
  });
}

GoogleDriveSyncStorage _storage(_FakeDrive drive) => GoogleDriveSyncStorage(
  accessToken: 'access-token',
  deviceId: 'device-123',
  client: MockClient(drive.handle),
);

BackupNovel _novel(String id, String title, int lastModified) =>
    BackupNovel(id: id, title: title, lastModified: Int64(lastModified));

Uint8List _payload(Iterable<BackupNovel> novels) =>
    const ChimahonSyncCodec().encode(
      BackupMihon(backupNovels: novels),
      format: ChimahonSyncWireFormat.gzipProtobuf,
    );

Uint8List _mangaPayload(String description, String scanlator) =>
    const ChimahonSyncCodec().encode(
      BackupMihon(
        backupManga: [
          BackupManga(
            source: Int64(42),
            url: '/same',
            title: 'Same title',
            description: description,
            version: Int64(5),
            lastModifiedAt: Int64(100),
            chapters: [
              BackupChapter(
                url: '/chapter',
                name: 'Same chapter',
                scanlator: scanlator,
                version: Int64(3),
                lastModifiedAt: Int64(100),
              ),
            ],
          ),
        ],
      ),
      format: ChimahonSyncWireFormat.gzipProtobuf,
    );

Map<String, Object> _metadata(String id, int version, DateTime modifiedTime) =>
    {
      'id': id,
      'name': GoogleDriveSyncStorage.chimahonRemoteFileName,
      'mimeType': 'application/x-gzip',
      'modifiedTime': modifiedTime.toUtc().toIso8601String(),
      'version': version.toString(),
    };

Map<String, Object?> _v2Metadata(
  String id,
  int version,
  DateTime modifiedTime,
  String? etag,
) => {
  'id': id,
  'title': GoogleDriveSyncStorage.chimahonRemoteFileName,
  'mimeType': 'application/x-gzip',
  'modifiedDate': modifiedTime.toUtc().toIso8601String(),
  'version': version.toString(),
  'etag': etag,
  'appDataContents': true,
  'labels': {'trashed': false},
  'properties': const <Object>[],
};

class _FakeDrive {
  _FakeDrive(this.files);

  final List<_FakeDriveFile> files;
  final List<http.Request> requests = [];
  final Map<String, Uint8List> bytesAtCreation = {};
  final Set<String> failArchiveIds = {};
  bool failContentUpdate = false;
  bool omitDeviceIdAfterContentUpdate = false;
  int listCount = 0;
  int createCount = 0;
  int archiveCount = 0;
  void Function(_FakeDrive drive, int listCount)? beforeList;
  void Function(_FakeDrive drive, _FakeDriveFile file, int readCount)?
  beforeV2MetadataRead;
  void Function(_FakeDrive drive)? afterCreate;
  void Function(_FakeDrive drive, int archiveCount)? afterArchive;
  final Map<String, int> metadataReadCounts = {};

  Iterable<http.Request> get mutationRequests =>
      requests.where((request) => request.method != 'GET');

  _FakeDriveFile file(String id) =>
      files.singleWhere((candidate) => candidate.id == id);

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
      listCount++;
      beforeList?.call(this, listCount);
      return http.Response(
        jsonEncode({
          'files': files
              .where(
                (file) =>
                    file.name == GoogleDriveSyncStorage.chimahonRemoteFileName,
              )
              .map((file) => file.metadata)
              .toList(),
        }),
        200,
      );
    }

    if (request.method == 'GET' &&
        request.url.path.startsWith('/drive/v2/files/') &&
        request.url.queryParameters['alt'] != 'media') {
      final remote = file(request.url.pathSegments.last);
      final readCount = (metadataReadCounts[remote.id] ?? 0) + 1;
      metadataReadCounts[remote.id] = readCount;
      beforeV2MetadataRead?.call(this, remote, readCount);
      return http.Response(jsonEncode(remote.v2Metadata), 200);
    }

    if (request.method == 'GET' &&
        request.url.path.startsWith('/drive/v2/files/') &&
        request.url.queryParameters['alt'] == 'media') {
      final remote = file(request.url.pathSegments.last);
      return http.Response.bytes(remote.bytes, 200);
    }

    if (request.method == 'POST' &&
        request.url.path == '/upload/drive/v3/files') {
      createCount++;
      final createdId = createCount == 1 ? 'created' : 'created-$createCount';
      final created = _FakeDriveFile(
        id: createdId,
        version: 1,
        modifiedTime: DateTime.utc(2026, 7, 17, 21, createCount),
        mimeType: 'application/x-gzip',
        bytes: _multipartMedia(request),
        etag: '"etag-$createdId"',
      );
      files.add(created);
      bytesAtCreation[createdId] = Uint8List.fromList(created.bytes);
      afterCreate?.call(this);
      return http.Response(jsonEncode(created.metadata), 200);
    }

    if (request.method == 'PUT' &&
        request.url.path.startsWith('/upload/drive/v2/files/')) {
      final remote = file(request.url.pathSegments.last);
      if (failContentUpdate || request.headers['If-Match'] != remote.etag) {
        return http.Response('', 412);
      }
      remote
        ..version = remote.version + 1
        ..mimeType = 'application/x-gzip'
        ..etag = '"etag-${remote.id}-${remote.version}"';
      final metadata = _multipartMetadata(request);
      final properties = metadata['properties'];
      if (!omitDeviceIdAfterContentUpdate && properties is List) {
        for (final property in properties.whereType<Map>()) {
          if (property['visibility'] == 'PRIVATE' &&
              property['key'] == 'deviceId' &&
              property['value'] is String) {
            remote.privateProperties['deviceId'] = property['value'] as String;
          }
        }
      }
      remote.bytes = _multipartMedia(request);
      return http.Response(jsonEncode(remote.v2Metadata), 200);
    }

    if (request.method == 'PATCH' &&
        request.url.path.startsWith('/drive/v2/files/')) {
      final remote = file(request.url.pathSegments.last);
      if (failArchiveIds.contains(remote.id) ||
          request.headers['If-Match'] != remote.etag) {
        return http.Response('', 412);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      remote
        ..name = body['title'] as String
        ..version = remote.version + 1
        ..etag = '"etag-${remote.id}-${remote.version}"';
      archiveCount++;
      afterArchive?.call(this, archiveCount);
      return http.Response(jsonEncode(remote.v2Metadata), 200);
    }

    return http.Response('', 404);
  }
}

class _FakeDriveFile {
  _FakeDriveFile({
    required this.id,
    required this.version,
    required this.modifiedTime,
    required this.bytes,
    required this.etag,
    this.mimeType = 'application/x-gzip',
  }) : name = GoogleDriveSyncStorage.chimahonRemoteFileName;

  final String id;
  int version;
  DateTime modifiedTime;
  List<int> bytes;
  String? etag;
  String name;
  String mimeType;
  bool appDataContents = true;
  bool trashed = false;
  final Map<String, String> privateProperties = {};
  String? metadataIdOverride;
  String? metadataTitleOverride;
  String? metadataVersionOverride;

  Map<String, Object> get metadata => {
    'id': id,
    'name': name,
    'mimeType': mimeType,
    'modifiedTime': modifiedTime.toUtc().toIso8601String(),
    'version': version.toString(),
  };

  Map<String, Object?> get v2Metadata => {
    'id': metadataIdOverride ?? id,
    'title': metadataTitleOverride ?? name,
    'mimeType': mimeType,
    'modifiedDate': modifiedTime.toUtc().toIso8601String(),
    'version': metadataVersionOverride ?? version.toString(),
    'etag': etag,
    'appDataContents': appDataContents,
    'labels': {'trashed': trashed},
    'properties': [
      for (final property in privateProperties.entries)
        {'key': property.key, 'value': property.value, 'visibility': 'PRIVATE'},
    ],
  };
}

Map<String, dynamic> _multipartMetadata(http.Request request) {
  final contentType = request.headers['content-type']!;
  final boundary = contentType.split('boundary=').last;
  final prefix = utf8.encode(
    '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n',
  );
  final start = _indexOfBytes(request.bodyBytes, prefix) + prefix.length;
  final endMarker = utf8.encode('\r\n--$boundary\r\n');
  final end = _indexOfBytes(request.bodyBytes, endMarker, start: start);
  return (jsonDecode(utf8.decode(request.bodyBytes.sublist(start, end))) as Map)
      .cast<String, dynamic>();
}

Uint8List _multipartMedia(http.Request request) {
  final contentType = request.headers['content-type']!;
  final boundary = contentType.split('boundary=').last;
  final marker = utf8.encode(
    '--$boundary\r\nContent-Type: application/x-gzip\r\n\r\n',
  );
  final start = _indexOfBytes(request.bodyBytes, marker) + marker.length;
  final endMarker = utf8.encode('\r\n--$boundary--\r\n');
  final end = _indexOfBytes(request.bodyBytes, endMarker, start: start);
  return Uint8List.fromList(request.bodyBytes.sublist(start, end));
}

int _indexOfBytes(List<int> haystack, List<int> needle, {int start = 0}) {
  for (var index = start; index <= haystack.length - needle.length; index++) {
    var matches = true;
    for (var offset = 0; offset < needle.length; offset++) {
      if (haystack[index + offset] != needle[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return index;
  }
  throw StateError('Multipart marker not found');
}
