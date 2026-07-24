import 'dart:io';
import 'dart:math';

import 'package:media_kit/media_kit.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const _sentenceAudioPadding = Duration(milliseconds: 250);
const _sentenceAudioMaxDuration = Duration(seconds: 35);

class SubtitleAudioTiming {
  const SubtitleAudioTiming({required this.start, required this.end});

  final Duration start;
  final Duration end;

  Duration get duration => end - start;
}

class AnimeSentenceAudioSnapshot {
  const AnimeSentenceAudioSnapshot({
    required this.source,
    required this.timing,
  });

  final String source;
  final SubtitleAudioTiming timing;
}

class AnimeSentenceAudioService {
  const AnimeSentenceAudioService();

  static Future<AnimeSentenceAudioSnapshot> snapshot({
    required Player player,
    required String fallbackSource,
    required Duration fallbackPosition,
    Duration subtitleDelay = Duration.zero,
  }) async {
    var source = fallbackSource;
    Duration? subtitleStart;
    Duration? subtitleEnd;
    var currentPosition = fallbackPosition;

    final platform = player.platform;
    if (platform is NativePlayer) {
      try {
        final values = await Future.wait([
          platform.getProperty('path'),
          platform.getProperty('sub-start'),
          platform.getProperty('sub-end'),
          platform.getProperty('time-pos'),
        ]);
        if (values[0].trim().isNotEmpty) source = values[0].trim();
        subtitleStart = _parseDuration(values[1]);
        subtitleEnd = _parseDuration(values[2]);
        currentPosition = _parseDuration(values[3]) ?? fallbackPosition;
      } catch (_) {}
    }

    return AnimeSentenceAudioSnapshot(
      source: source,
      timing: subtitleAudioTimingForCue(
        subtitleStart: subtitleStart,
        subtitleEnd: subtitleEnd,
        currentPosition: currentPosition,
        subtitleDelay: subtitleDelay,
      ),
    );
  }

  Future<AnkiMediaFile> capture({
    required String source,
    required SubtitleAudioTiming timing,
    required AnkiSentenceAudioFormat format,
    required String sourceTitle,
    required String chapterTitle,
    Map<String, String>? headers,
  }) async {
    if (!_isDesktop) {
      throw StateError('Sentence audio export is available on desktop only.');
    }
    final ffmpeg = await _findFfmpeg();
    if (ffmpeg == null) {
      throw StateError(
        'Sentence audio requires ffmpeg. Install it or set FFMPEG_PATH.',
      );
    }

    final identifier = DateTime.now().microsecondsSinceEpoch.toString();
    final temporaryDirectory = await getTemporaryDirectory();
    final output = File(
      path.join(
        temporaryDirectory.path,
        'mangatan-sentence-$identifier.${format.name}',
      ),
    );
    try {
      final result = await Process.run(
        ffmpeg,
        sentenceAudioFfmpegArguments(
          source: source,
          headers: headers,
          timing: timing,
          format: format,
          outputPath: output.path,
        ),
      );
      if (result.exitCode != 0 || !await output.exists()) {
        final details = '${result.stderr}\n${result.stdout}'.trim();
        throw StateError(
          'Sentence audio capture failed${details.isEmpty ? '' : ': ${details.substring(0, min(details.length, 500))}'}',
        );
      }
      final bytes = await output.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Sentence audio capture produced an empty file.');
      }
      return AnkiMediaFile(
        filename: _filename(sourceTitle, chapterTitle, identifier, format),
        bytes: bytes,
      );
    } finally {
      if (await output.exists()) await output.delete();
    }
  }
}

SubtitleAudioTiming subtitleAudioTimingForCue({
  Duration? subtitleStart,
  Duration? subtitleEnd,
  required Duration currentPosition,
  Duration subtitleDelay = Duration.zero,
  Duration padding = _sentenceAudioPadding,
}) {
  if (subtitleStart != null) subtitleStart += subtitleDelay;
  if (subtitleEnd != null) subtitleEnd += subtitleDelay;
  var start =
      subtitleStart ??
      currentPosition - const Duration(seconds: 1, milliseconds: 500);
  if (start.isNegative) start = Duration.zero;
  final fallbackEnd = start + const Duration(seconds: 4);
  final currentEnd =
      currentPosition + const Duration(seconds: 2, milliseconds: 500);
  var end = subtitleEnd != null && subtitleEnd > start
      ? subtitleEnd
      : fallbackEnd < currentEnd
      ? fallbackEnd
      : currentEnd;
  start -= padding;
  if (start.isNegative) start = Duration.zero;
  end += padding;
  if (end < start + const Duration(milliseconds: 250)) {
    end = start + const Duration(milliseconds: 250);
  }
  if (end - start > _sentenceAudioMaxDuration) {
    end = start + _sentenceAudioMaxDuration;
  }
  return SubtitleAudioTiming(start: start, end: end);
}

