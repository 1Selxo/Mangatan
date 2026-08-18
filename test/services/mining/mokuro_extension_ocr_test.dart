import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/mining/mokuro_extension_ocr.dart';

void main() {
  setUp(MokuroExtensionOcrClient.clearCache);
  tearDown(MokuroExtensionOcrClient.clearCache);

  test('builds a Mokuro volume URL from the extension chapter URL', () {
    final uri = MokuroExtensionOcrClient.volumeUri(
      sourceName: 'mokuro',
      chapterUrl: 'series/folder|Volume #1',
    );

    expect(
      uri.toString(),
      'https://mokuro.moe/mokuro-reader/series%2Ffolder/Volume%20%231.mokuro',
    );
    expect(
      MokuroExtensionOcrClient.volumeUri(
        sourceName: 'Another source',
        chapterUrl: 'series|volume',
      ),
      isNull,
    );
    expect(
      MokuroExtensionOcrClient.volumeUri(
        sourceName: 'Mokuro',
        chapterUrl: 'missing-separator',
      ),
      isNull,
    );
  });

  test('fetches saved OCR with the catalog referer', () async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return _volumeResponse();
    });
    final loader = MokuroExtensionOcrClient(client: client);

    final document = await loader.fetchDocument(
      sourceName: 'Mokuro',
      chapterUrl: 'example|volume-1',
    );

    expect(request.headers['Referer'], MokuroExtensionOcrClient.catalogUrl);
    expect(document?.bytes, utf8.encode(jsonEncode(_volumeJson)));
    expect(document?.volume.pages, hasLength(1));
    expect(document?.volume.pages.single.blocks.single.lines, ['日本語']);
  });

  test('shares one saved OCR request between concurrent page loads', () async {
    var requests = 0;
    final loadingEvents = <bool>[];
    final client = MockClient((_) async {
      requests++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _volumeResponse();
    });
    final loader = MokuroExtensionOcrClient(client: client);

    final volumes = await Future.wait([
      loader.fetchVolume(
        sourceName: 'Mokuro',
        chapterUrl: 'example|volume-1',
        onLoadingChanged: loadingEvents.add,
      ),
      loader.fetchVolume(sourceName: 'Mokuro', chapterUrl: 'example|volume-1'),
    ]);

    expect(requests, 1);
    expect(loadingEvents, [true, false]);
    expect(volumes.every((volume) => volume != null), isTrue);
  });

  test('treats unavailable or invalid saved OCR as a retryable miss', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return requests == 1
          ? http.Response('not found', 404)
          : http.Response('{not json', 200);
    });
    final loader = MokuroExtensionOcrClient(client: client);

    expect(
      await loader.fetchVolume(
        sourceName: 'Mokuro',
        chapterUrl: 'example|volume-1',
      ),
      isNull,
    );
    expect(
      await loader.fetchVolume(
        sourceName: 'Mokuro',
        chapterUrl: 'example|volume-1',
      ),
      isNull,
    );
    expect(requests, 2);
  });
}

const _volumeJson = {
  'title': 'Example',
  'volume': '1',
  'pages': [
    {
      'img_path': '001.jpg',
      'img_width': 1000,
      'img_height': 1600,
      'blocks': [
        {
          'box': [100, 200, 300, 500],
          'vertical': true,
          'lines': ['日本語'],
          'lines_coords': [],
        },
      ],
    },
  ],
};

http.Response _volumeResponse() => http.Response.bytes(
  utf8.encode(jsonEncode(_volumeJson)),
  200,
  headers: const {'content-type': 'application/octet-stream'},
);
