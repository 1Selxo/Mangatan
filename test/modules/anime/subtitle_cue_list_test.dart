import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/widgets/subtitle_cue_list.dart';

void main() {
  group('subtitle delay snapping', () {
    const cues = [
      AnimeSubtitleCue(
        index: 0,
        text: 'first',
        start: Duration(seconds: 5),
        end: Duration(seconds: 6),
      ),
      AnimeSubtitleCue(
        index: 1,
        text: 'second',
        start: Duration(seconds: 10),
        end: Duration(seconds: 11),
      ),
      AnimeSubtitleCue(
        index: 2,
        text: 'third',
        start: Duration(seconds: 15),
        end: Duration(seconds: 16),
      ),
    ];

    test('aligns the next subtitle start to playback', () {
      expect(
        subtitleDelayForAdjacentCue(
          cues: cues,
          playbackPosition: const Duration(seconds: 12),
          currentDelayMs: 2000,
          next: true,
        ),
        -3000,
      );
    });

    test('aligns the previous subtitle start to playback', () {
      expect(
        subtitleDelayForAdjacentCue(
          cues: cues,
          playbackPosition: const Duration(seconds: 12),
          currentDelayMs: 2000,
          next: false,
        ),
        7000,
      );
    });

    test('returns null at either end of the subtitle list', () {
      expect(
        subtitleDelayForAdjacentCue(
          cues: cues,
          playbackPosition: const Duration(seconds: 5),
          currentDelayMs: 0,
          next: false,
        ),
        isNull,
      );
    });
  });

  test('parses and orders SRT cues for the subtitle side list', () {
    final cues = parseAnimeSubtitleContent('episode.srt', '''
1
00:00:01,200 --> 00:00:03,000
最初の字幕

2
00:00:04,500 --> 00:00:06,000
二番目の字幕
''');

    expect(cues, hasLength(2));
    expect(cues.first.text, '最初の字幕');
    expect(cues.first.start, const Duration(milliseconds: 1200));
    expect(cues.last.text, '二番目の字幕');
    expect(cues.last.contains(const Duration(seconds: 5)), isTrue);
  });

  test('parses ASS dialogue and removes style tags', () {
    final cues = parseAnimeSubtitleContent('episode.ass', '''
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:02.00,0:00:04.50,Default,,0,0,0,,{\\i1}字幕\\N二行目
''');

    expect(cues, hasLength(1));
    expect(cues.single.text, '字幕\n二行目');
    expect(cues.single.end, const Duration(milliseconds: 4500));
  });
}
