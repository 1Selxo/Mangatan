enum CrossDeviceSyncPhase {
  exportLocal,
  readSidecars,
  download,
  decode,
  reconcile,
  serialize,
  encode,
  preUpload,
  upload,
  confirmNoOp,
  recheckLocal,
  compareLocal,
  importMerged,
  persistSidecars,
}

/// Timing and volume measurements for one complete synchronization call.
///
/// Durations from conflict retries are accumulated. [readSidecars] and
/// [download] intentionally overlap because both groups are read concurrently.
class CrossDeviceSyncMetrics {
  CrossDeviceSyncMetrics({
    required this.total,
    required Map<CrossDeviceSyncPhase, Duration> phases,
    required this.attempts,
    required this.conflicts,
    required this.remoteBytes,
    required this.protobufBytes,
    required this.uploadBytes,
    required this.uploaded,
    required this.skippedUpload,
    required this.imported,
  }) : phases = Map.unmodifiable(phases);

  final Duration total;
  final Map<CrossDeviceSyncPhase, Duration> phases;
  final int attempts;
  final int conflicts;
  final int remoteBytes;
  final int protobufBytes;
  final int uploadBytes;
  final bool uploaded;
  final bool skippedUpload;
  final bool imported;

  Duration duration(CrossDeviceSyncPhase phase) =>
      phases[phase] ?? Duration.zero;

  String toLogMessage() {
    final phaseValues = [
      for (final phase in CrossDeviceSyncPhase.values)
        if (phases.containsKey(phase))
          '${phase.name}=${_milliseconds(duration(phase))}ms',
    ];
    return 'total=${_milliseconds(total)}ms attempts=$attempts '
        'conflicts=$conflicts remoteBytes=$remoteBytes '
        'protobufBytes=$protobufBytes uploadBytes=$uploadBytes '
        'uploaded=$uploaded skippedUpload=$skippedUpload imported=$imported '
        '${phaseValues.join(' ')}';
  }

  String _milliseconds(Duration duration) =>
      (duration.inMicroseconds / Duration.microsecondsPerMillisecond)
          .toStringAsFixed(2);

  @override
  String toString() => toLogMessage();
}

typedef CrossDeviceSyncMetricsReporter =
    void Function(CrossDeviceSyncMetrics metrics);
