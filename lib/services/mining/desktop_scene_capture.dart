import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:mangayomi/services/mining/animated_avif_validator.dart';
import 'package:mangayomi/services/mining/desktop_ffmpeg.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/scene_capture_timing.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const desktopScenePreparationTimeout = Duration(seconds: 60);

class SceneSourceAssessment {
  const SceneSourceAssessment._({
    required this.supported,
    required this.input,
    this.reason,
  });

  const SceneSourceAssessment.supported(String input)
    : this._(supported: true, input: input);

  const SceneSourceAssessment.unsupported(String input, String reason)
    : this._(supported: false, input: input, reason: reason);

  final bool supported;
  final String input;
  final String? reason;
}

SceneSourceAssessment assessSceneSource({
  required String source,
  required Map<String, String> headers,
  required bool seekable,
}) {
  final trimmed = source.trim();
  if (!seekable) {
    return SceneSourceAssessment.unsupported(trimmed, 'input is not seekable');
  }
  if (trimmed.isEmpty) {
    return const SceneSourceAssessment.unsupported('', 'input is empty');
  }
  for (final entry in headers.entries) {
    final name = entry.key.trim().toLowerCase();
    if (entry.key.contains(RegExp(r'[\r\n]')) ||
        entry.value.contains(RegExp(r'[\r\n]'))) {
      return SceneSourceAssessment.unsupported(
        trimmed,
        'headers contain line breaks',
      );
    }
    if (!_safeHeaderNames.contains(name)) {
      return SceneSourceAssessment.unsupported(
        trimmed,
        'input requires authenticated or unsupported headers',
      );
    }
  }

  final directFile = File(trimmed);
  if (directFile.isAbsolute) {
    return SceneSourceAssessment.supported(directFile.path);
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme.isEmpty) {
    return SceneSourceAssessment.unsupported(trimmed, 'local path is relative');
  }
  if (uri.scheme == 'file') {
    try {
      return SceneSourceAssessment.supported(uri.toFilePath());
    } on UnsupportedError {
      return SceneSourceAssessment.unsupported(
        trimmed,
        'file URL is not local',
      );
    }
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return SceneSourceAssessment.unsupported(
      trimmed,
      'only local files and public HTTP inputs are supported',
    );
  }
  if (uri.userInfo.isNotEmpty || !_isPublicHost(uri.host)) {
    return SceneSourceAssessment.unsupported(
      trimmed,
      'HTTP input is authenticated or private',
    );
  }
  final lowerPath = uri.path.toLowerCase();
  if (lowerPath.endsWith('.mpd') ||
      lowerPath.contains('/dash/') ||
      lowerPath.endsWith('/manifest')) {
    return SceneSourceAssessment.unsupported(
      trimmed,
      'DASH inputs are not supported',
    );
  }
  for (final key in uri.queryParameters.keys) {
    if (_signedQueryKey.hasMatch(key)) {
      return SceneSourceAssessment.unsupported(
        trimmed,
        'signed or transient HTTP URLs are not supported',
      );
    }
  }
  return SceneSourceAssessment.supported(trimmed);
}

class SceneMediaProbe {
  const SceneMediaProbe({
    required this.formatNames,
    required this.duration,
    required this.videoStreams,
    required this.audioStreamIndexes,
  });

