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
              yield [1, 2];
              throw http.ClientException('connection interrupted');
            }(),
            200,
            contentLength: 4,
            headers: {'etag': '"video-v1"'},
          );
        }
        expect(request.headers['range'], 'bytes=2-');
        expect(request.headers['if-range'], '"video-v1"');
        return http.StreamedResponse(
          Stream.value(honorsRange ? [3, 4] : [1, 2, 3, 4]),
          honorsRange ? 206 : 200,
          contentLength: honorsRange ? 2 : 4,
          headers: {
            'etag': '"video-v1"',
            if (honorsRange) 'content-range': 'bytes 2-3/4',
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
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
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
        Stream.value(attempts == 1 ? [1] : [1, 2]),
        200,
        contentLength: 2,
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
    expect(await file.readAsBytes(), [1, 2]);
  });
}
