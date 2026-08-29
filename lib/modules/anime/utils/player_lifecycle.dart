/// Cancels every player listener before releasing the native player.
///
/// `Player.dispose()` already stops playback. Starting `Player.stop()` and
/// `Player.dispose()` at the same time races media_kit's native lock and can
/// terminate desktop builds while a route is being popped.
Future<void> disposePlaybackSession({
  required Iterable<Future<void>> listenerCancellations,
  required Future<void> Function() disposePlayer,
}) async {
  try {
    await Future.wait(listenerCancellations);
  } finally {
    await disposePlayer();
  }
}
