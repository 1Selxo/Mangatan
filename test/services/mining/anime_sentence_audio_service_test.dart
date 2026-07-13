import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/anime_sentence_audio_service.dart';
import 'package:mangayomi/services/mining/mining_models.dart';

void main() {
  test('uses the displayed subtitle cue with IINAtan-style padding', () {
    final timing = subtitleAudioTimingForCue(
      subtitleStart: const Duration(seconds: 10, milliseconds: 200),
      subtitleEnd: const Duration(seconds: 11, milliseconds: 400),
      currentPosition: const Duration(seconds: 11),
    );

    expect(timing.start, const Duration(seconds: 9, milliseconds: 950));
    expect(timing.end, const Duration(seconds: 11, milliseconds: 650));
  });

  test('applies the active subtitle delay to sentence audio timing', () {
    final timing = subtitleAudioTimingForCue(
      subtitleStart: const Duration(seconds: 85),
      subtitleEnd: const Duration(seconds: 87),
      currentPosition: const Duration(seconds: 244),
      subtitleDelay: const Duration(seconds: 158),
    );

    expect(timing.start, const Duration(seconds: 242, milliseconds: 750));
    expect(timing.end, const Duration(seconds: 245, milliseconds: 250));
  });

  test(
    'uses a bounded current-position fallback when cue timing is absent',
    () {
      final timing = subtitleAudioTimingForCue(
        currentPosition: const Duration(seconds: 5),
      );

      expect(timing.start, const Duration(seconds: 3, milliseconds: 250));
      expect(timing.end, const Duration(seconds: 7, milliseconds: 750));
    },
  );

  test('bounds long cue captures and forwards request headers to ffmpeg', () {
    final timing = subtitleAudioTimingForCue(
      subtitleStart: Duration.zero,
      subtitleEnd: const Duration(seconds: 80),
      currentPosition: const Duration(seconds: 2),
    );
    final args = sentenceAudioFfmpegArguments(
      source: 'https://video.example/playlist.m3u8',
      headers: const {
        'Referer': 'https://example.com',
        'User-Agent': 'Mangatan',
      },
      timing: timing,
      format: AnkiSentenceAudioFormat.mp3,
      outputPath: '/tmp/sentence.mp3',
    );

    expect(timing.duration, const Duration(seconds: 35));
    expect(
      args,
      containsAllInOrder([
        '-allowed_extensions',
        'ALL',
        '-allowed_segment_extensions',
        'ALL',
        '-extension_picky',
        '0',
        '-headers',
        'Referer: https://example.com\r\nUser-Agent: Mangatan\r\n',
      ]),
    );
    expect(
      args,
      containsAllInOrder([
        '-ss',
        '0.000',
        '-i',
        'https://video.example/playlist.m3u8',
      ]),
    );
    expect(
      args,
      containsAllInOrder(['-map', '0:a:0', '-codec:a', 'libmp3lame']),
    );
  });

  test('uses the Opus encoder and extension when configured', () {
    final args = sentenceAudioFfmpegArguments(
      source: 'file:///episode.mkv',
      timing: const SubtitleAudioTiming(
        start: Duration(seconds: 5),
        end: Duration(seconds: 7),
      ),
      format: AnkiSentenceAudioFormat.opus,
      outputPath: '/tmp/sentence.opus',
    );

    expect(args, containsAllInOrder(['-codec:a', 'libopus', '-b:a', '96k']));
    expect(args.last, '/tmp/sentence.opus');
  });

  test('permits extensionless HLS proxy segments only for HLS inputs', () {
    final timing = const SubtitleAudioTiming(
      start: Duration.zero,
      end: Duration(seconds: 1),
    );
    final proxyArgs = sentenceAudioFfmpegArguments(
      source: 'http://localhost:53858/m3u8?url=https%3A%2F%2Fvideo.example',
      timing: timing,
      format: AnkiSentenceAudioFormat.mp3,
      outputPath: '/tmp/sentence.mp3',
    );
    final fileArgs = sentenceAudioFfmpegArguments(
      source: 'file:///episode.mkv',
      timing: timing,
      format: AnkiSentenceAudioFormat.mp3,
      outputPath: '/tmp/sentence.mp3',
    );

    expect(
      proxyArgs,
      containsAllInOrder([
        '-allowed_extensions',
        'ALL',
        '-allowed_segment_extensions',
        'ALL',
        '-extension_picky',
        '0',
      ]),
    );
    expect(fileArgs, isNot(contains('-allowed_extensions')));
    expect(
      proxyArgs.indexOf('-ss'),
      lessThan(
        proxyArgs.indexOf(
          'http://localhost:53858/m3u8?url=https%3A%2F%2Fvideo.example',
        ),
      ),
    );
    expect(
      fileArgs.indexOf('-ss'),
      lessThan(fileArgs.indexOf('file:///episode.mkv')),
    );
  });
}
