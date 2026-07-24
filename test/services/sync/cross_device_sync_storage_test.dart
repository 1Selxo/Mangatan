import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

void main() {
  test('SyncYomi uses its content endpoint, API token, and ETag', () async {
    final requests = <http.Request>[];
    final storage = SyncYomiStorage(
      baseUrl: Uri.parse('https://sync.example'),
      apiToken: 'secret',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'etag': 'revision-1'},
          );
        }
        return http.Response('', 200, headers: {'etag': 'revision-2'});
      }),
    );

    final downloaded = await storage.download();
    final revision = await storage.upload(
      Uint8List.fromList([4, 5, 6]),
      expectedRevision: downloaded!.revision,
    );

    expect(requests, hasLength(2));
    expect(requests.first.url.path, '/api/sync/content');
    expect(requests.first.headers['X-API-Token'], 'secret');
    expect(requests.last.headers['If-Match'], 'revision-1');
    expect(revision, 'revision-2');
  });

  test('SyncYomi reports optimistic concurrency conflicts', () async {
    final storage = SyncYomiStorage(
      baseUrl: Uri.parse('https://sync.example'),
      apiToken: 'secret',
      client: MockClient((_) async => http.Response('', 412)),
    );

    expect(
      storage.upload(Uint8List(0), expectedRevision: 'stale'),
      throwsA(isA<SyncConflictException>()),
    );
  });
}
