import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/mining/anki_audio_service.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

void main() {
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
}