List<String> sentenceAudioFfmpegArguments({
  required String source,
  required SubtitleAudioTiming timing,
  required AnkiSentenceAudioFormat format,
  required String outputPath,
  Map<String, String>? headers,
}) {
  final isHlsInput = _isHlsInput(source);
  final httpHeaders = _httpHeadersArgument(headers);
  final codecArguments = switch (format) {
    AnkiSentenceAudioFormat.mp3 => const [
      '-codec:a',
      'libmp3lame',
      '-b:a',
      '96k',
    ],
    AnkiSentenceAudioFormat.opus => const [
      '-codec:a',
      'libopus',
      '-b:a',
      '96k',
    ],
  };
  return [
    '-nostdin',
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    if (isHlsInput) ...[
      '-allowed_extensions',
      'ALL',
      '-allowed_segment_extensions',
      'ALL',
      '-extension_picky',
      '0',
    ],
    if (httpHeaders != null) ...['-headers', httpHeaders],
    '-ss',
    _seconds(timing.start),
    '-i',
    source,
    '-t',
    _seconds(timing.duration),
    '-map',
    '0:a:0',
    '-vn',
    '-sn',
    '-dn',
    '-threads',
    '2',
    ...codecArguments,
    outputPath,
  ];
}

Duration? _parseDuration(String value) {
  final seconds = double.tryParse(value.trim());
  if (seconds == null || !seconds.isFinite || seconds < 0) return null;
  return Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );
}

String? _httpHeadersArgument(Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) return null;
  final values = headers.entries
      .map(
        (entry) =>
            '${entry.key.replaceAll(RegExp(r'[\r\n]'), '')}: ${entry.value.replaceAll(RegExp(r'[\r\n]'), '')}',
      )
      .where((value) => value.trim() != ':')
      .toList();
  return values.isEmpty ? null : '${values.join('\r\n')}\r\n';
}

String _seconds(Duration value) =>
    (value.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(3);

bool _isHlsInput(String source) {
  final uri = Uri.tryParse(source);
  final path = uri?.path.toLowerCase() ?? source.toLowerCase();
  return path.endsWith('.m3u8') || path.endsWith('.m3u') || path == '/m3u8';
}

bool get _isDesktop =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

Future<String?> _findFfmpeg() async {
  final executableName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
  final environmentPath = Platform.environment['FFMPEG_PATH'];
  final candidates = <String>[
    if (environmentPath?.trim().isNotEmpty ?? false) environmentPath!,
    path.join(path.dirname(Platform.resolvedExecutable), executableName),
    if (Platform.isMacOS) '/opt/homebrew/bin/ffmpeg',
    if (Platform.isMacOS) '/usr/local/bin/ffmpeg',
    if (Platform.isMacOS) '/Applications/IINA.app/Contents/MacOS/ffmpeg',
    if (!Platform.isWindows) '/usr/bin/ffmpeg',
    if (!Platform.isWindows) '/usr/local/bin/ffmpeg',
  ];
  for (final candidate in candidates) {
    if (await File(candidate).exists()) return candidate;
  }
  try {
    final lookup = await Process.run(
      Platform.isWindows ? 'where' : '/usr/bin/which',
      [executableName],
    );
    if (lookup.exitCode == 0) {
      final result = lookup.stdout.toString().trim().split(RegExp(r'\r?\n'));
      if (result.isNotEmpty && result.first.isNotEmpty) return result.first;
    }
  } catch (_) {}
  return null;
}

String _filename(
  String sourceTitle,
  String chapterTitle,
  String identifier,
  AnkiSentenceAudioFormat format,
) {
  final title = [sourceTitle, chapterTitle]
      .where((value) => value.trim().isNotEmpty)
      .join(' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N}._ -]', unicode: true), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  return '${title.isEmpty ? 'sentence' : title}-$identifier.${format.name}';
}
