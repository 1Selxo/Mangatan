import 'dart:async';

typedef AutoSyncTimerSettings = ({bool syncOn, int frequencySeconds});
typedef PeriodicTimerFactory =
    Timer Function(Duration interval, void Function(Timer timer) callback);
typedef AutoSyncTimerErrorHandler =
    void Function(Object error, StackTrace stackTrace);

/// Fixed internal signal used to stop automatic sync after a reported failure.
///
/// Sync services return failure instead of throwing so manual callers retain
/// their existing toast-only behavior. Automatic callers convert that result
/// into this exception for [AutoSyncTimerController] to handle.
class AutoSyncAttemptFailed implements Exception {
  const AutoSyncAttemptFailed();
}

Future<void> runAutoSyncOrThrow(Future<bool> Function() startSync) async {
  if (!await startSync()) throw const AutoSyncAttemptFailed();
}

Timer _createPeriodicTimer(
  Duration interval,
  void Function(Timer timer) callback,
) => Timer.periodic(interval, callback);

/// Owns the single periodic timer used for automatic sync.
///
/// Calling [configure] is idempotent. A changed preference cancels the old
/// timer before a replacement is created, while disabling sync cancels it
/// immediately. Ticks are also serialized so a slow sync cannot start another
/// automatic sync before it finishes.
class AutoSyncTimerController {
  factory AutoSyncTimerController({
    required FutureOr<void> Function() onTick,
    PeriodicTimerFactory timerFactory = _createPeriodicTimer,
    AutoSyncTimerErrorHandler? onError,
  }) => AutoSyncTimerController._(onTick, timerFactory, onError);

  AutoSyncTimerController._(this._onTick, this._timerFactory, this._onError);

  final FutureOr<void> Function() _onTick;
  final PeriodicTimerFactory _timerFactory;
  final AutoSyncTimerErrorHandler? _onError;

  Timer? _timer;
  Duration? _scheduledInterval;
  bool _tickInProgress = false;
  bool _disposed = false;

  void configure(AutoSyncTimerSettings settings) {
    if (_disposed) return;

    final interval = settings.syncOn && settings.frequencySeconds > 0
        ? Duration(seconds: settings.frequencySeconds)
        : null;
    if (interval == _scheduledInterval &&
        (interval == null || _timer?.isActive == true)) {
      return;
    }

    _cancelTimer();
    if (interval == null) return;

    _scheduledInterval = interval;
    _timer = _timerFactory(interval, _handleTimerTick);
  }

  void _handleTimerTick(Timer timer) {
    if (_disposed || !identical(timer, _timer) || _tickInProgress) return;
    unawaited(_runTick(timer));
  }

  Future<void> _runTick(Timer timer) async {
    _tickInProgress = true;
    try {
      await _onTick();
    } catch (error, stackTrace) {
      if (!_disposed && identical(timer, _timer)) {
        _cancelTimer();
        _onError?.call(error, stackTrace);
      }
    } finally {
      _tickInProgress = false;
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _scheduledInterval = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelTimer();
  }
}
