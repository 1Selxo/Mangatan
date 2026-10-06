import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/eval/mihon/service.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';

void main() {
  test('season parents fetch seasons; leaf entries fetch episodes', () async {
    final methods = <String>[];
    final service = MihonExtensionService(
      Source(itemType: ItemType.anime, sourceCode: 'apk'),
      'https://bridge.example',
      requestHeaders: {},
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final method = body['method'] as String;
        methods.add(method);
        final url = (body['animeData'] as Map)['url'];
        return http.Response(
          jsonEncode(switch (method) {
            'getDetailsAnime' => {
              'url': url,
              'title': 'Series',
              'fetch_type': url == '/series' ? 'Seasons' : 'Episodes',
            },
            'getSeasonList' => [
              {
                'url': '/season',
                'title': 'Season 1',
                'season_number': 1,
                'fetch_type': 'Episodes',
              },
            ],
            'getEpisodeList' => [
              {
                'url': '/episode',
                'name': 'Episode 1',
                'episode_number': 1,
                'summary': 'Synopsis',
                'preview_url': 'https://images.example/1.jpg',
                'fillermark': true,
              },
            ],
            _ => throw StateError(method),
          }),
          200,
        );
      }),
    );
    final parent = await service.getDetail('/series');
    expect(methods, ['getDetailsAnime', 'getSeasonList']);
    expect(parent.seasons!.single.seasonNumber, 1);
    expect(parent.chapters, isEmpty);
    final season = await service.getDetail('/season');
    expect(methods.last, 'getEpisodeList');
    expect(season.chapters!.single.description, 'Synopsis');
    expect(season.chapters!.single.isFiller, true);
  });

  test('legacy anime without fetch type still requests episodes', () async {
    final service = MihonExtensionService(
      Source(itemType: ItemType.anime, sourceCode: 'apk'),
      'https://bridge.example',
      requestHeaders: {},
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            jsonDecode(request.body)['method'] == 'getDetailsAnime'
                ? {'url': '/series', 'title': 'Series'}
                : <Object>[],
          ),
          200,
        ),
      ),
    );
    final result = await service.getDetail('/series');
    expect(result.animeFetchType, isNull);
    expect(result.seasons, isNull);
  });
}
