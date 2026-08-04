import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/utils/playback_error_report.dart';

void main() {
  group('formatPlaybackErrorToast', () {
    test('trims surrounding whitespace', () {
      expect(
        formatPlaybackErrorToast('   mpv: failed to open   '),
        'mpv: failed to open',
      );
    });

    test('returns short messages unchanged', () {
      final message = 'Failed to recognize file format.';
      expect(formatPlaybackErrorToast(message), message);
    });

    test('truncates messages longer than 240 chars with an ellipsis', () {
      final long = 'x' * 300;
      final result = formatPlaybackErrorToast(long);

      expect(result.length, 240);
      expect(result.endsWith('...'), isTrue);
      expect(result.substring(0, 237), 'x' * 237);
    });

    test('keeps a message of exactly 240 chars intact', () {
      final exact = 'y' * 240;
      expect(formatPlaybackErrorToast(exact), exact);
    });
  });

  group('shouldReportPlaybackError', () {
    final now = DateTime(2026, 1, 1, 12, 0, 0);

    test('suppresses an empty or whitespace-only error', () {
      expect(
        shouldReportPlaybackError(
          message: '   ',
          lastMessage: null,
          lastReportedAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('reports a fresh, non-empty error', () {
      expect(
        shouldReportPlaybackError(
          message: 'mpv: no such file',
          lastMessage: null,
          lastReportedAt: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('suppresses a duplicate error inside the 3s window', () {
      expect(
        shouldReportPlaybackError(
          message: 'mpv: no such file',
          lastMessage: 'mpv: no such file',
          lastReportedAt: now.subtract(const Duration(seconds: 2)),
          now: now,
        ),
        isFalse,
      );
    });

    test('reports the same error again once the 3s window has passed', () {
      expect(
        shouldReportPlaybackError(
          message: 'mpv: no such file',
          lastMessage: 'mpv: no such file',
          lastReportedAt: now.subtract(const Duration(seconds: 4)),
          now: now,
        ),
        isTrue,
      );
    });

    test('reports a distinct error even inside the window', () {
      expect(
        shouldReportPlaybackError(
          message: 'mpv: codec not supported',
          lastMessage: 'mpv: no such file',
          lastReportedAt: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
