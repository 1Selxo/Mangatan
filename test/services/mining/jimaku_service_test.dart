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

  test('does not strip a title ending in the letter e', () {
    final candidates = buildJimakuSearchCandidates(
      values: const ['One Piece Episode 280'],
    );

    expect(candidates, isNotEmpty);
    expect(candidates.first.query, 'One Piece');
    expect(candidates.first.guess.title, 'One Piece');
    expect(candidates.first.guess.episode, 280);
  });

  test('matches absolute One Piece episodes in season-numbered files', () {
    const fileName =
        'ワンピース.S03E051.第279話 滝に向かって飛べ！！ルフィの想い!!'
        'WEBRip.Amazon.ja-jp.srt';
    final parsed = guessJimakuMedia(fileName);
    final files = [
      JimakuFile(
        url: Uri.parse('https://jimaku.cc/files/one-piece-279.srt'),
        name: fileName,
        size: 32380,
        lastModified: '',
      ),
    ];

    expect(parsed?.episode, 279);
    expect(parsed?.episodeCandidates, containsAll(<int>{51, 279}));
    expect(
      files.matchedSubtitleFiles(
        const JimakuMediaGuess(
          title: 'One Piece',
          episode: 51,
          episodeCandidates: {51, 279},
        ),
        episodeFiltered: false,
      ),
      hasLength(1),
    );
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