  factory SceneMediaProbe.fromJson(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('ffprobe root is not an object');
    }
    final format = decoded['format'];
    final streams = decoded['streams'];
    if (format is! Map || streams is! List) {
      throw const FormatException('ffprobe response is incomplete');
    }
    final durationSeconds = double.tryParse('${format['duration'] ?? ''}');
    final formatNames = '${format['format_name'] ?? ''}'
        .split(',')
        .map((name) => name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    final videoStreams = <SceneVideoStream>[];
    final audioIndexes = <int>[];
    for (final raw in streams.whereType<Map>()) {
      final index = raw['index'];
      if (index is! num) continue;
      final type = '${raw['codec_type'] ?? ''}';
      if (type == 'audio') {
        audioIndexes.add(index.toInt());
      } else if (type == 'video') {
        final tags = raw['tags'] is Map ? raw['tags'] as Map : const {};
        final sideData = raw['side_data_list'] is List
            ? raw['side_data_list'] as List
            : const [];
        videoStreams.add(
          SceneVideoStream(
            index: index.toInt(),
            width: (raw['width'] as num?)?.toInt() ?? 0,
            height: (raw['height'] as num?)?.toInt() ?? 0,
            pixelFormat: '${raw['pix_fmt'] ?? ''}'.toLowerCase(),
            bitsPerRawSample:
                int.tryParse('${raw['bits_per_raw_sample'] ?? ''}') ?? 0,
            colorTransfer: '${raw['color_transfer'] ?? ''}'.toLowerCase(),
            protected:
                '${tags['ENCODER'] ?? ''}'.toLowerCase().contains(
                  'encrypted',
                ) ||
                sideData.any(
                  (entry) =>
                      '$entry'.toLowerCase().contains('encryption') ||
                      '$entry'.toLowerCase().contains('dolby vision'),
                ),
          ),
        );
      }
    }
    if (durationSeconds == null ||
        !durationSeconds.isFinite ||
        durationSeconds <= 0) {
      throw const FormatException('ffprobe duration is unavailable');
    }
    return SceneMediaProbe(
      formatNames: formatNames,
      duration: Duration(
        microseconds: (durationSeconds * Duration.microsecondsPerSecond)
            .round(),
      ),
      videoStreams: videoStreams,
      audioStreamIndexes: audioIndexes,
    );
  }

  final Set<String> formatNames;
  final Duration duration;
  final List<SceneVideoStream> videoStreams;
  final List<int> audioStreamIndexes;

  SceneVideoStream? selectVideo(int? selectedIndex) {
    if (videoStreams.isEmpty) return null;
    if (selectedIndex == null) return videoStreams.first;
    for (final stream in videoStreams) {
      if (stream.index == selectedIndex) return stream;
    }
    return null;
  }
}

class SceneVideoStream {
  const SceneVideoStream({
    required this.index,
    required this.width,
    required this.height,
    required this.pixelFormat,
    required this.bitsPerRawSample,
    required this.colorTransfer,
    required this.protected,
  });

  final int index;
  final int width;
  final int height;
  final String pixelFormat;
  final int bitsPerRawSample;
  final String colorTransfer;
  final bool protected;

  bool get isHdrOrHighBitDepth =>
      bitsPerRawSample > 8 ||
      RegExp(
        r'(?:^|[^0-9])p?0?(10|12|14|16)(?:le|be|$)',
      ).hasMatch(pixelFormat) ||
      colorTransfer == 'smpte2084' ||
      colorTransfer == 'arib-std-b67';
}

class DesktopSceneCaptureService {
  const DesktopSceneCaptureService({
    this.validator = const AnimatedAvifValidator(),
    this.preparationTimeout = desktopScenePreparationTimeout,
    this.temporaryDirectoryProvider,
  });

  final AnimatedAvifValidator validator;
  final Duration preparationTimeout;
  final Future<Directory> Function()? temporaryDirectoryProvider;

