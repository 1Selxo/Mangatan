import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

enum OcrQueueStatus { pending, processing, completed, error }

typedef OcrQueueProgressCallback = void Function(int completed, int total);
typedef OcrQueueOperation = Future<void> Function(
  OcrQueueProgressCallback onProgress,
);

@immutable
class OcrQueueRequest {
  const OcrQueueRequest({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.operation,
  });

  final String id;
  final String title;
  final String subtitle;
  final OcrQueueOperation operation;
}

@immutable
class OcrQueueEntry {
  const OcrQueueEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    this.completed = 0,
    this.total = 0,
    this.attempt = 0,
    this.error,
  });

  final String id;
  final String title;
  final String subtitle;
  final OcrQueueStatus status;
  final int completed;
  final int total;
  final int attempt;
  final String? error;

  OcrQueueEntry copyWith({
    OcrQueueStatus? status,
    int? completed,
    int? total,
    int? attempt,
    String? error,
    bool clearError = false,
  }) => OcrQueueEntry(
    id: id,
    title: title,
    subtitle: subtitle,
    status: status ?? this.status,
    completed: completed ?? this.completed,
    total: total ?? this.total,
    attempt: attempt ?? this.attempt,
    error: clearError ? null : error ?? this.error,
  );
}

/// Process-wide pre-OCR queue.
///
/// Jobs run one chapter at a time because [ReaderOcrState] owns a single scan
/// generation. Each chapter receives three automatic attempts. A terminal
/// failure stays visible until the user retries it or clears finished items.
class OcrProcessingQueueController {
  OcrProcessingQueueController({
    this.maxAutomaticAttempts = 3,
    Future<void> Function(Duration duration)? delay,
  }) : _delay = delay ?? Future<void>.delayed;

  static final instance = OcrProcessingQueueController();

  final int maxAutomaticAttempts;
  final Future<void> Function(Duration duration) _delay;
  final entries = ValueNotifier<List<OcrQueueEntry>>(const []);

  final Map<String, OcrQueueOperation> _operations = {};
  final Queue<String> _pending = Queue<String>();
  bool _draining = false;
  Completer<void>? _idleCompleter;

  bool get hasErrors =>
      entries.value.any((entry) => entry.status == OcrQueueStatus.error);

  bool get isBusy => entries.value.any(
    (entry) =>
        entry.status == OcrQueueStatus.pending ||
        entry.status == OcrQueueStatus.processing,
  );

  void enqueue(Iterable<OcrQueueRequest> requests) {
    final updated = entries.value.toList();
    for (final request in requests) {
      final index = updated.indexWhere((entry) => entry.id == request.id);
      if (index != -1 &&
          (updated[index].status == OcrQueueStatus.pending ||
              updated[index].status == OcrQueueStatus.processing)) {
        continue;
      }
      _operations[request.id] = request.operation;
      final entry = OcrQueueEntry(
        id: request.id,
        title: request.title,
        subtitle: request.subtitle,
        status: OcrQueueStatus.pending,
      );
      if (index == -1) {
        updated.add(entry);
      } else {
        updated[index] = entry;
      }
      if (!_pending.contains(request.id)) _pending.add(request.id);
    }
    entries.value = List.unmodifiable(updated);
    _startDrain();
  }

  bool retry(String id) {
    final entry = _entry(id);
    if (entry == null ||
        entry.status != OcrQueueStatus.error ||
        !_operations.containsKey(id)) {
      return false;
    }
    _replace(
      entry.copyWith(
        status: OcrQueueStatus.pending,
        completed: 0,
        total: 0,
        attempt: 0,
        clearError: true,
      ),
    );
    if (!_pending.contains(id)) _pending.add(id);
    _startDrain();
    return true;
  }

  void retryAllErrors() {
    for (final entry in entries.value.toList()) {
      retry(entry.id);
    }
  }

  void clearFinished() {
    final retained = entries.value
        .where((entry) => entry.status != OcrQueueStatus.completed)
        .toList(growable: false);
    final retainedIds = retained.map((entry) => entry.id).toSet();
    _operations.removeWhere((id, _) => !retainedIds.contains(id));
    entries.value = List.unmodifiable(retained);
  }

  Future<void> waitUntilIdle() {
    if (!_draining && _pending.isEmpty) return Future<void>.value();
    return (_idleCompleter ??= Completer<void>()).future;
  }

  @visibleForTesting
  void reset() {
    _pending.clear();
    _operations.clear();
    _draining = false;
    _idleCompleter?.complete();
    _idleCompleter = null;
    entries.value = const [];
  }

  void _startDrain() {
    if (_draining || _pending.isEmpty) return;
    _idleCompleter ??= Completer<void>();
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final id = _pending.removeFirst();
        final operation = _operations[id];
        final initial = _entry(id);
        if (operation == null ||
            initial == null ||
            initial.status != OcrQueueStatus.pending) {
          continue;
        }
        await _runEntry(initial, operation);
      }
    } finally {
      _draining = false;
      final completer = _idleCompleter;
      _idleCompleter = null;
      if (completer != null && !completer.isCompleted) completer.complete();
      if (_pending.isNotEmpty) _startDrain();
    }
  }

  Future<void> _runEntry(
    OcrQueueEntry initial,
    OcrQueueOperation operation,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAutomaticAttempts; attempt++) {
      _replace(
        (_entry(initial.id) ?? initial).copyWith(
          status: OcrQueueStatus.processing,
          attempt: attempt,
          clearError: true,
        ),
      );
      try {
        await operation((completed, total) {
          final current = _entry(initial.id);
          if (current == null || current.status != OcrQueueStatus.processing) {
            return;
          }
          _replace(current.copyWith(completed: completed, total: total));
        });
        final current = _entry(initial.id);
        if (current != null) {
          _replace(
            current.copyWith(
              status: OcrQueueStatus.completed,
              completed: current.total == 0 ? 1 : current.total,
              total: current.total == 0 ? 1 : current.total,
              clearError: true,
            ),
          );
        }
        return;
      } catch (error) {
        lastError = error;
        if (attempt < maxAutomaticAttempts) {
          await _delay(Duration(seconds: 1 << (attempt - 1)));
        }
      }
    }
    final current = _entry(initial.id);
    if (current != null) {
      _replace(
        current.copyWith(
          status: OcrQueueStatus.error,
          error: _readableError(lastError),
        ),
      );
    }
  }

  OcrQueueEntry? _entry(String id) {
    for (final entry in entries.value) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  void _replace(OcrQueueEntry replacement) {
    entries.value = List.unmodifiable([
      for (final entry in entries.value)
        if (entry.id == replacement.id) replacement else entry,
    ]);
  }

  static String _readableError(Object? error) {
    final text = error?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (text.isEmpty) return 'OCR processing failed';
    return text.length <= 180 ? text : '${text.substring(0, 177)}...';
  }
}
