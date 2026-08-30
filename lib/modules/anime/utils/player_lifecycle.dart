/// Cancels every player listener before releasing the native player.
///
/// `Player.dispose()` already stops playback. Starting `Player.stop()` and
/// `Player.dispose()` at the same time races media_kit's native lock and can
/// terminate desktop builds while a route is being popped.
Future<void> disposePlaybackSession({
  required Iterable<Future<void>> listenerCancellations,
  Future<void> Function()? beforeDisposePlayer,
  required Future<void> Function() disposePlayer,
}) async {
  try {
    await Future.wait(listenerCancellations);
  } finally {
    try {
      await beforeDisposePlayer?.call();
    } finally {
      await disposePlayer();
    }
  }
}

/// Removes a platform texture from Flutter's render tree and gives the raster
/// thread time to finish any frame that still refers to it.
Future<void> retirePlaybackSurface({
  required void Function() hideSurface,
  required Future<void> Function() waitForFrame,
  Duration rasterDrainDelay = const Duration(milliseconds: 100),
}) async {
  hideSurface();
  await waitForFrame();
  if (rasterDrainDelay > Duration.zero) {
    await Future<void>.delayed(rasterDrainDelay);
  }
}

/// Whether disposing the outer player route should leave desktop fullscreen.
///
/// Episode changes replace the route while continuing the same playback
/// session, so the outgoing route must not undo the window mode that the next
/// episode inherits.
bool shouldExitDesktopFullscreenOnDispose({
  required bool isDesktop,
  required bool isFullscreen,
  required bool isEpisodeReplacement,
}) => isDesktop && isFullscreen && !isEpisodeReplacement;

/// Whether media_kit should expose video through a GPU-backed Flutter texture.
///
/// Flutter's Windows embedder can lose its Skia graphics context while an
/// external texture is still being painted. media_kit's GPU output then calls
/// `GrDirectContext::flush` through a null context and terminates the process.
/// The pixel-buffer output avoids that engine path while leaving media decode
/// acceleration controlled independently by `hwdec`.
bool shouldUseHardwareAcceleratedVideoOutput({
  required bool userEnabled,
  required bool isWindows,
}) => userEnabled && !isWindows;
