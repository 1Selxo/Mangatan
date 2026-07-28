import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/eval/mihon/service.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';

void main() {
  test('resolves bridge video and track proxies against the server', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode([
          {
            'url': 'https://origin.example/embed/1',
            'quality': '1080p',
            'videoUrl': 'http://127.0.0.1:8080/video/master-token',
            'headers': {
              r'namesAndValues$okhttp': ['Referer', 'https://origin.example/'],
            },
            'audioTracks': [
              {
                'url': 'http://localhost:8080/video/audio-token',
                'lang': 'Japanese',
              },
            ],
            'subtitleTracks': [
              {
                'url': 'http://[::1]:8080/video/subtitle-token',
                'lang': 'English',
              },
            ],
          },
        ]),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final service = MihonExtensionService(
      Source(itemType: ItemType.anime, sourceCode: 'extension-package'),
      'http://192.168.2.112:8080',
      client: client,
      requestHeaders: const {},
    );

    final videos = await service.getVideoList('/episode/1');
    final video = videos.single;

    expect(video.url, 'http://192.168.2.112:8080/video/master-token');
    expect(video.originalUrl, 'https://origin.example/embed/1');
    expect(video.headers?['Referer'], 'https://origin.example/');
    expect(
      video.audios?.single.file,
      'http://192.168.2.112:8080/video/audio-token',
    );
    expect(
      video.subtitles?.single.file,
      'http://192.168.2.112:8080/video/subtitle-token',
    );
  });
}
