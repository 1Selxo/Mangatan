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