  Future<AnkiScreenshotPreparation> prepare({
    required AnkiSceneCaptureHandle capture,
    required AnkiExportJobSession session,
    DesktopFfmpegTools? tools,
  }) async {
    final stopwatch = Stopwatch()..start();
    final fallback = await _withDeadline(
      stopwatch,
      _frozenStill(capture.fallbackScreenshot),
      preparationTimeout,
    );
    File? output;
    Process? process;
    var outputOwnedByResult = false;
    session.registerCancel(() {
      process?.kill();
    });
    try {
      session.throwIfCancelled();
      if (!isDesktopPlatform) {
        return _fallbackWithDiagnostic(fallback, 'not a desktop platform');
      }
      final source = assessSceneSource(
        source: capture.playerSource,
        headers: capture.headers,
        seekable: capture.seekable,
      );
      if (!source.supported) {
        return _fallbackWithDiagnostic(
          fallback,
          source.reason ?? 'unsupported source',
        );
      }
      if (!await _hasOnlyPublicAddresses(
        source.input,
        remaining: _remaining(stopwatch, preparationTimeout),
      )) {
        return _fallbackWithDiagnostic(
          fallback,
          'HTTP input does not resolve to a public address',
        );
      }
      if (!await capture.validatePlayerState()) {
        return _fallbackWithDiagnostic(fallback, 'player state changed');
      }
      session.throwIfCancelled();

      final resolvedTools = tools ?? await DesktopFfmpegTools.discover();
      if (resolvedTools == null) {
        return _fallbackWithDiagnostic(fallback, 'ffmpeg tools unavailable');
      }
      final encoders = await _run(
        resolvedTools.ffmpeg,
        const ['-hide_banner', '-encoders'],
        remaining: _remaining(stopwatch, preparationTimeout),
        onStarted: (value) => process = value,
      );
      process = null;
      session.throwIfCancelled();
      final muxers = await _run(
        resolvedTools.ffmpeg,
        const ['-hide_banner', '-muxers'],
        remaining: _remaining(stopwatch, preparationTimeout),
        onStarted: (value) => process = value,
      );
      process = null;
      if (encoders.exitCode != 0 ||
          muxers.exitCode != 0 ||
          !supportsAnimatedAvifCapabilities(
            '${encoders.stdout}\n${encoders.stderr}',
            '${muxers.stdout}\n${muxers.stderr}',
          )) {
        return _fallbackWithDiagnostic(
          fallback,
          'ffmpeg lacks libaom-av1 or the AVIF muxer',
        );
      }
      session.throwIfCancelled();

      final probeResult = await _run(
        resolvedTools.ffprobe,
        sceneFfprobeArguments(source: source.input, headers: capture.headers),
        remaining: _remaining(stopwatch, preparationTimeout),
        onStarted: (value) => process = value,
      );
      process = null;
      if (probeResult.exitCode != 0) {
        return _fallbackWithDiagnostic(fallback, 'ffprobe failed');
      }
      final probe = SceneMediaProbe.fromJson(probeResult.stdout);
      if (probe.formatNames.contains('dash')) {
        return _fallbackWithDiagnostic(fallback, 'DASH input');
      }
      final video = probe.selectVideo(capture.videoStreamIndex);
      if (video == null ||
          video.protected ||
          video.isHdrOrHighBitDepth ||
          video.width <= 0 ||
          video.height <= 0) {
        return _fallbackWithDiagnostic(
          fallback,
          'video stream is missing, protected, HDR, or high bit depth',
        );
      }
      if (!await capture.validatePlayerState()) {
        return _fallbackWithDiagnostic(fallback, 'player state changed');
      }
      session.throwIfCancelled();

      final temporaryDirectory =
          await (temporaryDirectoryProvider?.call() ?? getTemporaryDirectory());
      output = File(
        path.join(
          temporaryDirectory.path,
          'mangatan-scene-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}.avif',
        ),
      );
      final encodeResult = await _run(
        resolvedTools.ffmpeg,
        animatedAvifFfmpegArguments(
          source: source.input,
          headers: capture.headers,
          timing: SceneTimingRange(
            start: capture.sceneStart,
            end: capture.sceneEnd,
          ),
          videoStreamIndex: video.index,
          outputPath: output.path,
        ),
        remaining: _remaining(stopwatch, preparationTimeout),
        onStarted: (value) => process = value,
      );
      process = null;
      session.throwIfCancelled();
      if (encodeResult.exitCode != 0 || !await output.exists()) {
        return _fallbackWithDiagnostic(
          fallback,
          'ffmpeg encode failed: ${encodeResult.stderr}',
        );
      }
      if (await output.length() > animatedAvifMaxBytes) {
        return _fallbackWithDiagnostic(fallback, 'AVIF exceeds 10 MiB');
      }
      await validator.validateFile(output);
      final hash = sha256.convert(await output.readAsBytes()).toString();
      outputOwnedByResult = true;
      return AnkiScreenshotPreparation(
        filename: 'mangatan-scene-$hash.avif',
        source: AnkiMediaSource.file(output, deleteOnDispose: true),
        fallbackFilename: fallback.fallbackFilename,
        fallbackSource: fallback.fallbackSource,
        animated: true,
      );
    } on AnkiExportCancelledException {
      rethrow;
    } on TimeoutException {
      process?.kill();
      return _fallbackWithDiagnostic(fallback, 'preparation timed out');
    } catch (error) {
      return _fallbackWithDiagnostic(fallback, '$error');
    } finally {
      session.registerCancel(() {});
      if (output != null && await output.exists() && !outputOwnedByResult) {
        await output.delete();
      }
    }
  }
}

