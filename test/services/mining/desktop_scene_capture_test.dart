import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/desktop_ffmpeg.dart';
import 'package:mangayomi/services/mining/desktop_scene_capture.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/scene_capture_timing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('scene source safety', () {
    test('accepts local files and public seekable HLS with safe headers', () {
      expect(
        assessSceneSource(
          source: '/videos/episode.mkv',
          headers: const {},
          seekable: true,
        ).supported,
        isTrue,
      );
      expect(
        sceneFfprobeArguments(
          source: 'https://cdn.example/video/master.m3u8',
          headers: const {'Referer': 'https://example.com'},
        ),
        containsAllInOrder([
          '-allowed_extensions',
          'ALL',
          '-allowed_segment_extensions',
          'ALL',
          '-extension_picky',
          '0',
          '-headers',
          'Referer: https://example.com\r\n',
        ]),
      );
      expect(
        assessSceneSource(
          source: 'https://cdn.example/video/master.m3u8',
          headers: const {
            'Referer': 'https://example.com',
            'User-Agent': 'Mangatan',
          },
          seekable: true,
        ).supported,
        isTrue,
      );
    });

    test(
      'rejects protected, transient, private, DASH, and non-seekable input',
      () {
        for (final assessment in [
          assessSceneSource(
            source: 'https://cdn.example/video.m3u8',
            headers: const {'Authorization': 'Bearer secret'},
            seekable: true,
          ),
          assessSceneSource(
            source: 'https://cdn.example/video.mp4?token=secret',
            headers: const {},
            seekable: true,
          ),
          assessSceneSource(
            source: 'http://127.0.0.1/video.mp4',
            headers: const {},
            seekable: true,
          ),
          assessSceneSource(
            source: 'https://cdn.example/video.mpd',
            headers: const {},
            seekable: true,
          ),
          assessSceneSource(
            source: 'https://cdn.example/video.mp4',
            headers: const {},
            seekable: false,
          ),
        ]) {
          expect(assessment.supported, isFalse);
        }
      },
    );
  });

  test('builds the bounded libaom animated AVIF command exactly', () {
    final arguments = animatedAvifFfmpegArguments(
      source: 'https://cdn.example/master.m3u8',
      headers: const {'Referer': 'https://example.com'},
      timing: const SceneTimingRange(
        start: Duration(seconds: 2),
        end: Duration(seconds: 8),
      ),
      videoStreamIndex: 3,
      outputPath: '/tmp/scene.avif',
    );

    expect(
      arguments,
      containsAllInOrder([
        '-allowed_extensions',
        'ALL',
        '-headers',
        'Referer: https://example.com\r\n',
        '-ss',
        '2.000',
        '-i',
        'https://cdn.example/master.m3u8',
        '-t',
        '6.000',
        '-map',
        '0:3',
        '-vf',
        r'fps=8,scale=w=min(640\,iw):h=min(640\,ih):force_original_aspect_ratio=decrease:force_divisible_by=2',
        '-frames:v',
        '80',
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
        '/tmp/scene.avif',
      ]),
    );
  });

  test('parses stream selection and rejects HDR or high-bit-depth video', () {
    final probe = SceneMediaProbe.fromJson('''
      {
        "format": {"format_name": "matroska,webm", "duration": "30.0"},
        "streams": [
          {"index": 1, "codec_type": "audio"},
          {
            "index": 2,
            "codec_type": "video",
            "width": 1920,
            "height": 1080,
            "pix_fmt": "yuv420p",
            "color_transfer": "bt709"
          },
          {
            "index": 4,
            "codec_type": "video",
            "width": 3840,
            "height": 2160,
            "pix_fmt": "yuv420p10le",
            "bits_per_raw_sample": "10",
            "color_transfer": "smpte2084"
          }
        ]
      }
    ''');

    expect(probe.selectVideo(2)?.isHdrOrHighBitDepth, isFalse);
    expect(probe.selectVideo(4)?.isHdrOrHighBitDepth, isTrue);
    expect(
      const SceneVideoStream(
        index: 5,
        width: 1920,
        height: 1080,
        pixelFormat: 'p010le',
        bitsPerRawSample: 0,
        colorTransfer: 'bt709',
        protected: false,
      ).isHdrOrHighBitDepth,
      isTrue,
    );
    expect(probe.selectVideo(99), isNull);
    expect(probe.audioStreamIndexes, [1]);
  });

  test('rejects a changed player state before starting FFmpeg', () async {
    final controller = AnkiExportJobController();
    final session = controller.beginPreparing();
    final result = await const DesktopSceneCaptureService().prepare(
      capture: _capture(validatePlayerState: () async => false),
      session: session,
      tools: const DesktopFfmpegTools(
        ffmpeg: '/does/not/exist',
        ffprobe: '/does/not/exist',
      ),
    );

    expect(result.animated, isFalse);
    expect(result.filename, endsWith('.png'));
    session.finish();
  });

  test('times out preparation and removes the partial output', () async {
    if (!Platform.isLinux && !Platform.isMacOS) return;
    final directory = await Directory.systemTemp.createTemp(
      'mangatan-scene-timeout-',
    );
    final ffmpeg = File('${directory.path}/ffmpeg');
    final ffprobe = File('${directory.path}/ffprobe');
    await ffmpeg.writeAsString('''#!/bin/sh
case " \$* " in
  *" -encoders "*) echo " V..... libaom-av1 libaom AV1"; exit 0 ;;
  *" -muxers "*) echo " E avif AVIF"; exit 0 ;;
esac
last=""
for argument in "\$@"; do last="\$argument"; done
: > "\$last"
sleep 5
''');
    await ffprobe.writeAsString('''#!/bin/sh
echo '{"format":{"format_name":"matroska","duration":"30"},"streams":[{"index":0,"codec_type":"video","width":320,"height":240,"pix_fmt":"yuv420p","color_transfer":"bt709"}]}'
''');
    await Process.run('chmod', ['700', ffmpeg.path, ffprobe.path]);
    final before = await _sceneTemporaryFiles();
    final controller = AnkiExportJobController();
    final session = controller.beginPreparing();
    try {
      final result =
          await const DesktopSceneCaptureService(
            preparationTimeout: Duration(milliseconds: 300),
          ).prepare(
            capture: _capture(validatePlayerState: () async => true),
            session: session,
            tools: DesktopFfmpegTools(
              ffmpeg: ffmpeg.path,
              ffprobe: ffprobe.path,
            ),
          );

      expect(result.animated, isFalse);
      expect(await _sceneTemporaryFiles(), before);
    } finally {
      session.finish();
      await directory.delete(recursive: true);
    }
  });

  test(
    'generates, validates, hashes, and cleans up a real animated AVIF',
    () async {
      if (!Platform.isLinux) return;
      final tools = await DesktopFfmpegTools.discover();
      expect(tools, isNotNull);
      final directory = await Directory.systemTemp.createTemp(
        'mangatan-scene-real-',
      );
      final source = File('${directory.path}/source.mkv');
      final generated = await Process.run(tools!.ffmpeg, [
        '-nostdin',
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=240x320:rate=8',
        '-t',
        '5',
        '-pix_fmt',
        'yuv420p',
        source.path,
      ]);
      expect(generated.exitCode, 0, reason: '${generated.stderr}');
      final controller = AnkiExportJobController();
      final session = controller.beginPreparing();
      final capture = _capture(
        source: source.path,
        validatePlayerState: () async => true,
      );
      try {
        final result = await DesktopSceneCaptureService(
          temporaryDirectoryProvider: () async => directory,
        ).prepare(capture: capture, session: session, tools: tools);

        expect(result.animated, isTrue, reason: result.diagnostic);
        expect(
          result.filename,
          matches(RegExp(r'^mangatan-scene-[0-9a-f]{64}\.avif$')),
        );
        final media = result.source as AnkiFileMediaSource;
        expect(await media.file.exists(), isTrue);
        await result.dispose();
        expect(await media.file.exists(), isFalse);
      } finally {
        session.finish();
        await directory.delete(recursive: true);
      }
    },
  );
}

