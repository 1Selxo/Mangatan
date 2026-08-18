import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

enum MiningMediaType { manga, anime, novel, unknown }

enum AnkiSentenceAudioFormat { mp3, opus }

enum AnkiScreenshotMode {
  full('full'),
  crop('crop'),
  noScreenshot('no_screenshot'),
  animatedScene('animated_scene');

  const AnkiScreenshotMode(this.wireValue);

  final String wireValue;

  static AnkiScreenshotMode fromWireValue(String? value) =>
      AnkiScreenshotMode.values.firstWhere(
        (mode) => mode.wireValue == value,
        orElse: () => AnkiScreenshotMode.full,
      );
}

enum AnkiExportJobState { idle, preparing, committing }

class AnkiExportCancelledException implements Exception {
  const AnkiExportCancelledException();

  @override
  String toString() => 'Anki media preparation was cancelled.';
}

class AnkiExportJobBusyException implements Exception {
  const AnkiExportJobBusyException();

  @override
  String toString() => 'Another scene is already being prepared.';
}

/// Coordinates the single media-preparation job owned by one player.
///
/// Cancellation is deliberately disabled after [beginCommitting], because
/// AnkiConnect media storage and note insertion are no longer transactional.
class AnkiExportJobController {
  final StreamController<AnkiExportJobState> _states =
      StreamController<AnkiExportJobState>.broadcast(sync: true);

  AnkiExportJobState _state = AnkiExportJobState.idle;
  int _generation = 0;
  void Function()? _cancelCurrent;

  AnkiExportJobState get state => _state;
  Stream<AnkiExportJobState> get states => _states.stream;
  bool get canCancel => _state == AnkiExportJobState.preparing;

  AnkiExportJobSession beginPreparing() {
    if (_states.isClosed) {
      throw StateError('The player scene job controller is disposed.');
    }
    if (_state != AnkiExportJobState.idle) {
      throw const AnkiExportJobBusyException();
    }
    final generation = ++_generation;
    _setState(AnkiExportJobState.preparing);
    return AnkiExportJobSession._(this, generation);
  }

  void cancel() {
    if (!canCancel) return;
    _cancelCurrent?.call();
  }

  void _registerCancel(int generation, void Function()? callback) {
    if (_generation == generation && _state == AnkiExportJobState.preparing) {
      _cancelCurrent = callback;
    }
  }

  void _beginCommitting(int generation) {
    if (_generation != generation || _state != AnkiExportJobState.preparing) {
      throw const AnkiExportCancelledException();
    }
    _cancelCurrent = null;
    _setState(AnkiExportJobState.committing);
  }

  void _finish(int generation) {
    if (_generation != generation) return;
    _cancelCurrent = null;
    _setState(AnkiExportJobState.idle);
  }

  void _setState(AnkiExportJobState value) {
    if (_state == value) return;
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  Future<void> dispose() async {
    cancel();
    await _states.close();
  }
}

class AnkiExportJobSession {
  AnkiExportJobSession._(this._controller, this._generation);

  final AnkiExportJobController _controller;
  final int _generation;
  bool _cancelled = false;
  bool _finished = false;

  bool get isCancelled => _cancelled;

  void registerCancel(void Function()? callback) {
    _controller._registerCancel(_generation, () {
      if (_cancelled || _finished) return;
      _cancelled = true;
      callback?.call();
    });
  }

  void throwIfCancelled() {
    if (_cancelled) throw const AnkiExportCancelledException();
  }

  void beginCommitting() {
    throwIfCancelled();
    _controller._beginCommitting(_generation);
  }

  void finish() {
    if (_finished) return;
    _finished = true;
    _controller._finish(_generation);
  }
}

sealed class AnkiMediaSource {
  const AnkiMediaSource();

  factory AnkiMediaSource.bytes(Uint8List bytes) = AnkiBytesMediaSource;

  factory AnkiMediaSource.file(File file, {bool deleteOnDispose = false}) =>
      AnkiFileMediaSource(file, deleteOnDispose: deleteOnDispose);

