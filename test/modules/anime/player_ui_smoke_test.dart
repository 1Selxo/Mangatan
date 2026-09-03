import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/anime_player_view.dart';

void main() {
  test('anime player route preserves its episode id', () {
    const view = AnimePlayerView(episodeId: 42);

    expect(view.episodeId, 42);
  });
}
