import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/scene_capture_timing.dart';

void main() {
  test('converts live subtitle clock to media time exactly once', () {
    final timing = resolveSubtitleSceneTiming(
      subtitleText: '事件だ',
      playbackPosition: const Duration(seconds: 22),
      mediaDuration: const Duration(minutes: 24),
      liveSubtitleStart: const Duration(seconds: 10),
      liveSubtitleEnd: const Duration(seconds: 12),
      subtitleSpeed: 2,
      subtitleDelay: const Duration(seconds: 1),
    );

    expect(timing.scene.start, const Duration(seconds: 21));
    expect(timing.scene.end, const Duration(seconds: 25));
    expect(timing.audio.start, const Duration(milliseconds: 20750));
    expect(timing.audio.end, const Duration(milliseconds: 25250));
  });

  test('uses the matching parsed cue when live endpoints are unavailable', () {
    final timing = resolveSubtitleSceneTiming(
      subtitleText: '同じ字幕',
      playbackPosition: const Duration(seconds: 42),
      mediaDuration: const Duration(minutes: 1),
      parsedCues: const [
        ParsedSubtitleTiming(
          text: '同じ字幕',
          start: Duration(seconds: 5),
          end: Duration(seconds: 7),
        ),
        ParsedSubtitleTiming(
          text: '同じ字幕',
          start: Duration(seconds: 41),
          end: Duration(seconds: 43),
        ),
      ],
    );

    expect(timing.scene.start, const Duration(seconds: 41));
    expect(timing.scene.end, const Duration(seconds: 43));
  });

  test('uses a one-second fallback and enforces timing bounds', () {
    final fallback = resolveSubtitleSceneTiming(
      subtitleText: 'missing',
      playbackPosition: const Duration(milliseconds: 600),
      mediaDuration: const Duration(seconds: 2),
    );
    expect(fallback.scene.start, const Duration(milliseconds: 100));
    expect(fallback.scene.end, const Duration(milliseconds: 1100));

    final bounded = resolveSubtitleSceneTiming(
      subtitleText: 'long',
      playbackPosition: const Duration(seconds: 5),
      mediaDuration: const Duration(minutes: 2),
      liveSubtitleStart: Duration.zero,
      liveSubtitleEnd: const Duration(seconds: 90),
    );
    expect(bounded.scene.duration, const Duration(seconds: 10));
    expect(bounded.audio.duration, const Duration(seconds: 30));
  });

  test('OCR capture uses configurable symmetric padding', () {
    final timing = resolveOcrSceneTiming(
      playbackPosition: const Duration(seconds: 5),
      mediaDuration: const Duration(seconds: 20),
    );
    expect(timing.scene.start, const Duration(seconds: 2));
    expect(timing.scene.end, const Duration(seconds: 8));

    final nearStart = resolveOcrSceneTiming(
      playbackPosition: const Duration(seconds: 1),
      mediaDuration: const Duration(seconds: 20),
      padding: const Duration(seconds: 3),
    );
    expect(nearStart.scene.start, Duration.zero);
    expect(nearStart.scene.end, const Duration(seconds: 4));
  });
}
