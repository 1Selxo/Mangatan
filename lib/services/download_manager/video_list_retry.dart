import 'dart:async';

/// Resolves an extension video list without treating a slow extractor as a
/// permanently failed download.
///
/// Anime extensions can perform multiple network requests (and sometimes a
/// Cloudflare challenge) before returning a stream. Keep each attempt bounded,
/// but retry transient failures with the same 2/4 second backoff used by
/// Anikku's downloader. [beforeRetry] lets Riverpod callers discard a failed
/// provider so the next attempt performs fresh source extraction.
Future<T> resolveVideoListWithRetry<T>({
  required Future<T> Function() resolve,
  FutureOr<void> Function()? beforeRetry,
  Duration attemptTimeout = const Duration(minutes: 2),
  int maxAttempts = 3,
  Future<void> Function(Duration delay)? wait,
}) async {
  if (maxAttempts < 1) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
  }

  Object? lastError;
  StackTrace? lastStackTrace;
  final delayFor = wait ?? Future<void>.delayed;

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await resolve().timeout(attemptTimeout);
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      if (attempt + 1 >= maxAttempts) break;

      await beforeRetry?.call();
      await delayFor(Duration(seconds: 2 << attempt));
    }
  }

  Error.throwWithStackTrace(lastError!, lastStackTrace!);
}
