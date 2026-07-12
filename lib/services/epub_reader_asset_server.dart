import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Serves one materialized EPUB reader session over an unguessable loopback
/// URL.
///
/// WebView2 does not implement the file-access setting used by the other
/// desktop WebViews. Keeping the files behind a local HTTP origin makes image,
/// stylesheet, and font loading independent of Windows file-URL permissions
/// and of non-ASCII paths in the user's profile or temporary directory.
class EpubReaderAssetServer {
  EpubReaderAssetServer._(this.root, this._server, this._token) {
    _server.listen((request) => unawaited(_serve(request)));
  }

  final Directory root;
  final HttpServer _server;
  final String _token;

  static Future<EpubReaderAssetServer> start(Directory root) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final token = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return EpubReaderAssetServer._(root, server, token);
  }

  Uri uriFor(File file, {Map<String, String>? queryParameters}) {
    final relative = p
        .relative(file.path, from: root.path)
        .replaceAll('\\', '/');
    final safePath = _safeRelativePath(relative);
    if (safePath == null || !p.isWithin(root.path, file.path)) {
      throw ArgumentError.value(
        file.path,
        'file',
        'File is outside the EPUB session',
      );
    }
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: _server.port,
      pathSegments: [_token, ...safePath.split('/')],
      queryParameters: queryParameters,
    );
  }

  bool owns(Uri uri) =>
      uri.scheme == 'http' &&
      uri.host == InternetAddress.loopbackIPv4.address &&
      uri.port == _server.port &&
      uri.pathSegments.firstOrNull == _token;

  Future<void> close() => _server.close(force: true);

  Future<void> _serve(HttpRequest request) async {
    try {
      await _handleRequest(request);
    } catch (_) {
      // Closing a reader can race an in-flight WebView request. Ensure the
      // connection is released without leaking an asynchronous socket error.
      try {
        await request.response.close();
      } catch (_) {
        // The forced server shutdown may already have closed the response.
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    final relative = segments.length > 1 && segments.first == _token
        ? segments.skip(1).join('/')
        : '';
    final safePath = _safeRelativePath(relative);
    if ((request.method != 'GET' && request.method != 'HEAD') ||
        safePath == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final file = File(p.joinAll([root.path, ...safePath.split('/')]));
    if (!p.isWithin(root.path, file.path) || !await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    request.response.headers.contentType = _contentType(file.path);
    request.response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff');
    request.response.contentLength = await file.length();
    if (request.method == 'GET') {
      await request.response.addStream(file.openRead());
    }
    await request.response.close();
  }
}

String? _safeRelativePath(String value) {
  final normalized = value.replaceAll('\\', '/');
  final segments = normalized.split('/');
  if (normalized.isEmpty ||
      normalized.startsWith('/') ||
      segments.any(
        (segment) =>
            segment.isEmpty ||
            segment == '.' ||
            segment == '..' ||
            segment.contains('\\'),
      )) {
    return null;
  }
  return segments.join('/');
}

ContentType _contentType(String path) =>
    switch (p.extension(path).toLowerCase()) {
      '.html' || '.htm' || '.xhtml' => ContentType.html,
      '.css' => ContentType('text', 'css', charset: 'utf-8'),
      '.svg' => ContentType('image', 'svg+xml'),
      '.jpg' || '.jpeg' => ContentType('image', 'jpeg'),
      '.png' => ContentType('image', 'png'),
      '.gif' => ContentType('image', 'gif'),
      '.webp' => ContentType('image', 'webp'),
      '.woff' => ContentType('font', 'woff'),
      '.woff2' => ContentType('font', 'woff2'),
      '.ttf' => ContentType('font', 'ttf'),
      '.otf' => ContentType('font', 'otf'),
      '.eot' => ContentType('application', 'vnd.ms-fontobject'),
      _ => ContentType.binary,
    };
