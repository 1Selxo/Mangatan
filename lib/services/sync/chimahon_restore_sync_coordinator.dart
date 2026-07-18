import 'dart:async';

/// Serializes explicit backup restores with Chimahon synchronization.
///
/// The durable pending-restore phase protects process restarts. This gate
/// closes the smaller in-process race where sync could inspect that phase just
/// before a restore changes it to `preparing` and starts replacing local data.
class ChimahonRestoreSyncCoordinator {
  ChimahonRestoreSyncCoordinator();

  static final shared = ChimahonRestoreSyncCoordinator();

  Future<void> _tail = Future<void>.value();

  Future<T> duringManualRestore<T>(Future<T> Function() operation) =>
      _runExclusive(operation);

  Future<T> duringSync<T>(Future<T> Function() operation) =>
      _runExclusive(operation);

  Future<T> duringReadOnlyPreview<T>(Future<T> Function() operation) =>
      _runExclusive(operation);

  Future<T> _runExclusive<T>(Future<T> Function() operation) async {
    final predecessor = _tail;
    final release = Completer<void>();
    _tail = release.future;
    await predecessor.catchError((Object _) {
      // A failed operation still releases the next queued operation.
    });
    try {
      return await operation();
    } finally {
      release.complete();
    }
  }
}
