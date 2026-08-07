import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/utils/audio_track_label.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  test('formats embedded audio metadata in the IINA style', () {
    final track = AudioTrack(
      '4',
      'Surround 7.1',
      'fra',
      codec: 'eac3',
      channelscount: 8,
      samplerate: 48000,
    );

    expect(audioTrackLabel(track), '[French] Surround 7.1 eac3, 8ch, 48kHz');
  });

  test('does not repeat a title that is already the language name', () {
    final track = AudioTrack('7', 'Japanese', 'jpn');

    expect(audioTrackLabel(track), '[Japanese]');
  });

  test('keeps None and external tracks readable', () {
    expect(audioTrackLabel(AudioTrack.no()), 'None');
    expect(
      audioTrackLabel(
        AudioTrack.uri('https://example.com/audio', language: 'en'),
      ),
      '[English]',
    );
  });
}
