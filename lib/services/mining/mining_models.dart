import 'dart:async';
import 'dart:typed_data';

enum MiningMediaType { manga, anime, novel, unknown }

enum AnkiSentenceAudioFormat { mp3, opus }

class MiningContext {
  final MiningMediaType mediaType;
  final String sourceTitle;
  final String chapterTitle;
  final String sentence;
  final int? pageIndex;
  final Duration? position;
  final Uri? sourceUri;
  final FutureOr<Uint8List?> Function()? imageBytesLoader;
  final FutureOr<AnkiMediaFile?> Function(AnkiSentenceAudioFormat format)?
  sentenceAudioLoader;

  const MiningContext({
    this.mediaType = MiningMediaType.unknown,
    this.sourceTitle = '',
    this.chapterTitle = '',
    this.sentence = '',
    this.pageIndex,
    this.position,
    this.sourceUri,
    this.imageBytesLoader,
    this.sentenceAudioLoader,
  });

  MiningContext copyWith({
    MiningMediaType? mediaType,
    String? sourceTitle,
    String? chapterTitle,
    String? sentence,
    int? pageIndex,
    Duration? position,
    Uri? sourceUri,
    FutureOr<Uint8List?> Function()? imageBytesLoader,
    FutureOr<AnkiMediaFile?> Function(AnkiSentenceAudioFormat format)?
    sentenceAudioLoader,
  }) {
    return MiningContext(
      mediaType: mediaType ?? this.mediaType,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      sentence: sentence ?? this.sentence,
      pageIndex: pageIndex ?? this.pageIndex,
      position: position ?? this.position,
      sourceUri: sourceUri ?? this.sourceUri,
      imageBytesLoader: imageBytesLoader ?? this.imageBytesLoader,
      sentenceAudioLoader: sentenceAudioLoader ?? this.sentenceAudioLoader,
    );
  }

  String get locationLabel {
    final parts = [
      sourceTitle,
      chapterTitle,
      if (pageIndex != null) 'p. ${pageIndex! + 1}',
      if (position != null) _formatDuration(position!),
    ].where((part) => part.trim().isNotEmpty);
    return parts.join(' - ');
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}

class AnkiCardDraft {
  final String deckName;
  final String modelName;
  final String expression;
  final Map<String, String> fields;
  final List<String> tags;
  final String? screenshotFileName;
  final Uint8List? screenshotBytes;
  final List<AnkiMediaFile> mediaFiles;

  const AnkiCardDraft({
    required this.deckName,
    required this.modelName,
    required this.expression,
    required this.fields,
    this.tags = const [],
    this.screenshotFileName,
    this.screenshotBytes,
    this.mediaFiles = const [],
  });
}

class AnkiMediaFile {
  final String filename;
  final Uint8List bytes;

  const AnkiMediaFile({required this.filename, required this.bytes});
}
