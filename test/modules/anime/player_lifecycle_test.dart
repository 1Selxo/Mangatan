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

  test('Windows uses the GPU texture only when opted in', () {
    expect(
      shouldUseHardwareAcceleratedVideoOutput(
        userEnabled: true,
        isWindows: true,
        windowsGpuOptIn: true,
      ),
      isTrue,
    );
    expect(
      shouldUseHardwareAcceleratedVideoOutput(
        userEnabled: false,
        isWindows: true,
        windowsGpuOptIn: true,
      ),
      isFalse,
    );
  });

  test('shaders need both the mpv config and the GPU output', () {
    expect(
      playerShadersAvailable(useMpvConfig: true, gpuVideoOutput: true),
      isTrue,
    );
    expect(
      playerShadersAvailable(useMpvConfig: true, gpuVideoOutput: false),
      isFalse,
    );
    expect(
      playerShadersAvailable(useMpvConfig: false, gpuVideoOutput: true),
      isFalse,
    );
  });

  test('desktop hides the shader presets its renderer cannot run', () {
    for (final isLinux in [true, false]) {
      expect(
        desktopShaderPresetSupported('set_anime_a', isLinux: isLinux),
        isTrue,
      );
      expect(desktopShaderPresetSupported('set_fsr', isLinux: isLinux), isTrue);
      expect(
        desktopShaderPresetSupported('set_luma', isLinux: isLinux),
        isFalse,
      );
      expect(
        desktopShaderPresetSupported('set_snapdragon', isLinux: isLinux),
        isFalse,
      );
    }
    expect(desktopShaderPresetSupported('set_nvidia', isLinux: true), isTrue);
    expect(desktopShaderPresetSupported('set_nvidia', isLinux: false), isFalse);
  });

  test('scaled output keeps the video shape and fits the screen', () {
    // A 720p video in a 1920x1080 window at 1x: scaled up to the window,
    // so an x2 upscaling shader sees a larger output than the source.
    expect(
      scaledVideoOutputSize(
        videoWidth: 1280,
        videoHeight: 720,
        logicalWidth: 1920,
        logicalHeight: 1080,
        devicePixelRatio: 1,
        cover: false,
      ),
      (width: 1920, height: 1080),
    );
    // A 4:3 video in a wide window: contained by height, covered by width.
    expect(
      scaledVideoOutputSize(
        videoWidth: 640,
        videoHeight: 480,
        logicalWidth: 1600,
        logicalHeight: 900,
        devicePixelRatio: 1,
        cover: false,
      ),
      (width: 1200, height: 900),
    );
    expect(
      scaledVideoOutputSize(
        videoWidth: 640,
        videoHeight: 480,
        logicalWidth: 1600,
        logicalHeight: 900,
        devicePixelRatio: 1,
        cover: true,
      ),
      (width: 1600, height: 1200),
    );
  });

  test('scaled output waits for the video size', () {
    expect(
      scaledVideoOutputSize(
        videoWidth: 0,
        videoHeight: 0,
        logicalWidth: 1920,
        logicalHeight: 1080,
        devicePixelRatio: 1,
        cover: false,
      ),
      isNull,
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
