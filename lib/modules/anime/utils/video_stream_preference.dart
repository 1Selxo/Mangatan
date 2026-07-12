import 'package:mangayomi/models/video.dart';

Video preferredVideoStream(List<Video> videos, String preference) {
  if (videos.isEmpty) throw StateError('Cannot select from an empty video list');
  final target = _StreamLabel.parse(preference);
  if (target.normalized.isEmpty) return videos.first;
  var best = videos.first;
  var bestScore = -1 << 30;
  for (final video in videos) {
    final candidate = _StreamLabel.parse(video.quality);
    final score = candidate.scoreAgainst(target);
    if (score > bestScore) {
      best = video;
      bestScore = score;
    }
  }
  return best;
}

class _StreamLabel {
  const _StreamLabel({
    required this.normalized,
    required this.server,
    required this.variant,
    required this.resolution,
  });

  factory _StreamLabel.parse(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final parts = normalized
        .split(RegExp(r'\s*-\s*'))
        .where((part) => part.isNotEmpty)
        .toList();
    final resolutionMatch = RegExp(r'(\d{3,4})\s*p\b').firstMatch(normalized);
    final variant = parts.firstWhere(
      (part) => const {'sub', 'hsub', 'dub', 'raw'}.contains(part),
      orElse: () => '',
    );
    return _StreamLabel(
      normalized: normalized,
      server: parts.isEmpty ? '' : parts.first,
      variant: variant,
      resolution: int.tryParse(resolutionMatch?.group(1) ?? ''),
    );
  }

  final String normalized;
  final String server;
  final String variant;
  final int? resolution;

  int scoreAgainst(_StreamLabel target) {
    if (normalized == target.normalized) return 100000;
    var score = 0;
    if (server.isNotEmpty && server == target.server) score += 1000;
    if (variant.isNotEmpty && variant == target.variant) score += 500;
    if (resolution != null && target.resolution != null) {
      final difference = (resolution! - target.resolution!).abs();
      score += difference == 0
          ? 250
          : (200 - difference).clamp(-500, 200).toInt();
    }
    return score;
  }
}
