import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/eval/mihon/service.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';

void main() {
  test('resolves bridge image proxies against the configured server', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode([
          {
            'index': 0,
            'url': '',
            'imageUrl': 'http://127.0.0.1:8080/image/mangakuro-token',
          },
          {'index': 1, 'url': '', 'imageUrl': 'https://cdn.example/002.jpg'},
        ]),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final service = MihonExtensionService(
      Source(itemType: ItemType.manga, sourceCode: 'extension-package'),
      'http://192.168.2.112:8080',
      client: client,
      requestHeaders: const {},
    );

    final pages = await service.getPageList('/chapter/1');

    expect(pages.first.url, 'http://192.168.2.112:8080/image/mangakuro-token');
    expect(pages.last.url, 'https://cdn.example/002.jpg');
  });
}