AnkiSceneCaptureHandle _capture({
  required Future<bool> Function() validatePlayerState,
  String source = '/tmp/input.mkv',
}) {
  final controller = AnkiExportJobController();
  late final AnkiSceneCaptureHandle capture;
  capture = AnkiSceneCaptureHandle(
    fallbackScreenshot: Uint8List.fromList([1, 2, 3]),
    playerSource: source,
    position: const Duration(seconds: 3),
    duration: const Duration(seconds: 30),
    sceneStart: const Duration(seconds: 2),
    sceneEnd: const Duration(seconds: 4),
    audioStart: const Duration(seconds: 2),
    audioEnd: const Duration(seconds: 4),
    subtitleDelay: Duration.zero,
    subtitleSpeed: 1,
    videoStreamIndex: 0,
    audioStreamIndex: 1,
    headers: const {},
    seekable: true,
    jobController: controller,
    validatePlayerState: validatePlayerState,
    prepareAnimatedScreenshot: (_) async {
      throw UnimplementedError();
    },
    disposeCapture: () async {},
  );
  return capture;
}

Future<Set<String>> _sceneTemporaryFiles() async {
  return {
    await for (final entity in Directory.systemTemp.list())
      if (entity is File &&
          entity.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('mangatan-scene-'))
        entity.path,
  };
}
