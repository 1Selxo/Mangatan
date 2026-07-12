String formatNovelProgressPercentage(double progress) {
  return '${(_normalizedProgress(progress) * 100).toStringAsFixed(1)} %';
}

int novelProgressCharacterCount({
  required double progress,
  required int totalCharacterCount,
  int? exactCharacterCount,
}) {
  if (exactCharacterCount != null) {
    return exactCharacterCount < 0 ? 0 : exactCharacterCount;
  }

  final safeTotal = totalCharacterCount < 0 ? 0 : totalCharacterCount;
  return (safeTotal * _normalizedProgress(progress)).floor();
}

String formatNovelReaderProgress({
  required double progress,
  required int totalCharacterCount,
  int? exactCharacterCount,
}) {
  final characterCount = novelProgressCharacterCount(
    progress: progress,
    totalCharacterCount: totalCharacterCount,
    exactCharacterCount: exactCharacterCount,
  );
  return '${formatNovelProgressPercentage(progress)} / $characterCount';
}

double _normalizedProgress(double progress) {
  if (!progress.isFinite) return 0;
  return progress.clamp(0.0, 1.0).toDouble();
}