AnkiScreenshotPreparation _fallbackWithDiagnostic(
  AnkiScreenshotPreparation fallback,
  String diagnostic,
) {
  return AnkiScreenshotPreparation(
    filename: fallback.filename,
    source: fallback.source,
    fallbackFilename: fallback.fallbackFilename,
    fallbackSource: fallback.fallbackSource,
    diagnostic: diagnostic,
  );
}

List<String> sceneFfprobeArguments({
  required String source,
  Map<String, String> headers = const {},
}) {
  final headerValue = sceneHttpHeadersArgument(headers);
  return [
    '-v',
    'error',
    if (_isHls(source)) ...[
      '-allowed_extensions',
      'ALL',
      '-allowed_segment_extensions',
      'ALL',
      '-extension_picky',
      '0',
    ],
    if (headerValue != null) ...['-headers', headerValue],
    '-show_format',
    '-show_streams',
    '-of',
    'json',
    source,
  ];
}

List<String> animatedAvifFfmpegArguments({
  required String source,
  required SceneTimingRange timing,
  required int videoStreamIndex,
  required String outputPath,
  Map<String, String> headers = const {},
}) {
  final headerValue = sceneHttpHeadersArgument(headers);
  final isHls = _isHls(source);
  return [
    '-nostdin',
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    if (isHls) ...[
      '-allowed_extensions',
      'ALL',
      '-allowed_segment_extensions',
      'ALL',
      '-extension_picky',
      '0',
    ],
    if (headerValue != null) ...['-headers', headerValue],
    '-ss',
    _seconds(timing.start),
    '-i',
    source,
    '-t',
    _seconds(timing.duration),
    '-map',
    '0:$videoStreamIndex',
    '-an',
    '-sn',
    '-dn',
    '-vf',
    'fps=8,scale=w=min(640\\,iw):h=min(640\\,ih):force_original_aspect_ratio=decrease:force_divisible_by=2',
    '-frames:v',
    '$animatedAvifMaxFrames',
    '-pix_fmt',
    'yuv420p',
    '-c:v',
    'libaom-av1',
    '-crf',
    '35',
    '-cpu-used',
    '8',
    '-loop',
    '0',
    '-f',
    'avif',
    outputPath,
  ];
}

String? sceneHttpHeadersArgument(Map<String, String> headers) {
  if (headers.isEmpty) return null;
  final safe = headers.entries
      .where((entry) => _safeHeaderNames.contains(entry.key.toLowerCase()))
      .map(
        (entry) =>
            '${entry.key.replaceAll(RegExp(r'[\r\n]'), '')}: ${entry.value.replaceAll(RegExp(r'[\r\n]'), '')}',
      )
      .toList(growable: false);
  return safe.isEmpty ? null : '${safe.join('\r\n')}\r\n';
}

bool supportsAnimatedAvifCapabilities(String encoders, String muxers) {
  return encoders.contains('libaom-av1') &&
      RegExp(r'^\s*E\s+avif\s', multiLine: true).hasMatch(muxers);
}

Future<AnkiScreenshotPreparation> _frozenStill(Uint8List original) async {
  final encoded = await Isolate.run(() => _encodeStill(original));
  final bytes = encoded.$1;
  final extension = encoded.$2;
  final hash = sha256.convert(bytes).toString();
  final filename = 'mangatan-still-$hash.$extension';
  final source = AnkiMediaSource.bytes(bytes);
  return AnkiScreenshotPreparation(
    filename: filename,
    source: source,
    fallbackFilename: filename,
    fallbackSource: source,
  );
}

(Uint8List, String) _encodeStill(Uint8List original) {
  try {
    final decoded = image.decodeImage(original);
    if (decoded == null) return (original, _imageExtension(original));
    final longest = max(decoded.width, decoded.height);
    final resized = longest > 1280
        ? image.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 1280 : null,
            height: decoded.height > decoded.width ? 1280 : null,
            interpolation: image.Interpolation.average,
          )
        : decoded;
    final jpeg = Uint8List.fromList(image.encodeJpg(resized, quality: 82));
    return jpeg.length < original.length
        ? (jpeg, 'jpg')
        : (original, _imageExtension(original));
  } catch (_) {
    return (original, _imageExtension(original));
  }
}

String _imageExtension(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'jpg';
  }
  if (bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'webp';
  }
  return 'png';
}

