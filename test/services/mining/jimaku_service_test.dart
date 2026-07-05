import 'package:flutter_test/flutter_test.dart';
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
}
