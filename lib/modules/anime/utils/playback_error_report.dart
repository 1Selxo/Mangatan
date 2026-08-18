/// Pure decision helpers for surfacing local/remote video playback errors.
///
/// media_kit's player only exposes failures through `player.stream.error`.
/// Before this logic existed, local playback failures on Windows (a corrupted
/// UNC path, a missing `libmpv-2.dll`, an unsupported codec) produced a black
/// or frozen player with no message, making bug reports impossible to triage
/// (issue #72, Finding 2). These helpers isolate the two pure decisions the
/// player's error handler makes so they can be regression-tested without a
/// widget harness or static-toast mocking:
///
///  * whether a given error should surface at all, and
///  * how the message is formatted for the on-screen toast.
library;

/// The window during which an identical error is treated as a duplicate and
/// suppressed, so a single failing open does not spam repeated toasts.
const Duration playbackErrorDedupeWindow = Duration(seconds: 3);

/// The maximum length of a playback-error toast before it is truncated.
const int playbackErrorToastMaxLength = 240;

/// Formats a playback-error message for display in a toast: trims surrounding
/// whitespace and truncates overly long messages with a trailing ellipsis.
String formatPlaybackErrorToast(String message) {
  final trimmed = message.trim();
  if (trimmed.length <= playbackErrorToastMaxLength) {
    return trimmed;
  }
  return '${trimmed.substring(0, playbackErrorToastMaxLength - 3)}...';
}

/// Decides whether a playback error should be surfaced to the user.
///
/// Returns `false` for empty/whitespace-only messages and for a message
/// identical to the last reported one within [playbackErrorDedupeWindow];
/// otherwise `true`.
bool shouldReportPlaybackError({
  required String message,
  required String? lastMessage,
  required DateTime? lastReportedAt,
  required DateTime now,
}) {
  if (message.trim().isEmpty) {
    return false;
  }
  final isDuplicate =
      message == lastMessage &&
      lastReportedAt != null &&
      now.difference(lastReportedAt) < playbackErrorDedupeWindow;
  return !isDuplicate;
}
