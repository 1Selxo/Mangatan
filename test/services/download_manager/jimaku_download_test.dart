import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/download_manager/jimaku_download.dart';
import 'package:mangayomi/services/mining/jimaku_service.dart';

void main() {
  test(
    'saves only matching episode subtitles to persistent offline sidecars',
    () async {
      final dir = await Directory.systemTemp.createTemp('jimaku-offline-test-');
      final service = JimakuSubtitleService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/search')) {
            expect(request.url.queryParameters['query'], 'One Piece');
            return http.Response(
              jsonEncode([
                {'id': 1, 'name': 'One Piece'},
              ]),
              200,
            );
          }
          if (request.url.path.endsWith('/files')) {
            expect(request.url.queryParameters['episode'], '316');
            return http.Response(
              jsonEncode([
                {
                  'url': 'https://example.com/316.srt',
                  'name': 'One Piece - 316.srt',
                },
                {
                  'url': 'https://example.com/317.srt',
                  'name': 'One Piece - 317.srt',
                },
              ]),
              200,
            );
          }
          expect(request.url.path, '/316.srt');
          return http.Response(
            '1\n00:00:01,000 --> 00:00:02,000\nHello\n',
            200,
          );
        }),
      );
      try {
        final files = await downloadJimakuSidecars(
          service: service,
          apiKey: 'test',
          guess: const JimakuMediaGuess(title: 'One Piece', episode: 316),
          chapterDirectory: '${dir.path}/episode316',
        );
        expect(files, hasLength(1));
        expect(
          files.single.parent.path,
          Directory('${dir.path}/episode316_subtitles').path,
        );
        expect(await files.single.readAsString(), contains('Hello'));
      } finally {
        service.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test('missing API key does not make requests', () async {
    final service = JimakuSubtitleService(
      client: MockClient((_) async => throw StateError('Unexpected request')),
    );
    try {
      expect(
        await downloadJimakuSidecars(
          service: service,
          apiKey: '',
          guess: const JimakuMediaGuess(title: 'One Piece', episode: 1),
          chapterDirectory: 'unused',
        ),
        isEmpty,
      );
    } finally {
      service.close();
    }
  });
}
