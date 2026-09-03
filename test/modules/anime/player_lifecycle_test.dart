import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/utils/player_lifecycle.dart';

void main() {
  group('Windows playback surface lifecycle', () {
    test('retires the texture for hidden and suspended states', () {
      expect(
        shouldSuspendWindowsPlaybackSurface(AppLifecycleState.hidden),
        isTrue,
      );
      expect(
        shouldSuspendWindowsPlaybackSurface(AppLifecycleState.paused),
        isTrue,
      );
      expect(
        shouldSuspendWindowsPlaybackSurface(AppLifecycleState.detached),
        isTrue,
      );
      expect(
        shouldSuspendWindowsPlaybackSurface(AppLifecycleState.inactive),
        isFalse,
      );
    });

    test('recreates the texture only after resume', () {
      expect(
        shouldResumeWindowsPlaybackSurface(AppLifecycleState.resumed),
        isTrue,
      );
      expect(
        shouldResumeWindowsPlaybackSurface(AppLifecycleState.hidden),
        isFalse,
      );
    });
  });

  test('episode replacement preserves desktop fullscreen', () {
    expect(
      shouldExitDesktopFullscreenOnDispose(
        isDesktop: true,
        isFullscreen: true,
        isEpisodeReplacement: true,
      ),
      isFalse,
    );
  });

  test('leaving the player exits desktop fullscreen', () {
    expect(
      shouldExitDesktopFullscreenOnDispose(
        isDesktop: true,
        isFullscreen: true,
        isEpisodeReplacement: false,
      ),
      isTrue,
    );
  });

  test('Windows avoids the crashing GPU texture output', () {
    expect(
      shouldUseHardwareAcceleratedVideoOutput(
        userEnabled: true,
        isWindows: true,
      ),
      isFalse,
    );
  });

  test('other platforms honor the GPU texture preference', () {
    expect(
      shouldUseHardwareAcceleratedVideoOutput(
        userEnabled: true,
        isWindows: false,
      ),
      isTrue,
    );
    expect(
      shouldUseHardwareAcceleratedVideoOutput(
        userEnabled: false,
        isWindows: false,
      ),
      isFalse,
    );
  });

  test('Linux video output follows the physical viewport', () {
    expect(
      linuxVideoOutputSize(
        logicalWidth: 853,
        logicalHeight: 480,
        devicePixelRatio: 1.25,
      ),
      (width: 1068, height: 600),
    );
  });

  test('Linux video output rejects an unbounded viewport', () {
    expect(
      linuxVideoOutputSize(
        logicalWidth: double.infinity,
        logicalHeight: 480,
        devicePixelRatio: 1,
      ),
      isNull,
    );
  });

  test('surface is hidden before waiting for the raster thread', () async {
    final events = <String>[];

    await retirePlaybackSurface(
      hideSurface: () => events.add('hidden'),
      waitForFrame: () async => events.add('frame'),
      rasterDrainDelay: Duration.zero,
    );

    expect(events, ['hidden', 'frame']);
  });

  test('player disposal waits for every listener cancellation', () async {
    final firstCancellation = Completer<void>();
    final secondCancellation = Completer<void>();
    var disposeCalls = 0;

    final cleanup = disposePlaybackSession(
      listenerCancellations: [
        firstCancellation.future,
        secondCancellation.future,
      ],
      disposePlayer: () async {
        disposeCalls++;
      },
    );

    firstCancellation.complete();
    await Future<void>.delayed(Duration.zero);
    expect(disposeCalls, 0);

    secondCancellation.complete();
    await cleanup;
    expect(disposeCalls, 1);
  });

  test('player is still disposed when listener cancellation fails', () async {
    var disposeCalls = 0;

    await expectLater(
      disposePlaybackSession(
        listenerCancellations: [
          Future<void>.error(StateError('cancel failed')),
        ],
        disposePlayer: () async {
          disposeCalls++;
        },
      ),
      throwsStateError,
    );

    expect(disposeCalls, 1);
  });

  test('player disposal waits for platform texture cleanup', () async {
    final textureCleanup = Completer<void>();
    var disposeCalls = 0;

    final cleanup = disposePlaybackSession(
      listenerCancellations: const [],
      beforeDisposePlayer: () => textureCleanup.future,
      disposePlayer: () async {
        disposeCalls++;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(disposeCalls, 0);

    textureCleanup.complete();
    await cleanup;
    expect(disposeCalls, 1);
  });

  test(
    'player is still disposed when platform texture cleanup fails',
    () async {
      var disposeCalls = 0;

      await expectLater(
        disposePlaybackSession(
          listenerCancellations: const [],
          beforeDisposePlayer: () async => throw StateError('cleanup failed'),
          disposePlayer: () async {
            disposeCalls++;
          },
        ),
        throwsStateError,
      );

      expect(disposeCalls, 1);
    },
  );
}
