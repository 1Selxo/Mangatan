import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// A loopback stand-in for the Mihon extension server.
///
/// It answers the bridge protocol with deterministic catalogue data and waits
/// [latency] before every response, so the app's network time is known and
/// stable while its own processing is measured.
class FakeExtensionServer {
  FakeExtensionServer._(this._server, this.latency);

  final HttpServer _server;
  Duration latency;

  /// Chapters (or episodes) returned for every entry.
  int chapterCount = 1000;
  int pageCount = 40;
  int catalogueSize = 50;

  /// Served for every image request.
  List<int> imageBytes = const [];

  static const extensionId =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static Future<FakeExtensionServer> start({
    Duration latency = const Duration(milliseconds: 120),
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeExtensionServer._(server, latency);
    server.listen(fake._handle);
    return fake;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final body = await utf8.decoder.bind(request).join();
    await Future<void>.delayed(latency);
    final response = request.response;
    if (path == '/') {
      response.write('ok');
    } else if (path == '/capabilities') {
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode({
          'mangatanMihonBridge': 1,
          'sourceFactory': true,
          'preferenceCallbacks': true,
        }),
      );
    } else if (path.startsWith('/image/')) {
      response.headers.contentType = ContentType('image', 'jpeg');
      response.add(imageBytes);
    } else if (path == '/dalvik') {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      response.headers.contentType = ContentType.json;
      response.headers.set('x-mangatan-extension-id', extensionId);
      response.write(jsonEncode(_dalvik(payload)));
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }

  Object? _dalvik(Map<String, dynamic> payload) {
    final method = payload['method'] as String;
    final media =
        (payload['mangaData'] ?? payload['animeData']) as Map<String, dynamic>?;
    final seed = (media?['url'] as String? ?? method).hashCode;
    switch (method) {
      case 'getPopularManga' ||
          'getLatestManga' ||
          'getSearchManga' ||
          'getPopularAnime' ||
          'getLatestAnime' ||
          'getSearchAnime':
        final key = method.endsWith('Anime') ? 'animes' : 'mangas';
        return {
          key: [
            for (var i = 0; i < catalogueSize; i++) _catalogueEntry(i, seed),
          ],
          'hasNextPage': true,
        };
      case 'getDetailsManga' || 'getDetailsAnime':
        return {
          'title': 'Bench Title ${media!['url']}',
          'url': media['url'],
          'artist': 'Artist',
          'author': 'Author',
          'description': _text(seed, 60),
          'genre': 'Action, Adventure, Comedy, Drama, Fantasy',
          'status': 1,
          'thumbnail_url': '$baseUrl/image/cover/$seed.jpg',
          'initialized': true,
        };
      case 'getChapterList' || 'getEpisodeList':
        final anime = method == 'getEpisodeList';
        return [
          for (var i = chapterCount; i >= 1; i--)
            {
              'name': _chapterName(i, anime),
              'url': '${media!['url']}/chapter-$i',
              'date_upload': 1600000000000 + i * 86400000,
              'scanlator': i.isEven ? 'Group A' : 'Group B',
              anime ? 'episode_number' : 'chapter_number': i.isOdd
                  ? i.toDouble()
                  : -1.0,
            },
        ];
      case 'getPageList':
        final chapter = (payload['chapterData'] as Map)['url'];
        return [
          for (var i = 0; i < pageCount; i++)
            {
              'index': i,
              'imageUrl': '$baseUrl/image/page/${chapter.hashCode}-$i.jpg',
            },
        ];
      case 'getVideoList':
        return [
          for (final quality in ['1080p', '720p', '480p', '360p'])
            {
              'videoUrl': 'https://cdn.bench.example/video/$seed/$quality.m3u8',
              'quality': quality,
              'url': 'https://cdn.bench.example/video/$seed/$quality.m3u8',
              'headers': {
                'namesAndValues\$okhttp': [
                  'Referer',
                  'https://bench.example/',
                  'User-Agent',
                  'Bench',
                ],
              },
              'subtitleTracks': [
                {
                  'url': 'https://cdn.bench.example/sub/$seed.vtt',
                  'lang': 'en',
                },
              ],
              'audioTracks': [],
            },
        ];
      default:
        throw UnsupportedError(method);
    }
  }

  Map<String, Object?> _catalogueEntry(int i, int seed) => {
    'url': '/series/${seed.abs()}-$i',
    'title': 'Series $i ${_text(seed + i, 3)}',
    'artist': 'Artist $i',
    'author': 'Author $i',
    'description': _text(seed + i, 40),
    'genres': ['Action', 'Drama', 'Fantasy'],
    'status': 1 + i % 2,
    'thumbnail_url': '$baseUrl/image/thumb/${seed.abs()}-$i.jpg',
  };

  static String _chapterName(int i, bool anime) {
    if (anime) return 'Episode $i';
    return switch (i % 4) {
      0 => 'Chapter $i',
      1 => 'Vol.${i ~/ 10 + 1} Ch.$i - ${_text(i, 3)}',
      2 => 'Ch. $i',
      _ => 'Chapter $i: ${_text(i, 4)}',
    };
  }

  static const _words = [
    'lorem',
    'ipsum',
    'dolor',
    'sit',
    'amet',
    'consectetur',
    'adipiscing',
    'elit',
    'sed',
    'do',
    'eiusmod',
    'tempor',
  ];

  static String _text(int seed, int words) {
    final random = Random(seed);
    return List.generate(
      words,
      (_) => _words[random.nextInt(_words.length)],
    ).join(' ');
  }
}
