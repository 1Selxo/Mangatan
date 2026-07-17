import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/eval/mihon/service.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';

void main() {
  test('preserves a chapter number supplied by a Mihon extension', () async {
    final client = MockClient(
      (request) async => http.Response.bytes(
        utf8.encode(
          jsonEncode([
            {
              'name': '[水谷フーカ] 14歳の恋 第12巻',
              'url': '14-sai|volume-12',
              'date_upload': 0,
              'scanlator': null,
              'chapter_number': 12.0,
            },
          ]),
        ),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final service = MihonExtensionService(
      Source(itemType: ItemType.manga, sourceCode: 'extension-package'),
      'https://bridge.example.test',
      client: client,
      requestHeaders: const {},
    );

    final chapters = await service.getChapterList('/14-sai-no-koi');

    expect(chapters.single.chapterNumber, 12.0);
  });

  test('requests the extension-defined chapter WebView URL', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode('https://reader.example/volume/12'), 200);
    });
    final service = MihonExtensionService(
      Source(itemType: ItemType.manga, sourceCode: 'extension-package'),
      'https://bridge.example.test',
      client: client,
      requestHeaders: const {},
    );

    final url = await service.getChapterWebViewUrl(
      Chapter(
        mangaId: 1,
        name: 'Volume 12',
        url: '/volume/12',
        chapterNumber: 12,
      ),
    );

    expect(url, 'https://reader.example/volume/12');
    expect(requestBody['method'], 'getChapterUrl');
    expect(
      (requestBody['chapterData'] as Map<String, dynamic>)['chapter_number'],
      12,
    );
  });
}
