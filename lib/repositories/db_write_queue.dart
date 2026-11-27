import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

class DbWriteQueue {
  Future<void> _tail = Future.value();

  // Chains every write onto the same Future tail so none overlap in Isar's transaction lock.
  Future<T> run<T>(FutureOr<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Starts a fresh queue. For tests that run several app launches in one
  /// process: the last write of a previous launch belongs to a zone that never
  /// runs again, and chaining onto it would hold every later write forever.
  @visibleForTesting
  void reset() => _tail = Future.value();
}

// Only serializes the main isolate; isolate_service.dart's worker isar instance isn't covered.
final dbWriteQueue = DbWriteQueue();
