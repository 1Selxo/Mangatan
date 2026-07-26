import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/mining/anki_audio_service.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

void main() {
  test('selects the three Yomitan Japanese defaults in fallback order', () {
    expect(
      AnkiAudioPreferences.defaults.effectiveSources.map(
        (source) => source.type,
      ),
      [
        AnkiAudioSourceType.japanesePod101,
        AnkiAudioSourceType.jisho,
        AnkiAudioSourceType.languagePod101,
      ],
    );
  });

  test('tries multiple configured sources from top to bottom', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.host == 'missing.example') {
        return http.Response('not found', 404);
      }
      return http.Response.bytes(
        [0x49, 0x44, 0x33, 0x04],
        200,
        headers: {'content-type': 'audio/mpeg'},
      );
    });

    final media = await AnkiAudioService(client: client).fetchTermAudio(
      term: '食べる',
      reading: 'たべる',
      preferences: const AnkiAudioPreferences(
        enabled: true,
        sourceType: AnkiAudioSourceType.customUrl,
        url: '',
        sources: [
          AnkiAudioSource(
            type: AnkiAudioSourceType.customUrl,
            url: 'https://missing.example/{term}.mp3',
          ),
          AnkiAudioSource(
            type: AnkiAudioSourceType.customUrl,
            url: 'https://audio.example/{reading}.mp3',
          ),
        ],
        timeout: Duration(seconds: 1),
        language: 'ja',
      ),
    );

    expect(media, isNotNull);
    expect(requests.map((uri) => uri.host), [
      'missing.example',
      'audio.example',
    ]);
    expect(Uri.decodeComponent(requests.last.path), '/たべる.mp3');
  });

  test('falls back from JapanesePod101 to matching Jisho audio', () async {
    final hosts = <String>[];
    final client = MockClient((request) async {
      hosts.add(request.url.host);
      if (request.url.host == 'assets.languagepod101.com') {
        expect(request.url.queryParameters, {'kanji': '食べる', 'kana': 'たべる'});
        return http.Response('not audio', 200);
      }
      if (request.url.host == 'jisho.org') {
        return http.Response(
          '<audio id="audio_食べる:たべる">'
          '<source src="https://cdn.example/taberu.mp3">'
          '</audio>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }
      if (request.url.host == 'cdn.example') {
        return http.Response.bytes(
          [0x49, 0x44, 0x33, 0x04],
          200,
          headers: {'content-type': 'audio/mpeg'},
        );
      }
      return http.Response('not found', 404);
    });

    final media = await AnkiAudioService(client: client).fetchTermAudio(
      term: '食べる',
      reading: 'たべる',
      preferences: AnkiAudioPreferences.defaults,
    );

    expect(media, isNotNull);
    expect(hosts, ['assets.languagepod101.com', 'jisho.org', 'cdn.example']);
  });

  test('extracts matching LanguagePod101 dictionary audio', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/audio/jouzu.mp3') {
        return http.Response.bytes(
          [0x49, 0x44, 0x33, 0x04],
          200,
          headers: {'content-type': 'audio/mpeg'},
        );
      }
      if (request.url.host == 'www.japanesepod101.com') {
        expect(request.method, 'POST');
        expect(request.bodyFields['search_query'], '上手');
        return http.Response(
          '<div class="dc-result-row">'
          '<span class="dc-vocab_kana">じょうず</span>'
          '<audio><source src="/audio/jouzu.mp3"></audio>'
          '</div>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }
      return http.Response('not found', 404);
    });

    final media = await AnkiAudioService(client: client).fetchTermAudio(
      term: '上手',
      reading: 'じょうず',
      preferences: const AnkiAudioPreferences(
        enabled: true,
        sourceType: AnkiAudioSourceType.languagePod101,
        url: '',
        sources: [AnkiAudioSource(type: AnkiAudioSourceType.languagePod101)],
        timeout: Duration(seconds: 1),
        language: 'ja',
      ),
    );

    expect(media, isNotNull);
  });

  test(
    'keeps owned client alive until custom JSON audio download finishes',
    () async {
      final client = _DelayedCloseAwareClient();

      final media = await AnkiAudioService(client: client, closeClient: true)
          .fetchTermAudio(
            term: '食べる',
            reading: 'たべる',
            preferences: const AnkiAudioPreferences(
              enabled: true,
              sourceType: AnkiAudioSourceType.customJson,
              url: 'http://127.0.0.1:5050/?term={term}&reading={reading}',
              timeout: Duration(seconds: 1),
              language: 'ja',
            ),
          );

      expect(media, isNotNull);
      expect(media!.bytes, [0x49, 0x44, 0x33, 0x04]);
      expect(client.closed, isTrue);
    },
  );

  test('fetches the first valid Yomitan custom JSON audio source', () async {
    final client = MockClient((request) async {
      if (request.url.path.isEmpty || request.url.path == '/') {
        expect(request.url.queryParameters['term'], '食べる');
        expect(request.url.queryParameters['reading'], 'たべる');
        return http.Response(
          jsonEncode({
            'type': 'audioSourceList',
            'audioSources': [
              {'name': 'local', 'url': '/audio/食べる.mp3'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.pathSegments.length == 2 &&
          request.url.pathSegments.last == '食べる.mp3') {
        return http.Response.bytes(
          [0x49, 0x44, 0x33, 0x04],
          200,
          headers: {'content-type': 'audio/mpeg'},
        );
      }
      return http.Response('not found', 404);
    });

    final media = await AnkiAudioService(client: client).fetchTermAudio(
      term: '食べる',
      reading: 'たべる',
      preferences: const AnkiAudioPreferences(
        enabled: true,
        sourceType: AnkiAudioSourceType.customJson,
        url: 'http://127.0.0.1:5050/?term={term}&reading={reading}',
        timeout: Duration(seconds: 1),
        language: 'ja',
      ),
    );

    expect(media, isNotNull);
    expect(media!.filename, startsWith('食べる たべる-'));
    expect(media.filename, endsWith('.mp3'));
    expect(media.bytes, [0x49, 0x44, 0x33, 0x04]);
  });

  test('skips missing Yomitan custom JSON audio sources', () async {
    final client = MockClient((request) async {
      if (request.url.path.isEmpty || request.url.path == '/') {
        return http.Response(
          jsonEncode({
            'type': 'audioSourceList',
            'audioSources': [
              {'name': 'missing', 'url': '/audio/missing.opus'},
              {'name': 'local', 'url': '/audio/食べる.mp3'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/missing.opus')) {
        return http.Response('not found', 404);
      }
      if (request.url.pathSegments.isNotEmpty &&
          request.url.pathSegments.last == '食べる.mp3') {
        return http.Response.bytes(
          [0x49, 0x44, 0x33, 0x04],
          200,
          headers: {'content-type': 'audio/mpeg'},
        );
      }
      return http.Response('not found', 404);
    });

    final media = await AnkiAudioService(client: client).fetchTermAudio(
      term: '食べる',
      reading: 'たべる',
      preferences: const AnkiAudioPreferences(
        enabled: true,
        sourceType: AnkiAudioSourceType.customJson,
        url: 'http://127.0.0.1:5050/?term={term}&reading={reading}',
        timeout: Duration(seconds: 1),
        language: 'ja',
      ),
    );

    expect(media, isNotNull);
    expect(media!.filename, endsWith('.mp3'));
  });

  test(
    'resolves custom JSON audio source results for popup playback',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'audioSourceList',
            'audioSources': [
              {'name': 'nhk16', 'url': '/nhk16/audio/20170823114821.opus'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final sources = await AnkiAudioService(client: client)
          .resolveTermAudioSources(
            term: '上手',
            reading: 'じょうず',
            preferences: const AnkiAudioPreferences(
              enabled: true,
              sourceType: AnkiAudioSourceType.customJson,
              url: 'http://localhost:5050/?term={term}&reading={reading}',
              timeout: Duration(seconds: 1),
              language: 'ja',
            ),
          );

      expect(sources, hasLength(1));
      expect(sources.single.name, 'nhk16');
      expect(
        sources.single.url.toString(),
        'http://localhost:5050/nhk16/audio/20170823114821.opus',
      );
    },
  );
}

class _DelayedCloseAwareClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(Duration.zero);
    if (closed) {
      throw http.ClientException('Client is already closed.', request.url);
    }
    if (request.url.path.isEmpty || request.url.path == '/') {
      return _streamedResponse(
        utf8.encode(
          jsonEncode({
            'type': 'audioSourceList',
            'audioSources': [
              {'name': 'local', 'url': '/audio/食べる.mp3'},
            ],
          }),
        ),
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.pathSegments.isNotEmpty &&
        request.url.pathSegments.last == '食べる.mp3') {
      return _streamedResponse(
        [0x49, 0x44, 0x33, 0x04],
        headers: {'content-type': 'audio/mpeg'},
      );
    }
    return _streamedResponse(utf8.encode('not found'), statusCode: 404);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

http.StreamedResponse _streamedResponse(
  List<int> bytes, {
  int statusCode = 200,
  Map<String, String>? headers,
}) {
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    statusCode,
    headers: headers ?? const {},
  );
}