  Future<int> length();
  Future<Uint8List> readBytes();
  Future<void> dispose();
}

final class AnkiBytesMediaSource extends AnkiMediaSource {
  AnkiBytesMediaSource(Uint8List bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final Uint8List bytes;

  @override
  Future<int> length() async => bytes.length;

  @override
  Future<Uint8List> readBytes() async => bytes;

  @override
  Future<void> dispose() async {}
}

final class AnkiFileMediaSource extends AnkiMediaSource {
  const AnkiFileMediaSource(this.file, {this.deleteOnDispose = false});

  final File file;
  final bool deleteOnDispose;

  @override
  Future<int> length() => file.length();

  @override
  Future<Uint8List> readBytes() => file.readAsBytes();

  @override
  Future<void> dispose() async {
    if (deleteOnDispose && await file.exists()) {
      await file.delete();
    }
  }
}

class AnkiScreenshotPreparation {
  const AnkiScreenshotPreparation({
    required this.filename,
    required this.source,
    required this.fallbackFilename,
    required this.fallbackSource,
    this.animated = false,
    this.warnings = const [],
    this.diagnostic,
  });

  final String filename;
  final AnkiMediaSource source;
  final String fallbackFilename;
  final AnkiMediaSource fallbackSource;
  final bool animated;
  final List<String> warnings;
  final String? diagnostic;

  Future<void> dispose() async {
    await source.dispose();
    if (!identical(source, fallbackSource)) {
      await fallbackSource.dispose();
    }
  }
}

/// Immutable capture state detached from Riverpod and the live player.
class AnkiSceneCaptureHandle {
  AnkiSceneCaptureHandle({
    required Uint8List fallbackScreenshot,
    required this.playerSource,
    required this.position,
    required this.duration,
    required this.sceneStart,
    required this.sceneEnd,
    required this.audioStart,
    required this.audioEnd,
    required this.subtitleDelay,
    required this.subtitleSpeed,
    required this.videoStreamIndex,
    required this.audioStreamIndex,
    required Map<String, String> headers,
    required this.seekable,
    required this.jobController,
    required this.validatePlayerState,
    required this.prepareAnimatedScreenshot,
    required this.disposeCapture,
  }) : fallbackScreenshot = Uint8List.fromList(
         fallbackScreenshot,
       ).asUnmodifiableView(),
       headers = Map<String, String>.unmodifiable(headers);

  final Uint8List fallbackScreenshot;
  final String playerSource;
  final Duration position;
  final Duration duration;
  final Duration sceneStart;
  final Duration sceneEnd;
  final Duration audioStart;
  final Duration audioEnd;
  final Duration subtitleDelay;
  final double subtitleSpeed;
  final int? videoStreamIndex;
  final int? audioStreamIndex;
  final Map<String, String> headers;
  final bool seekable;
  final AnkiExportJobController jobController;
  final Future<bool> Function() validatePlayerState;
  final Future<AnkiScreenshotPreparation> Function(AnkiExportJobSession session)
  prepareAnimatedScreenshot;
  final Future<void> Function() disposeCapture;

  Future<void> dispose() => disposeCapture();
}

class MiningContext {
  final MiningMediaType mediaType;

  /// Local content ID used by Chimahon's per-entry profile override key.
  final int? mangaId;

  /// Source identity used by Chimahon's source override key. Mihon sources
  /// must provide their native Long ID rather than Mangatan's hashed Isar ID.
  final String? sourceId;

  /// BCP-47-style language declared by the source (for example `ja`).
  final String sourceLanguage;

  /// Chimahon's stable string identity for a locally imported novel.
  final String? novelId;
  final String sourceTitle;
  final String chapterTitle;
  final String sentence;
  final int? pageIndex;
  final Duration? position;
  final Uri? sourceUri;
  final FutureOr<Uint8List?> Function()? imageBytesLoader;
  final FutureOr<AnkiMediaFile?> Function(AnkiSentenceAudioFormat format)?
  sentenceAudioLoader;
  final AnkiSceneCaptureHandle? sceneCapture;

