import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/mining/jimaku_service.dart';

void main() {
  test('builds GuessIt-like Jimaku candidates from season and episode text', () {
    final candidates = buildJimakuSearchCandidates(
      values: const [
        'Re:Zero kara Hajimeru Isekai Seikatsu 4th Season Ep. 7 - Walking out of the Convenience Store',
      ],
    );

    expect(candidates, isNotEmpty);
    expect(
      candidates.map((candidate) => candidate.query),
      contains('Re:Zero kara Hajimeru Isekai Seikatsu'),
    );
    expect(
      candidates.first.guess.title,
      'Re:Zero kara Hajimeru Isekai Seikatsu 4th Season',
    );
    expect(candidates.first.guess.season, 4);
    expect(candidates.first.guess.episode, 7);
  });

  test('removes dangling episode markers from Jimaku guesses', () {
    final guess = guessJimakuMedia('Example Anime Ep');

    expect(guess?.title, 'Example Anime');
  });

  test('downloads every matched Jimaku file', () async {
    final requested = <String>[];
    final service = JimakuSubtitleService(
      client: MockClient((request) async {
        requested.add(request.url.pathSegments.last);
        return http.Response('subtitle:${request.url.pathSegments.last}', 200);
      }),
    );
    final directory = await Directory.systemTemp.createTemp('jimaku-many-');
    addTearDown(() => directory.delete(recursive: true));
    final files = [
      JimakuFile(
        url: Uri.parse('https://jimaku.cc/files/episode-a.srt'),
        name: 'episode-a.srt',
        size: 10,
        lastModified: '',
      ),
      JimakuFile(
        url: Uri.parse('https://jimaku.cc/files/episode-b.ass'),
        name: 'episode-b.ass',
        size: 20,
        lastModified: '',
      ),
    ];

    final downloaded = await service.downloadFiles(
      apiKey: 'token',
      files: files,
      outputDirectory: directory,
    );

    expect(requested, ['episode-a.srt', 'episode-b.ass']);
    expect(downloaded.map((file) => file.path), hasLength(2));
    expect(await downloaded[0].readAsString(), 'subtitle:episode-a.srt');
    expect(await downloaded[1].readAsString(), 'subtitle:episode-b.ass');
  });
}
