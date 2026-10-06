import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/download_manager/video_list_retry.dart';

void main() {
  test('retries extraction failures with exponential backoff', () async {
    var attempts = 0;
    var resets = 0;
    final delays = <Duration>[];

    final result = await resolveVideoListWithRetry(
      resolve: () async {
        attempts++;
        if (attempts < 3) throw StateError('temporary source failure');
        return 'video';
      },
      beforeRetry: () => resets++,
      wait: (delay) async => delays.add(delay),
    );

    expect(result, 'video');
    expect(attempts, 3);
    expect(resets, 2);
    expect(delays, const [Duration(seconds: 2), Duration(seconds: 4)]);
  });

  test('retries a timed-out extractor with a fresh provider', () async {
    var attempts = 0;
    var resets = 0;

    final result = await resolveVideoListWithRetry(
      resolve: () {
        attempts++;
        if (attempts == 1) return Completer<String>().future;
        return Future.value('recovered');
      },
      beforeRetry: () => resets++,
      attemptTimeout: const Duration(milliseconds: 5),
      wait: (_) async {},
    );

    expect(result, 'recovered');
    expect(attempts, 2);
    expect(resets, 1);
  });

  test('surfaces the final error after three attempts', () async {
    var attempts = 0;

    await expectLater(
      resolveVideoListWithRetry<void>(
        resolve: () async {
          attempts++;
          throw StateError('still broken');
        },
        wait: (_) async {},
      ),
      throwsA(isA<StateError>()),
    );

    expect(attempts, 3);
  });
}