  const MiningContext({
    this.mediaType = MiningMediaType.unknown,
    this.mangaId,
    this.sourceId,
    this.sourceLanguage = '',
    this.novelId,
    this.sourceTitle = '',
    this.chapterTitle = '',
    this.sentence = '',
    this.pageIndex,
    this.position,
    this.sourceUri,
    this.imageBytesLoader,
    this.sentenceAudioLoader,
    this.sceneCapture,
  });

  MiningContext copyWith({
    MiningMediaType? mediaType,
    int? mangaId,
    String? sourceId,
    String? sourceLanguage,
    String? novelId,
    String? sourceTitle,
    String? chapterTitle,
    String? sentence,
    int? pageIndex,
    Duration? position,
    Uri? sourceUri,
    FutureOr<Uint8List?> Function()? imageBytesLoader,
    FutureOr<AnkiMediaFile?> Function(AnkiSentenceAudioFormat format)?
    sentenceAudioLoader,
    AnkiSceneCaptureHandle? sceneCapture,
  }) {
    return MiningContext(
      mediaType: mediaType ?? this.mediaType,
      mangaId: mangaId ?? this.mangaId,
      sourceId: sourceId ?? this.sourceId,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      novelId: novelId ?? this.novelId,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      sentence: sentence ?? this.sentence,
      pageIndex: pageIndex ?? this.pageIndex,
      position: position ?? this.position,
      sourceUri: sourceUri ?? this.sourceUri,
      imageBytesLoader: imageBytesLoader ?? this.imageBytesLoader,
      sentenceAudioLoader: sentenceAudioLoader ?? this.sentenceAudioLoader,
      sceneCapture: sceneCapture ?? this.sceneCapture,
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
  final AnkiMediaSource? screenshotSource;
  final List<AnkiMediaFile> mediaFiles;

  const AnkiCardDraft({
    required this.deckName,
    required this.modelName,
    required this.expression,
    required this.fields,
    this.tags = const [],
    this.screenshotFileName,
    this.screenshotBytes,
    this.screenshotSource,
    this.mediaFiles = const [],
  });
}

class AnkiMediaFile {
  final String filename;
  final AnkiMediaSource source;

  AnkiMediaFile({required this.filename, required Uint8List bytes})
    : source = AnkiMediaSource.bytes(bytes);

  const AnkiMediaFile.fromSource({
    required this.filename,
    required this.source,
  });

  Uint8List get bytes {
    final value = source;
    if (value is AnkiBytesMediaSource) return value.bytes;
    throw StateError('File-backed Anki media must be read asynchronously.');
  }

  Future<Uint8List> readBytes() => source.readBytes();
}

class PendingAnkiCard {
  const PendingAnkiCard({
    required this.placeholderDraft,
    required this.prepare,
    this.jobController,
    this.mediaRequests = const [],
  });

  final AnkiCardDraft placeholderDraft;
  final Future<PreparedAnkiCard> Function(AnkiExportJobSession? session)
  prepare;
  final AnkiExportJobController? jobController;
  final List<AnkiMediaRequest> mediaRequests;
}

class AnkiMediaRequest {
  const AnkiMediaRequest({required this.marker, required this.load});

  final String marker;
  final Future<Object?> Function() load;
}

class PreparedAnkiCard {
  const PreparedAnkiCard({
    required this.draft,
    this.screenshot,
    this.warnings = const [],
  });

  final AnkiCardDraft draft;
  final AnkiScreenshotPreparation? screenshot;
  final List<String> warnings;

  Future<void> dispose() async {
    await screenshot?.dispose();
    for (final media in draft.mediaFiles) {
      await media.source.dispose();
    }
  }
}

class AnkiExportResult {
  const AnkiExportResult({required this.noteId, this.warnings = const []});

  final int noteId;
  final List<String> warnings;
}
