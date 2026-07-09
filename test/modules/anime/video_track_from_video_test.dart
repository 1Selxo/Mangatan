import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/video.dart';
import 'package:mangayomi/modules/anime/utils/video_track_from_video.dart';

void main() {
  test('video track opens the playable stream url', () {
    final video = Video(
      'https://cdn.example/episode/master.m3u8',
      '1080p',
      'https://source.example/watch/episode',
    );

    final track = videoTrackFromVideo(video);

    expect(track.id, 'https://cdn.example/episode/master.m3u8');
    expect(track.title, '1080p');
    expect(track.id, isNot(video.originalUrl));
  });
}
