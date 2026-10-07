import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/eval/mihon/service.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';

void main() {
  // DataBody at tool/mihon_server_commit.txt's pinned server revision. Jackson
  // rejects extra fields before an extension method can run.
  const supportedFields = {
    'data',
    'extensionId',
    'method',
    'page',
    'search',
    'filterList',
    'mangaData',
    'chapterData',
    'animeData',
    'episodeData',
    'preferences',
  };
  const realSourceId = '7066619062139039107';

  for (final itemType in [ItemType.manga, ItemType.anime]) {
    test('$itemType requests match the strict APKBridge schema', () async {
      final methods = <String>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final unsupported = body.keys.toSet().difference(supportedFields);
        if (unsupported.isNotEmpty) {
          return http.Response(
            'Unrecognized field "${unsupported.first}"',
            500,
          );
        }
        final preferences = body['preferences'] as List;
        final context = preferences.cast<Map<String, dynamic>>().singleWhere(
          (entry) => entry['key'] == mihonBridgeContextKey,
        );
        expect(context['sourceId'], realSourceId);
        expect(request.headers['source-base-url'], 'https://source.example');
        final method = body['method'] as String;
        methods.add(method);
        Object response = <Object>[];
        if (method.startsWith('getPopular') ||
            method.startsWith('getLatest') ||
            method.startsWith('getSearch')) {
          response = {
            itemType == ItemType.anime ? 'animes' : 'mangas': [],
            'hasNextPage': false,
          };
        } else if (method.startsWith('getDetails')) {
          response = {'title': 'Series', 'url': '/series', 'fetch_type': 1};
        } else if (method == 'getChapterUrl' || method == 'getEpisodeUrl') {
          response = 'https://source.example/chapter';
        }
        return http.Response(jsonEncode(response), 200);
      });
      addTearDown(client.close);
      final service = MihonExtensionService(
        Source(
          id: 1729, // Local database ID is not the JVM source ID.
          lang: 'en',
          itemType: itemType,
          sourceCode: 'extension-package',
          baseUrl: 'https://source.example',
          additionalParams: encodeMihonSourceMetadata(
            sourceId: realSourceId,
            packageName: 'extension.package',
          ),
        ),
        'http://127.0.0.1:55741',
        client: client,
        requestHeaders: const {},
      );

      await service.getPopular(1);
      await service.getLatestUpdates(1);
      await service.search('series', 1, []);
      await service.getDetail('/series');
      await service.getChapterWebViewUrl(
        Chapter(mangaId: 1, url: '/chapter', name: 'Chapter 1'),
      );
      if (itemType == ItemType.manga) {
        await service.getPageList('/chapter');
        expect(methods, contains('getPageList'));
      } else {
        await service.getVideoList('/episode');
        await service.getSeasonList({'url': '/series'});
        expect(methods, contains('getVideoList'));
        expect(methods, contains('getSeasonList'));
      }
      expect(methods.length, greaterThanOrEqualTo(7));
    });
  }
}
