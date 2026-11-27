/// A SyncYomi server on 127.0.0.1 for sync journeys: the `/api/sync/content`
/// protocol Mangatan speaks (lib/services/sync/cross_device_sync_storage.dart),
/// with its token check and ETag preconditions, holding the fixture payload.
///
/// GET returns the stored bytes with an ETag (404 when empty). PUT stores new
/// bytes only when `If-Match` names the current ETag, or `If-None-Match: *`
/// when nothing is stored; otherwise 412. A wrong `X-API-Token` is 401.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';

import 'sync_fixture.dart';

class FakeSyncRequest {
  FakeSyncRequest(this.method, this.headers, this.status);

  final String method;
  final Map<String, String> headers;
  final int status;

  @override
  String toString() => '$method → $status';
}

class FakeSyncYomi {
  FakeSyncYomi._(this._server, {required this.token, Uint8List? content})
    : _content = content {
    if (content != null) _etag = _nextEtag();
    _server.listen(_handle);
  }

  /// A small cover, preview or background image for any /covers, /previews
  /// or /backgrounds path the fixture names.
  static final _image = Uint8List.fromList(
    img.encodePng(
      img.Image(width: 30, height: 45)..clear(img.ColorRgb8(90, 120, 200)),
    ),
  );

  /// Starts serving [content] (the fixture by default; null for an empty
  /// account) on a free loopback port.
  /// Widget tests answer every HTTP request with 400 to keep tests off the
  /// network. A sync journey talks to this loopback server for real, so it
  /// lifts that for the test; nothing else it could reach is real.
  static void allowLoopbackHttp() {
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previous);
  }

  static Future<FakeSyncYomi> start({
    String token = 'fixture-token',
    Uint8List? content,
    bool empty = false,
  }) async {
    allowLoopbackHttp();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return FakeSyncYomi._(
      server,
      token: token,
      content: empty
          ? null
          : content ??
                syncFixtureBytes(
                  mediaBase: 'http://${server.address.address}:${server.port}',
                ),
    );
  }

  final HttpServer _server;
  final String token;
  Uint8List? _content;
  String? _etag;
  var _revision = 0;

  /// Every request, in order.
  final requests = <FakeSyncRequest>[];

  /// When set, the next request gets this status and nothing else happens.
  int? failNextWith;

  /// Runs once between the next download and the upload that follows it,
  /// to stand for another device syncing in between.
  void Function(FakeSyncYomi server)? beforeNextUpload;

  String get url => 'http://${_server.address.address}:${_server.port}';
  Uint8List? get content => _content;
  String? get etag => _etag;

  static BackupMihon decodeBytes(List<int> bytes) =>
      const ChimahonSyncCodec().decode(bytes).backup;

  /// What is stored, decoded.
  BackupMihon? get backup => _content == null
      ? null
      : const ChimahonSyncCodec().decode(_content!).backup;

  Iterable<FakeSyncRequest> get uploads =>
      requests.where((r) => r.method == 'PUT');
  Iterable<FakeSyncRequest> get downloads =>
      requests.where((r) => r.method == 'GET');

  /// Replaces the stored payload as another device's upload would.
  void store(Uint8List bytes) {
    _content = bytes;
    _etag = _nextEtag();
  }

  String _nextEtag() => '"rev-${++_revision}"';

  Future<void> _handle(HttpRequest request) async {
    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.join(','));
    final response = request.response;
    Future<void> finish(int status, {Uint8List? body}) async {
      requests.add(FakeSyncRequest(request.method, headers, status));
      response.statusCode = status;
      if (_etag != null && status == 200) response.headers.set('ETag', _etag!);
      if (body != null) {
        response.headers.contentType = ContentType.binary;
        response.add(body);
      }
      await response.close();
    }

    final body = await request.fold<BytesBuilder>(
      BytesBuilder(copy: false),
      (b, chunk) => b..add(chunk),
    );
    if (failNextWith != null) {
      final status = failNextWith!;
      failNextWith = null;
      return finish(status);
    }
    final path = request.uri.path;
    if (path.startsWith('/covers/') ||
        path.startsWith('/previews/') ||
        path.startsWith('/backgrounds/')) {
      response.headers.contentType = ContentType('image', 'png');
      response.add(_image);
      await response.close();
      return;
    }
    if (path != '/api/sync/content') return finish(404);
    if (headers['x-api-token'] != token) return finish(401);

    switch (request.method) {
      case 'GET':
        if (_content == null) return finish(404);
        return finish(200, body: _content);
      case 'PUT':
        final hook = beforeNextUpload;
        beforeNextUpload = null;
        hook?.call(this);
        final ifMatch = headers['if-match'];
        final ifNoneMatch = headers['if-none-match'];
        final allowed = _content == null
            ? (ifNoneMatch == '*' || ifMatch == null)
            : ifMatch == _etag;
        if (!allowed) return finish(412);
        store(body.takeBytes());
        return finish(200);
      default:
        return finish(405);
    }
  }

  Future<void> close() => _server.close(force: true);
}
