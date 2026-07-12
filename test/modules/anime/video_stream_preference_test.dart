import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/video.dart';
import 'package:mangayomi/modules/anime/utils/video_stream_preference.dart';

void main() {
  final videos = [
    Video('a', 'VidPlay-1 - Sub - 1080p', 'a'),
    Video('b', 'VidPlay-1 - Sub - 720p', 'b'),
    Video('c', 'VidCloud-1 - Sub - 720p', 'c'),
    Video('d', 'VidPlay-1 - Dub - 720p', 'd'),
  ];

  test('restores the exact server, variant, and quality', () {
    expect(
      preferredVideoStream(videos, 'VidPlay-1 - Sub - 720p').url,
      'b',
    );
  });

  test('prefers the same server and variant when quality is unavailable', () {
    expect(
      preferredVideoStream(videos, 'VidPlay-1 - Sub - 480p').url,
      'b',
    );
  });

  test('does not switch from subtitles to a dub for matching quality', () {
    expect(
      preferredVideoStream(videos, 'VidCloud-1 - Sub - 1080p').url,
      'c',
    );
  });
}
