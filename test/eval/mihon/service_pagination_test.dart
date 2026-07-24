import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/eval/mihon/service.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';

void main() {
  group('Mihon catalogue pagination', () {
    for (final itemType in [ItemType.manga, ItemType.anime]) {
      test('forwards one-based $itemType pages without skipping', () async {
        final requests = <Map<String, dynamic>>[];
        final responseListKey = itemType == ItemType.anime
            ? 'animes'
            : 'mangas';
        final client = MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({responseListKey: [], 'hasNextPage': true}),
            200,
          );
        });
        final service = MihonExtensionService(
          Source(itemType: itemType, sourceCode: 'extension-package'),
          'https://bridge.example.test',
          client: client,
          requestHeaders: const {},
        );

        await service.getPopular(1);
        await service.getPopular(2);
        await service.getLatestUpdates(1);

        expect(requests.map((request) => request['page']), [1, 2, 1]);
        final suffix = itemType == ItemType.anime ? 'Anime' : 'Manga';
        expect(requests.map((request) => request['method']), [
          'getPopular$suffix',
          'getPopular$suffix',
          'getLatest$suffix',
        ]);
      });
    }
  });
}