Future<_ProcessResult> _run(
  String executable,
  List<String> arguments, {
  required Duration remaining,
  required void Function(Process process) onStarted,
}) async {
  if (remaining <= Duration.zero) throw TimeoutException('deadline expired');
  final process = await Process.start(executable, arguments, runInShell: false);
  onStarted(process);
  final stdout = process.stdout
      .transform(utf8.decoder)
      .join()
      .then((value) => _bounded(value));
  final stderr = process.stderr
      .transform(utf8.decoder)
      .join()
      .then((value) => _bounded(value));
  try {
    final exitCode = await process.exitCode.timeout(remaining);
    return _ProcessResult(
      exitCode: exitCode,
      stdout: await stdout,
      stderr: await stderr,
    );
  } on TimeoutException {
    process.kill();
    rethrow;
  }
}

Future<T> _withDeadline<T>(
  Stopwatch stopwatch,
  Future<T> future,
  Duration timeout,
) => future.timeout(_remaining(stopwatch, timeout));

Duration _remaining(Stopwatch stopwatch, Duration timeout) {
  final remaining = timeout - stopwatch.elapsed;
  if (remaining <= Duration.zero) {
    throw TimeoutException('scene preparation timed out');
  }
  return remaining;
}

String _bounded(String value) {
  const maxOutputCharacters = 1 << 20;
  if (value.length <= maxOutputCharacters) return value;
  const half = maxOutputCharacters ~/ 2;
  return '${value.substring(0, half)}\n'
      '... process output truncated ...\n'
      '${value.substring(value.length - half)}';
}

String _seconds(Duration value) =>
    (value.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(3);

bool _isHls(String source) {
  final uri = Uri.tryParse(source);
  final value = (uri?.path ?? source).toLowerCase();
  return value.endsWith('.m3u8') || value.endsWith('.m3u') || value == '/m3u8';
}

bool _isPublicHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized.isEmpty ||
      normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized.endsWith('.local')) {
    return false;
  }
  final ipv4 = normalized.split('.').map(int.tryParse).toList();
  if (ipv4.length == 4 && ipv4.every((part) => part != null)) {
    return _isPublicIpv4(ipv4.cast<int>());
  }
  if (normalized == '::' ||
      normalized == '::1' ||
      normalized.startsWith('fc') ||
      normalized.startsWith('fd') ||
      RegExp(r'^fe[89ab]').hasMatch(normalized) ||
      normalized.startsWith('ff') ||
      normalized.startsWith('2001:db8:')) {
    return false;
  }
  if (normalized.startsWith('::ffff:')) {
    final mapped = normalized.substring('::ffff:'.length);
    final parts = mapped.split('.').map(int.tryParse).toList();
    return parts.length == 4 && parts.every((part) => part != null)
        ? _isPublicIpv4(parts.cast<int>())
        : false;
  }
  return true;
}

bool _isPublicIpv4(List<int> parts) {
  if (parts.length != 4 || parts.any((part) => part < 0 || part > 255)) {
    return false;
  }
  final a = parts[0];
  final b = parts[1];
  final c = parts[2];
  return !(a == 0 ||
      a == 10 ||
      a == 127 ||
      (a == 100 && b >= 64 && b <= 127) ||
      (a == 169 && b == 254) ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 0 && (c == 0 || c == 2)) ||
      (a == 192 && b == 168) ||
      (a == 198 && (b == 18 || b == 19 || (b == 51 && c == 100))) ||
      (a == 203 && b == 0 && c == 113) ||
      a >= 224);
}

Future<bool> _hasOnlyPublicAddresses(
  String source, {
  required Duration remaining,
}) async {
  final uri = Uri.tryParse(source);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return true;
  }
  if (!_isPublicHost(uri.host)) return false;
  if (InternetAddress.tryParse(uri.host) != null) return true;
  try {
    final addresses = await InternetAddress.lookup(uri.host).timeout(remaining);
    return addresses.isNotEmpty &&
        addresses.every((address) => _isPublicHost(address.address));
  } catch (_) {
    return false;
  }
}

const _safeHeaderNames = {
  'accept',
  'accept-language',
  'origin',
  'referer',
  'user-agent',
};

final _signedQueryKey = RegExp(
  r'(^|[_-])(auth|authorization|credential|expires?|key|policy|signature|signed|token)([_-]|$)',
  caseSensitive: false,
);

class _ProcessResult {
  const _ProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
