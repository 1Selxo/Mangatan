import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/page.dart';
import 'package:mangayomi/services/download_manager/download_isolate_pool.dart';

void main() {
  // Exercise transport retries with a media-sized payload: Mangatan rejects
  // tiny/error responses before declaring a video download complete.
  final video = List<int>.generate(64 * 1024, (index) => index & 0xff);
  video.setRange(0, 12, [0, 0, 0, 24, 102, 116, 121, 112, 105, 115, 111, 109]);
  const interruptedAt = 4096;
  for (final honorsRange in [true, false]) {
    test('interrupted video retry, honors range: $honorsRange', () async {
      final dir = await Directory.systemTemp.createTemp('video_retry');
      final port = ReceivePort();
      addTearDown(port.close);
      addTearDown(() => dir.delete(recursive: true));
      var attempts = 0;
      final client = MockClient.streaming((request, _) async {
        attempts++;
        if (attempts == 1) {
          return http.StreamedResponse(
            () async* {
              yield video.sublist(0, interruptedAt);
              throw http.ClientException('connection interrupted');
            }(),
            200,
            contentLength: video.length,
            headers: {'etag': '"video-v1"'},
          );
        }
        expect(request.headers['range'], 'bytes=$interruptedAt-');
        expect(request.headers['if-range'], '"video-v1"');
        return http.StreamedResponse(
          Stream.value(honorsRange ? video.sublist(interruptedAt) : video),
          honorsRange ? 206 : 200,
          contentLength: honorsRange
              ? video.length - interruptedAt
              : video.length,
          headers: {
            'etag': '"video-v1"',
            if (honorsRange)
              'content-range':
                  'bytes $interruptedAt-${video.length - 1}/${video.length}',
          },
        );
      });
      addTearDown(client.close);
      final file = File('${dir.path}/video.mp4');
      await downloadFile(
        PageUrl('https://example.com/video', fileName: file.path),
        client,
        ItemType.anime,
        port.sendPort,
      );
      expect(attempts, 2);
      expect(await file.readAsBytes(), video);
    });
  }

  test('short video body is retried rather than marked complete', () async {
    final dir = await Directory.systemTemp.createTemp('video_retry');
    final port = ReceivePort();
    addTearDown(port.close);
    addTearDown(() => dir.delete(recursive: true));
    var attempts = 0;
    final client = MockClient.streaming((request, _) async {
      attempts++;
      return http.StreamedResponse(
        Stream.value(attempts == 1 ? video.sublist(0, interruptedAt) : video),
        200,
        contentLength: video.length,
      );
    });
    addTearDown(client.close);
    final file = File('${dir.path}/video.mp4');
    await downloadFile(
      PageUrl('https://example.com/video', fileName: file.path),
      client,
      ItemType.anime,
      port.sendPort,
    );
    expect(attempts, 2);
    expect(await file.readAsBytes(), video);
  });
}
