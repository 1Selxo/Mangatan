import 'package:mangayomi/modules/anime/utils/audio_track_label.dart';
import 'package:media_kit/media_kit.dart';

final _audioDecoderErrorPattern = RegExp(
  r'''failed to initialize a decoder for codec\s+['"]([^'"]+)['"]''',
  caseSensitive: false,
);

/// Returns the codec from a libmpv audio decoder initialization error.
String? audioDecoderCodecFromError(String message) {
  return _audioDecoderErrorPattern.firstMatch(message)?.group(1)?.trim();
}

bool isAudioDecoderInitializationError(String message) {
  return audioDecoderCodecFromError(message) != null;
}

String audioTrackFallbackKey(AudioTrack track) {
  return '${track.uri ? 'external' : 'embedded'}:${track.id}';
}

/// Orders playable alternatives while retaining the order provided by mpv.
/// Tracks in the requested language are always preferred, and a codec that has
/// already failed is excluded because another track using it cannot recover the
/// same decoder failure.
List<AudioTrack> audioTrackFallbackCandidates({
  required AudioTrack failedTrack,
  required Iterable<AudioTrack> availableTracks,
  String? requestedLanguage,
  Set<String> failedTrackKeys = const {},
  Set<String> failedCodecs = const {},
}) {
  final failedKey = audioTrackFallbackKey(failedTrack);
  final failedCodec = _normalizedCodec(failedTrack.codec);
  final excludedCodecs = <String>{
    ...failedCodecs.map((codec) => codec.trim().toLowerCase()),
    ?failedCodec,
  };

  final candidates = availableTracks
      .where(
        (track) =>
            track.id != 'auto' &&
            track.id != 'no' &&
            audioTrackFallbackKey(track) != failedKey &&
            !failedTrackKeys.contains(audioTrackFallbackKey(track)) &&
            !_isExcludedCodec(track.codec, excludedCodecs),
      )
      .toList();

  final language = requestedLanguage ?? failedTrack.language;
  if (language == null || language.trim().isEmpty) return candidates;

  final matching = candidates
      .where((track) => audioTrackLanguagesMatch(track.language, language))
      .toList();
  if (matching.isEmpty) return candidates;

  return [
    ...matching,
    ...candidates.where((track) => !matching.contains(track)),
  ];
}

String? _normalizedCodec(String? codec) {
  final normalized = codec?.trim().toLowerCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

bool _isExcludedCodec(String? codec, Set<String> excludedCodecs) {
  final normalized = _normalizedCodec(codec);
  return normalized != null && excludedCodecs.contains(normalized);
}
