import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';
import 'package:mangayomi/services/sync/mangatan_epub_sync_manifest.dart';
import 'package:mangayomi/services/sync/webdav_credential_store.dart';
import 'package:mangayomi/services/sync/webdav_sync_storage.dart';

void main() {
  String repeat(String value, int count) => List.filled(count, value).join();

  late _FakeWebDavServer server;
  late WebDavSyncStorage storage;

  setUp(() async {
    server = await _FakeWebDavServer.start();
    storage = WebDavSyncStorage(
      collectionUrl: server.collectionUri,
      credentials: const WebDavCredentials(
        username: 'reader',
        password: 'secret',
      ),
    );
  });

  tearDown(() async {
    storage.close();
    await server.close();
  });

  test('uploads gzip-protobuf with If-None-Match then updates with If-Match', () async {
    final bytes = const ChimahonSyncCodec().encode(
      BackupMihon(),
      format: storage.wireFormat,
    );

    final revision = await storage.upload(bytes, expectedAbsent: true);
    final snapshot = await storage.download();
    expect(snapshot, isNotNull);
    expect(snapshot!.revision, revision);

    final next = await storage.upload(bytes, expectedRevision: revision);
    expect(next, isNot(revision));
    expect(
      server.requests.map((request) => request.path),
      contains('/dav/Chimahon_sync.proto.gz'),
    );
  });

  test('create and update conflicts map to shared sync conflict', () async {
    final bytes = const ChimahonSyncCodec().encode(
      BackupMihon(),
      format: storage.wireFormat,
    );
    await storage.upload(bytes, expectedAbsent: true);

    await expectLater(
      storage.upload(bytes, expectedAbsent: true),
      throwsA(isA<SyncConflictException>()),
    );
    await expectLater(
      storage.upload(bytes, expectedRevision: '"stale"'),
      throwsA(isA<SyncConflictException>()),
    );
  });

  test('fails closed when server omits write ETag', () async {
    server.omitEtags = true;
    final bytes = const ChimahonSyncCodec().encode(
      BackupMihon(),
      format: storage.wireFormat,
    );

    await expectLater(
      storage.upload(bytes, expectedAbsent: true),
      throwsA(isA<SyncStorageException>()),
    );
  });

  test('uses encoded WebDAV paths for EPUB manifest and blobs', () async {
    final hash = repeat('0', 64);
    final manifest = MangatanEpubManifest(
      generatedAtUtc: DateTime.utc(2026),
      deviceId: 'device',
      entries: const {},
    );
    await storage.uploadEpubManifest(manifest, expectedAbsent: true);
    await storage.uploadEpubBlob(
      sha256: hash,
      sizeBytes: 3,
      bytes: Stream.value([1, 2, 3]),
    );

    expect(await storage.hasEpubBlob(hash), isTrue);
    expect(
      server.requests.map((request) => request.path),
      contains('/dav/mangatan-epub-blobs/$hash.epub'),
    );
  });
}

class _RecordedRequest {
  const _RecordedRequest(this.method, this.path);

  final String method;
  final String path;
}

class _FakeWebDavServer {
  _FakeWebDavServer._(this._server);

  final HttpServer _server;
  final files = <String, _StoredFile>{};
  final requests = <_RecordedRequest>[];
  bool omitEtags = false;

  Uri get collectionUri => Uri.parse('http://127.0.0.1:${_server.port}/dav/');

  static Future<_FakeWebDavServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeWebDavServer._(server);
    unawaited(fake._serve());
    return fake;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _serve() async {
    await for (final request in _server) {
      requests.add(_RecordedRequest(request.method, request.uri.path));
      if (request.headers.value(HttpHeaders.authorizationHeader) !=
          'Basic ${base64Encode(utf8.encode('reader:secret'))}') {
        request.response.statusCode = 401;
        await request.response.close();
        continue;
      }
      if (request.method == 'MKCOL') {
        request.response.statusCode = 201;
        await request.response.close();
        continue;
      }
      final path = request.uri.path;
      final existing = files[path];
      switch (request.method) {
        case 'GET':
          if (existing == null) {
            request.response.statusCode = 404;
          } else {
            request.response.headers.set(HttpHeaders.etagHeader, existing.etag);
            request.response.add(existing.bytes);
          }
          break;
        case 'HEAD':
          if (existing == null) {
            request.response.statusCode = 404;
          } else {
            request.response.headers.set(HttpHeaders.etagHeader, existing.etag);
          }
          break;
        case 'PUT':
          final ifNoneMatch = request.headers.value('if-none-match');
          final ifMatch = request.headers.value('if-match');
          if (ifNoneMatch == '*' && existing != null) {
            request.response.statusCode = 412;
            break;
          }
          if (ifMatch != null && existing?.etag != ifMatch) {
            request.response.statusCode = 412;
            break;
          }
          final bytes = await request.fold<List<int>>(
            <int>[],
            (buffer, chunk) => buffer..addAll(chunk),
          );
          final etag = '"${(existing?.version ?? 0) + 1}"';
          files[path] = _StoredFile(bytes, etag, (existing?.version ?? 0) + 1);
          request.response.statusCode = existing == null ? 201 : 204;
          if (!omitEtags) {
            request.response.headers.set(HttpHeaders.etagHeader, etag);
          }
          break;
        case 'DELETE':
          files.remove(path);
          request.response.statusCode = 204;
          break;
        default:
          request.response.statusCode = 405;
      }
      await request.response.close();
    }
  }
}

class _StoredFile {
  const _StoredFile(this.bytes, this.etag, this.version);

  final List<int> bytes;
  final String etag;
  final int version;
}
