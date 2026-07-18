import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';
import 'package:mangayomi/services/sync/google_drive_read_only_inspector.dart';

void main() {
  const codec = ChimahonSyncCodec();

  test(
    'uses only GET requests and emits a credential-safe comparison',
    () async {
      const accessToken = 'do-not-print-access-token';
      const permissionId = 'stable-google-permission-id';
      const fileId = 'opaque-google-file-id';
      const deviceId = 'private-device-id';
      const metadataEtag = '"private-metadata-etag"';
      const legacyMetadataEtag = '"private-v2-metadata-etag"';
      const legacyHeaderEtag = '"private-v2-header-etag"';
      const legacyHeadRevisionId = 'private-head-revision-id';
      const downloadEtag = '"private-download-etag"';
      final referenceBytes = codec.encode(
        BackupMihon(
          backupNovels: [
            BackupNovel(title: 'Novel', categoryIds: const ['reading']),
          ],
        ),
        format: ChimahonSyncWireFormat.gzipProtobuf,
      );
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        switch (request.url.path) {
          case '/drive/v3/about':
            return http.Response(
              jsonEncode({
                'user': {'permissionId': permissionId},
              }),
              200,
            );
          case '/drive/v3/files':
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': fileId,
                    'name': 'Chimahon_sync.proto.gz',
                    'mimeType': 'application/octet-stream',
                    'createdTime': '2026-07-17T20:00:00Z',
                    'modifiedTime': '2026-07-17T21:00:00Z',
                    'version': '7',
                    'size': '${referenceBytes.length}',
                    'md5Checksum': md5.convert(referenceBytes).toString(),
                    'appProperties': {'deviceId': deviceId},
                  },
                ],
              }),
              200,
            );
          case '/drive/v3/files/$fileId':
            if (!request.url.queryParameters.containsKey('alt')) {
              return http.Response(
                jsonEncode({
                  'id': fileId,
                  'name': 'Chimahon_sync.proto.gz',
                  'version': '7',
                }),
                200,
                headers: {'etag': metadataEtag},
              );
            }
            return http.Response.bytes(
              referenceBytes,
              200,
              headers: {'etag': downloadEtag},
            );
          case '/drive/v2/files/$fileId':
            return http.Response(
              jsonEncode({
                'id': fileId,
                'title': 'Chimahon_sync.proto.gz',
                'version': '7',
                'etag': legacyMetadataEtag,
                'headRevisionId': legacyHeadRevisionId,
              }),
              200,
              headers: {'etag': legacyHeaderEtag},
            );
        }
        return http.Response('', 404);
      });
      final inspector = GoogleDriveReadOnlyInspector(
        accessToken: accessToken,
        client: client,
      );

      final report = await inspector.inspect(referenceBytes: referenceBytes);

      expect(requests, hasLength(5));
      expect(requests, everyElement(isA<http.Request>()));
      expect(requests.map((request) => request.method).toSet(), {'GET'});
      expect(requests[1].url.queryParameters['spaces'], 'appDataFolder');
      expect(
        requests[1].url.queryParameters['q'],
        "name = 'Chimahon_sync.proto.gz' and trashed = false",
      );
      expect(requests[2].url.queryParameters, {'fields': 'id,name,version'});
      expect(requests[3].url.path, '/drive/v2/files/$fileId');
      expect(requests[3].url.queryParameters, {
        'fields': 'id,title,version,etag,headRevisionId',
      });
      expect(requests[4].url.queryParameters, {'alt': 'media'});
      expect(report.files, hasLength(1));
      final file = report.files.single;
      expect(file.wouldBeCanonical, isTrue);
      expect(file.mimeType, 'application/octet-stream');
      expect(file.declaredSize, referenceBytes.length);
      expect(file.declaredSizeMatchesDownload, isTrue);
      expect(file.driveMd5MatchesDownload, isTrue);
      expect(
        file.metadataEtagSha256,
        sha256.convert(utf8.encode(metadataEtag)).toString(),
      );
      expect(
        file.downloadEtagSha256,
        sha256.convert(utf8.encode(downloadEtag)).toString(),
      );
      expect(
        file.legacyMetadataEtagSha256,
        sha256.convert(utf8.encode(legacyMetadataEtag)).toString(),
      );
      expect(file.legacyMetadataEtagIsStrong, isTrue);
      expect(
        file.legacyMetadataHeaderEtagSha256,
        sha256.convert(utf8.encode(legacyHeaderEtag)).toString(),
      );
      expect(file.legacyMetadataEtagsMatch, isFalse);
      expect(
        file.legacyHeadRevisionIdSha256,
        sha256.convert(utf8.encode(legacyHeadRevisionId)).toString(),
      );
      expect(file.fingerprint?.counts['novels'], 1);
      expect(file.comparison?.rawBytesMatch, isTrue);
      expect(file.comparison?.protobufBytesMatch, isTrue);
      expect(file.comparison?.countDifferences, isEmpty);

      final safeJson = report.toSafeJson();
      final safeFile = (safeJson['files']! as List).single as Map;
      expect(safeFile['metadataEtagSha256'], file.metadataEtagSha256);
      expect(
        safeFile['legacyMetadataEtagSha256'],
        file.legacyMetadataEtagSha256,
      );
      expect(safeFile['downloadEtagSha256'], file.downloadEtagSha256);
      final safeOutput = jsonEncode(safeJson);
      for (final secret in [
        accessToken,
        permissionId,
        fileId,
        deviceId,
        metadataEtag,
        legacyMetadataEtag,
        legacyHeaderEtag,
        legacyHeadRevisionId,
        downloadEtag,
      ]) {
        expect(safeOutput, isNot(contains(secret)));
      }
      expect(
        safeOutput,
        contains(sha256.convert(utf8.encode(permissionId)).toString()),
      );
    },
  );

  test(
    'reports corrupt duplicates without mutating or selecting them',
    () async {
      final validBytes = codec.encode(
        BackupMihon(backupNovels: [BackupNovel(title: 'Valid')]),
        format: ChimahonSyncWireFormat.gzipProtobuf,
      );
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/drive/v3/about') {
          return http.Response('{"user":{"permissionId":"account"}}', 200);
        }
        if (request.url.path == '/drive/v3/files') {
          return http.Response(
            jsonEncode({
              'files': [
                {
                  'id': 'corrupt-newest',
                  'name': 'Chimahon_sync.proto.gz',
                  'modifiedTime': '2026-07-17T22:00:00Z',
                  'version': '9',
                },
                {
                  'id': 'valid-older',
                  'name': 'Chimahon_sync.proto.gz',
                  'modifiedTime': '2026-07-17T21:00:00Z',
                  'version': '8',
                },
              ],
            }),
            200,
          );
        }
        if (!request.url.queryParameters.containsKey('alt')) {
          final id = request.url.pathSegments.last;
          if (request.url.path.startsWith('/drive/v2/files/')) {
            return http.Response(
              jsonEncode({
                'id': id,
                'title': 'Chimahon_sync.proto.gz',
                'version': id == 'corrupt-newest' ? '9' : '8',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'id': id,
              'name': 'Chimahon_sync.proto.gz',
              'version': id == 'corrupt-newest' ? '9' : '8',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/corrupt-newest')) {
          return http.Response.bytes(const [1, 2, 3], 200);
        }
        if (request.url.path.endsWith('/valid-older')) {
          return http.Response.bytes(validBytes, 200);
        }
        return http.Response('', 404);
      });
      final inspector = GoogleDriveReadOnlyInspector(
        accessToken: 'access',
        client: client,
      );

      final report = await inspector.inspect();

      expect(requests.map((request) => request.method).toSet(), {'GET'});
      expect(requests, hasLength(8));
      expect(
        requests
            .where(
              (request) =>
                  request.url.path.startsWith('/drive/v3/files/') &&
                  !request.url.queryParameters.containsKey('alt'),
            )
            .map((request) => request.url.path)
            .toSet(),
        {'/drive/v3/files/corrupt-newest', '/drive/v3/files/valid-older'},
      );
      expect(report.files, hasLength(2));
      expect(report.files.first.formatError, 'invalidChimahonPayload');
      expect(report.files.first.wouldBeCanonical, isFalse);
      expect(report.files.last.fingerprint, isNotNull);
      expect(report.files.last.wouldBeCanonical, isTrue);
    },
  );

  for (final mismatch in <String, String>{
    'id': 'different-file-id',
    'name': 'different-file-name',
    'version': '8',
  }.entries) {
    test(
      'rejects metadata ${mismatch.key} changes since the list snapshot',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/drive/v3/about') {
            return http.Response('{"user":{"permissionId":"account"}}', 200);
          }
          if (request.url.path == '/drive/v3/files') {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'listed-file-id',
                    'name': 'Chimahon_sync.proto.gz',
                    'version': '7',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/drive/v3/files/listed-file-id' &&
              !request.url.queryParameters.containsKey('alt')) {
            final metadata = <String, String>{
              'id': 'listed-file-id',
              'name': 'Chimahon_sync.proto.gz',
              'version': '7',
            }..[mismatch.key] = mismatch.value;
            return http.Response(jsonEncode(metadata), 200);
          }
          fail('The inspector must reject changed metadata before download.');
        });
        final inspector = GoogleDriveReadOnlyInspector(
          accessToken: 'access',
          client: client,
        );

        await expectLater(
          inspector.inspect(),
          throwsA(isA<SyncConflictException>()),
        );

        expect(requests, hasLength(3));
        expect(requests.map((request) => request.method).toSet(), {'GET'});
        expect(requests.last.url.queryParameters, {
          'fields': 'id,name,version',
        });
      },
    );
  }

  for (final mismatch in <String, String>{
    'id': 'different-file-id',
    'title': 'different-file-name',
    'version': '8',
  }.entries) {
    test(
      'rejects v2 metadata ${mismatch.key} changes before media download',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/drive/v3/about') {
            return http.Response('{"user":{"permissionId":"account"}}', 200);
          }
          if (request.url.path == '/drive/v3/files') {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'listed-file-id',
                    'name': 'Chimahon_sync.proto.gz',
                    'version': '7',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/drive/v3/files/listed-file-id') {
            return http.Response(
              jsonEncode({
                'id': 'listed-file-id',
                'name': 'Chimahon_sync.proto.gz',
                'version': '7',
              }),
              200,
            );
          }
          if (request.url.path == '/drive/v2/files/listed-file-id') {
            final metadata = <String, String>{
              'id': 'listed-file-id',
              'title': 'Chimahon_sync.proto.gz',
              'version': '7',
            }..[mismatch.key] = mismatch.value;
            return http.Response(jsonEncode(metadata), 200);
          }
          fail('The inspector must reject changed v2 metadata before media.');
        });
        final inspector = GoogleDriveReadOnlyInspector(
          accessToken: 'access',
          client: client,
        );

        await expectLater(
          inspector.inspect(),
          throwsA(isA<SyncConflictException>()),
        );

        expect(requests, hasLength(4));
        expect(requests.map((request) => request.method).toSet(), {'GET'});
        expect(requests.last.url.queryParameters, {
          'fields': 'id,title,version,etag,headRevisionId',
        });
      },
    );
  }
}
